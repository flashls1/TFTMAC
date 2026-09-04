#!/usr/bin/env node
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const root = process.cwd();
const changeId = '215ec5a3-6554-4ca3-95db-1525433bb20f';
const expectedHead = '310404da3ca3edaa63b6ebdecb2acc8d52fb59ba';
const planRoot = '.clara/plans/tftmac-causal-graphics-v1';
const waveRoot = `${planRoot}/wave-b-v3`;
const expected = {
  [`${planRoot}/IMPLEMENTATION_PLAN.md`]: '78785b29815dba26a8da1d2ed56e0e9c256d3e7d9cfb4c4857b3c954846e8d2b',
  [`${planRoot}/SCOPE_LOCK.txt`]: 'dc77b6913d14409adc883dd27a67c42e982c40ab9149a68771b61dc99fae297e',
  [`${waveRoot}/CONTINUATION_AMENDMENT.md`]: 'df9d3a537d94d4f32337c2658168714925c1f3206775964069ea135a27cbdc4a',
  [`${waveRoot}/PREFLIGHT.json`]: 'bec3a488d3386966cb3f98cdf1b5f35a083519d1dfb873260db4d63576b19247',
  [`${waveRoot}/ZENGATE_RECEIPT.json`]: '6d460880102823285456668f98dde26d54a11b0e3e20f8270d699947ae2b7003',
  [`${planRoot}/protected-local-work/unaccepted-waveb-draft-before-v3/wave-b-v2/RuntimeMode.swift.template`]: 'cb8e62545832e457e12046bed5eb8dcd72a17feb090ce3dad3e15b6cfad7f60f',
  [`${planRoot}/protected-local-work/unaccepted-waveb-draft-before-v3/wave-b-v2/RuntimeLease.swift.template`]: 'f3b4db12f4e8c085343d87813ab026ff6045ec679cb8afea48dd87bf8f04c0f9',
  [`${waveRoot}/RuntimeModeAuthority.swift.template`]: '3ab10d59a94ef4e60e920290a940a55a624a0209a7fe6e05abe65fdfaf040c59',
  [`${waveRoot}/validate-waveb-v3.mjs`]: '23fe5b2e93622c73ba349f8327ab0dc80f94a4d10857bb7af53ea20e320e9a61',
  'ssot/runtime-modes.json': '81086498d8a16f2096f8461922731d7cf5c027cf6163d874452c16ffa543fdb2',
  'ssot/runtime-authority.json': '2af6196e08b3f81032b8226fa3a9c25a3b0d99537f0872b7eb21a96aaf2b5d2f',
  'tftmac/App/AppCoordinator.swift': 'd0eb27df9a0e6aaa45ff60c63fd81bc229350a6f8feca833b776bbe4a954bda4',
  'tftmac/Runtime/RuntimeLease.swift': '55a44dbd5fc8b112cb48d17e879c00ae068161f2755af1876244e03bf75b498b',
  'tftmac/Runtime/RuntimeProfile.swift': '93b5ac436f4f1f315b343151cacc304d76337ac39c996df7dee38ffa48909bae',
  'tftmac/Runtime/TFTMACRuntime.swift': '8932032d93af01b46e46b5fb5a04eff1ec457f2f0e8f92f364d5a1a703ab5a5f',
  'Tests/TFTMACTests/TFTMACGate1Tests.swift': '3a3302778bda256a9e2977cf2de51827867f211b97f5bf9f74e41389ecd0b7fb',
  'TFTMAC.xcodeproj/project.pbxproj': '4961d37cc1802ca179b7f115ff4be3a4f1c222e706a01aff9f137fcb27c57dfd',
  'scripts/build-native-app.command': '9bedc13dab3f395a75e8b74fccbeaff92209ddd48b1a83e368768196fd96ae0f',
  'scripts/verify-tftmac.command': 'd58721d6c06cd321052b150184b970f46b5977afe50c2ef6470ed4999dd5a84d',
  'RuntimeHost/main.c': 'c749cd998a6f066e2f7a6ef818eecf05b90d1a8808f6c9966e0b5fc21affeeed',
  'RuntimeHost/Info.plist': 'cab05fb3b54fb76c9b1b85e9f6a66aebcc5b91bed98c757b603db89e2b7939ca'
};
const identities = {
  control: {
    adb: '1811e253b21b12cbfda7201ebaf86c10e7ddcb5c606a7a81f7c82b4c429c2d3b',
    emulator: 'b3b8fc0dcedcf6e15b54b41f3e5156319029aa00b88a59fd489f80abdd8fc133',
    emulatorUUIDs: ['4C4C449E-5555-3144-A182-644CCB895091:arm64'],
    qemu: 'eaa97a970b81f81640db73ed79e19ee173323653a0a1203217e1199d078011f3',
    qemuUUIDs: ['4C4C4467-5555-3144-A10A-A9E5A99446F1:arm64'],
    gfxstream: '3772fef215058831ea419c9281fd203d010003d5defdc195dd120bc7748e4093',
    gfxstreamUUIDs: ['4C4C4406-5555-3144-A122-8AC522465662:arm64']
  },
  diagnostic: {
    adb: '1811e253b21b12cbfda7201ebaf86c10e7ddcb5c606a7a81f7c82b4c429c2d3b',
    emulator: 'fb7782eb3abd7c5b4cb000e68f0c296fed1098f9581aacb01971a45f6b6836aa',
    emulatorUUIDs: ['4C4C4436-5555-3144-A1EE-05B0F446F580:arm64'],
    qemu: '042c4932b17fd09ff056ecc2dd21084e08e1110b774c594bbcaf1e4d1ceac608',
    qemuUUIDs: ['4C4C447F-5555-3144-A16C-0DB6C4482B7A:arm64'],
    gfxstream: '23d54a05a3b73704a7f7d0394f40e04f21bd7e546b1982911a681ae0fe375c9d',
    gfxstreamUUIDs: ['4C4C4449-5555-3144-A1FC-F6DFE0021481:arm64']
  }
};

function fail(message) { console.error(`WAVE_B_V3_APPLY_FAILED: ${message}`); process.exit(1); }
function ensure(value, message) { if (!value) fail(message); }
function absolute(relativePath) { return path.join(root, relativePath); }
function sha256(data) { return crypto.createHash('sha256').update(data).digest('hex'); }
function fileSha(relativePath) { return sha256(fs.readFileSync(absolute(relativePath))); }
function externalSha(filePath) { return sha256(fs.readFileSync(filePath)); }
function git(...args) { return execFileSync('/usr/bin/git', args, { cwd: root, encoding: 'utf8' }); }
function readText(relativePath) { return fs.readFileSync(absolute(relativePath), 'utf8'); }
function replaceOnce(text, before, after, label) {
  const count = text.split(before).length - 1;
  ensure(count === 1, `${label}: expected one anchor, found ${count}`);
  return text.replace(before, after);
}
function replaceSection(text, startMarker, endMarker, replacement, label) {
  const start = text.indexOf(startMarker);
  const end = text.indexOf(endMarker, start + startMarker.length);
  ensure(start >= 0 && end > start, `${label}: section anchors were not found`);
  ensure(text.indexOf(startMarker, start + 1) < 0, `${label}: start anchor is not unique`);
  return text.slice(0, start) + replacement + text.slice(end);
}
function writeAtomic(relativePath, content, mode = 0o644) {
  const destination = absolute(relativePath);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  const temporary = `${destination}.waveb-v3-${process.pid}`;
  fs.writeFileSync(temporary, content, { mode });
  fs.renameSync(temporary, destination);
  fs.chmodSync(destination, mode);
}
function configurationHash(mode) {
  const fields = [
    ['mode', mode.mode], ['launch_state', mode.launch_state], ['runtime_root', mode.runtime_root],
    ['sdk_root', mode.sdk_root], ['library_root', mode.library_root], ['emulator_path', mode.emulator_path],
    ['emulator_sha256', mode.emulator_sha256 ?? ''], ['gfxstream_backend_path', mode.gfxstream_backend_path],
    ['gfxstream_backend_sha256', mode.gfxstream_backend_sha256 ?? ''], ['adb_path', mode.adb_path],
    ['avd_home', mode.avd_home], ['avd_name', mode.avd_name], ['avd_directory', mode.avd_directory],
    ['avd_config_path', mode.avd_config_path], ['avd_config_sha256', mode.avd_config_sha256 ?? ''],
    ['avd_ini_path', mode.avd_ini_path], ['avd_ini_sha256', mode.avd_ini_sha256 ?? ''],
    ['adb_server_port', mode.adb_server_port], ['console_port', mode.console_port],
    ['controller_port', mode.controller_port ?? ''], ['serial', mode.serial],
    ['authority_manifest_kind', mode.authority_manifest.kind], ['authority_manifest_path', mode.authority_manifest.path],
    ['authority_manifest_sha256', mode.authority_manifest.sha256 ?? ''], ['application_bundle_id', mode.application_bundle_id],
    ['application_version', mode.application_version], ['application_build', mode.application_build],
    ['allowed_purpose', mode.allowed_purpose], ['comparability_class', mode.comparability_class],
    ['rollback_target', mode.rollback_target], ['requires_control_stopped', String(mode.requires_control_stopped)]
  ];
  return sha256(Buffer.from(fields.map(([key, value]) => `${key}=${value}`).join('\n')));
}

