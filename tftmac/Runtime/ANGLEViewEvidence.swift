import Foundation

// Normalization runs after collection. Swap, request and presentation identities
// remain separate; these records support only same-guest-clock call latency.
struct ANGLEViewEvidence {
    struct Event: Codable, Sendable {
        let kind: String
        let pid: Int32
        let context: UInt64
        let swap: UInt64
        let guestMonotonicNS: UInt64
        let request: UInt64?
        let durationNS: UInt64?
        let values: [String: UInt64]
    }

    struct Summary: Codable, Sendable {
        var frames: UInt64 = 0
        var spans: UInt64 = 0
        var retainedBindings: UInt64 = 0
        var retainedSyncs: UInt64 = 0
        var creations: UInt64 = 0
        var explicitLoss: UInt64 = 0
        var missingFrames: UInt64 = 0
        var missingSpans: UInt64 = 0
        var malformed: UInt64 = 0
        var duplicates: UInt64 = 0
        var healthy: Bool {
            frames > 0 && explicitLoss == 0 && missingFrames == 0 && missingSpans == 0 && malformed == 0
        }
    }

    private struct Context {
        var swap: UInt64 = 0
        var expected: UInt64 = 0
        var received: UInt64 = 0
        var nextChunk: UInt64 = 0
        var lastRequest: UInt64 = 0
        var createNS: UInt64 = 0
        var receivedNS: UInt64 = 0
        var lost: UInt64 = 0
    }
    let pid: Int32
    private var contexts: [UInt64: Context] = [:]
    private(set) var summary = Summary()

    private mutating func close(_ context: Context) {
        if context.expected > context.received { summary.missingSpans += context.expected - context.received }
        if context.receivedNS > context.createNS ||
            (context.expected == context.received && context.lost == 0 && context.receivedNS != context.createNS) {
            summary.malformed += 1
        }
    }

    mutating func consume(_ line: String, emit: (Event) throws -> Void) throws {
        let parts = line.split(maxSplits: 6, whereSeparator: \.isWhitespace)
        guard parts.count == 7, parts[5] == "TFTMAC_VIEW:", Int32(parts[2]) == pid else { return }
        let fields = parts[6].split(whereSeparator: \.isWhitespace)
        guard fields.count >= 4, fields[1] == "1", let id = UInt64(fields[2]), id > 0,
              let swap = UInt64(fields[3]), swap > 0, swap < UInt64(Int64.max),
              contexts[id] != nil || contexts.count < 64 else { summary.malformed += 1; return }
        var context = contexts[id] ?? Context()
        if fields[0] == "F" {
            let numbers = fields.dropFirst(2).compactMap { UInt64($0) }
            guard numbers.count == 17, fields.count == 19, numbers[2] > 0,
                  numbers[3] <= 1, numbers[15] <= 512,
                  numbers[16] <= numbers[7], numbers[15] == numbers[7] - numbers[16],
                  numbers.allSatisfy({ $0 < UInt64(Int64.max) }) else { summary.malformed += 1; return }
            if swap <= context.swap { summary.duplicates += 1; return }
            close(context)
            summary.missingFrames += swap - context.swap - 1
            context.swap = swap; context.expected = numbers[15]; context.received = 0
            context.nextChunk = 0; context.createNS = numbers[8]; context.receivedNS = 0; context.lost = numbers[16]
            contexts[id] = context
            summary.frames += 1; summary.creations += numbers[7]; summary.explicitLoss += numbers[16]
            summary.retainedBindings += numbers[4]; summary.retainedSyncs += numbers[5]
            let keys = ["context", "swap", "guest_monotonic_ns", "reuse_enabled", "retained_bindings",
                "retained_syncs", "invalidated_syncs", "creates", "create_call_ns", "cache_hits",
                "unchanged", "allocation_changed", "range_changed", "format_changed", "other",
                "span_count", "lost_spans"]
            try emit(Event(kind: "SWAP_AGGREGATE", pid: pid, context: id, swap: swap,
                guestMonotonicNS: numbers[2], request: nil, durationNS: nil,
                values: Dictionary(uniqueKeysWithValues: zip(keys, numbers))))
        } else if fields[0] == "S" {
            guard fields.count == 6, let chunk = UInt64(fields[4]) else { summary.malformed += 1; return }
            if swap < context.swap || (swap == context.swap && chunk < context.nextChunk) {
                summary.duplicates += 1; return
            }
            guard swap == context.swap, chunk == context.nextChunk else { summary.malformed += 1; return }
            let records = fields[5].split(separator: ";")
            guard !records.isEmpty, records.count <= 512 else { summary.malformed += 1; return }
            for record in records {
                let items = record.split(separator: ",", omittingEmptySubsequences: false)
                let n = items.compactMap { UInt64($0) }
                guard items.count == 6, n.count == 6, n[0] > context.lastRequest, n[1] > 0,
                      n[2] < UInt64(Int64.max), context.received < context.expected,
                      n[2] <= UInt64.max - context.receivedNS else { summary.malformed += 1; continue }
                context.lastRequest = n[0]; context.received += 1; context.receivedNS += n[2]
                summary.spans += 1
                try emit(Event(kind: "CREATE_BUFFER_VIEW", pid: pid, context: id, swap: swap,
                    guestMonotonicNS: n[1], request: n[0], durationNS: n[2],
                    values: ["format": n[3], "offset": n[4], "range": n[5]]))
            }
            context.nextChunk += 1; contexts[id] = context
        } else { summary.malformed += 1 }
    }

    mutating func finish() -> Summary {
        for context in contexts.values { close(context) }
        contexts.removeAll()
        return summary
    }

    static func normalize(files: [URL], pid: Int32, emit: (Event) throws -> Void) throws -> Summary {
        var parser = ANGLEViewEvidence(pid: pid)
        for file in files {
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            var pending = Data()
            while let data = try handle.read(upToCount: 128 * 1024), !data.isEmpty {
                pending.append(data)
                while let end = pending.firstIndex(of: 10) {
                    let line = pending[..<end]
                    if line.count <= 16_384 { try parser.consume(String(decoding: line, as: UTF8.self), emit: emit) }
                    else { parser.summary.malformed += 1 }
                    pending.removeSubrange(...end)
                }
                if pending.count > 16_384 { parser.summary.malformed += 1; pending.removeAll() }
            }
            if !pending.isEmpty { parser.summary.malformed += 1 }
        }
        return parser.finish()
    }
}
