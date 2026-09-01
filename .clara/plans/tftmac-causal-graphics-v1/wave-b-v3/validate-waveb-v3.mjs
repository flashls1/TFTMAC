#!/usr/bin/env node
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const root = process.cwd();
const planRoot = '.clara/plans/tftmac-causal-graphics-v1';
const waveRoot = `${planRoot}/wave-b-v3`;
const expectedPlanSha = '78785b29815dba26a8da1d2ed56e0e9c256d3e7d9cfb4c4857b3c954846e8d2b';
const expectedScopeSha = 'dc77b6913d14409adc883dd27a67c42e982c40ab9149a68771b61dc99fae297e';
const expectedBuildSha = '9556ffe5c9d083d3ba90006628b8fc5a94a6989f56fa21d40bb9a30f2f99ef8d';
const expectedCloneSha = '09e4b2d21290de582320cb0aee3148af25f5e2e59199e225e604afbb6cb19648';
const expectedHostSha = 'a72d10106acb83444a38027ed3978b6ef3bc60e7ec0ae0ba9439f67eb57f6067';

function absolute(relativePath) { return path.join(root, relativePath); }
function fail(message) { throw new Error(`WAVE_B_V3_VALIDATION_FAILED: ${message}`); }
function assert(value, message) { if (!value) fail(message); }
function sha256(data) { return crypto.createHash('sha256').update(data).digest('hex'); }
function read(relativePath) { return fs.readFileSync(absolute(relativePath)); }
function readText(relativePath) { return fs.readFileSync(absolute(relativePath), 'utf8'); }
function fileSha(relativePath) { return sha256(read(relativePath)); }
function externalSha(filePath) { return sha256(fs.readFileSync(filePath)); }
function run(executable, args, options = {}) {
  const result = spawnSync(executable, args, {
    cwd: root,
    encoding: 'utf8',
    maxBuffer: options.maxBuffer ?? 32 * 1024 * 1024,
    timeout: options.timeout ?? 30_000
  });
  if (result.error) fail(`${executable} failed: ${result.error.message}`);
  return { status: result.status, output: `${result.stdout ?? ''}${result.stderr ?? ''}` };
}
function configurationHash(mode) {
  const fields = [
    ['mode', mode.mode],
    ['launch_state', mode.launch_state],
    ['runtime_root', mode.runtime_root],
    ['sdk_root', mode.sdk_root],
    ['library_root', mode.library_root],
    ['emulator_path', mode.emulator_path],
    ['emulator_sha256', mode.emulator_sha256 ?? ''],
    ['gfxstream_backend_path', mode.gfxstream_backend_path],
    ['gfxstream_backend_sha256', mode.gfxstream_backend_sha256 ?? ''],
    ['adb_path', mode.adb_path],
    ['avd_home', mode.avd_home],
    ['avd_name', mode.avd_name],
    ['avd_directory', mode.avd_directory],
    ['avd_config_path', mode.avd_config_path],
    ['avd_config_sha256', mode.avd_config_sha256 ?? ''],
    ['avd_ini_path', mode.avd_ini_path],
    ['avd_ini_sha256', mode.avd_ini_sha256 ?? ''],
    ['adb_server_port', mode.adb_server_port],
    ['console_port', mode.console_port],
    ['controller_port', mode.controller_port ?? ''],
    ['serial', mode.serial],
    ['authority_manifest_kind', mode.authority_manifest.kind],
    ['authority_manifest_path', mode.authority_manifest.path],
    ['authority_manifest_sha256', mode.authority_manifest.sha256 ?? ''],
    ['application_bundle_id', mode.application_bundle_id],
    ['application_version', mode.application_version],
    ['application_build', mode.application_build],
    ['allowed_purpose', mode.allowed_purpose],
    ['comparability_class', mode.comparability_class],
    ['rollback_target', mode.rollback_target],
    ['requires_control_stopped', String(mode.requires_control_stopped)]
  ];
  return sha256(Buffer.from(fields.map(([key, value]) => `${key}=${value}`).join('\n')));
}
function assertSha(value, label) {
  assert(typeof value === 'string' && /^[0-9a-f]{64}$/.test(value), `${label} is not a lowercase SHA-256`);
}
function assertUUIDs(filePath, expected, label) {
  assert(Array.isArray(expected) && expected.length > 0, `${label} UUID authority is empty`);
  const result = run('/usr/bin/dwarfdump', ['--uuid', filePath]);
  assert(result.status === 0, `${label} UUID inspection failed`);
  for (const identity of expected) {
    const [uuid, arch] = identity.split(':');
    assert(uuid && arch && result.output.toUpperCase().includes(uuid.toUpperCase()) && result.output.includes(`(${arch})`), `${label} UUID drifted`);
  }
}
function readSealed(reference) {
  assertSha(reference.sha256, `${reference.path} receipt SHA`);
  assert(externalSha(reference.path) === reference.sha256, `sealed receipt hash drifted: ${reference.path}`);
  const sidecar = fs.readFileSync(`${reference.path}.sha256`, 'utf8').trim().split(/\s+/)[0];
  assert(sidecar === reference.sha256, `sealed receipt sidecar drifted: ${reference.path}`);
  return JSON.parse(fs.readFileSync(reference.path, 'utf8'));
}

