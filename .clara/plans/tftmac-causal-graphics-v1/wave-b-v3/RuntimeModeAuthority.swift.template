import CryptoKit
import Darwin
import Foundation

enum TFTMACRuntimeLaunchStrategy: String, Codable, Sendable {
    case bundledForwarder = "bundled_forwarder"
    case externalNativeHost = "external_native_host"
    case blocked
}

enum TFTMACRuntimeProfilePolicy: String, Codable, Sendable {
    case validatedNativePreferences = "validated_native_preferences"
    case fixedRegistryProfile = "fixed_registry_profile"
    case blocked
}

enum TFTMACRuntimeHostKind: String, Codable, Sendable {
    case bundledResource = "bundled_resource"
    case externalApplication = "external_application"
}

struct TFTMACSealedReceiptReference: Codable, Equatable, Sendable {
    let path: String
    let sha256: String
    let requiredState: String
}

struct TFTMACRuntimeHostAuthority: Codable, Equatable, Sendable {
    let kind: TFTMACRuntimeHostKind
    let path: String
    let bundleIdentifier: String
    let executableRelativePath: String
    let executableSha256: String?
    let sourcePath: String?
    let sourceSha256: String?
    let infoPlistPath: String?
    let infoPlistSha256: String?
    let buildReceiptResource: String?
}

struct TFTMACRuntimeLockedProfile: Codable, Equatable, Sendable {
    let identifier: String
    let width: Int
    let height: Int
    let densityDpi: Int
    let refreshHz: Int
    let vcpu: Int
    let ramMib: Int
    let gpuMode: String
    let audioBackend: String
    let graphicsTransport: String
    let asgWriteBufferSize: Int
    let asgWriteStepSize: Int
    let asgDataRingSize: Int
    let asgDrawFlushInterval: Int
    let angleEnabledFeatures: String
    let angleDisabledFeatures: String
}

struct TFTMACDiagnosticReceiptAuthority: Codable, Equatable, Sendable {
    let buildId: String
    let runtimeConfigurationSha256: String
    let build: TFTMACSealedReceiptReference
    let clone: TFTMACSealedReceiptReference
    let nativeHost: TFTMACSealedReceiptReference
}

struct TFTMACRuntimeModeSupplementalDefinition: Codable, Equatable, Sendable {
    let mode: TFTMACRuntimeMode
    let stateNamespace: String
    let usesLegacyApplicationSupportRoot: Bool
    let emulatorIdentifier: String
    let launchStrategy: TFTMACRuntimeLaunchStrategy
    let profilePolicy: TFTMACRuntimeProfilePolicy
    let lockedProfile: TFTMACRuntimeLockedProfile?
    let adbSha256: String?
    let adbVendorKeysPolicy: String
    let expectedEmulatorVersionContains: String?
    let emulatorUuids: [String]?
    let qemuPath: String?
    let qemuSha256: String?
    let qemuUuids: [String]?
    let gfxstreamBackendUuids: [String]?
    let hostApplication: TFTMACRuntimeHostAuthority?
    let diagnosticReceipts: TFTMACDiagnosticReceiptAuthority?
}

struct TFTMACRuntimeModeAuthorityDocument: Codable, Equatable, Sendable {
    let schema: Int
    let contract: String
    let selectionEnvironmentVariable: String
    let modes: [String: TFTMACRuntimeModeSupplementalDefinition]
}

struct TFTMACLoadedRuntimeIdentity: Equatable, Sendable {
    let processIdentifier: Int32
    let qemuPath: String
    let qemuSha256: String
    let qemuUuids: [String]
    let gfxstreamBackendPath: String
    let gfxstreamBackendSha256: String
    let gfxstreamBackendUuids: [String]
}

struct TFTMACResolvedRuntimeModeAuthority: Sendable {
    let supplemental: TFTMACRuntimeModeSupplementalDefinition
    let hostApplication: URL
    let applicationSupport: URL
    let globalApplicationSupport: URL
}

struct TFTMACSelectedRuntimeConfiguration: Sendable {
    let registry: TFTMACRuntimeModeRegistry
    let selection: TFTMACRuntimeSelection
    let authority: TFTMACRuntimeModeAuthority
    let profile: TFTMACRuntimeProfile
    let applicationSupport: URL

