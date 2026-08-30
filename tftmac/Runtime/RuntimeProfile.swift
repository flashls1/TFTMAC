import Foundation

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
        angleDisabledFeatures: "preferSubmitAtFBOBoundary"
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

    static func load(from defaults: UserDefaults = .standard) -> Self {
        let baseline = Self.playable
        let vCPU = supportedValue(defaults.integer(forKey: PreferenceKey.vCPU), in: supportedVCPU) ?? baseline.vCPU
        let ramMiB = supportedValue(defaults.integer(forKey: PreferenceKey.ramMiB), in: supportedRAMMiB) ?? baseline.ramMiB
        let refreshHz = supportedValue(defaults.integer(forKey: PreferenceKey.refreshHz), in: supportedRefreshHz) ?? baseline.refreshHz
        let flush = supportedValue(
            defaults.integer(forKey: PreferenceKey.asgDrawFlushInterval),
            in: supportedASGDrawFlushIntervals
        ) ?? baseline.asgDrawFlushInterval
        return baseline.with(vCPU: vCPU, ramMiB: ramMiB, refreshHz: refreshHz, asgDrawFlushInterval: flush)
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(vCPU, forKey: PreferenceKey.vCPU)
        defaults.set(ramMiB, forKey: PreferenceKey.ramMiB)
        defaults.set(refreshHz, forKey: PreferenceKey.refreshHz)
        defaults.set(asgDrawFlushInterval, forKey: PreferenceKey.asgDrawFlushInterval)
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
            angleDisabledFeatures: angleDisabledFeatures
        )
    }

    private static func supportedValue(_ candidate: Int, in allowed: [Int]) -> Int? {
        allowed.contains(candidate) ? candidate : nil
    }
}