assert(fileSha(`${planRoot}/IMPLEMENTATION_PLAN.md`) === expectedPlanSha, 'original plan identity drifted');
assert(fileSha(`${planRoot}/SCOPE_LOCK.txt`) === expectedScopeSha, 'scope-lock identity drifted');
for (const required of [
  `${waveRoot}/CONTINUATION_AMENDMENT.md`,
  `${waveRoot}/PREFLIGHT.json`,
  `${waveRoot}/ZENGATE_RECEIPT.json`,
  `${waveRoot}/PREPARATION_RECEIPT.json`,
  `${waveRoot}/IMPLEMENTATION_RECEIPT.json`,
  'ssot/runtime-modes.json',
  'ssot/runtime-authority.json',
  'tftmac/Runtime/RuntimeMode.swift',
  'tftmac/Runtime/RuntimeModeAuthority.swift',
  'tftmac/Runtime/RuntimeLease.swift',
  'tftmac/Runtime/TFTMACRuntime.swift',
  'tftmac/App/AppCoordinator.swift',
  'Tests/TFTMACTests/TFTMACGate1Tests.swift',
  'TFTMAC.xcodeproj/project.pbxproj',
  'scripts/verify-tftmac.command'
]) assert(fs.existsSync(absolute(required)), `required Wave B file is missing: ${required}`);

const registryBytes = read('ssot/runtime-modes.json');
const registrySha = sha256(registryBytes);
const runtimeModeSource = readText('tftmac/Runtime/RuntimeMode.swift');
const pinned = runtimeModeSource.match(/static let expectedRegistrySha256 = "([0-9a-f]{64})"/);
assert(pinned?.[1] === registrySha, 'Swift registry identity does not match packaged JSON');
const registry = JSON.parse(registryBytes);
assert(registry.schema === 1, 'runtime-mode schema must remain 1');
assert(registry.contract === 'TFTMAC_RUNTIME_MODES_V1', 'runtime-mode contract drifted');
assert(registry.default_mode === 'control', 'control is not the default mode');
assert(registry.selection_environment_variable === 'TFTMAC_RUNTIME_MODE', 'selection environment variable drifted');
assert(registry.active_lease_relative_path === 'State/native-runtime.lease', 'global exclusive lease path drifted');
assert(JSON.stringify(Object.keys(registry.modes).sort()) === JSON.stringify(['advanced_diagnostics', 'candidate', 'control']), 'registry does not define exactly three modes');

const usedPorts = new Map();
const usedNamespaces = new Set();
for (const [name, mode] of Object.entries(registry.modes)) {
  assert(name === mode.mode, `registry key mismatch for ${name}`);
  assert(configurationHash(mode) === mode.configuration_sha256, `configuration SHA drifted for ${name}`);
  assert(mode.serial === `emulator-${mode.console_port}`, `serial/console identity drifted for ${name}`);
  assert(!usedNamespaces.has(mode.state_namespace), `state namespace collision at ${mode.state_namespace}`);
  usedNamespaces.add(mode.state_namespace);
  for (const [kind, value] of [['adb', mode.adb_server_port], ['console', mode.console_port], ['controller', mode.controller_port]]) {
    if (value === null) continue;
    assert(Number.isInteger(value) && value > 0 && value < 65536, `${name}.${kind} is invalid`);
    assert(!usedPorts.has(value), `port ${value} collides between ${usedPorts.get(value)} and ${name}.${kind}`);
    usedPorts.set(value, `${name}.${kind}`);
  }
}