    static func load(
        savedProfile: TFTMACRuntimeProfile,
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> Self {
        let registry = try TFTMACRuntimeModeRegistry.loadBundled(bundle: bundle)
        let authority = try TFTMACRuntimeModeAuthority.loadBundled(bundle: bundle)
        try authority.validateConsistency(with: registry)
        let selection = try registry.selection(environment: environment)
        let profile = try authority.effectiveProfile(savedProfile: savedProfile, selection: selection)
        return Self(
            registry: registry,
            selection: selection,
            authority: authority,
            profile: profile,
            applicationSupport: authority.applicationSupportURL(for: selection.mode)
        )
    }
}

struct TFTMACRuntimeModeAuthority: Sendable {
    static let expectedContract = "TFTMAC_RUNTIME_MODES_V1"

    let document: TFTMACRuntimeModeAuthorityDocument
    let registrySha256: String

    init(data: Data) throws {
        let observed = Self.sha256Hex(data)
        guard observed == TFTMACRuntimeModeRegistry.expectedRegistrySha256 else {
            throw TFTMACRuntimeModeError(
                message: "TFTMAC supplemental runtime authority rejected registry SHA-256 \(observed)."
            )
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            document = try decoder.decode(TFTMACRuntimeModeAuthorityDocument.self, from: data)
        } catch {
            throw TFTMACRuntimeModeError(
                message: "TFTMAC supplemental runtime authority could not be decoded: \(error.localizedDescription)"
            )
        }
        registrySha256 = observed
        try Self.validateStatic(document)
    }

    static func loadBundled(bundle: Bundle = .main) throws -> Self {
        guard let url = bundle.url(forResource: "runtime-modes", withExtension: "json") else {
            throw TFTMACRuntimeModeError(message: "TFTMAC.app is missing runtime-modes.json.")
        }
        do {
            return try Self(data: Data(contentsOf: url))
        } catch let error as TFTMACRuntimeModeError {
            throw error
        } catch {
            throw TFTMACRuntimeModeError(
                message: "TFTMAC could not read supplemental runtime authority: \(error.localizedDescription)"
            )
        }
    }

    func definition(for mode: TFTMACRuntimeMode) throws -> TFTMACRuntimeModeSupplementalDefinition {
        guard let definition = document.modes[mode.rawValue] else {
            throw TFTMACRuntimeModeError(message: "Supplemental runtime mode \(mode.rawValue) is missing.")
        }
        return definition
    }

    func validateConsistency(with registry: TFTMACRuntimeModeRegistry) throws {
        guard registry.registrySha256 == registrySha256 else {
            throw TFTMACRuntimeModeError(message: "Base and supplemental runtime authority hashes differ.")
        }
        for mode in TFTMACRuntimeMode.allCases {
            let base = try registry.definition(for: mode)
            let supplemental = try definition(for: mode)
            guard base.mode == supplemental.mode else {
                throw TFTMACRuntimeModeError(message: "Runtime mode authority mismatch for \(mode.rawValue).")
            }
        }
    }

    func effectiveProfile(
        savedProfile: TFTMACRuntimeProfile,
        selection: TFTMACRuntimeSelection
    ) throws -> TFTMACRuntimeProfile {
        let supplemental = try definition(for: selection.mode)
        guard let controllerPort = selection.definition.controllerPort else {
            throw TFTMACRuntimeModeError(
                message: "Runtime mode \(selection.mode.rawValue) has no accepted controller port."
            )
        }
        switch supplemental.profilePolicy {
        case .validatedNativePreferences:
            guard selection.mode == .control, savedProfile.controllerPort == controllerPort else {
                throw TFTMACRuntimeModeError(
                    message: "Saved control profile does not match the accepted controller lease."
                )
            }
            return savedProfile
        case .fixedRegistryProfile:
            guard let locked = supplemental.lockedProfile else {
                throw TFTMACRuntimeModeError(
                    message: "Runtime mode \(selection.mode.rawValue) is missing its fixed profile."
                )
            }
            return TFTMACRuntimeProfile(
                identifier: locked.identifier,
                width: locked.width,
                height: locked.height,
                densityDPI: locked.densityDpi,
                refreshHz: locked.refreshHz,
                vCPU: locked.vcpu,
                ramMiB: locked.ramMib,
                gpuMode: locked.gpuMode,
                audioBackend: locked.audioBackend,
                graphicsTransport: locked.graphicsTransport,
                asgWriteBufferSize: locked.asgWriteBufferSize,
                asgWriteStepSize: locked.asgWriteStepSize,
                asgDataRingSize: locked.asgDataRingSize,
                asgDrawFlushInterval: locked.asgDrawFlushInterval,
                controllerPort: controllerPort,
                angleEnabledFeatures: locked.angleEnabledFeatures,
                angleDisabledFeatures: locked.angleDisabledFeatures,
                experimentPreset: .control
            )
        case .blocked:
            throw TFTMACRuntimeModeError(
                message: "Runtime mode \(selection.mode.rawValue) has no accepted profile."
            )
        }
    }

