#define _POSIX_C_SOURCE 200809L
#include "ClockHandshake.h"

#include <arpa/inet.h>
#include <errno.h>
#include <inttypes.h>
#include <limits.h>
#include <netinet/tcp.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>
#ifdef __APPLE__
#include <mach/mach_time.h>
#endif

_Static_assert(sizeof(TFTClockPacket) == 80, "Clock wire format drift");
#if __BYTE_ORDER__ != __ORDER_LITTLE_ENDIAN__
#error Clock wire format 1 requires a little-endian target
#endif

void TFTClockInitialize(TFTClockPacket *packet, uint64_t session0, uint64_t session1,
                        uint64_t sequence, uint64_t host_send_ns) {
    memset(packet, 0, sizeof(*packet));
    memcpy(packet->magic, "TFTCLK01", 8);
    packet->version = 1;
    packet->size = sizeof(*packet);
    packet->session[0] = session0;
    packet->session[1] = session1;
    packet->sequence = sequence;
    packet->host_send_ns = host_send_ns;
}

int TFTClockCalibrate(const TFTClockPacket *request, const TFTClockPacket *reply,
                      uint64_t host_receive_ns, TFTClockCalibration *out) {
    memset(out, 0, sizeof(*out));
    if (memcmp(reply->magic, "TFTCLK01", 8) || reply->version != 1 ||
        reply->size != sizeof(*reply) || reply->status || reply->reserved ||
        reply->guest_clock != TFT_CLOCK_MONOTONIC ||
        memcmp(request->session, reply->session, sizeof(request->session)) ||
        request->sequence != reply->sequence || request->host_send_ns != reply->host_send_ns ||
        !request->host_send_ns || !host_receive_ns || !reply->guest_receive_ns || !reply->guest_send_ns ||
        host_receive_ns < request->host_send_ns || reply->guest_send_ns < reply->guest_receive_ns ||
        host_receive_ns > INT64_MAX || request->host_send_ns > INT64_MAX ||
        reply->guest_receive_ns > INT64_MAX || reply->guest_send_ns > INT64_MAX) {
        return 0;
    }
    // Nonnegative one-way transit gives an interval, without assuming symmetry.
    int64_t lower = (int64_t)reply->guest_send_ns - (int64_t)host_receive_ns;
    int64_t upper = (int64_t)reply->guest_receive_ns - (int64_t)request->host_send_ns;
    if (lower > upper) return 0;
    __int128 width = (__int128)upper - lower;
    if (width > UINT64_MAX) return 0;
    out->offset_lower_ns = lower;
    out->offset_upper_ns = upper;
    out->uncertainty_ns = ((uint64_t)width + 1) / 2;
    out->precise = out->uncertainty_ns <= TFT_CLOCK_MAX_UNCERTAINTY_NS;
    return 1;
}

#ifndef TFTMAC_CLOCK_LIBRARY
static uint64_t monotonic_ns(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts)) return 0;
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

static uint64_t host_ns(void) {
#ifdef __APPLE__
    static mach_timebase_info_data_t scale;
    if (!scale.denom && mach_timebase_info(&scale)) return 0;
    return (uint64_t)((__uint128_t)mach_absolute_time() * scale.numer / scale.denom);
#else
    return monotonic_ns();
#endif
}

static int transfer(int fd, void *bytes, size_t size, int sending) {
    char *cursor = bytes;
    while (size) {
        ssize_t count = sending ? send(fd, cursor, size, 0) : recv(fd, cursor, size, 0);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) return 0;
        cursor += count;
        size -= (size_t)count;
    }
    return 1;
}

static int set_timeouts(int fd) {
    const struct timeval timeout = {.tv_sec = 2, .tv_usec = 0};
    const int no_delay = 1;
    return !setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) &&
           !setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout)) &&
           !setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &no_delay, sizeof(no_delay));
}

static int parse_number(const char *text, unsigned long maximum, unsigned long *out) {
    if (!*text || *text == '-') return 0;
    char *end;
    errno = 0;
    unsigned long value = strtoul(text, &end, 10);
    if (errno || *end || !value || value > maximum) return 0;
    *out = value;
    return 1;
}