ensure(git('rev-parse', 'HEAD').trim() === expectedHead, 'managed change HEAD drifted');
ensure(git('status', '--porcelain=v1', '--untracked-files=no').trim() === '', 'tracked worktree changed before guarded apply');
for (const [relativePath, expectedSha] of Object.entries(expected)) {
  ensure(fs.existsSync(absolute(relativePath)), `required input is missing: ${relativePath}`);
  ensure(fileSha(relativePath) === expectedSha, `input SHA-256 drifted: ${relativePath}`);
}
for (const [filePath, expectedSha] of [
  ['/Volumes/MAC MINI M4/TFTMAC/Runtime/SDK/platform-tools/adb', identities.control.adb],
  ['/Volumes/MAC MINI M4/TFTMAC/Runtime/SDK/emulator/emulator', identities.control.emulator],
  ['/Volumes/MAC MINI M4/TFTMAC/Runtime/SDK/emulator/qemu/darwin-aarch64/qemu-system-aarch64', identities.control.qemu],
  ['/Volumes/MAC MINI M4/TFTMAC/Runtime/SDK/emulator/lib64/libgfxstream_backend.dylib', identities.control.gfxstream],
  ['/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Install/gate4-r9-20260901/emulator/emulator', identities.diagnostic.emulator],
  ['/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Install/gate4-r9-20260901/emulator/qemu/darwin-aarch64/qemu-system-aarch64', identities.diagnostic.qemu],
  ['/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Install/gate4-r9-20260901/emulator/lib64/libgfxstream_backend.dylib', identities.diagnostic.gfxstream]
]) ensure(externalSha(filePath) === expectedSha, `external binary identity drifted: ${filePath}`);

const registry = JSON.parse(readText('ssot/runtime-modes.json'));
registry.contract = 'TFTMAC_RUNTIME_MODES_V1';
registry.selection_environment_variable = 'TFTMAC_RUNTIME_MODE';
const control = registry.modes.control;
Object.assign(control, {
  emulator_sha256: identities.control.emulator,
  gfxstream_backend_sha256: identities.control.gfxstream,
  state_namespace: 'control',
  uses_legacy_application_support_root: true,
  emulator_identifier: 'TFTMAC',
  launch_strategy: 'bundled_forwarder',
  profile_policy: 'validated_native_preferences',
  locked_profile: null,
  adb_sha256: identities.control.adb,
  adb_vendor_keys_policy: 'ABSENT',
  expected_emulator_version_contains: '37.1.11',
  emulator_uuids: identities.control.emulatorUUIDs,
  qemu_path: '/Volumes/MAC MINI M4/TFTMAC/Runtime/SDK/emulator/qemu/darwin-aarch64/qemu-system-aarch64',
  qemu_sha256: identities.control.qemu,
  qemu_uuids: identities.control.qemuUUIDs,
  gfxstream_backend_uuids: identities.control.gfxstreamUUIDs,
  host_application: {
    kind: 'bundled_resource',
    path: 'TFTMAC Emulator Host.app',
    bundle_identifier: 'com.flashls1.tftmac.emulator-host',
    executable_relative_path: 'Contents/MacOS/TFTMACEmulatorHost',
    executable_sha256: null,
    source_path: 'RuntimeHost/main.c',
    source_sha256: expected['RuntimeHost/main.c'],
    info_plist_path: 'RuntimeHost/Info.plist',
    info_plist_sha256: expected['RuntimeHost/Info.plist'],
    build_receipt_resource: 'control-host-build.json'
  },
  diagnostic_receipts: null
});
control.configuration_sha256 = configurationHash(control);

const diagnostic = registry.modes.advanced_diagnostics;
Object.assign(diagnostic, {
  state_namespace: 'advanced_diagnostics',
  uses_legacy_application_support_root: false,
  emulator_identifier: 'TFTMAC-DIAGNOSTIC',
  launch_strategy: 'external_native_host',
  profile_policy: 'fixed_registry_profile',
  locked_profile: {
    identifier: 'tftmac_diagnostic_r9', width: 1920, height: 1080, density_dpi: 280, refresh_hz: 60,
    vcpu: 6, ram_mib: 6144, gpu_mode: 'host', audio_backend: 'coreaudio', graphics_transport: 'pipe',
    asg_write_buffer_size: 1048576, asg_write_step_size: 4096, asg_data_ring_size: 32768,
    asg_draw_flush_interval: 800,
    angle_enabled_features: 'exposeNonConformantExtensionsAndVersions:exposeES32ForTesting',
    angle_disabled_features: 'preferSubmitAtFBOBoundary'
  },
  adb_sha256: identities.diagnostic.adb,
  adb_vendor_keys_policy: 'USER_DEFAULT_KEY',
  expected_emulator_version_contains: '35.6.3',
  emulator_uuids: identities.diagnostic.emulatorUUIDs,
  qemu_path: '/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Install/gate4-r9-20260901/emulator/qemu/darwin-aarch64/qemu-system-aarch64',
  qemu_sha256: identities.diagnostic.qemu,
  qemu_uuids: identities.diagnostic.qemuUUIDs,
  gfxstream_backend_uuids: identities.diagnostic.gfxstreamUUIDs,
  host_application: {
    kind: 'external_application',
    path: '/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Install/gate4-r9-20260901/TFTMAC Diagnostic Host.app',
    bundle_identifier: 'com.flashls1.tftmac.runtime.diagnostics',
    executable_relative_path: 'Contents/MacOS/TFTMACApp',
    executable_sha256: 'd335a23d710956f96a4c01f977d49437424c9fd52ccc20ed872e5786d206eef2',
    source_path: null,
    source_sha256: null,
    info_plist_path: null,
    info_plist_sha256: '4e15592461ce8a50f17ccd6285fd12fcd84dd407eba86919f90c8c0026b5ca61',
    build_receipt_resource: null
  },
  diagnostic_receipts: {
    build_id: 'gate4-r9-20260901',
    runtime_configuration_sha256: '005c85a2a7ffe86e7626c871fd3dd23f42c5d3ce994162d17b032e69cfc4d4f3',
    build: {
      path: '/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Manifests/gate4-r9-20260901/diagnostic-build.json',
      sha256: '9556ffe5c9d083d3ba90006628b8fc5a94a6989f56fa21d40bb9a30f2f99ef8d',
      required_state: 'DIAGNOSTIC_BUILD_IDENTITY_PASS'
    },
    clone: {
      path: '/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Manifests/gate4-r9-20260901/diagnostic-avd-clone.json',
      sha256: '09e4b2d21290de582320cb0aee3148af25f5e2e59199e225e604afbb6cb19648',
      required_state: 'DIAGNOSTIC_AVD_CLONE_RECEIPT_PASS'
    },
    native_host: {
      path: '/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Manifests/gate4-r9-20260901/gate4-r9-host-r1-native-host-build.json',
      sha256: 'a72d10106acb83444a38027ed3978b6ef3bc60e7ec0ae0ba9439f67eb57f6067',
      required_state: 'DIAGNOSTIC_NATIVE_HOST_BUILD_PASS'
    }
  }
});
diagnostic.configuration_sha256 = configurationHash(diagnostic);

const candidate = registry.modes.candidate;
Object.assign(candidate, {
  state_namespace: 'candidate',
  uses_legacy_application_support_root: false,
  emulator_identifier: 'TFTMAC-CANDIDATE',
  launch_strategy: 'blocked',
  profile_policy: 'blocked',
  locked_profile: null,
  adb_sha256: null,
  adb_vendor_keys_policy: 'UNRESOLVED',
  expected_emulator_version_contains: null,
  emulator_uuids: null,
  qemu_path: '/Volumes/MAC MINI M4/TFTMAC/Candidate/SDK/emulator/qemu/darwin-aarch64/qemu-system-aarch64',
  qemu_sha256: null,
  qemu_uuids: null,
  gfxstream_backend_uuids: null,
  host_application: null,
  diagnostic_receipts: null
});
candidate.configuration_sha256 = configurationHash(candidate);

const portOwners = new Map();
for (const [modeName, mode] of Object.entries(registry.modes)) {
  ensure(mode.serial === `emulator-${mode.console_port}`, `${modeName} serial/console mismatch`);
  for (const [kind, value] of [['adb', mode.adb_server_port], ['console', mode.console_port], ['controller', mode.controller_port]]) {
    if (value === null) continue;
    ensure(!portOwners.has(value), `port collision: ${value}`);
    portOwners.set(value, `${modeName}.${kind}`);
  }
}
ensure(diagnostic.launch_state === 'blocked_pending_controller_lease' && diagnostic.controller_port === null, 'diagnostics must remain blocked');
ensure(candidate.launch_state === 'blocked_not_built' && candidate.controller_port === null, 'candidate must remain blocked');
const registryText = `${JSON.stringify(registry, null, 2)}\n`;
const registrySha = sha256(Buffer.from(registryText));

const modeTemplate = readText(`${planRoot}/protected-local-work/unaccepted-waveb-draft-before-v3/wave-b-v2/RuntimeMode.swift.template`);
ensure(modeTemplate.includes('__EXPECTED_RUNTIME_MODES_SHA256__'), 'runtime mode template placeholder is missing');
const runtimeModeSource = modeTemplate.replace('__EXPECTED_RUNTIME_MODES_SHA256__', registrySha);
const runtimeModeAuthoritySource = readText(`${waveRoot}/RuntimeModeAuthority.swift.template`);
const runtimeLeaseSource = readText(`${planRoot}/protected-local-work/unaccepted-waveb-draft-before-v3/wave-b-v2/RuntimeLease.swift.template`);