    func applicationSupportURL(for mode: TFTMACRuntimeMode) -> URL {
        let global = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TFTMAC", isDirectory: true)
        guard let supplemental = try? definition(for: mode), !supplemental.usesLegacyApplicationSupportRoot else {
            return global
        }
        return global
            .appendingPathComponent("Modes", isDirectory: true)
            .appendingPathComponent(supplemental.stateNamespace, isDirectory: true)
    }

    func resolveForLaunch(
        selection: TFTMACRuntimeSelection,
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) throws -> TFTMACResolvedRuntimeModeAuthority {
        try selection.validateForLaunch(bundle: bundle, fileManager: fileManager)
        let supplemental = try definition(for: selection.mode)
        try validateModeEvidence(
            base: selection.definition,
            supplemental: supplemental,
            bundle: bundle,
            fileManager: fileManager
        )
        let hostApplication = try resolveHostApplication(
            supplemental: supplemental,
            bundle: bundle,
            fileManager: fileManager
        )
        let global = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TFTMAC", isDirectory: true)
        return TFTMACResolvedRuntimeModeAuthority(
            supplemental: supplemental,
            hostApplication: hostApplication,
            applicationSupport: applicationSupportURL(for: selection.mode),
            globalApplicationSupport: global
        )
    }

    func validateLoadedRuntime(
        processIdentifier: Int32,
        selection: TFTMACRuntimeSelection
    ) throws -> TFTMACLoadedRuntimeIdentity {
        let supplemental = try definition(for: selection.mode)
        guard let qemuPath = supplemental.qemuPath,
              let qemuSha256 = supplemental.qemuSha256,
              let qemuUuids = supplemental.qemuUuids,
              let gfxstreamSha256 = selection.definition.gfxstreamBackendSha256,
              let gfxstreamUuids = supplemental.gfxstreamBackendUuids,
              let controllerPort = selection.definition.controllerPort else {
            throw TFTMACRuntimeModeError(
                message: "Runtime mode \(selection.mode.rawValue) lacks loaded-runtime identity authority."
            )
        }
        let observedExecutable = try Self.processExecutablePath(processIdentifier)
        guard Self.standardized(observedExecutable) == Self.standardized(qemuPath) else {
            throw TFTMACRuntimeModeError(
                message: "Loaded emulator process path \(observedExecutable) does not match \(qemuPath)."
            )
        }
        try Self.validateSHA256(path: qemuPath, expected: qemuSha256, label: "loaded qemu")
        try Self.validateUUIDs(path: qemuPath, expected: qemuUuids, label: "loaded qemu")

        let command = try Self.runCommand(
            executable: "/bin/ps",
            arguments: ["-p", "\(processIdentifier)", "-ww", "-o", "command="],
            timeout: 10
        )
        guard command.status == 0,
              command.output.contains("@\(selection.definition.avdName)"),
              command.output.contains("-port \(selection.definition.consolePort)"),
              command.output.contains("-grpc \(controllerPort)") else {
            throw TFTMACRuntimeModeError(
                message: "Loaded emulator command line does not match the selected AVD and port lease."
            )
        }

        let vmmap = try Self.runCommand(
            executable: "/usr/bin/vmmap",
            arguments: ["-w", "\(processIdentifier)"],
            timeout: 30
        )
        guard vmmap.status == 0,
              vmmap.output.contains(selection.definition.gfxstreamBackendPath) else {
            throw TFTMACRuntimeModeError(
                message: "Loaded emulator did not prove the accepted gfxstream image mapping."
            )
        }
        try Self.validateSHA256(
            path: selection.definition.gfxstreamBackendPath,
            expected: gfxstreamSha256,
            label: "loaded gfxstream backend"
        )
        try Self.validateUUIDs(
            path: selection.definition.gfxstreamBackendPath,
            expected: gfxstreamUuids,
            label: "loaded gfxstream backend"
        )
        return TFTMACLoadedRuntimeIdentity(
            processIdentifier: processIdentifier,
            qemuPath: qemuPath,
            qemuSha256: qemuSha256,
            qemuUuids: qemuUuids,
            gfxstreamBackendPath: selection.definition.gfxstreamBackendPath,
            gfxstreamBackendSha256: gfxstreamSha256,
            gfxstreamBackendUuids: gfxstreamUuids
        )
    }

