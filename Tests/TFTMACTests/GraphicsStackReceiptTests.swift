import XCTest

final class GraphicsStackReceiptTests: XCTestCase {
    func testSelectedRHIUsesEngineSelectionInsteadOfVulkanCapability() {
        let engineLog = """
        LogAndroid: VulkanRHI is available, Vulkan capable device detected.
        LogAndroid: FAndroidGPUInfo ANGLE detected with GL_RENDERER string ANGLE (Apple, Vulkan 1.3.0)
        LogAndroid: VulkanRHI will NOT be used:
        LogAndroid:  ** Vulkan is disabled via console variable.
        LogAndroid: OpenGL ES will be used.
        LogRHI: Initializing OpenGL RHI
        LogRHI:   GL_RENDERER: ANGLE (Apple, Vulkan 1.3.0)
        """

        XCTAssertEqual(TFTSelectedGameRHIParser.parse(engineLog), .openGLESAngle)
    }

    func testSelectedRHIRejectsCapabilityOnlyVulkanEvidence() {
        let capabilityOnlyLog = """
        LogAndroid: VulkanRHI is available, Vulkan capable device detected.
        LogAndroid: FAndroidGPUInfo ANGLE detected with GL_RENDERER string ANGLE (Apple, Vulkan 1.3.0)
        """

        XCTAssertEqual(TFTSelectedGameRHIParser.parse(capabilityOnlyLog), .unknown)
    }

    func testSelectedRHIRecognizesVulkanInitialization() {
        let engineLog = """
        LogAndroid: VulkanRHI is available, Vulkan capable device detected.
        LogRHI: Initializing Vulkan RHI
        LogVulkanRHI: Creating Vulkan Device
        """

        XCTAssertEqual(TFTSelectedGameRHIParser.parse(engineLog), .vulkan)
    }

    func testCanonicalJSONAndHashIgnoreFieldInsertionOrder() {
        let surface = GraphicsStackReceiptField(value: "EXACT_LAYER_ACTIVE", source: "SURFACEFLINGER", confidence: "PROVEN")
        let angle = GraphicsStackReceiptField(value: "PROVEN_ACTIVE", source: "EMULATOR_STDERR", confidence: "PROVEN")

        let first = GraphicsStackReceipt(fields: ["surface": surface, "angle": angle])
        let second = GraphicsStackReceipt(fields: ["angle": angle, "surface": surface])

        XCTAssertEqual(first.canonicalJSON, second.canonicalJSON)
        XCTAssertEqual(first.sha256, second.sha256)
    }

    func testFieldValueChangeChangesHash() {
        let baseline = GraphicsStackReceipt(fields: [
            "gfxstream": GraphicsStackReceiptField(value: "PROVEN_ACTIVE", source: "EMULATOR_STDOUT", confidence: "PROVEN")
        ])
        let changed = GraphicsStackReceipt(fields: [
            "gfxstream": GraphicsStackReceiptField(value: "NOT_OBSERVED", source: "EMULATOR_STDOUT", confidence: "PROVEN")
        ])

        XCTAssertNotEqual(baseline.sha256, changed.sha256)
    }

    func testCompletenessAndExplicitUnknownsAreDeterministic() {
        let receipt = GraphicsStackReceipt(fields: [
            "surface": GraphicsStackReceiptField(value: "EXACT_LAYER_ACTIVE", source: "SURFACEFLINGER", confidence: "PROVEN"),
            "moltenvk": GraphicsStackReceiptField(value: "", source: "EMULATOR_STDERR", confidence: "UNKNOWN"),
            "angle": GraphicsStackReceiptField(value: "", source: "ADB_GETPROP", confidence: "UNKNOWN")
        ])

        XCTAssertEqual(receipt.explicitUnknownKeys(), ["angle", "moltenvk"])
        XCTAssertEqual(receipt.unresolvedRequiredKeys(requiredKeys: ["surface", "moltenvk", "gfxstream"]), ["gfxstream", "moltenvk"])
        XCTAssertEqual(receipt.completeness(requiredKeys: ["surface", "moltenvk", "gfxstream"]), .partial)
        XCTAssertEqual(receipt.completeness(requiredKeys: ["moltenvk", "gfxstream"]), .unknown)
        XCTAssertEqual(receipt.completeness(requiredKeys: ["surface"]), .complete)
    }

}
