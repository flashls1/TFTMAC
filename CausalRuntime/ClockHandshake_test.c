#include "ClockHandshake.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    TFTClockPacket request, reply;
    TFTClockCalibration calibration;
    TFTClockInitialize(&request, 11, 22, 1, 10000000);
    reply = request;
    reply.guest_clock = TFT_CLOCK_MONOTONIC;
    reply.guest_receive_ns = 13001000;
    reply.guest_send_ns = 13002000;
    assert(TFTClockCalibrate(&request, &reply, 10003000, &calibration));
    assert(calibration.offset_lower_ns == 2999000 && calibration.offset_upper_ns == 3001000);
    assert(calibration.uncertainty_ns == 1000 && calibration.precise);
    assert(TFTClockCalibrate(&request, &reply, 12003000, &calibration));
    assert(!calibration.precise);
    reply.sequence++;
    assert(!TFTClockCalibrate(&request, &reply, 10003000, &calibration));
    reply.sequence = request.sequence;
    reply.session[1]++;
    assert(!TFTClockCalibrate(&request, &reply, 10003000, &calibration));
    reply.session[1] = request.session[1];
    reply.guest_send_ns = reply.guest_receive_ns - 1;
    assert(!TFTClockCalibrate(&request, &reply, 10003000, &calibration));
    reply.guest_send_ns = reply.guest_receive_ns + 100000;
    assert(!TFTClockCalibrate(&request, &reply, 10003000, &calibration));
    reply.guest_send_ns = 13002000;
    reply.guest_clock = 99;
    assert(!TFTClockCalibrate(&request, &reply, 10003000, &calibration));
    puts("Clock handshake interval, uncertainty, identity, and clock-domain rejection tests passed.");
    return 0;
}