    private static func validateStatic(_ document: TFTMACRuntimeModeAuthorityDocument) throws {
        guard document.schema == 1,
              document.contract == expectedContract,
              document.selectionEnvironmentVariable == TFTMACRuntimeModeRegistry.environmentKey else {
            throw TFTMACRuntimeModeError(message: "Supplemental runtime-mode contract identity failed.")
        }
        let exactModes = Set(TFTMACRuntimeMode.allCases.map(\.rawValue))
        guard Set(document.modes.keys) == exactModes else {
            throw TFTMACRuntimeModeError(
                message: "Supplemental authority must define exactly control, advanced_diagnostics, and candidate."
            )
        }
        var namespaces = Set<String>()
        for (key, definition) in document.modes {
            guard key == definition.mode.rawValue,
                  !definition.stateNamespace.isEmpty,
                  namespaces.insert(definition.stateNamespace).inserted,
                  !definition.emulatorIdentifier.isEmpty,
                  !definition.adbVendorKeysPolicy.isEmpty else {
                throw TFTMACRuntimeModeError(
                    message: "Supplemental runtime identity is invalid for \(key)."
                )
            }
        }

        guard let control = document.modes[TFTMACRuntimeMode.control.rawValue],
              control.usesLegacyApplicationSupportRoot,
              control.stateNamespace == "control",
              control.launchStrategy == .bundledForwarder,
              control.profilePolicy == .validatedNativePreferences,
              control.lockedProfile == nil,
              control.adbSha256.map(Self.isSHA256) == true,
              control.emulatorUuids?.isEmpty == false,
              control.qemuPath?.hasPrefix("/") == true,
              control.qemuSha256.map(Self.isSHA256) == true,
              control.qemuUuids?.isEmpty == false,
              control.gfxstreamBackendUuids?.isEmpty == false,
              control.hostApplication?.kind == .bundledResource,
              control.hostApplication?.executableSha256 == nil,
              control.hostApplication?.sourcePath == "RuntimeHost/main.c",
              control.hostApplication?.sourceSha256.map(Self.isSHA256) == true,
              control.hostApplication?.infoPlistPath == "RuntimeHost/Info.plist",
              control.hostApplication?.infoPlistSha256.map(Self.isSHA256) == true,
              control.hostApplication?.buildReceiptResource == "control-host-build.json",
              control.diagnosticReceipts == nil else {
            throw TFTMACRuntimeModeError(message: "Supplemental control authority is incomplete.")
        }

        guard let diagnostics = document.modes[TFTMACRuntimeMode.advancedDiagnostics.rawValue],
              !diagnostics.usesLegacyApplicationSupportRoot,
              diagnostics.stateNamespace == "advanced_diagnostics",
              diagnostics.launchStrategy == .externalNativeHost,
              diagnostics.profilePolicy == .fixedRegistryProfile,
              diagnostics.lockedProfile != nil,
              diagnostics.adbSha256.map(Self.isSHA256) == true,
              diagnostics.emulatorUuids?.isEmpty == false,
              diagnostics.qemuPath?.hasPrefix("/") == true,
              diagnostics.qemuSha256.map(Self.isSHA256) == true,
              diagnostics.qemuUuids?.isEmpty == false,
              diagnostics.gfxstreamBackendUuids?.isEmpty == false,
              diagnostics.hostApplication?.kind == .externalApplication,
              diagnostics.hostApplication?.executableSha256.map(Self.isSHA256) == true,
              diagnostics.hostApplication?.sourcePath == nil,
              diagnostics.hostApplication?.sourceSha256 == nil,
              diagnostics.hostApplication?.infoPlistSha256.map(Self.isSHA256) == true,
              diagnostics.hostApplication?.buildReceiptResource == nil,
              let receipts = diagnostics.diagnosticReceipts,
              receipts.buildId == "gate4-r9-20260901",
              Self.isSHA256(receipts.runtimeConfigurationSha256),
              receipts.build.requiredState == "DIAGNOSTIC_BUILD_IDENTITY_PASS",
              receipts.clone.requiredState == "DIAGNOSTIC_AVD_CLONE_RECEIPT_PASS",
              receipts.nativeHost.requiredState == "DIAGNOSTIC_NATIVE_HOST_BUILD_PASS" else {
            throw TFTMACRuntimeModeError(message: "Supplemental diagnostic authority is incomplete.")
        }

        guard let candidate = document.modes[TFTMACRuntimeMode.candidate.rawValue],
              !candidate.usesLegacyApplicationSupportRoot,
              candidate.stateNamespace == "candidate",
              candidate.launchStrategy == .blocked,
              candidate.profilePolicy == .blocked,
              candidate.lockedProfile == nil,
              candidate.hostApplication == nil,
              candidate.diagnosticReceipts == nil else {
            throw TFTMACRuntimeModeError(message: "Supplemental candidate authority must remain blocked.")
        }
    }

