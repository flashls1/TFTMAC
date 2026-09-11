import Foundation
import XCTest

final class RuntimeInputChannelTests: XCTestCase {
    func testCancelledConsumerCannotSilentlyAcceptMoreInput() async {
        let channel = RuntimeInputChannel<Int>()
        let failureReported = expectation(description: "terminated consumer reported")
        channel.open(onFailure: { failure in
            XCTAssertEqual(failure, .consumerTerminated)
            failureReported.fulfill()
        })
        let consumer = Task {
            var iterator = channel.stream.makeAsyncIterator()
            _ = try? await iterator.next()
        }
        consumer.cancel()
        await consumer.value
        XCTAssertFalse(channel.send(1))
        await fulfillment(of: [failureReported], timeout: 1)
    }

    func testOrderedInputSurvivesBlockedDiagnosticWorker() async throws {
        let diagnosticStarted = expectation(description: "diagnostic started")
        let unblockDiagnostic = DispatchSemaphore(value: 0)
        DispatchQueue(label: "test.blocked-diagnostic").async {
            diagnosticStarted.fulfill()
            _ = unblockDiagnostic.wait(timeout: .now() + 5)
        }
        defer { unblockDiagnostic.signal() }
        await fulfillment(of: [diagnosticStarted], timeout: 1)

        let channel = RuntimeInputChannel<String>()
        channel.open()
        let collected = Task {
            var values = [String]()
            var delays = [UInt64]()
            for try await event in channel.stream {
                channel.didDequeue()
                values.append(event.payload)
                delays.append(DispatchTime.now().uptimeNanoseconds - event.enqueuedMonotonicNS)
            }
            return (values, delays)
        }
        for event in ["down", "move", "up", "key"] {
            XCTAssertTrue(channel.send(event, nativeEventMonotonicNS: 123))
        }
        channel.finish()
        let (values, delays) = try await collected.value
        XCTAssertEqual(values, ["down", "move", "up", "key"])
        XCTAssertLessThan(try XCTUnwrap(delays.max()), 16_666_667)
    }

    func testOverflowIsExplicitAndDoesNotOverwriteQueuedRelease() async throws {
        let channel = RuntimeInputChannel<String>(capacity: 2)
        channel.open()
        XCTAssertTrue(channel.send("down"))
        XCTAssertTrue(channel.send("up"))
        XCTAssertFalse(channel.send("extra"))
        var values = [String]()
        do {
            for try await event in channel.stream {
                channel.didDequeue()
                values.append(event.payload)
            }
            XCTFail("Overflow must terminate with a visible error")
        } catch {
            XCTAssertEqual(error as? RuntimeInputChannelError, .overflow(capacity: 2))
        }
        XCTAssertEqual(values, ["down", "up"])
    }

    func testCaptureTimestampAndSequenceSurviveDelivery() async throws {
        let channel = RuntimeInputChannel<Int>(capacity: 2)
        XCTAssertFalse(channel.send(0))
        channel.open()
        XCTAssertTrue(channel.send(1, nativeEventMonotonicNS: 99))
        XCTAssertTrue(channel.send(2))
        channel.finish()
        var events = [RuntimeInputEnvelope<Int>]()
        for try await event in channel.stream { events.append(event) }
        XCTAssertEqual(events.map(\.sequence), [1, 2])
        XCTAssertEqual(events.first?.nativeEventMonotonicNS, 99)
        XCTAssertNil(events.last?.nativeEventMonotonicNS)
        XCTAssertFalse(channel.send(3))
        channel.open()
        XCTAssertFalse(channel.send(4))
    }
}