const control = registry.modes.control;
assert(control.launch_state === 'enabled', 'control is not enabled');
assert(control.state_namespace === 'control' && control.uses_legacy_application_support_root === true, 'control state compatibility drifted');
assert(control.launch_strategy === 'bundled_forwarder' && control.profile_policy === 'validated_native_preferences', 'control launch/profile strategy drifted');
assert(control.runtime_root === '/Volumes/MAC MINI M4/TFTMAC/Runtime', 'control root drifted');
assert(control.avd_name === 'TFT_Ultra_Tablet', 'control AVD drifted');
assert(control.adb_server_port === 5038 && control.console_port === 5582 && control.controller_port === 8554, 'control ports drifted');
assert(control.serial === 'emulator-5582', 'control serial drifted');
assert(control.rollback_target === 'control' && control.requires_control_stopped === false, 'control rollback contract drifted');
for (const [filePath, expected, label] of [
  [control.adb_path, control.adb_sha256, 'control ADB'],
  [control.emulator_path, control.emulator_sha256, 'control emulator'],
  [control.qemu_path, control.qemu_sha256, 'control qemu'],
  [control.gfxstream_backend_path, control.gfxstream_backend_sha256, 'control gfxstream']
]) {
  assertSha(expected, `${label} SHA`);
  assert(externalSha(filePath) === expected, `${label} hash drifted`);
}
assertUUIDs(control.emulator_path, control.emulator_uuids, 'control emulator');
assertUUIDs(control.qemu_path, control.qemu_uuids, 'control qemu');
assertUUIDs(control.gfxstream_backend_path, control.gfxstream_backend_uuids, 'control gfxstream');
const controlVersion = run(control.emulator_path, ['-version']);
assert(controlVersion.status === 0 && controlVersion.output.includes(control.expected_emulator_version_contains), 'control emulator version drifted');
assert(control.authority_manifest.sha256 === fileSha('ssot/runtime-authority.json'), 'control authority manifest hash drifted');
assert(control.host_application.executable_sha256 === null, 'control host cannot pin a non-reproducible pre-sign executable hash');
assert(control.host_application.source_path === 'RuntimeHost/main.c', 'control host source path drifted');
assert(control.host_application.source_sha256 === fileSha('RuntimeHost/main.c'), 'control host source identity drifted');
assert(control.host_application.info_plist_path === 'RuntimeHost/Info.plist', 'control host Info.plist path drifted');
assert(control.host_application.info_plist_sha256 === fileSha('RuntimeHost/Info.plist'), 'control host Info.plist identity drifted');
assert(control.host_application.build_receipt_resource === 'control-host-build.json', 'control host signed build receipt contract drifted');
const buildScript = readText('scripts/build-native-app.command');
for (const required of ['CONTROL_NATIVE_HOST_BUILD_PASS', 'control-host-build.json', 'executable_uuids', 'source_sha256', 'info_plist_sha256']) {
  assert(buildScript.includes(required), `build script is missing control-host receipt field: ${required}`);
}
assert(!buildScript.includes('codesign --force --deep --sign "${SIGNING_IDENTITY_HASH}" --timestamp=none "${DIST}"'), 'outer app still deep-resigns the nested control host after its receipt');

const diagnostics = registry.modes.advanced_diagnostics;
assert(diagnostics.launch_state === 'blocked_pending_controller_lease' && diagnostics.controller_port === null, 'diagnostics are not fail-closed');
assert(diagnostics.state_namespace === 'advanced_diagnostics' && diagnostics.uses_legacy_application_support_root === false, 'diagnostic state isolation drifted');
assert(diagnostics.launch_strategy === 'external_native_host' && diagnostics.profile_policy === 'fixed_registry_profile', 'diagnostic launch/profile strategy drifted');
assert(diagnostics.adb_server_port === 5041 && diagnostics.console_port === 5586 && diagnostics.serial === 'emulator-5586', 'diagnostic port identity drifted');
assert(diagnostics.requires_control_stopped === true && diagnostics.rollback_target === 'control', 'diagnostic noninterference contract drifted');
for (const [filePath, expected, label] of [
  [diagnostics.adb_path, diagnostics.adb_sha256, 'diagnostic ADB'],
  [diagnostics.emulator_path, diagnostics.emulator_sha256, 'diagnostic emulator'],
  [diagnostics.qemu_path, diagnostics.qemu_sha256, 'diagnostic qemu'],
  [diagnostics.gfxstream_backend_path, diagnostics.gfxstream_backend_sha256, 'diagnostic gfxstream'],
  [diagnostics.avd_config_path, diagnostics.avd_config_sha256, 'diagnostic AVD config'],
  [diagnostics.avd_ini_path, diagnostics.avd_ini_sha256, 'diagnostic AVD ini']
]) {
  assertSha(expected, `${label} SHA`);
  assert(externalSha(filePath) === expected, `${label} hash drifted`);
}
assertUUIDs(diagnostics.emulator_path, diagnostics.emulator_uuids, 'diagnostic emulator');
assertUUIDs(diagnostics.qemu_path, diagnostics.qemu_uuids, 'diagnostic qemu');
assertUUIDs(diagnostics.gfxstream_backend_path, diagnostics.gfxstream_backend_uuids, 'diagnostic gfxstream');
const diagnosticVersion = run(diagnostics.emulator_path, ['-version']);
assert(diagnosticVersion.status === 0 && diagnosticVersion.output.includes(diagnostics.expected_emulator_version_contains), 'diagnostic emulator version drifted');