    private func validateModeEvidence(
        base: TFTMACRuntimeModeDefinition,
        supplemental: TFTMACRuntimeModeSupplementalDefinition,
        bundle: Bundle,
        fileManager: FileManager
    ) throws {
        guard let adbSha256 = supplemental.adbSha256,
              let emulatorUuids = supplemental.emulatorUuids,
              let versionFragment = supplemental.expectedEmulatorVersionContains,
              let qemuPath = supplemental.qemuPath,
              let qemuSha256 = supplemental.qemuSha256,
              let qemuUuids = supplemental.qemuUuids,
              let gfxstreamUuids = supplemental.gfxstreamBackendUuids else {
            throw TFTMACRuntimeModeError(
                message: "Runtime mode \(base.mode.rawValue) lacks accepted binary identity evidence."
            )
        }
        try Self.validateSHA256(path: base.adbPath, expected: adbSha256, label: "ADB")
        try Self.validateSHA256(path: qemuPath, expected: qemuSha256, label: "qemu")
        try Self.validateUUIDs(path: qemuPath, expected: qemuUuids, label: "qemu")
        try Self.validateUUIDs(path: base.emulatorPath, expected: emulatorUuids, label: "emulator")
        try Self.validateUUIDs(
            path: base.gfxstreamBackendPath,
            expected: gfxstreamUuids,
            label: "gfxstream backend"
        )
        let version = try Self.runCommand(
            executable: base.emulatorPath,
            arguments: ["-version"],
            timeout: 30
        )
        guard version.status == 0, version.output.contains(versionFragment) else {
            throw TFTMACRuntimeModeError(
                message: "Runtime mode \(base.mode.rawValue) rejected emulator version identity."
            )
        }
        if base.mode == .advancedDiagnostics {
            try validateDiagnosticReceipts(base: base, supplemental: supplemental)
        }
    }

    private func resolveHostApplication(
        supplemental: TFTMACRuntimeModeSupplementalDefinition,
        bundle: Bundle,
        fileManager: FileManager
    ) throws -> URL {
        guard let host = supplemental.hostApplication else {
            throw TFTMACRuntimeModeError(
                message: "Runtime mode \(supplemental.mode.rawValue) has no accepted native host."
            )
        }
        let appURL: URL
        switch host.kind {
        case .bundledResource:
            guard let resources = bundle.resourceURL else {
                throw TFTMACRuntimeModeError(message: "TFTMAC.app has no Resources directory.")
            }
            appURL = resources.appendingPathComponent(host.path, isDirectory: true)
        case .externalApplication:
            appURL = URL(fileURLWithPath: host.path, isDirectory: true)
        }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: appURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw TFTMACRuntimeModeError(
                message: "Runtime mode \(supplemental.mode.rawValue) is missing its native host at \(appURL.path)."
            )
        }
        let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let info = NSDictionary(contentsOf: infoURL),
              info["CFBundleIdentifier"] as? String == host.bundleIdentifier else {
            throw TFTMACRuntimeModeError(
                message: "Runtime mode \(supplemental.mode.rawValue) rejected native-host bundle identity."
            )
        }
        if let expectedInfoPlistSha256 = host.infoPlistSha256 {
            try Self.validateSHA256(
                path: infoURL.path,
                expected: expectedInfoPlistSha256,
                label: "native-host Info.plist"
            )
        }
        let executable = appURL.appendingPathComponent(host.executableRelativePath)
        guard fileManager.isExecutableFile(atPath: executable.path) else {
            throw TFTMACRuntimeModeError(
                message: "Runtime mode \(supplemental.mode.rawValue) native-host executable is missing."
            )
        }
        if let expectedExecutableSha256 = host.executableSha256 {
            try Self.validateSHA256(
                path: executable.path,
                expected: expectedExecutableSha256,
                label: "native-host executable"
            )
        } else if host.buildReceiptResource == nil {
            throw TFTMACRuntimeModeError(
                message: "Runtime mode \(supplemental.mode.rawValue) has no native-host build receipt authority."
            )
        }
        if host.buildReceiptResource != nil {
            try Self.validateControlHostBuildReceipt(host: host, appURL: appURL, bundle: bundle)
        }
        let codesign = try Self.runCommand(
            executable: "/usr/bin/codesign",
            arguments: ["--verify", "--deep", "--strict", appURL.path],
            timeout: 30
        )
        guard codesign.status == 0 else {
            throw TFTMACRuntimeModeError(
                message: "Runtime mode \(supplemental.mode.rawValue) native-host signature is invalid."
            )
        }
        return appURL
    }


