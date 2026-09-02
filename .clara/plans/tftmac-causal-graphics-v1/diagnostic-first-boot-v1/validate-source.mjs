#!/usr/bin/env node
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const registryPath = 'ssot/runtime-modes.json';
const expectedRegistrySha = 'f92cfc78923814d8eb3d8f6f550a4763ba918fe5e1c20088e2863d89ce58eafe';
const expectedPortReceiptSha = '3536b1d54a0643bc3fcbb9dbff01be2402ca9c45d2100e220c2f857e65a129cd';
const expectedStockShadowReceiptSha = '540f57f762d67b894916a96adc2c0836aec803a8af9cba988b8b5df94ddde285';

function absolute(relativePath) { return path.join(root, relativePath); }
function read(relativePath) { return fs.readFileSync(absolute(relativePath)); }
function readText(relativePath) { return fs.readFileSync(absolute(relativePath), 'utf8'); }
function sha256(data) { return crypto.createHash('sha256').update(data).digest('hex'); }
function fail(message) { throw new Error(`DIAGNOSTIC_FIRST_BOOT_SOURCE_FAILED: ${message}`); }
function assert(value, message) { if (!value) fail(message); }

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

for (const required of [
  '.clara/plans/tftmac-causal-graphics-v1/diagnostic-first-boot-v1/AMENDMENT.md',
  '.clara/plans/tftmac-causal-graphics-v1/diagnostic-first-boot-v1/ZENGATE_RECEIPT.json',
  '.clara/plans/tftmac-causal-graphics-v1/diagnostic-first-boot-v1/PORT_ALLOCATION_RECEIPT.json',
  'RuntimeHost/DiagnosticInfo.plist',
  'scripts/build-diagnostic-forwarder.command',
  'scripts/build-stock-shadow-runtime.command',
  registryPath,
  'tftmac/Runtime/RuntimeMode.swift',
  'tftmac/Runtime/RuntimeModeAuthority.swift',
  'tftmac/Runtime/TFTMACRuntime.swift',
  'Tests/TFTMACTests/TFTMACGate1Tests.swift'
]) assert(fs.existsSync(absolute(required)), `required source authority is missing: ${required}`);

const registryBytes = read(registryPath);
assert(sha256(registryBytes) === expectedRegistrySha, 'runtime-mode registry identity drifted');
const registry = JSON.parse(registryBytes);
assert(registry.schema === 1 && registry.contract === 'TFTMAC_RUNTIME_MODES_V1', 'runtime-mode contract drifted');
assert(registry.default_mode === 'control', 'control must remain the default mode');
assert(JSON.stringify(Object.keys(registry.modes).sort()) === JSON.stringify(['advanced_diagnostics', 'candidate', 'control']), 'runtime-mode inventory drifted');

for (const mode of Object.values(registry.modes)) {
  assert(configurationHash(mode) === mode.configuration_sha256, `${mode.mode} configuration hash drifted`);
}

const control = registry.modes.control;
assert(control.launch_state === 'enabled', 'control is not enabled');
assert(control.application_bundle_id === 'com.flashls1.tftmac', 'control app identity drifted');
assert(control.adb_server_port === 5038 && control.console_port === 5582 && control.controller_port === 8554, 'control ports drifted');
assert(control.avd_name === 'TFT_Ultra_Tablet' && control.serial === 'emulator-5582', 'control identity drifted');

