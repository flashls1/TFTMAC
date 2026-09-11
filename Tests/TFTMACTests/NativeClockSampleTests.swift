import Foundation
import XCTest

final class NativeClockSampleTests: XCTestCase {
    private let epoch = "0123456789abcdeffedcba9876543210"
    private func sample(_ changes: [String: Any] = [:]) throws -> Data {
        var object: [String: Any] = [
            "schema": 1, "state": "CLOCK_PRECISE", "session_id": epoch, "sequence": 1,
            "host_t0_ns": 10_000_000, "guest_t1_ns": 13_001_000,
            "guest_t2_ns": 13_002_000, "host_t3_ns": 10_003_000,
            "offset_lower_ns": 2_999_000, "offset_upper_ns": 3_001_000,
            "uncertainty_ns": 1000, "host_clock": "MACH_ABSOLUTE", "guest_clock": "CLOCK_MONOTONIC"
        ]
        object.merge(changes) { _, new in new }
        return try JSONSerialization.data(withJSONObject: object)
    }

    func testNativeExchangeRetainsBoundsAndRejectsClaimedPrecision() throws {
        let parsed = try NativeClockSample.parse(sample(), expectedEpoch: epoch, expectedSequence: 1)
        XCTAssertTrue(parsed.preciseAtSample)
        XCTAssertEqual(parsed.hostMidpointNS, 10_001_500)
        XCTAssertEqual(parsed.roundTripNS, 3000)
        XCTAssertThrowsError(try NativeClockSample.parse(sample(["uncertainty_ns": 0]),
                                                         expectedEpoch: epoch, expectedSequence: 1))
    }

    func testUncertainExchangeIsPreservedWithoutPreciseAttribution() throws {
        let data = try sample(["host_t3_ns": 12_003_000, "offset_lower_ns": 999_000,
                               "uncertainty_ns": 1_001_000, "state": "CLOCK_UNCERTAIN"])
        let parsed = try NativeClockSample.parse(data, expectedEpoch: epoch, expectedSequence: 1)
        XCTAssertFalse(parsed.preciseAtSample)
        XCTAssertThrowsError(try NativeClockSample.parse(
            sample(["host_t3_ns": 12_003_000, "offset_lower_ns": 999_000,
                    "uncertainty_ns": 1_001_000]), expectedEpoch: epoch, expectedSequence: 1))
    }

    func testWrongIdentityDomainAndImpossibleTimestampsFail() throws {
        for changes: [String: Any] in [
            ["sequence": 2], ["session_id": "foreign"], ["schema": 2],
            ["guest_clock": "CLOCK_BOOTTIME"], ["host_clock": "CLOCK_MONOTONIC_RAW"],
            ["guest_t2_ns": 12_000_000], ["guest_t2_ns": 14_000_000],
            ["host_t0_ns": 0], ["host_t3_ns": 9_000_000], ["host_t3_ns": UInt64.max]
        ] {
            XCTAssertThrowsError(try NativeClockSample.parse(sample(changes),
                                                             expectedEpoch: epoch, expectedSequence: 1))
        }
    }

    func testBatchRejectsLostDuplicateAndMalformedSamples() throws {
        let first = try sample()
        let second = try sample(["sequence": 2, "host_t0_ns": 20_000_000,
                                 "host_t3_ns": 20_003_000, "guest_t1_ns": 23_001_000,
                                 "guest_t2_ns": 23_002_000])
        let batch = first + Data("\n".utf8) + second + Data("\n".utf8)
        XCTAssertEqual(try NativeClockBatch.parse(batch, epoch: epoch, count: 2).count, 2)
        for broken in [first, first + Data("\n".utf8) + first,
                       first + Data("\n{\"state\":\"CLOCK_HANDSHAKE_IO_FAILED\"}\n".utf8)] {
            XCTAssertThrowsError(try NativeClockBatch.parse(broken, epoch: epoch, count: 2))
        }
    }

    func testBatchRejectsClockRollbackAcrossExchanges() throws {
        let batch = try sample() + Data("\n".utf8) + sample(["sequence": 2])
        XCTAssertThrowsError(try NativeClockBatch.parse(batch, epoch: epoch, count: 2))
    }
}