const pathsBlock = `struct TFTMACRuntimePaths: Sendable {
    let mode: TFTMACRuntimeMode
    let registrySha256: String
    let configurationSha256: String
    let runtimeRoot: URL
    let sdkRoot: URL
    let libraryRoot: URL
    let emulator: URL
    let qemu: URL
    let gfxstreamBackend: URL
    let adb: URL
    let avdHome: URL
    let avdName: String
    let avdDirectory: URL
    let avdConfig: URL
    let avdINI: URL
    let hostApplication: URL
    let applicationSupport: URL
    let globalApplicationSupport: URL
    let adbServerPort: Int
    let consolePort: Int
    let controllerPort: Int
    let serial: String
    let emulatorIdentifier: String
    let launchStrategy: TFTMACRuntimeLaunchStrategy
    let adbVendorKeysPolicy: String

    static func discover(
        configuration: TFTMACSelectedRuntimeConfiguration,
        bundle: Bundle = .main
    ) throws -> Self {
        let selection = configuration.selection
        let definition = selection.definition
        let resolved = try configuration.authority.resolveForLaunch(
            selection: selection,
            bundle: bundle
        )
        guard let controllerPort = definition.controllerPort,
              let qemuPath = resolved.supplemental.qemuPath else {
            throw TFTMACRuntimeModeError(
                message: "Runtime mode \\(selection.mode.rawValue) has no accepted launch lease."
            )
        }
        return Self(
            mode: selection.mode,
            registrySha256: selection.registrySha256,
            configurationSha256: definition.configurationSha256,
            runtimeRoot: URL(fileURLWithPath: definition.runtimeRoot, isDirectory: true),
            sdkRoot: URL(fileURLWithPath: definition.sdkRoot, isDirectory: true),
            libraryRoot: URL(fileURLWithPath: definition.libraryRoot, isDirectory: true),
            emulator: URL(fileURLWithPath: definition.emulatorPath),
            qemu: URL(fileURLWithPath: qemuPath),
            gfxstreamBackend: URL(fileURLWithPath: definition.gfxstreamBackendPath),
            adb: URL(fileURLWithPath: definition.adbPath),
            avdHome: URL(fileURLWithPath: definition.avdHome, isDirectory: true),
            avdName: definition.avdName,
            avdDirectory: URL(fileURLWithPath: definition.avdDirectory, isDirectory: true),
            avdConfig: URL(fileURLWithPath: definition.avdConfigPath),
            avdINI: URL(fileURLWithPath: definition.avdIniPath),
            hostApplication: resolved.hostApplication,
            applicationSupport: resolved.applicationSupport,
            globalApplicationSupport: resolved.globalApplicationSupport,
            adbServerPort: definition.adbServerPort,
            consolePort: definition.consolePort,
            controllerPort: controllerPort,
            serial: definition.serial,
            emulatorIdentifier: resolved.supplemental.emulatorIdentifier,
            launchStrategy: resolved.supplemental.launchStrategy,
            adbVendorKeysPolicy: resolved.supplemental.adbVendorKeysPolicy
        )
    }
}

`;

let runtime = readText('tftmac/Runtime/TFTMACRuntime.swift');
runtime = replaceSection(runtime, 'struct TFTMACRuntimePaths: Sendable {', 'struct EmulatorControllerDiscovery: Sendable {', pathsBlock, 'runtime paths');
runtime = replaceOnce(runtime, `    private let profile: TFTMACRuntimeProfile
    private let mailbox: LatestFrameMailbox
`, `    private let runtimeConfiguration: TFTMACSelectedRuntimeConfiguration
    private let profile: TFTMACRuntimeProfile
    private let mailbox: LatestFrameMailbox
`, 'runtime configuration field');
runtime = replaceOnce(runtime, `    init(
        profile: TFTMACRuntimeProfile,
        mailbox: LatestFrameMailbox,
        status: @escaping StatusHandler,
        gameFrame: @escaping GameFrameHandler
    ) {
        self.profile = profile
        self.mailbox = mailbox
        self.status = status
        self.gameFrame = gameFrame
    }
`, `    init(
        runtimeConfiguration: TFTMACSelectedRuntimeConfiguration,
        mailbox: LatestFrameMailbox,
        status: @escaping StatusHandler,
        gameFrame: @escaping GameFrameHandler
    ) {
        self.runtimeConfiguration = runtimeConfiguration
        self.profile = runtimeConfiguration.profile
        self.mailbox = mailbox
        self.status = status
        self.gameFrame = gameFrame
    }
`, 'runtime service initializer');

const runFunction = `    func run() async throws {
        await status("Validating the selected TFTMAC runtime identity…", false)
        do {
            let paths = try TFTMACRuntimePaths.discover(configuration: runtimeConfiguration)
            self.paths = paths
            let telemetry = try TFTMACNativeTelemetry(
                profile: profile,
                applicationSupport: paths.applicationSupport
            )
            self.telemetry = telemetry
            labStore = try CombatBenchmarkLabStore(applicationSupport: paths.applicationSupport)
            await status("Starting Android through the native Mac app host…", false)

            let leaseIdentity = try runtimeConfiguration.selection.leaseIdentity()
            let globalStateRoot = paths.globalApplicationSupport
                .appendingPathComponent("State", isDirectory: true)
            runtimeLease = try TFTMACRuntimeLease.acquire(
                stateRoot: globalStateRoot,
                identity: leaseIdentity
            )
            telemetry.recordEvent("RUNTIME_LEASE_ACQUIRED", payload: [
                "lease": runtimeConfiguration.registry.document.activeLeaseRelativePath,
                "pid": ProcessInfo.processInfo.processIdentifier,
                "exclusive": true,
                "mode": paths.mode.rawValue,
                "registry_sha256": paths.registrySha256,
                "configuration_sha256": paths.configurationSha256,
                "avd": paths.avdName,
                "adb_server_port": paths.adbServerPort,
                "console_port": paths.consolePort,
                "controller_port": paths.controllerPort,
                "serial": paths.serial
            ])
            try assertRuntimeUnoccupied(paths: paths, telemetry: telemetry)
            try recoverInterruptedAVDTransaction(paths: paths)
            recordFrozenReceipts(telemetry: telemetry, paths: paths)
            avdTransaction = try prepareAVD(paths: paths, telemetry: telemetry)
            try startADBServer(paths: paths, telemetry: telemetry)
            let launchStarted = Date()
            try launchEmulatorHost(paths: paths, telemetry: telemetry)
            let discovery = try await waitForDiscovery(
                paths: paths,
                captureDirectory: telemetry.captureDirectory,
                after: launchStarted
            )
            guard discovery.port == paths.controllerPort else {
                throw TFTMACRuntimeError(
                    "The emulator published controller port \\(discovery.port), not the accepted port \\(paths.controllerPort)."
                )
            }
            self.discovery = discovery
            telemetry.recordEvent("EMULATOR_CONTROLLER_DISCOVERED", payload: [
                "pid": discovery.processIdentifier,
                "grpc_port": discovery.port,
                "record": discovery.recordPath,
                "token_persisted": false,
                "mode": paths.mode.rawValue
            ])
            let loadedIdentity = try runtimeConfiguration.authority.validateLoadedRuntime(
                processIdentifier: discovery.processIdentifier,
                selection: runtimeConfiguration.selection
            )
            telemetry.recordEvent("LOADED_RUNTIME_IDENTITY_PASS", payload: [
                "pid": loadedIdentity.processIdentifier,
                "mode": paths.mode.rawValue,
                "qemu_path": loadedIdentity.qemuPath,
                "qemu_sha256": loadedIdentity.qemuSha256,
                "qemu_uuids": loadedIdentity.qemuUuids,
                "gfxstream_backend_path": loadedIdentity.gfxstreamBackendPath,
                "gfxstream_backend_sha256": loadedIdentity.gfxstreamBackendSha256,
                "gfxstream_backend_uuids": loadedIdentity.gfxstreamBackendUuids
            ])
            try recordHostSchedulingReceipt(telemetry: telemetry)

            let (inputStream, continuation) = AsyncStream.makeStream(
                of: EmulatorInput.self,
                bufferingPolicy: .bufferingNewest(256)
            )
            inputContinuation = continuation
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { [profile, mailbox] in
                    try await Self.runController(
                        discovery: discovery,
                        profile: profile,
                        mailbox: mailbox,
                        telemetry: telemetry,
                        inputStream: inputStream,
                        status: self.status
                    )
                }
                group.addTask {
                    try await self.waitForBootAndLaunchGame(paths: paths, telemetry: telemetry)
                }
                group.addTask {
                    try await self.sampleRuntime(
                        paths: paths,
                        telemetry: telemetry,
                        emulatorPID: discovery.processIdentifier
                    )
                }
                group.addTask {
                    try await self.sampleGameFrames(paths: paths, telemetry: telemetry)
                }
                _ = try await group.next()
                group.cancelAll()
            }
            if !stopping { throw TFTMACRuntimeError("The native emulator session ended unexpectedly.") }
        } catch {
            if stopping || error is CancellationError {
                telemetry?.recordEvent("RUNTIME_STOP_REQUESTED", payload: ["reason": "application_termination"])
                await cleanup(status: "STOPPED")
                return
            }
            telemetry?.recordEvent("RUNTIME_FAILED", payload: [
                "error": error.localizedDescription,
                "diagnostic": String(describing: error),
                "type": String(reflecting: type(of: error)),
                "mode": runtimeConfiguration.selection.mode.rawValue
            ])
            if profile.experimentPreset.isActiveCandidate {
                recordCorrectnessRejection(reason: error.localizedDescription)
                TFTMACRuntimeProfile.playable.with(experimentPreset: .control).save()
                telemetry?.recordEvent("EXPERIMENT_AUTO_ROLLBACK", payload: [
                    "failed_preset": profile.experimentPreset.rawValue,
                    "restored_preset": RuntimeExperimentPreset.control.rawValue,
                    "classification": "REJECTED_CORRECTNESS",
                    "applies_after_restart": true
                ])
            }
            await cleanup(status: stopping ? "STOPPED" : "FAILED")
            if !stopping { await status(error.localizedDescription, true) }
            throw error
        }
        await cleanup(status: "STOPPED")
    }

`;
runtime = replaceSection(runtime, '    func run() async throws {', '    func sendMouse(_ input: MouseInput) {', runFunction, 'runtime run');