    private static func validateControlHostBuildReceipt(
        host: TFTMACRuntimeHostAuthority,
        appURL: URL,
        bundle: Bundle
    ) throws {
        guard let receiptName = host.buildReceiptResource,
              let sourcePath = host.sourcePath,
              let sourceSha256 = host.sourceSha256,
              let infoPlistPath = host.infoPlistPath,
              let infoPlistSha256 = host.infoPlistSha256,
              let resources = bundle.resourceURL else {
            throw TFTMACRuntimeModeError(message: "Control native-host build receipt authority is incomplete.")
        }
        let receiptURL = resources.appendingPathComponent(receiptName)
        guard let data = try? Data(contentsOf: receiptURL),
              let receipt = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              string(receipt, ["state"]) == "CONTROL_NATIVE_HOST_BUILD_PASS",
              string(receipt, ["host_application_relative_path"]) == host.path,
              string(receipt, ["bundle_identifier"]) == host.bundleIdentifier,
              string(receipt, ["source_path"]) == sourcePath,
              string(receipt, ["source_sha256"]) == sourceSha256,
              string(receipt, ["info_plist_path"]) == infoPlistPath,
              string(receipt, ["info_plist_sha256"]) == infoPlistSha256,
              string(receipt, ["executable_relative_path"]) == host.executableRelativePath,
              let executableSha256 = string(receipt, ["executable_sha256"]),
              let executableUuids = strings(receipt, ["executable_uuids"]),
              strings(receipt, ["compile_arguments"]) == ["-Os", "-arch", "arm64", "-mmacosx-version-min=15.0"] else {
            throw TFTMACRuntimeModeError(message: "Control native-host signed build receipt is missing or invalid.")
        }
        let executable = appURL.appendingPathComponent(host.executableRelativePath)
        try validateSHA256(path: executable.path, expected: executableSha256, label: "control native-host executable")
        try validateUUIDs(path: executable.path, expected: executableUuids, label: "control native-host executable")
    }

