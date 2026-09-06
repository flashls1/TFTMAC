#pragma once

#include <stdint.h>

// Wire format 1 is little-endian, used only between the owned arm64 Android
// guest and arm64 macOS host. Session and sequence are checked on every reply.
typedef struct {
    char magic[8];
    uint32_t version;
    uint32_t size;
    uint64_t session[2];
    uint64_t sequence;
    uint64_t host_send_ns;
    uint64_t guest_receive_ns;
    uint64_t guest_send_ns;
    uint32_t guest_clock;
    uint32_t status;
    uint64_t reserved;
} TFTClockPacket;

typedef struct {
    int64_t offset_lower_ns;
    int64_t offset_upper_ns;
    uint64_t uncertainty_ns;
    int precise;
} TFTClockCalibration;

enum { TFT_CLOCK_MONOTONIC = 1, TFT_CLOCK_MAX_UNCERTAINTY_NS = 500000 };

int TFTClockCalibrate(const TFTClockPacket *request, const TFTClockPacket *reply,
                      uint64_t host_receive_ns, TFTClockCalibration *calibration);
void TFTClockInitialize(TFTClockPacket *packet, uint64_t session0, uint64_t session1,
                        uint64_t sequence, uint64_t host_send_ns);