const receipts = diagnostics.diagnostic_receipts;
assert(receipts.build.sha256 === expectedBuildSha && receipts.clone.sha256 === expectedCloneSha && receipts.native_host.sha256 === expectedHostSha, 'diagnostic receipt identities drifted');
const build = readSealed(receipts.build);
assert(build.state === 'DIAGNOSTIC_BUILD_IDENTITY_PASS' && build.build_id === receipts.build_id, 'diagnostic build state drifted');
assert(build.non_comparable_to_stock === true && build.control_runtime_touched === false && build.control_noninterference?.matched === true, 'diagnostic build noninterference drifted');
assert(build.release_and_tracing?.runtime_configuration_sha256 === receipts.runtime_configuration_sha256, 'diagnostic runtime configuration receipt drifted');
assert(build.emulator?.path === diagnostics.emulator_path && build.emulator?.sha256 === diagnostics.emulator_sha256, 'diagnostic build emulator identity drifted');
assert(JSON.stringify(build.emulator?.uuids) === JSON.stringify(diagnostics.emulator_uuids), 'diagnostic build emulator UUIDs drifted');
assert(build.gfxstream_backend?.path === diagnostics.gfxstream_backend_path && build.gfxstream_backend?.sha256 === diagnostics.gfxstream_backend_sha256, 'diagnostic build gfxstream identity drifted');
assert(JSON.stringify(build.gfxstream_backend?.uuids) === JSON.stringify(diagnostics.gfxstream_backend_uuids), 'diagnostic build gfxstream UUIDs drifted');

const clone = readSealed(receipts.clone);
assert(clone.state === 'DIAGNOSTIC_AVD_CLONE_RECEIPT_PASS' && clone.build_id === receipts.build_id, 'diagnostic clone state drifted');
assert(clone.diagnostic_avd?.name === diagnostics.avd_name && clone.diagnostic_avd?.avd_path === diagnostics.avd_directory, 'diagnostic clone AVD identity drifted');
assert(clone.diagnostic_avd?.config_sha256 === diagnostics.avd_config_sha256 && clone.diagnostic_avd?.ini_sha256 === diagnostics.avd_ini_sha256, 'diagnostic clone configuration identity drifted');
assert(clone.diagnostic_avd?.adb_server_port === diagnostics.adb_server_port && clone.diagnostic_avd?.console_port === diagnostics.console_port && clone.diagnostic_avd?.serial === diagnostics.serial, 'diagnostic clone port identity drifted');
assert(clone.accepted_build?.sha256 === expectedBuildSha, 'diagnostic clone accepted-build link drifted');
assert(clone.control_noninterference_matched === true && clone.sealed_before_first_boot === true, 'diagnostic clone seal drifted');
assert(clone.first_boot_attempted === false && clone.launch_attempted === false && clone.control_runtime_mutation_attempted === false && clone.control_avd_touched === false, 'diagnostic clone no-first-boot boundary drifted');