    private func validateDiagnosticReceipts(
        base: TFTMACRuntimeModeDefinition,
        supplemental: TFTMACRuntimeModeSupplementalDefinition
    ) throws {
        guard let authority = supplemental.diagnosticReceipts,
              let host = supplemental.hostApplication,
              let emulatorUuids = supplemental.emulatorUuids,
              let gfxstreamUuids = supplemental.gfxstreamBackendUuids else {
            throw TFTMACRuntimeModeError(message: "Diagnostic receipt authority is missing.")
        }
        let build = try Self.readSealedReceipt(authority.build)
        guard Self.string(build, ["state"]) == authority.build.requiredState,
              Self.string(build, ["build_id"]) == authority.buildId,
              Self.bool(build, ["non_comparable_to_stock"]) == true,
              Self.bool(build, ["control_runtime_touched"]) == false,
              Self.bool(build, ["control_noninterference", "matched"]) == true,
              Self.string(build, ["release_and_tracing", "runtime_configuration_sha256"]) == authority.runtimeConfigurationSha256,
              Self.string(build, ["emulator", "path"]) == base.emulatorPath,
              Self.string(build, ["emulator", "sha256"]) == base.emulatorSha256,
              Self.strings(build, ["emulator", "uuids"]) == emulatorUuids,
              Self.string(build, ["gfxstream_backend", "path"]) == base.gfxstreamBackendPath,
              Self.string(build, ["gfxstream_backend", "sha256"]) == base.gfxstreamBackendSha256,
              Self.strings(build, ["gfxstream_backend", "uuids"]) == gfxstreamUuids else {
            throw TFTMACRuntimeModeError(message: "Diagnostic build receipt structure drifted.")
        }

        let clone = try Self.readSealedReceipt(authority.clone)
        guard Self.string(clone, ["state"]) == authority.clone.requiredState,
              Self.string(clone, ["build_id"]) == authority.buildId,
              Self.string(clone, ["diagnostic_avd", "name"]) == base.avdName,
              Self.string(clone, ["diagnostic_avd", "root"]) == base.avdHome,
              Self.string(clone, ["diagnostic_avd", "avd_path"]) == base.avdDirectory,
              Self.string(clone, ["diagnostic_avd", "ini_path"]) == base.avdIniPath,
              Self.string(clone, ["diagnostic_avd", "config_sha256"]) == base.avdConfigSha256,
              Self.string(clone, ["diagnostic_avd", "ini_sha256"]) == base.avdIniSha256,
              Self.int(clone, ["diagnostic_avd", "adb_server_port"]) == base.adbServerPort,
              Self.int(clone, ["diagnostic_avd", "console_port"]) == base.consolePort,
              Self.string(clone, ["diagnostic_avd", "serial"]) == base.serial,
              Self.string(clone, ["accepted_build", "sha256"]) == authority.build.sha256,
              Self.bool(clone, ["control_noninterference_matched"]) == true,
              Self.bool(clone, ["sealed_before_first_boot"]) == true,
              Self.bool(clone, ["first_boot_attempted"]) == false,
              Self.bool(clone, ["launch_attempted"]) == false,
              Self.bool(clone, ["control_runtime_mutation_attempted"]) == false,
              Self.bool(clone, ["control_avd_touched"]) == false else {
            throw TFTMACRuntimeModeError(message: "Diagnostic stopped-clone receipt structure drifted.")
        }

        let nativeHost = try Self.readSealedReceipt(authority.nativeHost)
        guard let expectedHostExecutableSha256 = host.executableSha256 else {
            throw TFTMACRuntimeModeError(message: "Diagnostic native-host executable SHA-256 authority is missing.")
        }
        let expectedHostPath = host.path
        let expectedExecutable = URL(fileURLWithPath: expectedHostPath, isDirectory: true)
            .appendingPathComponent(host.executableRelativePath).path
        guard Self.string(nativeHost, ["state"]) == authority.nativeHost.requiredState,
              Self.string(nativeHost, ["build_id"]) == authority.buildId,
              Self.string(nativeHost, ["app", "path"]) == expectedHostPath,
              Self.string(nativeHost, ["app", "bundle_identifier"]) == host.bundleIdentifier,
              Self.string(nativeHost, ["app", "executable", "path"]) == expectedExecutable,
              Self.string(nativeHost, ["app", "executable", "sha256"]) == expectedHostExecutableSha256,
              Self.int(nativeHost, ["app", "codesign_verify_status"]) == 0,
              Self.string(nativeHost, ["launch_contract", "method"])?.contains("/usr/bin/open") == true,
              Self.string(nativeHost, ["launch_contract", "emulator_spawn_owner"]) == "NATIVE_MACOS_APP_PROCESS",
              Self.bool(nativeHost, ["launch_contract", "service_context_emulator_spawn_forbidden"]) == true,
              Self.bool(nativeHost, ["control_runtime_mutation_attempted"]) == false else {
            throw TFTMACRuntimeModeError(message: "Diagnostic native-host receipt structure drifted.")
        }
    }