int main(int argc, char **argv) {
    if (argc != 5 && argc != 7) {
        fprintf(stderr, "usage: clock-handshake server PORT SESSION_HEX0 SESSION_HEX1\n"
                        "       clock-handshake client PORT SESSION_HEX0 SESSION_HEX1 COUNT INTERVAL_MS\n");
        return 2;
    }
    const int guest_server = !strcmp(argv[1], "server-guest");
#ifndef __ANDROID__
    // Never expose the host helper beyond loopback. The Android-only mode is
    // reached through the emulator's host-loopback TCP redirection.
    if (guest_server) return 2;
#endif
    const int server = !strcmp(argv[1], "server") || guest_server;
    if ((!server && strcmp(argv[1], "client")) || (server ? argc != 5 : argc != 7)) return 2;
    unsigned long port, count = 0, interval = 0;
    if (!parse_number(argv[2], 65535, &port) ||
        (!server && (!parse_number(argv[5], 1000000, &count) || !parse_number(argv[6], 1000, &interval)))) return 2;
    uint64_t session[2];
    for (int i = 0; i < 2; ++i) {
        const char *value = argv[3 + i];
        if (strlen(value) != 16 || strspn(value, "0123456789abcdefABCDEF") != 16) return 2;
        session[i] = strtoull(value, NULL, 16);
    }
    signal(SIGPIPE, SIG_IGN);
    int socket_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (socket_fd < 0 || (!server && !set_timeouts(socket_fd))) return 3;
    struct sockaddr_in address = {0};
    address.sin_family = AF_INET;
    const char *bind_address = guest_server ? "0.0.0.0" : "127.0.0.1";
    if (inet_pton(AF_INET, bind_address, &address.sin_addr) != 1) return 3;
    address.sin_port = htons((uint16_t)port);
    if (server) {
        if (bind(socket_fd, (struct sockaddr *)&address, sizeof(address)) || listen(socket_fd, 1)) return 3;
        printf("{\"state\":\"CLOCK_SERVER_READY\",\"pid\":%d,\"port\":%lu,\"bind_address\":\"%s\"}\n",
               getpid(), port, bind_address);
        fflush(stdout);
        for (;;) {
            if (guest_server) {
                // An interrupted host must not leave a permanent guest daemon.
                struct pollfd listener = {.fd = socket_fd, .events = POLLIN};
                int ready;
                do { ready = poll(&listener, 1, 180000); } while (ready < 0 && errno == EINTR);
                if (ready <= 0) { close(socket_fd); return ready == 0 ? 0 : 3; }
            }
            int peer = accept(socket_fd, NULL, NULL);
            if (peer < 0) { if (errno == EINTR) continue; return 3; }
            if (!set_timeouts(peer)) { close(peer); continue; }
            TFTClockPacket packet;
            while (transfer(peer, &packet, sizeof(packet), 0)) {
                uint64_t received = monotonic_ns();
                if (memcmp(packet.magic, "TFTCLK01", 8) || packet.version != 1 ||
                    packet.size != sizeof(packet) || memcmp(packet.session, session, sizeof(session)) ||
                    packet.guest_receive_ns || packet.guest_send_ns || packet.guest_clock ||
                    packet.status || packet.reserved) break;
                packet.guest_receive_ns = received;
                packet.guest_clock = TFT_CLOCK_MONOTONIC;
                packet.guest_send_ns = monotonic_ns();
                if (!transfer(peer, &packet, sizeof(packet), 1)) break;
            }
            close(peer);
        }
    }
    if (connect(socket_fd, (struct sockaddr *)&address, sizeof(address))) return 3;
    for (uint64_t sequence = 1; sequence <= count; ++sequence) {
        TFTClockPacket request, reply;
        TFTClockInitialize(&request, session[0], session[1], sequence, host_ns());
        reply = request;
        if (!transfer(socket_fd, &reply, sizeof(reply), 1) || !transfer(socket_fd, &reply, sizeof(reply), 0)) {
            printf("{\"schema\":1,\"state\":\"CLOCK_HANDSHAKE_IO_FAILED\",\"sequence\":%" PRIu64 "}\n", sequence);
            close(socket_fd);
            return 4;
        }
        const uint64_t received = host_ns();
        TFTClockCalibration calibration;
        const int valid = TFTClockCalibrate(&request, &reply, received, &calibration);
        printf("{\"schema\":1,\"state\":\"%s\",\"session_id\":\"%016" PRIx64 "%016" PRIx64 "\",\"sequence\":%" PRIu64
               ",\"host_t0_ns\":%" PRIu64 ",\"guest_t1_ns\":%" PRIu64
               ",\"guest_t2_ns\":%" PRIu64 ",\"host_t3_ns\":%" PRIu64
               ",\"offset_lower_ns\":%" PRId64 ",\"offset_upper_ns\":%" PRId64
               ",\"uncertainty_ns\":%" PRIu64
               ",\"host_clock\":\"%s\",\"guest_clock\":\"CLOCK_MONOTONIC\"}\n",
               !valid ? "CLOCK_HANDSHAKE_INVALID" : calibration.precise ? "CLOCK_PRECISE" : "CLOCK_UNCERTAIN",
               session[0], session[1], sequence, request.host_send_ns, reply.guest_receive_ns, reply.guest_send_ns, received,
               calibration.offset_lower_ns, calibration.offset_upper_ns, calibration.uncertainty_ns,
#ifdef __APPLE__
               "MACH_ABSOLUTE"
#else
               "CLOCK_MONOTONIC"
#endif
        );
        fflush(stdout);
        if (!valid) { close(socket_fd); return 5; }
        if (sequence < count) {
            struct timespec delay = {.tv_sec = (time_t)(interval / 1000), .tv_nsec = (long)(interval % 1000) * 1000000};
            while (nanosleep(&delay, &delay) && errno == EINTR) {}
        }
    }
    close(socket_fd);
    return 0;
}
#endif