runtime = replaceOnce(runtime,
`           Self.processMatchesLaunchedIdentity(ownedPID, sessionMarker: expectedSessionMarker) {`,
`           Self.processMatchesLaunchedIdentity(ownedPID, paths: paths, sessionMarker: expectedSessionMarker) {`,
'stop ownership check');
runtime = replaceOnce(runtime, `                "serial": "emulator-5582",`, `                "serial": paths.serial,`, 'stop serial');
runtime = replaceOnce(runtime,
`                ["-P", "5038", "-s", "emulator-5582", "emu", "kill"],`,
`                ["-P", "\\(paths.adbServerPort)", "-s", paths.serial, "emu", "kill"],`,
'stop adb identity');
runtime = replaceOnce(runtime,
`            let ownedPID = discovery?.processIdentifier ?? expectedSessionMarker.flatMap(Self.findOwnedEmulatorPID)`,
`            let ownedPID = discovery?.processIdentifier ?? expectedSessionMarker.flatMap { marker in
                Self.findOwnedEmulatorPID(sessionMarker: marker, paths: paths)
            }`,
'cleanup owner lookup');
runtime = replaceOnce(runtime,
`                ownedProcessExists && Self.processMatchesLaunchedIdentity($0, sessionMarker: expectedSessionMarker)`,
`                ownedProcessExists && Self.processMatchesLaunchedIdentity(
                    $0,
                    paths: paths,
                    sessionMarker: expectedSessionMarker
                )`,
'cleanup ownership verification');
runtime = replaceOnce(runtime,
`                    ["-P", "5038", "-s", "emulator-5582", "emu", "kill"],`,
`                    ["-P", "\\(paths.adbServerPort)", "-s", paths.serial, "emu", "kill"],`,
'cleanup adb identity');
runtime = replaceOnce(runtime,
`                payload: ["pid": ownedPID ?? 0, "serial": "emulator-5582", "owned": ownsRunningEmulator]`,
`                payload: ["pid": ownedPID ?? 0, "serial": paths.serial, "owned": ownsRunningEmulator]`,
'cleanup telemetry identity');
runtime = replaceOnce(runtime,
`                guard !Self.anyEmulatorUsingSharedAVD() else {
                    throw TFTMACRuntimeError("AVD restore was withheld because another TFT_Ultra_Tablet process is active.")
                }`,
`                guard !Self.anyEmulatorUsingSelectedAVD(paths: paths) else {
                    throw TFTMACRuntimeError(
                        "AVD restore was withheld because another \\(paths.avdName) process is active."
                    )
                }`,
'cleanup selected AVD');

runtime = replaceOnce(runtime,
`        process.arguments = ["-P", "5038", "-s", "emulator-5582", "logcat", "-v", "threadtime", "-T", sessionStartSelector]`,
`        process.arguments = [
            "-P", "\\(paths.adbServerPort)", "-s", paths.serial,
            "logcat", "-v", "threadtime", "-T", sessionStartSelector
        ]`,
'logcat identity');

const occupancyFunction = `    private func assertRuntimeUnoccupied(
        paths: TFTMACRuntimePaths,
        telemetry: TFTMACNativeTelemetry
    ) throws {
        var definitions = [runtimeConfiguration.selection.definition]
        if runtimeConfiguration.selection.definition.requiresControlStopped {
            let control = try runtimeConfiguration.registry.definition(for: .control)
            if control.mode != runtimeConfiguration.selection.mode { definitions.append(control) }
        }
        let processOutput = (try? Self.runCommand(
            URL(fileURLWithPath: "/bin/ps"),
            ["-axo", "pid=,command="],
            timeout: 10
        ).output) ?? ""
        let emulatorConflicts = processOutput.split(whereSeparator: \\.isNewline).filter { line in
            guard line.contains("qemu-system-aarch64") else { return false }
            return definitions.contains { definition in
                line.contains("@\\(definition.avdName)")
                    || line.contains("-port \\(definition.consolePort)")
                    || definition.controllerPort.map { line.contains("-grpc \\($0)") } == true
            }
        }
        let leasedPorts = Set(definitions.flatMap { definition -> [Int] in
            [definition.consolePort] + definition.controllerPort.map { [$0] } ?? []
        }).sorted()
        var listenerArguments = ["-nP"]
        for port in leasedPorts { listenerArguments.append("-iTCP:\\(port)") }
        listenerArguments.append("-sTCP:LISTEN")
        let listenerOutput = (try? Self.runCommand(
            URL(fileURLWithPath: "/usr/sbin/lsof"),
            listenerArguments,
            timeout: 10
        ).output) ?? ""
        let listeners = listenerOutput.split(whereSeparator: \\.isNewline).dropFirst()
        guard emulatorConflicts.isEmpty && listeners.isEmpty else {
            let modes = definitions.map(\\.mode.rawValue).joined(separator: ", ")
            throw TFTMACRuntimeError(
                "The selected runtime lease conflicts with an active \\(modes) emulator or port listener."
            )
        }
        let checkedIdentities: [[String: Any]] = definitions.map { definition in
            [
                "mode": definition.mode.rawValue,
                "avd": definition.avdName,
                "console_port": definition.consolePort,
                "controller_port": definition.controllerPort ?? 0,
                "serial": definition.serial
            ]
        }
        telemetry.recordEvent("RUNTIME_OWNERSHIP_PREFLIGHT_PASSED", payload: [
            "selected_mode": paths.mode.rawValue,
            "checked_identities": checkedIdentities,
            "existing_emulator_count": 0,
            "existing_listener_count": 0
        ])
    }

`;
runtime = replaceSection(runtime, '    private func assertRuntimeUnoccupied(telemetry: TFTMACNativeTelemetry) throws {', '    private func recordFrozenReceipts', occupancyFunction, 'runtime occupancy');

const receiptsFunction = `    private func recordFrozenReceipts(
        telemetry: TFTMACNativeTelemetry,
        paths: TFTMACRuntimePaths
    ) {
        let experimentReceipt = profile.experimentConfigurationReceipt
        let receipts: [(String, String, String, String)] = [
            ("engine", "Unreal Engine", "user_locked_fact", "LOCKED"),
            ("runtime_mode", paths.mode.rawValue, "sealed runtime-mode registry", "DIRECT"),
            ("runtime_mode_registry_sha256", paths.registrySha256, "bundled signed registry", "DIRECT"),
            ("runtime_mode_configuration_sha256", paths.configurationSha256, "sealed runtime-mode registry", "DIRECT"),
            ("runtime_profile_id", profile.identifier, "validated mode profile", "DIRECT"),
            ("runtime_experiment_preset", profile.experimentPreset.rawValue, "named launch experiment", "DIRECT"),
            ("runtime_configuration_sha256", experimentReceipt.sha256, "canonical effective configuration", "DIRECT"),
            ("runtime_configuration_json", experimentReceipt.canonicalJSON, "canonical effective configuration", "DIRECT"),
            ("launcher_method", paths.launchStrategy.rawValue, "runtime-mode authority", "DIRECT"),
            ("native_host_application", paths.hostApplication.path, "signed host authority", "DIRECT"),
            ("macos_game_mode_eligible", "true", "LSSupportsGameMode bundle contract", "DIRECT"),
            ("host_qos_requested", profile.experimentPreset.requestsHostLatencyQoS ? "user_interactive" : "default", "named launch experiment", "REQUESTED"),
            ("adb_server_port", "\\(paths.adbServerPort)", "runtime-mode lease", "DIRECT"),
            ("emulator_console_port", "\\(paths.consolePort)", "runtime-mode lease", "DIRECT"),
            ("adb_serial", paths.serial, "runtime-mode lease", "DIRECT"),
            ("controller_port", "\\(paths.controllerPort)", "runtime-mode lease", "DIRECT"),
            ("adb_vendor_keys", paths.adbVendorKeysPolicy, "runtime-mode authority", "DIRECT"),
            ("avd", paths.avdName, "runtime-mode authority", "DIRECT"),
            ("runtime_root", paths.runtimeRoot.path, "runtime-mode authority", "DIRECT"),
            ("mode_application_support", paths.applicationSupport.path, "runtime-mode state isolation", "DIRECT"),
            ("resolution", "\\(profile.width)x\\(profile.height)", "validated mode profile", "DIRECT"),
            ("density_dpi", "\\(profile.densityDPI)", "validated mode profile", "DIRECT"),
            ("refresh_hz", "\\(profile.refreshHz)", "validated mode profile", "DIRECT"),
            ("vcpu", "\\(profile.vCPU)", "validated mode profile", "DIRECT"),
            ("ram_mib", "\\(profile.ramMiB)", "validated mode profile", "DIRECT"),
            ("gpu_mode", profile.gpuMode, "validated mode profile", "DIRECT"),
            ("audio_backend", profile.audioBackend, "validated mode profile", "DIRECT"),
            ("graphics_transport_requested", profile.graphicsTransport, "validated mode profile", "REQUESTED"),
            ("emulator_features_requested", profile.effectiveEmulatorFeatures.joined(separator: ","), "named launch experiment", "REQUESTED"),
            ("asg_write_buffer_size", "\\(profile.asgWriteBufferSize)", "validated mode profile", "REQUESTED"),
            ("asg_write_step_size", "\\(profile.asgWriteStepSize)", "validated mode profile", "REQUESTED"),
            ("asg_data_ring_size", "\\(profile.asgDataRingSize)", "validated mode profile", "REQUESTED"),
            ("asg_draw_flush_interval_us", "\\(profile.asgDrawFlushInterval)", "validated mode profile", "REQUESTED"),
            ("angle_enabled_requested", profile.angleEnabledFeatures, "validated mode profile", "REQUESTED"),
            ("angle_disabled_requested", profile.angleDisabledFeatures, "validated mode profile", "REQUESTED"),
            ("frame_transport", "raw_grpc_rgba8888", "native admission path", "DIRECT"),
            ("raw_logcat_policy", "LOCAL_SENSITIVE_SESSION_SCOPED_NOT_FOR_SHARING", "privacy contract", "LOCKED"),
            ("sdk_root", paths.sdkRoot.path, "runtime-mode authority", "DIRECT")
        ]
        for receipt in receipts {
            telemetry.recordReceipt(key: receipt.0, value: receipt.1, source: receipt.2, confidence: receipt.3)
        }
    }

`;
runtime = replaceSection(runtime, '    private func recordFrozenReceipts', '    private func startADBServer', receiptsFunction, 'frozen receipts');