    private static func readSealedReceipt(_ reference: TFTMACSealedReceiptReference) throws -> [String: Any] {
        guard isSHA256(reference.sha256) else {
            throw TFTMACRuntimeModeError(message: "Receipt authority contains an invalid SHA-256.")
        }
        try validateSHA256(path: reference.path, expected: reference.sha256, label: "sealed receipt")
        let sidecarPath = "\(reference.path).sha256"
        guard let sidecar = try? String(contentsOfFile: sidecarPath, encoding: .utf8),
              sidecar.split(whereSeparator: \.isWhitespace).first.map(String.init) == reference.sha256 else {
            throw TFTMACRuntimeModeError(message: "Sealed receipt sidecar is missing or mismatched: \(sidecarPath)")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: reference.path))
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TFTMACRuntimeModeError(message: "Sealed receipt is not a JSON object: \(reference.path)")
        }
        return object
    }

    private static func value(_ object: [String: Any], _ path: [String]) -> Any? {
        var current: Any = object
        for component in path {
            guard let dictionary = current as? [String: Any], let next = dictionary[component] else { return nil }
            current = next
        }
        return current
    }

    private static func string(_ object: [String: Any], _ path: [String]) -> String? {
        value(object, path) as? String
    }

    private static func strings(_ object: [String: Any], _ path: [String]) -> [String]? {
        value(object, path) as? [String]
    }

    private static func bool(_ object: [String: Any], _ path: [String]) -> Bool? {
        value(object, path) as? Bool
    }

    private static func int(_ object: [String: Any], _ path: [String]) -> Int? {
        (value(object, path) as? NSNumber)?.intValue
    }

    private static func validateSHA256(path: String, expected: String, label: String) throws {
        guard isSHA256(expected) else {
            throw TFTMACRuntimeModeError(message: "\(label) authority is not a SHA-256 value.")
        }
        let url = URL(fileURLWithPath: path)
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw TFTMACRuntimeModeError(message: "Could not open \(label) at \(path): \(error.localizedDescription)")
        }
        defer { try? handle.close() }
        var hasher = SHA256()
        do {
            while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
        } catch {
            throw TFTMACRuntimeModeError(message: "Could not hash \(label): \(error.localizedDescription)")
        }
        let observed = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard observed == expected else {
            throw TFTMACRuntimeModeError(
                message: "\(label) SHA-256 mismatch: expected \(expected), observed \(observed)."
            )
        }
    }

    private static func validateUUIDs(path: String, expected: [String], label: String) throws {
        guard !expected.isEmpty else {
            throw TFTMACRuntimeModeError(message: "\(label) has no accepted Mach-O UUID authority.")
        }
        let result = try runCommand(
            executable: "/usr/bin/dwarfdump",
            arguments: ["--uuid", path],
            timeout: 30
        )
        guard result.status == 0 else {
            throw TFTMACRuntimeModeError(message: "Could not inspect \(label) Mach-O UUIDs.")
        }
        for identity in expected {
            let parts = identity.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  result.output.localizedCaseInsensitiveContains(parts[0]),
                  result.output.contains("(\(parts[1]))") else {
                throw TFTMACRuntimeModeError(message: "\(label) Mach-O UUID identity drifted.")
            }
        }
    }

    private struct CommandResult {
        let status: Int32
        let output: String
    }

    private static func runCommand(
        executable: String,
        arguments: [String],
        timeout: TimeInterval
    ) throws -> CommandResult {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(
            "tftmac-runtime-authority-\(UUID().uuidString)",
            isDirectory: true
        )
        try manager.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? manager.removeItem(at: root) }
        let stdoutURL = root.appendingPathComponent("stdout")
        let stderrURL = root.appendingPathComponent("stderr")
        manager.createFile(atPath: stdoutURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        manager.createFile(atPath: stderrURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        let stdout = try FileHandle(forWritingTo: stdoutURL)
        let stderr = try FileHandle(forWritingTo: stderrURL)
        defer {
            try? stdout.close()
            try? stderr.close()
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            throw TFTMACRuntimeModeError(
                message: "Could not execute \(executable): \(error.localizedDescription)"
            )
        }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.2)
            if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
        }
        process.waitUntilExit()
        try stdout.synchronize()
        try stderr.synchronize()
        let out = (try? String(contentsOf: stdoutURL, encoding: .utf8)) ?? ""
        let err = (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
        return CommandResult(status: process.terminationStatus, output: out + err)
    }

    private static func processExecutablePath(_ processIdentifier: Int32) throws -> String {
        var buffer = [CChar](repeating: 0, count: 4096)
        let count = buffer.withUnsafeMutableBufferPointer {
            proc_pidpath(processIdentifier, $0.baseAddress, UInt32($0.count))
        }
        guard count > 0 else {
            throw TFTMACRuntimeModeError(
                message: "Could not resolve loaded emulator process path for PID \(processIdentifier)."
            )
        }
        return String(cString: buffer)
    }

    private static func standardized(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }

    private static func isSHA256(_ value: String) -> Bool {
        guard value.count == 64 else { return false }
        return value.unicodeScalars.allSatisfy {
            (48...57).contains($0.value) || (97...102).contains($0.value)
        }
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