const hostReceipt = readSealed(receipts.native_host);
assert(hostReceipt.state === 'DIAGNOSTIC_NATIVE_HOST_BUILD_PASS' && hostReceipt.build_id === receipts.build_id, 'diagnostic native-host state drifted');
assert(hostReceipt.app?.path === diagnostics.host_application.path && hostReceipt.app?.bundle_identifier === diagnostics.host_application.bundle_identifier, 'diagnostic native-host app identity drifted');
const diagnosticHostExecutable = path.join(diagnostics.host_application.path, diagnostics.host_application.executable_relative_path);
assertSha(diagnostics.host_application.executable_sha256, 'diagnostic native-host executable SHA');
assert(hostReceipt.app?.executable?.path === diagnosticHostExecutable && hostReceipt.app?.executable?.sha256 === diagnostics.host_application.executable_sha256, 'diagnostic native-host executable receipt drifted');
assert(externalSha(diagnosticHostExecutable) === diagnostics.host_application.executable_sha256, 'diagnostic native-host executable drifted');
assert(hostReceipt.app?.codesign_verify_status === 0 && hostReceipt.control_runtime_mutation_attempted === false, 'diagnostic native-host signing/noninterference drifted');
assert(hostReceipt.launch_contract?.method?.includes('/usr/bin/open') && hostReceipt.launch_contract?.emulator_spawn_owner === 'NATIVE_MACOS_APP_PROCESS' && hostReceipt.launch_contract?.service_context_emulator_spawn_forbidden === true, 'diagnostic native-host launch contract drifted');

const candidate = registry.modes.candidate;
assert(candidate.launch_state === 'blocked_not_built' && candidate.controller_port === null, 'candidate is not fail-closed');
assert(candidate.state_namespace === 'candidate' && candidate.launch_strategy === 'blocked' && candidate.profile_policy === 'blocked', 'candidate isolation drifted');
assert(candidate.requires_control_stopped === true && candidate.rollback_target === 'control', 'candidate rollback contract drifted');

const runtime = readText('tftmac/Runtime/TFTMACRuntime.swift');
for (const forbidden of ['["-P", "5038"', '"emulator-5582"', '"@TFT_Ultra_Tablet"', '"-iTCP:5582"', '"-iTCP:8554"']) {
  assert(!runtime.includes(forbidden), `shared runtime still hard-codes control identity: ${forbidden}`);
}
for (const required of [
  'TFTMACSelectedRuntimeConfiguration',
  'runtimeConfiguration.authority.resolveForLaunch',
  'TFTMACRuntimeLease.acquire(',
  'identity: leaseIdentity',
  'validateLoadedRuntime(',
  'paths.adbServerPort',
  'paths.consolePort',
  'paths.controllerPort',
  'paths.serial',
  'paths.avdName'
]) assert(runtime.includes(required), `runtime is missing mode-aware source seam: ${required}`);

const coordinator = readText('tftmac/App/AppCoordinator.swift');
assert(coordinator.includes('TFTMACSelectedRuntimeConfiguration.load'), 'AppCoordinator does not load the accepted runtime configuration');
assert(coordinator.includes('runtimeConfiguration: runtimeConfiguration'), 'AppCoordinator does not pass selected runtime authority');
assert(coordinator.includes('activeApplicationSupport = runtimeConfiguration.applicationSupport'), 'AppCoordinator does not preserve mode-specific capture state');

const project = readText('TFTMAC.xcodeproj/project.pbxproj');
for (const required of ['RuntimeMode.swift in Sources', 'RuntimeModeAuthority.swift in Sources', 'runtime-modes.json in Resources', 'runtime-authority.json in Resources']) {
  assert(project.includes(required), `Xcode project is missing ${required}`);
}
const testCount = (readText('Tests/TFTMACTests/TFTMACGate1Tests.swift').match(/^    func test/gm) ?? []).length;
assert(testCount === 49, `expected 49 native tests after Wave B, found ${testCount}`);

const receipt = JSON.parse(readText(`${waveRoot}/IMPLEMENTATION_RECEIPT.json`));
assert(receipt.state === 'WAVE_B_V3_IMPLEMENTATION_APPLIED', 'implementation receipt state drifted');
assert(receipt.runtime_modes_sha256 === registrySha, 'implementation receipt registry SHA drifted');
assert(receipt.effects?.source_only === true, 'implementation receipt is not source-only');
for (const effect of ['emulator_launch_attempted', 'runtime_replacement_attempted', 'control_stop_attempted', 'installed_app_replacement_attempted', 'package_launch_attempted']) {
  assert(receipt.effects?.[effect] === false, `implementation receipt reports forbidden effect: ${effect}`);
}

console.log(JSON.stringify({
  state: 'WAVE_B_V3_SOURCE_VALIDATION_PASS',
  runtime_modes_sha256: registrySha,
  test_count: testCount,
  control: { avd: control.avd_name, adb: control.adb_server_port, console: control.console_port, controller: control.controller_port, serial: control.serial },
  advanced_diagnostics: { state: diagnostics.launch_state, first_boot_attempted: clone.first_boot_attempted, launch_attempted: clone.launch_attempted },
  candidate: { state: candidate.launch_state },
  runtime_effect_attempted: false
}, null, 2));