const adbServerFunction = `    private func startADBServer(
        paths: TFTMACRuntimePaths,
        telemetry: TFTMACNativeTelemetry
    ) throws {
        let result = try Self.runCommand(
            paths.adb,
            ["-P", "\\(paths.adbServerPort)", "start-server"],
            environment: Self.adbEnvironment(paths: paths),
            timeout: 30
        )
        guard result.status == 0 else {
            throw TFTMACRuntimeError(
                "ADB server \\(paths.adbServerPort) could not start: \\(result.output.suffix(1200))"
            )
        }
        telemetry.recordEvent("ADB_SERVER_STARTED", payload: [
            "port": paths.adbServerPort,
            "serial": paths.serial,
            "adb_vendor_keys_policy": paths.adbVendorKeysPolicy,
            "output": result.output.suffix(2000).description
        ])
    }

`;
runtime = replaceSection(runtime, '    private func startADBServer', '    private func launchEmulatorHost', adbServerFunction, 'ADB server');

const launchFunction = `    private func launchEmulatorHost(
        paths: TFTMACRuntimePaths,
        telemetry: TFTMACNativeTelemetry
    ) throws {
        guard paths.launchStrategy == .bundledForwarder else {
            throw TFTMACRuntimeModeError(
                message: "Runtime mode \\(paths.mode.rawValue) requires its separately receipted native-host acceptance operation."
            )
        }
        let stdout = telemetry.captureDirectory.appendingPathComponent("emulator.stdout.log")
        let stderr = telemetry.captureDirectory.appendingPathComponent("emulator.stderr.log")
        FileManager.default.createFile(atPath: stdout.path, contents: nil)
        FileManager.default.createFile(atPath: stderr.path, contents: nil)
        for root in Self.controllerDiscoveryRoots(paths: paths) {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
        expectedSessionMarker = "androidboot.tftmac.session=\\(telemetry.sessionIdentifier)"
        var arguments = [
            "-n", "-W",
            "--env", "TFT_EMULATOR=\\(paths.emulator.path)",
            "--env", "TFT_ADB_SERVER_PORT=\\(paths.adbServerPort)",
            "--env", "ANDROID_ADB_SERVER_PORT=\\(paths.adbServerPort)",
            "--env", "ADB_MDNS_AUTO_CONNECT=",
            "--env", "ADB_SERVER_SOCKET=",
            "--env", "ANDROID_ADB_SERVER_ADDRESS=",
            "--env", "ANDROID_SDK_ROOT=\\(paths.sdkRoot.path)",
            "--env", "ANDROID_AVD_HOME=\\(paths.avdHome.path)",
            "--env", "ANDROID_EMULATOR_USE_SYSTEM_LIBS=0",
            "--env", "ANGLE_FEATURE_OVERRIDES_ENABLED=\\(profile.angleEnabledFeatures)",
            "--env", "ANGLE_FEATURE_OVERRIDES_DISABLED=\\(profile.angleDisabledFeatures)",
            "--env", "MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS=0",
            "--env", "MVK_CONFIG_MAX_ACTIVE_METAL_COMMAND_BUFFERS_PER_QUEUE=64",
            "--env", "MVK_CONFIG_FAST_MATH_ENABLED=1",
            "--env", "TFT_HOST_LATENCY_QOS=\\(profile.experimentPreset.requestsHostLatencyQoS ? "user_interactive" : "default")",
            "--env", "TFT_HOST_STDOUT=\\(stdout.path)",
            "--env", "TFT_HOST_STDERR=\\(stderr.path)",
            paths.hostApplication.path,
            "--args",
            "@\\(paths.avdName)", "-id", paths.emulatorIdentifier, "-port", "\\(paths.consolePort)",
            "-gpu", profile.gpuMode, "-audio", profile.audioBackend,
            "-feature", profile.effectiveEmulatorFeatures.joined(separator: ","),
            "-append-userspace-opt", "androidboot.opengles.version=196610",
            "-append-userspace-opt", "androidboot.tftmac.graphics_profile=tftmac",
            "-append-userspace-opt", expectedSessionMarker!,
            "-skin", "\\(profile.width)x\\(profile.height)",
            "-vsync-rate", "\\(profile.refreshHz)",
            "-dns-server", "1.1.1.1,8.8.8.8",
            "-cores", "\\(profile.vCPU)", "-memory", "\\(profile.ramMiB)",
            "-no-hidpi-scaling", "-no-snapshot", "-no-metrics", "-no-boot-anim",
            "-crash-report-mode", "disabled", "-qt-hide-window",
            "-grpc", "\\(paths.controllerPort)", "-grpc-use-token",
            "-idle-grpc-timeout", "300"
        ]
        if let zone = TimeZone.current.identifier.addingPercentEncoding(withAllowedCharacters: .alphanumerics), !zone.isEmpty {
            arguments += ["-timezone", TimeZone.current.identifier]
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "ADB_VENDOR_KEYS")
        process.environment = environment
        try process.run()
        openProcess = process
        telemetry.recordEvent("EMULATOR_HOST_LAUNCHED", payload: [
            "method": "/usr/bin/open",
            "flags": ["-n", "-W", "--env", "--args"],
            "mode": paths.mode.rawValue,
            "host_application": paths.hostApplication.path,
            "open_pid": process.processIdentifier,
            "adb_vendor_keys_policy": paths.adbVendorKeysPolicy,
            "game_mode_eligible": true,
            "host_qos_requested": profile.experimentPreset.requestsHostLatencyQoS ? "user_interactive" : "default",
            "controller_discovery_roots": Self.controllerDiscoveryRoots(paths: paths).map(\\.path),
            "emulator_arguments": Array(arguments.suffix(from: arguments.firstIndex(of: "--args") ?? arguments.startIndex).dropFirst())
        ])
    }

`;
runtime = replaceSection(runtime, '    private func launchEmulatorHost', '    private func recordHostSchedulingReceipt', launchFunction, 'emulator host launch');

