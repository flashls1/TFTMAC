import Foundation

enum TelemetrySignalClassifier {
    /// Counts only lines that identify an actual memory-pressure victim.
    /// LMKD startup, socket, memevent, tracepoint, and policy messages are not kills.
    static func isConfirmedGuestMemoryKill(_ line: String) -> Bool {
        let lower = line.lowercased()

        if lower.contains("out of memory: killed process") {
            return true
        }

        guard lower.contains("lmkd") || lower.contains("lowmemorykiller") else {
            return false
        }

        return lower.contains("kill '")
            || lower.contains("killing '")
            || lower.contains("kill process ")
            || lower.contains("killing process ")
            || lower.contains("killed process ")
    }
}
