import CryptoKit
import Foundation

/// A named, reversible experiment selection. The runtime treats `control` as
/// the normal launch contract; a non-control value must be explicitly applied
/// and recorded by the launch transaction.
enum RuntimeExperimentPreset: String, CaseIterable, Codable, Sendable {
    case control
    case homeRunA = "home_run_a"

    private static let preferenceKey = "runtime.experimentPreset"
    static let baselineEmulatorFeatures = [
        "GLESDynamicVersion",
        "Vulkan",
        "GuestAngle",
        "-GLPipeChecksum",
        "VulkanBatchedDescriptorSetUpdate",
        "AsyncComposeSupport",
        "VirtioGpuFenceContexts"
    ]

    var displayName: String {
        switch self {
        case .control: "Control (Proven Baseline)"
        case .homeRunA: "Home Run A Performance Mode"
        }
    }

    var detail: String {
        switch self {
        case .control:
            "Uses the proven baseline settings."
        case .homeRunA:
            "Requires official TFT Performance Mode Beta to be enabled manually; requests two reversible emulator features on the next launch."
        }
    }

    var requiresManualPerformanceModeBetaConfirmation: Bool {
        self == .homeRunA
    }

    var emulatorFeatureAdditions: [String] {
        switch self {
        case .control: []
        case .homeRunA: ["NativeTextureDecompression", "NoDelayCloseColorBuffer"]
        }
    }

    func effectiveEmulatorFeatures(
        baseline: [String] = RuntimeExperimentPreset.baselineEmulatorFeatures
    ) -> [String] {
        baseline + emulatorFeatureAdditions.filter { !baseline.contains($0) }
    }

    func configurationReceipt(
        baselineFeatures: [String] = RuntimeExperimentPreset.baselineEmulatorFeatures
    ) -> RuntimeExperimentConfigurationReceipt {
        let configuration: [String: Any] = [
            "emulator_features": effectiveEmulatorFeatures(baseline: baselineFeatures),
            "preset": rawValue,
            "requires_manual_performance_mode_beta_confirmation": requiresManualPerformanceModeBetaConfirmation,
            "schema": 1
        ]
        let data = (try? JSONSerialization.data(withJSONObject: configuration, options: [.sortedKeys])) ?? Data()
        return RuntimeExperimentConfigurationReceipt(
            canonicalJSON: String(decoding: data, as: UTF8.self),
            sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        )
    }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let rawValue = defaults.string(forKey: preferenceKey),
              let preset = Self(rawValue: rawValue) else {
            return .control
        }
        return preset
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.preferenceKey)
    }
}

struct RuntimeExperimentConfigurationReceipt: Sendable, Equatable {
    let canonicalJSON: String
    let sha256: String
}

struct TFTMACRuntimeProfile: Codable, Equatable, Sendable {
    static let supportedVCPU = [4, 6, 8]
    static let supportedRAMMiB = [4096, 5120, 6144]
    static let supportedRefreshHz = [30, 60]
    static let supportedASGDrawFlushIntervals = [400, 800]

    static let playable = TFTMACRuntimeProfile(
        identifier: "tftmac_5gb_native_v1",
        width: 1920,
        height: 1080,
        densityDPI: 320,
        refreshHz: 60,
        vCPU: 6,
        ramMiB: 5120,
        gpuMode: "host",
        audioBackend: "coreaudio",
        graphicsTransport: "virtio-gpu-asg",
        asgWriteBufferSize: 1_048_576,
        asgWriteStepSize: 16_384,
        asgDataRingSize: 32_768,
        asgDrawFlushInterval: 800,
        controllerPort: 8554,
        angleEnabledFeatures: "exposeNonConformantExtensionsAndVersions:exposeES32ForTesting",
        angleDisabledFeatures: "preferSubmitAtFBOBoundary",
        experimentPreset: .control
    )

    private enum PreferenceKey {
        static let vCPU = "runtime.vcpu"
        static let ramMiB = "runtime.ramMiB"
        static let refreshHz = "runtime.refreshHz"
        static let asgDrawFlushInterval = "runtime.asgDrawFlushInterval"
    }

    let identifier: String
    let width: Int
    let height: Int
    let densityDPI: Int
    let refreshHz: Int
    let vCPU: Int
    let ramMiB: Int
    let gpuMode: String
    let audioBackend: String
    let graphicsTransport: String
    let asgWriteBufferSize: Int
    let asgWriteStepSize: Int
    let asgDataRingSize: Int
    let asgDrawFlushInterval: Int
    let controllerPort: Int
    let angleEnabledFeatures: String
    let angleDisabledFeatures: String
    let experimentPreset: RuntimeExperimentPreset

    var effectiveEmulatorFeatures: [String] {
        experimentPreset.effectiveEmulatorFeatures()
    }