runtime = replaceOnce(runtime,
`                guard let pid = Int32(pidText), Self.processMatchesLaunchedIdentity(pid, sessionMarker: expectedSessionMarker) else { continue }`,
`                guard let pid = Int32(pidText),
                      Self.processMatchesLaunchedIdentity(
                        pid,
                        paths: paths,
                        sessionMarker: expectedSessionMarker
                      ) else { continue }`,
'discovery process identity');
runtime = replaceOnce(runtime, `        await status("Waiting for the proven ADB identity on emulator-5582…", false)`, `        await status("Waiting for the proven ADB identity on \\(paths.serial)…", false)`, 'ADB wait status');
runtime = replaceOnce(runtime,
`                ["-P", "5038", "-s", "emulator-5582", "get-state"],`,
`                ["-P", "\\(paths.adbServerPort)", "-s", paths.serial, "get-state"],`,
'ADB state identity');
runtime = replaceOnce(runtime, `                    "serial": "emulator-5582",`, `                    "serial": paths.serial,`, 'ADB state serial');
runtime = replaceOnce(runtime, `                        "serial": "emulator-5582",`, `                        "serial": paths.serial,`, 'ADB unauthorized serial');
runtime = replaceOnce(runtime, `                    await status("Waiting for emulator-5582 to appear on ADB 5038…", false)`, `                    await status("Waiting for \\(paths.serial) to appear on ADB \\(paths.adbServerPort)…", false)`, 'ADB missing status');
runtime = replaceOnce(runtime, `            throw TFTMACRuntimeError("ADB emulator-5582 did not authorize in the logged-in Mac session (last state: \\(lastState)).")`, `            throw TFTMACRuntimeError("ADB \\(paths.serial) did not authorize in the logged-in Mac session (last state: \\(lastState)).")`, 'ADB authorization error');
runtime = replaceOnce(runtime, `        telemetry.recordEvent("ADB_DEVICE_AUTHORIZED", payload: ["port": 5038, "serial": "emulator-5582"])`, `        telemetry.recordEvent("ADB_DEVICE_AUTHORIZED", payload: ["port": paths.adbServerPort, "serial": paths.serial])`, 'ADB authorized event');
runtime = replaceOnce(runtime, `            "resolution": "1920x1080",`, `            "resolution": "\\(profile.width)x\\(profile.height)",`, 'TFT resolution receipt');
runtime = replaceOnce(runtime, `            "audio_backend": "coreaudio",`, `            "audio_backend": profile.audioBackend,`, 'TFT audio receipt');
runtime = replaceOnce(runtime,
`            ["-P", "5038", "-s", "emulator-5582", "shell", "perfetto", "--txt", "-c", "-", "-o", remotePath],`,
`            ["-P", "\\(paths.adbServerPort)", "-s", paths.serial, "shell", "perfetto", "--txt", "-c", "-", "-o", remotePath],`,
'Perfetto ADB identity');

const adbEnvironmentFunction = `    nonisolated private static func adbEnvironment(
        paths: TFTMACRuntimePaths
    ) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "ADB_VENDOR_KEYS")
        environment.removeValue(forKey: "ADB_SERVER_SOCKET")
        environment.removeValue(forKey: "ANDROID_ADB_SERVER_ADDRESS")
        environment["ANDROID_SDK_ROOT"] = paths.sdkRoot.path
        environment["ANDROID_AVD_HOME"] = paths.avdHome.path
        environment["ANDROID_ADB_SERVER_PORT"] = "\\(paths.adbServerPort)"
        environment["ADB_MDNS_AUTO_CONNECT"] = ""
        return environment
    }

`;
runtime = replaceSection(runtime, '    nonisolated private static func adbEnvironment', '    nonisolated private static func adb(paths:', adbEnvironmentFunction, 'ADB environment');
runtime = replaceOnce(runtime,
`            ["-P", "5038", "-s", "emulator-5582"] + arguments,`,
`            ["-P", "\\(paths.adbServerPort)", "-s", paths.serial] + arguments,`,
'ADB helper identity');
runtime = replaceOnce(runtime,
`                "-P", "5038", "-s", "emulator-5582", "shell", "pidof",`,
`                "-P", "\\(paths.adbServerPort)", "-s", paths.serial, "shell", "pidof",`,
'TFT process identity');

const processHelpers = `    nonisolated private static func processMatchesLaunchedIdentity(
        _ processIdentifier: Int32,
        paths: TFTMACRuntimePaths,
        sessionMarker: String? = nil
    ) -> Bool {
        guard processExists(processIdentifier),
              let result = try? runCommand(
                URL(fileURLWithPath: "/bin/ps"),
                ["-p", "\\(processIdentifier)", "-ww", "-o", "command="],
                timeout: 5
              ), result.status == 0 else { return false }
        let baseIdentityMatches = result.output.contains(paths.qemu.lastPathComponent)
            && result.output.contains("@\\(paths.avdName)")
            && result.output.contains("-port \\(paths.consolePort)")
            && result.output.contains("-grpc \\(paths.controllerPort)")
        return baseIdentityMatches && (sessionMarker.map(result.output.contains) ?? true)
    }

    nonisolated private static func findOwnedEmulatorPID(
        sessionMarker: String,
        paths: TFTMACRuntimePaths
    ) -> Int32? {
        guard let result = try? runCommand(
            URL(fileURLWithPath: "/bin/ps"),
            ["-axo", "pid=,command="],
            timeout: 10
        ), result.status == 0 else { return nil }
        for line in result.output.split(whereSeparator: \\.isNewline) {
            guard line.contains(paths.qemu.lastPathComponent),
                  line.contains("@\\(paths.avdName)"),
                  line.contains("-port \\(paths.consolePort)"),
                  line.contains("-grpc \\(paths.controllerPort)"),
                  line.contains(sessionMarker),
                  let pid = line.split(whereSeparator: \\.isWhitespace).first.flatMap({ Int32($0) }) else { continue }
            return pid
        }
        return nil
    }

    nonisolated private static func anyEmulatorUsingSelectedAVD(
        paths: TFTMACRuntimePaths
    ) -> Bool {
        guard let result = try? runCommand(
            URL(fileURLWithPath: "/bin/ps"),
            ["-axo", "command="],
            timeout: 10
        ), result.status == 0 else { return true }
        return result.output.split(whereSeparator: \\.isNewline).contains { line in
            line.contains(paths.qemu.lastPathComponent)
                && line.contains("@\\(paths.avdName)")
                && line.contains("-port \\(paths.consolePort)")
        }
    }

`;
runtime = replaceSection(runtime, '    nonisolated private static func processMatchesLaunchedIdentity(', '    nonisolated private static func processExists', processHelpers, 'process identity helpers');

const controllerHeader = `@MainActor
final class TFTMACRuntimeController {
    private let service: TFTMACRuntimeService
    private var runTask: Task<Void, Never>?
    private(set) var failed = false

    init(
        runtimeConfiguration: TFTMACSelectedRuntimeConfiguration,
        mailbox: LatestFrameMailbox,
        status: @escaping TFTMACRuntimeService.StatusHandler,
        gameFrame: @escaping TFTMACRuntimeService.GameFrameHandler
    ) {
        service = TFTMACRuntimeService(
            runtimeConfiguration: runtimeConfiguration,
            mailbox: mailbox,
            status: status,
            gameFrame: gameFrame
        )
    }

`;
runtime = replaceSection(runtime, '@MainActor\nfinal class TFTMACRuntimeController {', '    func start() {', controllerHeader, 'runtime controller initializer');
for (const forbidden of ['["-P", "5038"', '"emulator-5582"', '"@TFT_Ultra_Tablet"', '"-iTCP:5582"', '"-iTCP:8554"']) {
  ensure(!runtime.includes(forbidden), `runtime still hard-codes control identity: ${forbidden}`);
}

let coordinator = readText('tftmac/App/AppCoordinator.swift');
coordinator = replaceOnce(coordinator,
`    private var activeProfile: TFTMACRuntimeProfile = .playable
    private var terminationInProgress = false
`,
`    private var activeProfile: TFTMACRuntimeProfile = .playable
    private var activeApplicationSupport = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/TFTMAC", isDirectory: true)
    private var terminationInProgress = false
`,
'coordinator state root');
const launchCoordinator = `    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = MainWindowController(mailbox: mailbox)
        mainWindowController = controller
        controller.showWindow(nil)
        controller.window?.makeFirstResponder(controller.emulatorView)
        NSApp.activate(ignoringOtherApps: true)

        do {
            let savedProfile = TFTMACRuntimeProfile.load()
            let runtimeConfiguration = try TFTMACSelectedRuntimeConfiguration.load(
                savedProfile: savedProfile
            )
            activeProfile = runtimeConfiguration.profile
            activeApplicationSupport = runtimeConfiguration.applicationSupport
            let runtime = TFTMACRuntimeController(
                runtimeConfiguration: runtimeConfiguration,
                mailbox: mailbox,
                status: { [weak controller] text, isError in
                    controller?.emulatorView.setStatus(text, isError: isError)
                },
                gameFrame: { [weak controller] window in
                    controller?.emulatorView.setGameFrameWindow(window)
                }
            )
            runtimeController = runtime
            controller.emulatorView.onTouchInput = { [weak runtime] input in
                runtime?.sendTouch(input)
            }
            controller.emulatorView.onMouseInput = { [weak runtime] x, y, buttons in
                runtime?.sendMouse(x: x, y: y, buttons: buttons)
            }
            controller.emulatorView.onKeyboardInput = { [weak runtime] text, key in
                runtime?.sendKeyboard(text: text, key: key)
            }
            controller.emulatorView.onPresentationSample = { [weak runtime] sample in
                runtime?.recordPresentation(sample)
            }
            controller.emulatorView.onHostPresentationWindow = { [weak runtime] sample in
                runtime?.recordHostPresentation(sample)
            }
            runtime.start()
        } catch {
            controller.emulatorView.setStatus(error.localizedDescription, isError: true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak controller] in
            controller?.enterNativeFullscreen()
        }
    }

`;
coordinator = replaceSection(coordinator, '    func applicationDidFinishLaunching(_ notification: Notification) {', '    @objc func showSettings', launchCoordinator, 'AppCoordinator launch');
coordinator = replaceOnce(coordinator,
`        let captures = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TFTMAC/Captures", isDirectory: true)`,
`        let captures = activeApplicationSupport
            .appendingPathComponent("Captures", isDirectory: true)`,
'mode-specific capture reveal');

