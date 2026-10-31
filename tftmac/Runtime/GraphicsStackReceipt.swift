import CryptoKit
import Foundation

enum TFTSelectedGameRHI: String, Sendable, Equatable {
    case openGLESAngle = "OPENGL_ES_ANGLE"
    case vulkan = "VULKAN"
    case unknown = "UNKNOWN"

    var confidence: String {
        switch self {
        case .unknown: return "UNKNOWN"
        case .openGLESAngle, .vulkan: return "DIRECT_SELECTED_RHI_ENGINE_LOG"
        }
    }
}

enum TFTSelectedGameRHIParser {
    /// Selects the game's RHI from the engine's selection/initialization lines.
    /// Capability lines such as `VulkanRHI is available` are deliberately not
    /// sufficient evidence of the selected route.
    static func parse(_ engineLog: String) -> TFTSelectedGameRHI {
        let hasOpenGLRHI = engineLog.contains("LogRHI: Initializing OpenGL RHI")
        let hasAngleRenderer = engineLog.range(
            of: "GL_RENDERER: ANGLE",
            options: [.caseInsensitive]
        ) != nil
        let hasVulkanRHI = engineLog.contains("LogRHI: Initializing Vulkan RHI")
            || engineLog.contains("Creating Vulkan Device")

        if hasOpenGLRHI && hasAngleRenderer && !hasVulkanRHI {
            return .openGLESAngle
        }
        if hasVulkanRHI && !hasOpenGLRHI {
            return .vulkan
        }
        return .unknown
    }
}

struct GraphicsStackReceiptField: Sendable, Equatable {
    let value: String
    let source: String
    let confidence: String

    var isExplicitlyUnknown: Bool {
        confidence.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() == "UNKNOWN"
    }
}

enum GraphicsStackReceiptCompleteness: String, Sendable, Equatable {
    case complete = "COMPLETE"
    case partial = "PARTIAL"
    case unknown = "UNKNOWN"
}

struct GraphicsStackReceipt: Sendable, Equatable {
    let fields: [String: GraphicsStackReceiptField]

    var canonicalJSON: String {
        let object = Dictionary(uniqueKeysWithValues: fields.map { key, field in
            (
                key,
                [
                    "value": field.value,
                    "source": field.source,
                    "confidence": field.confidence
                ]
            )
        })
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    var sha256: String {
        SHA256.hash(data: Data(canonicalJSON.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func explicitUnknownKeys() -> [String] {
        fields.compactMap { key, field in field.isExplicitlyUnknown ? key : nil }.sorted()
    }

    func unresolvedRequiredKeys(requiredKeys: Set<String>) -> [String] {
        requiredKeys.filter { key in
            guard let field = fields[key] else { return true }
            return field.isExplicitlyUnknown
        }.sorted()
    }

    func completeness(requiredKeys: Set<String>) -> GraphicsStackReceiptCompleteness {
        let unresolved = unresolvedRequiredKeys(requiredKeys: requiredKeys)
        if unresolved.isEmpty { return .complete }
        return unresolved.count == requiredKeys.count ? .unknown : .partial
    }
}
