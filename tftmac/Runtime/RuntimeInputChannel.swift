import Foundation

struct RuntimeInputEnvelope<Payload: Sendable>: Sendable {
    let sequence: UInt64
    let nativeEventMonotonicNS: UInt64?
    let enqueuedMonotonicNS: UInt64
    let payload: Payload
}

enum RuntimeInputChannelError: Error, Equatable {
    case overflow(capacity: Int)
    case consumerTerminated
}

/// The input producer never enters the runtime/diagnostics actor. The single
/// consumer preserves enqueue order; overload fails explicitly instead of
/// silently replacing a touch release or keyboard event.
final class RuntimeInputChannel<Payload: Sendable>: @unchecked Sendable {
    typealias Envelope = RuntimeInputEnvelope<Payload>
    typealias Stream = AsyncThrowingStream<Envelope, Error>

    let stream: Stream
    private let continuation: Stream.Continuation
    private let capacity: Int
    private let lock = NSLock()
    private var accepting = false
    private var finished = false
    private var pending = 0
    private var sequence: UInt64 = 0
    private var onEnqueue: (@Sendable (Envelope) -> Void)?
    private var onFailure: (@Sendable (RuntimeInputChannelError) -> Void)?

    init(capacity: Int = 512) {
        precondition(capacity > 0)
        self.capacity = capacity
        // Capacity is enforced under the same lock as sequence assignment.
        // Using a dropping AsyncStream policy would lose input transitions.
        let pair = Stream.makeStream(bufferingPolicy: .unbounded)
        stream = pair.stream
        continuation = pair.continuation
    }

    func open(
        onEnqueue: @escaping @Sendable (Envelope) -> Void = { _ in },
        onFailure: @escaping @Sendable (RuntimeInputChannelError) -> Void = { _ in }
    ) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        self.onEnqueue = onEnqueue
        self.onFailure = onFailure
        accepting = true
    }

    @discardableResult
    func send(_ payload: Payload, nativeEventMonotonicNS: UInt64? = nil) -> Bool {
        lock.lock()
        guard accepting, !finished else {
            lock.unlock()
            return false
        }
        guard pending < capacity else {
            let failure = RuntimeInputChannelError.overflow(capacity: capacity)
            let report = onFailure
            accepting = false
            finished = true
            continuation.finish(throwing: failure)
            lock.unlock()
            report?(failure)
            return false
        }
        sequence &+= 1
        let envelope = Envelope(
            sequence: sequence,
            nativeEventMonotonicNS: nativeEventMonotonicNS,
            enqueuedMonotonicNS: DispatchTime.now().uptimeNanoseconds,
            payload: payload
        )
        pending += 1
        // Receipt is queued before the consumer can queue a dispatch update.
        // This callback must only enqueue telemetry, never perform I/O.
        onEnqueue?(envelope)
        switch continuation.yield(envelope) {
        case .enqueued:
            lock.unlock()
            return true
        case .terminated, .dropped:
            pending -= 1
            accepting = false
            finished = true
            let report = onFailure
            lock.unlock()
            report?(.consumerTerminated)
            return false
        @unknown default:
            accepting = false
            finished = true
            let report = onFailure
            lock.unlock()
            report?(.consumerTerminated)
            return false
        }
    }

    func didDequeue() {
        lock.lock()
        pending = max(0, pending - 1)
        lock.unlock()
    }

    func finish() {
        lock.lock()
        accepting = false
        finished = true
        continuation.finish()
        onEnqueue = nil
        onFailure = nil
        lock.unlock()
    }
}