    var experimentConfigurationReceipt: RuntimeExperimentConfigurationReceipt {
        let configuration: [String: Any] = [
            "angle_disabled_features": angleDisabledFeatures,
            "angle_enabled_features": angleEnabledFeatures,
            "asg_data_ring_size": asgDataRingSize,
            "asg_draw_flush_interval_us": asgDrawFlushInterval,
            "asg_write_buffer_size": asgWriteBufferSize,
            "asg_write_step_size": asgWriteStepSize,
            "audio_backend": audioBackend,
            "controller_port": controllerPort,
            "density_dpi": densityDPI,
            "emulator_features": effectiveEmulatorFeatures,
            "gpu_mode": gpuMode,
            "graphics_transport": graphicsTransport,
            "height": height,
            "moltenvk_fast_math": true,
            "moltenvk_max_active_command_buffers": 64,
            "moltenvk_synchronous_queue_submits": false,
            "preset": experimentPreset.rawValue,
            "ram_mib": ramMiB,
            "refresh_hz": refreshHz,
            "requires_manual_performance_mode_beta_confirmation": experimentPreset.requiresManualPerformanceModeBetaConfirmation,
            "schema": 1,
            "tft_frame_rate_cap": 60,
            "tft_graphics_quality": "medium",
            "tft_performance_mode_beta_expected": experimentPreset == .homeRunA,
            "vcpu": vCPU,
            "width": width
        ]
        let data = (try? JSONSerialization.data(withJSONObject: configuration, options: [.sortedKeys])) ?? Data()
        return RuntimeExperimentConfigurationReceipt(
            canonicalJSON: String(decoding: data, as: UTF8.self),
            sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        )
    }

    /// Hash of every locked comparison value with the experiment intervention
    /// normalized to Control. Candidate runs can only pair with a Control run
    /// carrying this same identity.
    var comparisonConfigurationSHA256: String {
        with(experimentPreset: .control).experimentConfigurationReceipt.sha256
    }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        Self.playable.with(experimentPreset: RuntimeExperimentPreset.load(from: defaults))
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(vCPU, forKey: PreferenceKey.vCPU)
        defaults.set(ramMiB, forKey: PreferenceKey.ramMiB)
        defaults.set(refreshHz, forKey: PreferenceKey.refreshHz)
        defaults.set(asgDrawFlushInterval, forKey: PreferenceKey.asgDrawFlushInterval)
        experimentPreset.save(to: defaults)
    }

    func with(vCPU: Int, ramMiB: Int, refreshHz: Int, asgDrawFlushInterval: Int) -> Self {
        let safeVCPU = Self.supportedValue(vCPU, in: Self.supportedVCPU) ?? self.vCPU
        let safeRAM = Self.supportedValue(ramMiB, in: Self.supportedRAMMiB) ?? self.ramMiB
        let safeRefresh = Self.supportedValue(refreshHz, in: Self.supportedRefreshHz) ?? self.refreshHz
        let safeFlush = Self.supportedValue(
            asgDrawFlushInterval,
            in: Self.supportedASGDrawFlushIntervals
        ) ?? self.asgDrawFlushInterval
        let identifier = "tftmac_native_\(safeRAM)m_\(safeVCPU)c_\(safeRefresh)hz_flush\(safeFlush)"
        return Self(
            identifier: identifier,
            width: width,
            height: height,
            densityDPI: densityDPI,
            refreshHz: safeRefresh,
            vCPU: safeVCPU,
            ramMiB: safeRAM,
            gpuMode: gpuMode,
            audioBackend: audioBackend,
            graphicsTransport: graphicsTransport,
            asgWriteBufferSize: asgWriteBufferSize,
            asgWriteStepSize: asgWriteStepSize,
            asgDataRingSize: asgDataRingSize,
            asgDrawFlushInterval: safeFlush,
            controllerPort: controllerPort,
            angleEnabledFeatures: angleEnabledFeatures,
            angleDisabledFeatures: angleDisabledFeatures,
            experimentPreset: experimentPreset
        )
    }

    func with(experimentPreset: RuntimeExperimentPreset) -> Self {
        let identifier = experimentPreset == .control
            ? self.identifier.replacingOccurrences(of: "_preset_home_run_a", with: "")
            : self.identifier.replacingOccurrences(of: "_preset_home_run_a", with: "") + "_preset_home_run_a"
        return Self(
            identifier: identifier,
            width: width,
            height: height,
            densityDPI: densityDPI,
            refreshHz: refreshHz,
            vCPU: vCPU,
            ramMiB: ramMiB,
            gpuMode: gpuMode,
            audioBackend: audioBackend,
            graphicsTransport: graphicsTransport,
            asgWriteBufferSize: asgWriteBufferSize,
            asgWriteStepSize: asgWriteStepSize,
            asgDataRingSize: asgDataRingSize,
            asgDrawFlushInterval: asgDrawFlushInterval,
            controllerPort: controllerPort,
            angleEnabledFeatures: angleEnabledFeatures,
            angleDisabledFeatures: angleDisabledFeatures,
            experimentPreset: experimentPreset
        )
    }

    private static func supportedValue(_ candidate: Int, in allowed: [Int]) -> Int? {
        allowed.contains(candidate) ? candidate : nil
    }
}