const diagnostics = registry.modes.advanced_diagnostics;
assert(diagnostics.launch_state === 'enabled', 'advanced diagnostics is not enabled');
assert(diagnostics.application_bundle_id === 'com.flashls1.tftmac.dev', 'advanced diagnostic app identity drifted');
assert(diagnostics.adb_vendor_keys_policy === 'USER_DEFAULT_KEY', 'advanced diagnostic ADB-auth policy drifted');
assert(diagnostics.runtime_variant === 'stock_shadow', 'advanced diagnostic runtime variant drifted');
assert(diagnostics.sdk_root === '/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow/SDK', 'advanced diagnostic SDK root drifted');
assert(diagnostics.adb_path === '/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow/SDK/platform-tools/adb', 'advanced diagnostic ADB path drifted');
assert(diagnostics.requires_control_stopped === true && diagnostics.rollback_target === 'control', 'diagnostic isolation/rollback drifted');
assert(diagnostics.avd_name === 'TFTMAC_Diagnostic_StockShadow_R1' && diagnostics.serial === 'emulator-5586', 'diagnostic AVD identity drifted');
assert(diagnostics.adb_server_port === 5041 && diagnostics.console_port === 5586 && diagnostics.controller_port === 8556, 'diagnostic port allocation drifted');
assert(diagnostics.launch_strategy === 'external_native_host', 'diagnostic launch strategy drifted');
assert(diagnostics.host_application?.path === '/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Install/gate4-r9-forwarder-r1/TFTMAC Diagnostic Forwarder.app', 'diagnostic host path drifted');
assert(diagnostics.host_application?.bundle_identifier === 'com.flashls1.tftmac.runtime.diagnostic-forwarder', 'diagnostic host bundle identity drifted');
assert(diagnostics.host_application?.executable_relative_path === 'Contents/MacOS/TFTMACDiagnosticForwarder', 'diagnostic host executable path drifted');
assert(diagnostics.host_application?.executable_sha256 === '128239b2cf3ddb04669c4fda97e895e1a4a800dcf2c2144066979427d92af5b6', 'diagnostic host executable identity drifted');
assert(diagnostics.diagnostic_receipts?.build_id === 'stock-shadow-r1-20260902', 'stock-shadow build identity drifted');
for (const receipt of Object.values(diagnostics.diagnostic_receipts ?? {}).filter((value) => value && typeof value === 'object')) {
  assert(receipt.sha256 === expectedStockShadowReceiptSha, 'stock-shadow receipt reference drifted');
  assert(receipt.required_state === 'STOCK_SHADOW_RUNTIME_IDENTITY_PASS', 'stock-shadow receipt state drifted');
}

const candidate = registry.modes.candidate;
assert(candidate.launch_state === 'blocked_not_built' && candidate.controller_port === null, 'candidate is not fail-closed');

const portReceipt = JSON.parse(readText('.clara/plans/tftmac-causal-graphics-v1/diagnostic-first-boot-v1/PORT_ALLOCATION_RECEIPT.json'));
assert(sha256(read('.clara/plans/tftmac-causal-graphics-v1/diagnostic-first-boot-v1/PORT_ALLOCATION_RECEIPT.json')) === expectedPortReceiptSha, 'port receipt identity drifted');
assert(portReceipt.state === 'DIAGNOSTIC_PORT_ALLOCATION_PASS' && portReceipt.ports?.controller === 8556, 'port receipt contract drifted');

const runtimeModeSource = readText('tftmac/Runtime/RuntimeMode.swift');
assert(runtimeModeSource.includes(`static let expectedRegistrySha256 = "${expectedRegistrySha}"`), 'Swift registry pin drifted');
const runtimeSource = readText('tftmac/Runtime/TFTMACRuntime.swift');
assert(runtimeSource.includes('paths.launchStrategy == .bundledForwarder || paths.launchStrategy == .externalNativeHost'), 'runtime does not accept the receipted external native host');
assert(runtimeSource.includes('if paths.expectedEmulatorVersionContains == "37.1.11" {\n            arguments += ["-crash-report-mode", "disabled"]'), '37.1.11 Control/shadow crash-report consent suppression drifted');
const tests = readText('Tests/TFTMACTests/TFTMACGate1Tests.swift');
assert(tests.includes('testRuntimeModeRegistrySelectsReceiptedDiagnosticsAndRejectsUnacceptedModes'), 'diagnostic selection contract test is missing');

const testCount = fs.readdirSync(absolute('Tests/TFTMACTests'))
  .filter((name) => name.endsWith('.swift'))
  .reduce((total, name) => total + (readText(`Tests/TFTMACTests/${name}`).match(/^    func test/gm) ?? []).length, 0);
assert(testCount === 54, `expected 54 native tests, found ${testCount}`);

console.log(JSON.stringify({
  state: 'DIAGNOSTIC_FIRST_BOOT_SOURCE_PASS',
  runtime_modes_sha256: expectedRegistrySha,
  test_count: testCount,
  control_default: true,
  diagnostics: { avd: diagnostics.avd_name, adb: 5041, console: 5586, controller: 8556 },
  candidate: candidate.launch_state,
  external_artifacts_read: false
}, null, 2));