let tests = readText('Tests/TFTMACTests/TFTMACGate1Tests.swift');
const addedTests = `
    private func runtimeModeRegistryData() throws -> Data {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try Data(contentsOf: repositoryRoot.appendingPathComponent("ssot/runtime-modes.json"))
    }

    func testRuntimeModeRegistryDefinesExactControlIdentity() throws {
        let registry = try TFTMACRuntimeModeRegistry(data: runtimeModeRegistryData())
        XCTAssertEqual(Set(registry.document.modes.keys), Set(TFTMACRuntimeMode.allCases.map(\\.rawValue)))
        XCTAssertEqual(registry.document.defaultMode, .control)
        let selection = try registry.selection(environment: [:])
        XCTAssertEqual(selection.mode, .control)
        XCTAssertEqual(selection.definition.avdName, "TFT_Ultra_Tablet")
        XCTAssertEqual(selection.definition.adbServerPort, 5038)
        XCTAssertEqual(selection.definition.consolePort, 5582)
        XCTAssertEqual(selection.definition.controllerPort, 8554)
        XCTAssertEqual(selection.definition.serial, "emulator-5582")
    }

    func testRuntimeModeRegistryFailsClosedForUnacceptedModes() throws {
        let registry = try TFTMACRuntimeModeRegistry(data: runtimeModeRegistryData())
        for requested in ["advanced_diagnostics", "candidate", "unknown"] {
            XCTAssertThrowsError(try registry.selection(environment: [
                TFTMACRuntimeModeRegistry.environmentKey: requested
            ]), requested)
        }
    }

    func testRuntimeModeRegistryRejectsTamperedBytes() throws {
        var data = try runtimeModeRegistryData()
        data.append(Data(" ".utf8))
        XCTAssertThrowsError(try TFTMACRuntimeModeRegistry(data: data))
        XCTAssertThrowsError(try TFTMACRuntimeModeAuthority(data: data))
    }

    func testSupplementalRuntimeAuthoritySeparatesStateAndLaunchStrategies() throws {
        let data = try runtimeModeRegistryData()
        let registry = try TFTMACRuntimeModeRegistry(data: data)
        let authority = try TFTMACRuntimeModeAuthority(data: data)
        XCTAssertNoThrow(try authority.validateConsistency(with: registry))
        let control = try authority.definition(for: .control)
        let diagnostics = try authority.definition(for: .advancedDiagnostics)
        let candidate = try authority.definition(for: .candidate)
        XCTAssertEqual(control.launchStrategy, .bundledForwarder)
        XCTAssertEqual(diagnostics.launchStrategy, .externalNativeHost)
        XCTAssertEqual(candidate.launchStrategy, .blocked)
        XCTAssertNotEqual(control.stateNamespace, diagnostics.stateNamespace)
        XCTAssertNotEqual(diagnostics.stateNamespace, candidate.stateNamespace)
        XCTAssertNotNil(diagnostics.diagnosticReceipts)
        XCTAssertNil(candidate.hostApplication)
        XCTAssertNotEqual(
            authority.applicationSupportURL(for: .control),
            authority.applicationSupportURL(for: .advancedDiagnostics)
        )
    }

    func testControlModePreservesValidatedNativeProfile() throws {
        let data = try runtimeModeRegistryData()
        let registry = try TFTMACRuntimeModeRegistry(data: data)
        let authority = try TFTMACRuntimeModeAuthority(data: data)
        let selection = try registry.selection(environment: [:])
        let effective = try authority.effectiveProfile(savedProfile: .playable, selection: selection)
        XCTAssertEqual(effective, .playable)
        XCTAssertEqual(effective.controllerPort, selection.definition.controllerPort)
    }

    func testRuntimeLeasePersistsExactModeIdentityAndRejectsSecondOwner() throws {
        let registry = try TFTMACRuntimeModeRegistry(data: runtimeModeRegistryData())
        let selection = try registry.selection(environment: [:])
        let identity = try selection.leaseIdentity()
        let stateRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("tftmac-mode-lease-test-\\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: stateRoot) }
        let first = try TFTMACRuntimeLease.acquire(stateRoot: stateRoot, identity: identity)
        defer { first.release() }
        let leaseURL = stateRoot.appendingPathComponent("native-runtime.lease")
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: leaseURL)) as? [String: Any]
        )
        XCTAssertEqual((object["schema"] as? NSNumber)?.intValue, 2)
        XCTAssertEqual(object["mode"] as? String, "control")
        XCTAssertEqual(object["registry_sha256"] as? String, registry.registrySha256)
        XCTAssertEqual(object["configuration_sha256"] as? String, selection.definition.configurationSha256)
        XCTAssertEqual(object["avd_name"] as? String, "TFT_Ultra_Tablet")
        XCTAssertEqual((object["adb_server_port"] as? NSNumber)?.intValue, 5038)
        XCTAssertEqual((object["console_port"] as? NSNumber)?.intValue, 5582)
        XCTAssertEqual((object["controller_port"] as? NSNumber)?.intValue, 8554)
        XCTAssertEqual(object["serial"] as? String, "emulator-5582")
        XCTAssertThrowsError(try TFTMACRuntimeLease.acquire(stateRoot: stateRoot, identity: identity))
    }
`;
ensure(tests.endsWith('}\n'), 'test class closing brace changed');
tests = `${tests.slice(0, -2)}${addedTests}}\n`;

let project = readText('TFTMAC.xcodeproj/project.pbxproj');
project = replaceOnce(project, '/* End PBXBuildFile section */', `\t\t100000000000000000000038 /* RuntimeMode.swift in Sources */ = {isa = PBXBuildFile; fileRef = 200000000000000000000023 /* RuntimeMode.swift */; };
\t\t100000000000000000000039 /* RuntimeMode.swift in Tests */ = {isa = PBXBuildFile; fileRef = 200000000000000000000023 /* RuntimeMode.swift */; };
\t\t10000000000000000000003A /* runtime-modes.json in Resources */ = {isa = PBXBuildFile; fileRef = 200000000000000000000024 /* runtime-modes.json */; };
\t\t10000000000000000000003B /* RuntimeModeAuthority.swift in Sources */ = {isa = PBXBuildFile; fileRef = 200000000000000000000025 /* RuntimeModeAuthority.swift */; };
\t\t10000000000000000000003C /* RuntimeModeAuthority.swift in Tests */ = {isa = PBXBuildFile; fileRef = 200000000000000000000025 /* RuntimeModeAuthority.swift */; };
\t\t10000000000000000000003D /* runtime-authority.json in Resources */ = {isa = PBXBuildFile; fileRef = 200000000000000000000026 /* runtime-authority.json */; };
/* End PBXBuildFile section */`, 'PBX build files');
project = replaceOnce(project, '/* End PBXFileReference section */', `\t\t200000000000000000000023 /* RuntimeMode.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RuntimeMode.swift; sourceTree = "<group>"; };
\t\t200000000000000000000024 /* runtime-modes.json */ = {isa = PBXFileReference; lastKnownFileType = text.json; path = ssot/runtime-modes.json; sourceTree = SOURCE_ROOT; };
\t\t200000000000000000000025 /* RuntimeModeAuthority.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RuntimeModeAuthority.swift; sourceTree = "<group>"; };
\t\t200000000000000000000026 /* runtime-authority.json */ = {isa = PBXFileReference; lastKnownFileType = text.json; path = ssot/runtime-authority.json; sourceTree = SOURCE_ROOT; };
/* End PBXFileReference section */`, 'PBX file references');
project = replaceOnce(project,
`\t\t\t\t400000000000000000000007 /* Tests */,
\t\t\t\t400000000000000000000009 /* Products */,`,
`\t\t\t\t400000000000000000000007 /* Tests */,
\t\t\t\t200000000000000000000024 /* runtime-modes.json */,
\t\t\t\t200000000000000000000026 /* runtime-authority.json */,
\t\t\t\t400000000000000000000009 /* Products */,`,
'PBX root resources');
project = replaceOnce(project,
`\t\t40000000000000000000000C /* Runtime */ = {isa = PBXGroup; children = (200000000000000000000017 /* RuntimeProfile.swift */, 200000000000000000000019 /* RuntimeLease.swift */,`,
`\t\t40000000000000000000000C /* Runtime */ = {isa = PBXGroup; children = (200000000000000000000017 /* RuntimeProfile.swift */, 200000000000000000000023 /* RuntimeMode.swift */, 200000000000000000000025 /* RuntimeModeAuthority.swift */, 200000000000000000000019 /* RuntimeLease.swift */,`,
'PBX runtime group');
project = replaceOnce(project,
`\t\t800000000000000000000001 /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };`,
`\t\t800000000000000000000001 /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (10000000000000000000003A /* runtime-modes.json in Resources */, 10000000000000000000003D /* runtime-authority.json in Resources */,); runOnlyForDeploymentPostprocessing = 0; };`,
'PBX resources phase');
project = replaceOnce(project,
`100000000000000000000025, 100000000000000000000028,`,
`100000000000000000000025, 100000000000000000000038, 10000000000000000000003B, 100000000000000000000028,`,
'PBX app sources');
project = replaceOnce(project,
`100000000000000000000026, 100000000000000000000029,`,
`100000000000000000000026, 100000000000000000000039, 10000000000000000000003C, 100000000000000000000029,`,
'PBX test sources');

let buildScript = readText('scripts/build-native-app.command');
buildScript = replaceOnce(buildScript,
`/usr/bin/codesign --force --sign "\${SIGNING_IDENTITY_HASH}" --timestamp=none "\${HOST_APP}"

/usr/bin/codesign --force --deep --sign "\${SIGNING_IDENTITY_HASH}" --timestamp=none "\${DIST}"
/usr/bin/codesign --verify --deep --strict --verbose=2 "\${DIST}"`,
`/usr/bin/codesign --force --sign "\${SIGNING_IDENTITY_HASH}" --timestamp=none "\${HOST_APP}"

# Seal the non-reproducible signed Mach-O identity into a receipt that is then
# protected by the outer application signature. Source and Info.plist hashes
# remain fixed in the runtime-mode registry; the signed receipt binds those
# inputs to the exact packaged host executable and UUID.
/usr/bin/python3 - "\${ROOT}" "\${DIST}" "\${HOST_APP}" <<'PY'
import datetime
import hashlib
import json
import pathlib
import plistlib
import re
import subprocess
import sys

root = pathlib.Path(sys.argv[1])
dist = pathlib.Path(sys.argv[2])
host = pathlib.Path(sys.argv[3])
source = root / "RuntimeHost/main.c"
info_source = root / "RuntimeHost/Info.plist"
info_packaged = host / "Contents/Info.plist"
executable = host / "Contents/MacOS/TFTMACEmulatorHost"

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

uuid_output = subprocess.check_output(["/usr/bin/dwarfdump", "--uuid", str(executable)], text=True)
uuids = [f"{match.group(1)}:{match.group(2)}" for match in re.finditer(r"UUID: ([0-9A-F-]+) \\(([^)]+)\\)", uuid_output)]
if not uuids:
    raise SystemExit("Control native host has no Mach-O UUID receipt")
with info_packaged.open("rb") as handle:
    bundle_identifier = plistlib.load(handle)["CFBundleIdentifier"]
compiler = subprocess.check_output(["/usr/bin/xcrun", "--find", "clang"], text=True).strip()
compiler_version = subprocess.check_output([compiler, "--version"], text=True).splitlines()[0]
receipt = {
    "schema": 1,
    "state": "CONTROL_NATIVE_HOST_BUILD_PASS",
    "generated_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "host_application_relative_path": "TFTMAC Emulator Host.app",
    "bundle_identifier": bundle_identifier,
    "source_path": "RuntimeHost/main.c",
    "source_sha256": sha256(source),
    "info_plist_path": "RuntimeHost/Info.plist",
    "info_plist_sha256": sha256(info_source),
    "packaged_info_plist_sha256": sha256(info_packaged),
    "executable_relative_path": "Contents/MacOS/TFTMACEmulatorHost",
    "executable_sha256": sha256(executable),
    "executable_uuids": uuids,
    "compiler_path": compiler,
    "compiler_version": compiler_version,
    "compile_arguments": ["-Os", "-arch", "arm64", "-mmacosx-version-min=15.0"],
    "signed_before_receipt": True,
    "outer_app_seals_receipt": True
}
receipt_path = dist / "Contents/Resources/control-host-build.json"
receipt_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\\n")
PY

# The nested host is already signed. Sign the outer app without deep-resigning
# it, so the exact executable hash in the newly written receipt stays true.
/usr/bin/codesign --force --sign "\${SIGNING_IDENTITY_HASH}" --timestamp=none "\${DIST}"
/usr/bin/codesign --verify --deep --strict --verbose=2 "\${DIST}"
/usr/bin/python3 - "\${DIST}" "\${HOST_APP}" <<'PY'
import hashlib
import json
import pathlib
import sys

dist = pathlib.Path(sys.argv[1])
host = pathlib.Path(sys.argv[2])
receipt = json.loads((dist / "Contents/Resources/control-host-build.json").read_text())
executable = host / receipt["executable_relative_path"]
h = hashlib.sha256(executable.read_bytes()).hexdigest()
if h != receipt["executable_sha256"]:
    raise SystemExit("Outer signing changed the receipted control-host executable")
PY`,
'control host signed receipt');

let verifier = readText('scripts/verify-tftmac.command');
verifier = replaceOnce(verifier,
`  ssot/runtime-authority.json \\
  ssot/retained-evidence-index.json \\`,
`  ssot/runtime-authority.json \\
  ssot/runtime-modes.json \\
  tftmac/Runtime/RuntimeMode.swift \\
  tftmac/Runtime/RuntimeModeAuthority.swift \\
  ${waveRoot}/validate-waveb-v3.mjs \\
  ssot/retained-evidence-index.json \\`,
'verifier required files');
verifier = replaceOnce(verifier,
`[[ "$TEST_FUNCTION_COUNT" == "43" ]] || fail "native test inventory drifted: expected 43, found $TEST_FUNCTION_COUNT"`,
`[[ "$TEST_FUNCTION_COUNT" == "49" ]] || fail "native test inventory drifted: expected 49, found $TEST_FUNCTION_COUNT"`,
'test count');
verifier = replaceOnce(verifier,
`node --check tools/tftmac-direct-control.mjs >/dev/null`,
`node --check tools/tftmac-direct-control.mjs >/dev/null
node --check ${waveRoot}/validate-waveb-v3.mjs >/dev/null`,
'validator syntax');
verifier = replaceOnce(verifier,
`[[ -x "\${RELEASE_DERIVED}/Build/Products/Release/TFTMAC.app/Contents/MacOS/TFTMAC" ]] \\
  || fail "unsigned Release build did not produce the TFTMAC executable"

/bin/zsh scripts/test-native-app.command`,
`readonly RELEASE_APP="\${RELEASE_DERIVED}/Build/Products/Release/TFTMAC.app"
[[ -x "\${RELEASE_APP}/Contents/MacOS/TFTMAC" ]] \\
  || fail "unsigned Release build did not produce the TFTMAC executable"
cmp -s ssot/runtime-modes.json "\${RELEASE_APP}/Contents/Resources/runtime-modes.json" \\
  || fail "unsigned Release app did not package the exact runtime-mode registry"
cmp -s ssot/runtime-authority.json "\${RELEASE_APP}/Contents/Resources/runtime-authority.json" \\
  || fail "unsigned Release app did not package the exact control authority"
node ${waveRoot}/validate-waveb-v3.mjs >/dev/null

/bin/zsh scripts/test-native-app.command`,
'verifier build resources');
verifier = replaceOnce(verifier,
`print "TFTMAC source validation: OK (unsigned Release build; 43 native tests)"`,
`print "TFTMAC source validation: OK (unsigned Release build; 49 native tests; Wave B mode authority PASS)"`,
'verifier final output');

const receipt = {
  schema: 1,
  state: 'WAVE_B_V3_IMPLEMENTATION_APPLIED',
  project_id: 'tftmac',
  change_id: changeId,
  operation_id: process.env.CLARA_OPERATION_ID ?? null,
  applied_at: new Date().toISOString(),
  base_head_sha: expectedHead,
  original_plan_sha256: expected[`${planRoot}/IMPLEMENTATION_PLAN.md`],
  scope_lock_sha256: expected[`${planRoot}/SCOPE_LOCK.txt`],
  continuation_amendment_sha256: expected[`${waveRoot}/CONTINUATION_AMENDMENT.md`],
  runtime_modes_sha256: registrySha,
  expected_test_count: 49,
  modified_paths: [
    'ssot/runtime-modes.json',
    'tftmac/App/AppCoordinator.swift',
    'tftmac/Runtime/RuntimeMode.swift',
    'tftmac/Runtime/RuntimeModeAuthority.swift',
    'tftmac/Runtime/RuntimeLease.swift',
    'tftmac/Runtime/TFTMACRuntime.swift',
    'Tests/TFTMACTests/TFTMACGate1Tests.swift',
    'TFTMAC.xcodeproj/project.pbxproj',
    'scripts/build-native-app.command',
    'scripts/verify-tftmac.command'
  ],
  effects: {
    source_only: true,
    emulator_launch_attempted: false,
    runtime_replacement_attempted: false,
    control_stop_attempted: false,
    installed_app_replacement_attempted: false,
    package_launch_attempted: false
  },
  next_safe_action: 'Run the single changed-head production source verifier and correct only a proven failure.'
};

const outputs = {
  'ssot/runtime-modes.json': registryText,
  'tftmac/App/AppCoordinator.swift': coordinator,
  'tftmac/Runtime/RuntimeMode.swift': runtimeModeSource,
  'tftmac/Runtime/RuntimeModeAuthority.swift': runtimeModeAuthoritySource,
  'tftmac/Runtime/RuntimeLease.swift': runtimeLeaseSource,
  'tftmac/Runtime/TFTMACRuntime.swift': runtime,
  'Tests/TFTMACTests/TFTMACGate1Tests.swift': tests,
  'TFTMAC.xcodeproj/project.pbxproj': project,
  'scripts/build-native-app.command': buildScript,
  'scripts/verify-tftmac.command': verifier,
  [`${waveRoot}/IMPLEMENTATION_RECEIPT.json`]: `${JSON.stringify(receipt, null, 2)}\n`
};
for (const [relativePath, content] of Object.entries(outputs)) {
  writeAtomic(relativePath, content, relativePath.endsWith('.command') || relativePath.endsWith('.mjs') ? 0o755 : 0o644);
}
console.log(JSON.stringify(receipt, null, 2));
