import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const root = process.cwd();
const planRoot = ".clara/plans/tftmac-causal-graphics-v1";
const operationId = "tftmac-waveb-source-apply-20260901-v1";

const expectedInputs = {
  [`${planRoot}/SCOPE_LOCK.txt`]: "dc77b6913d14409adc883dd27a67c42e982c40ab9149a68771b61dc99fae297e",
  [`${planRoot}/RuntimeMode.swift.template`]: "2e105ff01b778e98a4a6ef33e0c02972102b4b73aa0c8cd2250eafb2bac6b113",
  [`${planRoot}/RuntimeLease.swift.template`]: "de774fd9bd59020093ec35736374f0dfc6013831132ba42c386c6188a4bbe72e",
  [`${planRoot}/AppCoordinator.swift.template`]: "5e95ff55b865d217e058ce252e8052eaba79a47bfd860c43cc9740e126ee35f6",
  "ssot/runtime-modes.json": "7912c8d40027a7dbf99b9a91f495493a918ef38921fa5cc4077fddfd987fe579",
  "ssot/runtime-authority.json": "2af6196e08b3f81032b8226fa3a9c25a3b0d99537f0872b7eb21a96aaf2b5d2f",
  "tftmac/App/AppCoordinator.swift": "d0eb27df9a0e6aaa45ff60c63fd81bc229350a6f8feca833b776bbe4a954bda4",
  "tftmac/Runtime/RuntimeLease.swift": "55a44dbd5fc8b112cb48d17e879c00ae068161f2755af1876244e03bf75b498b",
  "tftmac/Runtime/TFTMACRuntime.swift": "8932032d93af01b46e46b5fb5a04eff1ec457f2f0e8f92f364d5a1a703ab5a5f",
  "TFTMAC.xcodeproj/project.pbxproj": "4961d37cc1802ca179b7f115ff4be3a4f1c222e706a01aff9f137fcb27c57dfd",
  "Tests/TFTMACTests/TFTMACGate1Tests.swift": "3a3307d19d2a48c22ee5504c96b4ee9e428992d2b026bedec2946240abc803d6",
  "scripts/verify-tftmac.command": "d587850fef7d5b25bf2a46cf6249824703130761b1ed388e1e93c485be763ccc"
};

const templatePaths = [
  `${planRoot}/RuntimeMode.swift.template`,
  `${planRoot}/RuntimeLease.swift.template`,
  `${planRoot}/AppCoordinator.swift.template`
];

function absolute(relativePath) {
  return path.join(root, relativePath);
}

function sha256Buffer(buffer) {
  return crypto.createHash("sha256").update(buffer).digest("hex");
}

function sha256Text(text) {
  return sha256Buffer(Buffer.from(text, "utf8"));
}

function sha256FileSync(relativePath) {
  return sha256Buffer(fs.readFileSync(absolute(relativePath)));
}

async function sha256ExternalFile(filePath) {
  return await new Promise((resolve, reject) => {
    const hash = crypto.createHash("sha256");
    const stream = fs.createReadStream(filePath);
    stream.on("data", (chunk) => hash.update(chunk));
    stream.on("error", reject);
    stream.on("end", () => resolve(hash.digest("hex")));
  });
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function readText(relativePath) {
  return fs.readFileSync(absolute(relativePath), "utf8");
}

function replaceOnce(text, before, after, label) {
  const first = text.indexOf(before);
  assert(first >= 0, `${label}: required anchor was not found`);
  assert(text.indexOf(before, first + before.length) < 0, `${label}: required anchor was not unique`);
  return text.slice(0, first) + after + text.slice(first + before.length);
}

function insertBefore(text, marker, insertion, label) {
  const index = text.indexOf(marker);
  assert(index >= 0, `${label}: insertion marker was not found`);
  assert(text.indexOf(marker, index + marker.length) < 0, `${label}: insertion marker was not unique`);
  return text.slice(0, index) + insertion + text.slice(index);
}

function configurationHash(mode) {
  const values = [
    ["mode", mode.mode],
    ["launch_state", mode.launch_state],
    ["runtime_root", mode.runtime_root],
    ["sdk_root", mode.sdk_root],
    ["library_root", mode.library_root],
    ["emulator_path", mode.emulator_path],
    ["emulator_sha256", mode.emulator_sha256 ?? ""],
    ["gfxstream_backend_path", mode.gfxstream_backend_path],
    ["gfxstream_backend_sha256", mode.gfxstream_backend_sha256 ?? ""],
    ["adb_path", mode.adb_path],
    ["avd_home", mode.avd_home],
    ["avd_name", mode.avd_name],
    ["avd_directory", mode.avd_directory],
    ["avd_config_path", mode.avd_config_path],
    ["avd_config_sha256", mode.avd_config_sha256 ?? ""],
    ["avd_ini_path", mode.avd_ini_path],
    ["avd_ini_sha256", mode.avd_ini_sha256 ?? ""],
    ["adb_server_port", mode.adb_server_port],
    ["console_port", mode.console_port],
    ["controller_port", mode.controller_port ?? ""],
    ["serial", mode.serial],
    ["authority_manifest_kind", mode.authority_manifest.kind],
    ["authority_manifest_path", mode.authority_manifest.path],
    ["authority_manifest_sha256", mode.authority_manifest.sha256 ?? ""],
    ["application_bundle_id", mode.application_bundle_id],
    ["application_version", mode.application_version],
    ["application_build", mode.application_build],
    ["allowed_purpose", mode.allowed_purpose],
    ["comparability_class", mode.comparability_class],
    ["rollback_target", mode.rollback_target],
    ["requires_control_stopped", String(mode.requires_control_stopped)]
  ];
  return sha256Text(values.map(([key, value]) => `${key}=${value}`).join("\n"));
}

function validateRegistry(registry) {
  assert(registry.schema === 1, "runtime registry schema must be 1");
  assert(registry.default_mode === "control", "control must remain the default runtime mode");
  assert(registry.active_lease_relative_path === "State/native-runtime.lease", "runtime lease path drifted");
  const names = Object.keys(registry.modes).sort();
  assert(JSON.stringify(names) === JSON.stringify(["advanced_diagnostics", "candidate", "control"]), "runtime registry must define exactly three modes");
  const occupied = new Map();
  for (const [name, mode] of Object.entries(registry.modes)) {
    assert(name === mode.mode, `runtime registry key mismatch for ${name}`);
    assert(configurationHash(mode) === mode.configuration_sha256, `configuration SHA mismatch for ${name}`);
    assert(mode.serial === `emulator-${mode.console_port}`, `serial/console mismatch for ${name}`);
    for (const [kind, value] of [["adb", mode.adb_server_port], ["console", mode.console_port], ["controller", mode.controller_port]]) {
      if (value === null) continue;
      assert(Number.isInteger(value) && value > 0 && value <= 65535, `invalid ${kind} port for ${name}`);
      assert(!occupied.has(value), `port ${value} is shared by ${occupied.get(value)} and ${name}.${kind}`);
      occupied.set(value, `${name}.${kind}`);
    }
  }
  const control = registry.modes.control;
  assert(control.launch_state === "enabled", "control must remain enabled");
  assert(control.adb_server_port === 5038 && control.console_port === 5582 && control.controller_port === 8554, "control lease identity drifted");
  assert(control.serial === "emulator-5582", "control serial drifted");
  assert(control.rollback_target === "control" && control.requires_control_stopped === false, "control rollback contract drifted");
  const diagnostics = registry.modes.advanced_diagnostics;
  assert(diagnostics.launch_state === "blocked_pending_controller_lease" && diagnostics.controller_port === null, "diagnostics must remain blocked pending a controller receipt");
  assert(diagnostics.adb_server_port === 5041 && diagnostics.console_port === 5586 && diagnostics.serial === "emulator-5586", "diagnostic lease identity drifted");
  assert(diagnostics.requires_control_stopped === true && diagnostics.rollback_target === "control", "diagnostic noninterference contract drifted");
  const candidate = registry.modes.candidate;
  assert(candidate.launch_state === "blocked_not_built" && candidate.controller_port === null, "candidate must remain blocked until built and accepted");
  assert(candidate.requires_control_stopped === true && candidate.rollback_target === "control", "candidate rollback contract drifted");
}

for (const [relativePath, expected] of Object.entries(expectedInputs)) {
  assert(fs.existsSync(absolute(relativePath)), `required input is missing: ${relativePath}`);
  const observed = sha256FileSync(relativePath);
  assert(observed === expected, `input drift for ${relativePath}: expected ${expected}, observed ${observed}`);
}
assert(!fs.existsSync(absolute("tftmac/Runtime/RuntimeMode.swift")), "RuntimeMode.swift already exists; refusing a non-idempotent replay");

const registry = JSON.parse(readText("ssot/runtime-modes.json"));
validateRegistry(registry);
const control = registry.modes.control;
control.emulator_sha256 = await sha256ExternalFile(control.emulator_path);
control.gfxstream_backend_sha256 = await sha256ExternalFile(control.gfxstream_backend_path);
control.configuration_sha256 = configurationHash(control);
validateRegistry(registry);
const registryOutput = `${JSON.stringify(registry, null, 2)}\n`;

const runtimeModeOutput = readText(`${planRoot}/RuntimeMode.swift.template`);
const runtimeLeaseOutput = readText(`${planRoot}/RuntimeLease.swift.template`);
const appCoordinatorOutput = readText(`${planRoot}/AppCoordinator.swift.template`);

let runtime = readText("tftmac/Runtime/TFTMACRuntime.swift");
const actorStart = runtime.indexOf("actor TFTMACRuntimeService {");
const controllerStart = runtime.lastIndexOf("final class TFTMACRuntimeController");
assert(actorStart >= 0 && controllerStart > actorStart, "runtime service/controller boundaries were not found");
const runtimePrefix = runtime.slice(0, actorStart);
let actor = runtime.slice(actorStart, controllerStart);
let controller = runtime.slice(controllerStart);

actor = replaceOnce(
  actor,
  "    private let profile: TFTMACRuntimeProfile\n",
  "    private let profile: TFTMACRuntimeProfile\n    private let runtimeSelection: TFTMACRuntimeSelection\n",
  "runtime service selection field"
);
actor = replaceOnce(
  actor,
  "    init(\n        profile: TFTMACRuntimeProfile,\n        mailbox: LatestFrameMailbox,",
  "    init(\n        profile: TFTMACRuntimeProfile,\n        runtimeSelection: TFTMACRuntimeSelection,\n        mailbox: LatestFrameMailbox,",
  "runtime service initializer signature"
);
actor = replaceOnce(
  actor,
  "        self.profile = profile\n        self.mailbox = mailbox",
  "        self.profile = profile\n        self.runtimeSelection = runtimeSelection\n        self.mailbox = mailbox",
  "runtime service initializer assignment"
);

const oldLeaseBlock = String.raw`            let paths = try TFTMACRuntimePaths.discover()
            self.paths = paths
            let stateRoot = paths.applicationSupport.appendingPathComponent("State", isDirectory: true)
            runtimeLease = try TFTMACRuntimeLease.acquire(stateRoot: stateRoot)
            telemetry.recordEvent("RUNTIME_LEASE_ACQUIRED", payload: [
                "lease": "State/native-runtime.lease",
                "pid": ProcessInfo.processInfo.processIdentifier,
                "exclusive": true
            ])`;
const newLeaseBlock = String.raw`            try runtimeSelection.validateForLaunch()
            let leaseIdentity = try runtimeSelection.leaseIdentity()
            guard profile.controllerPort == leaseIdentity.controllerPort else {
                throw TFTMACRuntimeModeError(
                    message: "Runtime profile controller port \(profile.controllerPort) does not match the accepted \(runtimeSelection.mode.rawValue) lease port \(leaseIdentity.controllerPort)."
                )
            }
            let definition = runtimeSelection.definition
            let paths = try TFTMACRuntimePaths.discover()
            guard paths.sdkRoot.standardizedFileURL.path == URL(fileURLWithPath: definition.sdkRoot, isDirectory: true).standardizedFileURL.path,
                  paths.emulator.standardizedFileURL.path == URL(fileURLWithPath: definition.emulatorPath).standardizedFileURL.path,
                  paths.adb.standardizedFileURL.path == URL(fileURLWithPath: definition.adbPath).standardizedFileURL.path,
                  paths.avdHome.standardizedFileURL.path == URL(fileURLWithPath: definition.avdHome, isDirectory: true).standardizedFileURL.path,
                  paths.avdDirectory.standardizedFileURL.path == URL(fileURLWithPath: definition.avdDirectory, isDirectory: true).standardizedFileURL.path,
                  paths.avdConfig.standardizedFileURL.path == URL(fileURLWithPath: definition.avdConfigPath).standardizedFileURL.path else {
                throw TFTMACRuntimeModeError(
                    message: "The discovered runtime paths do not match the accepted \(runtimeSelection.mode.rawValue) registry identity."
                )
            }
            self.paths = paths
            guard runtimeSelection.activeLeaseRelativePath == "State/native-runtime.lease" else {
                throw TFTMACRuntimeModeError(message: "The accepted runtime lease path changed unexpectedly.")
            }
            let stateRoot = paths.applicationSupport.appendingPathComponent("State", isDirectory: true)
            runtimeLease = try TFTMACRuntimeLease.acquire(stateRoot: stateRoot, identity: leaseIdentity)
            telemetry.recordEvent("RUNTIME_LEASE_ACQUIRED", payload: [
                "lease": runtimeSelection.activeLeaseRelativePath,
                "pid": ProcessInfo.processInfo.processIdentifier,
                "exclusive": true,
                "mode": runtimeSelection.mode.rawValue,
                "registry_sha256": runtimeSelection.registrySha256,
                "configuration_sha256": leaseIdentity.configurationSha256,
                "avd": leaseIdentity.avdName,
                "adb_server_port": leaseIdentity.adbServerPort,
                "console_port": leaseIdentity.consolePort,
                "controller_port": leaseIdentity.controllerPort,
                "serial": leaseIdentity.serial
            ])`;
actor = replaceOnce(actor, oldLeaseBlock, newLeaseBlock, "runtime lease acquisition boundary");

controller = replaceOnce(
  controller,
  "    init(\n        profile: TFTMACRuntimeProfile,\n        mailbox: LatestFrameMailbox,",
  "    init(\n        profile: TFTMACRuntimeProfile,\n        runtimeSelection: TFTMACRuntimeSelection,\n        mailbox: LatestFrameMailbox,",
  "runtime controller initializer signature"
);
controller = replaceOnce(
  controller,
  "        self.service = TFTMACRuntimeService(\n            profile: profile,\n            mailbox: mailbox,",
  "        self.service = TFTMACRuntimeService(\n            profile: profile,\n            runtimeSelection: runtimeSelection,\n            mailbox: mailbox,",
  "runtime controller service construction"
);
runtime = runtimePrefix + actor + controller;

let tests = readText("Tests/TFTMACTests/TFTMACGate1Tests.swift");
assert(!tests.includes("testRuntimeModeRegistryDefinesExactlyThreeModesAndDefaultsControl"), "Wave B tests already exist; refusing replay");
const testInsertion = String.raw`

    func testRuntimeModeRegistryDefinesExactlyThreeModesAndDefaultsControl() throws {
        let registry = try TFTMACRuntimeModeRegistry(data: try runtimeModeRegistryData())
        XCTAssertEqual(registry.defaultMode, .control)
        XCTAssertEqual(registry.registeredModes, Set(TFTMACRuntimeMode.allCases))
        let selection = try registry.selection(environment: [:])
        XCTAssertEqual(selection.mode, .control)
        XCTAssertEqual(selection.definition.adbServerPort, 5038)
        XCTAssertEqual(selection.definition.consolePort, 5582)
        XCTAssertEqual(selection.definition.controllerPort, 8554)
        XCTAssertEqual(selection.definition.serial, "emulator-5582")
        XCTAssertEqual(selection.definition.rollbackTarget, .control)
    }

    func testRuntimeModeRegistryRejectsUnknownAndBlockedModes() throws {
        let registry = try TFTMACRuntimeModeRegistry(data: try runtimeModeRegistryData())
        XCTAssertThrowsError(
            try registry.selection(environment: [TFTMACRuntimeModeRegistry.environmentKey: "unknown"])
        )
        XCTAssertThrowsError(
            try registry.selection(environment: [TFTMACRuntimeModeRegistry.environmentKey: "advanced_diagnostics"])
        )
        XCTAssertThrowsError(
            try registry.selection(environment: [TFTMACRuntimeModeRegistry.environmentKey: "candidate"])
        )
        XCTAssertEqual(
            try registry.definition(for: .advancedDiagnostics).launchState,
            .blockedPendingControllerLease
        )
        XCTAssertNil(try registry.definition(for: .advancedDiagnostics).controllerPort)
        XCTAssertEqual(try registry.definition(for: .candidate).launchState, .blockedNotBuilt)
        XCTAssertNil(try registry.definition(for: .candidate).controllerPort)
    }

    func testRuntimeModeRegistryRejectsConfigurationTampering() throws {
        let data = try runtimeModeRegistryData()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var modes = try XCTUnwrap(object["modes"] as? [String: Any])
        var control = try XCTUnwrap(modes["control"] as? [String: Any])
        control["configuration_sha256"] = String(repeating: "0", count: 64)
        modes["control"] = control
        object["modes"] = modes
        let tampered = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        XCTAssertThrowsError(try TFTMACRuntimeModeRegistry(data: tampered))
    }

    func testRuntimeLeasePersistsAcceptedModeIdentity() throws {
        let registry = try TFTMACRuntimeModeRegistry(data: try runtimeModeRegistryData())
        let identity = try registry.selection(environment: [:]).leaseIdentity()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tftmac-mode-lease-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let lease = try TFTMACRuntimeLease.acquire(
            stateRoot: root,
            identity: identity,
            processIdentifier: getpid()
        )
        defer { lease.release() }
        let payloadData = try Data(contentsOf: lease.url)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: payloadData) as? [String: Any])
        XCTAssertEqual((payload["schema"] as? NSNumber)?.intValue, 2)
        let savedIdentity = try XCTUnwrap(payload["identity"] as? [String: Any])
        XCTAssertEqual(savedIdentity["mode"] as? String, "control")
        XCTAssertEqual(savedIdentity["avd_name"] as? String, "TFT_Ultra_Tablet")
        XCTAssertEqual((savedIdentity["adb_server_port"] as? NSNumber)?.intValue, 5038)
        XCTAssertEqual((savedIdentity["console_port"] as? NSNumber)?.intValue, 5582)
        XCTAssertEqual((savedIdentity["controller_port"] as? NSNumber)?.intValue, 8554)
        XCTAssertEqual(savedIdentity["serial"] as? String, "emulator-5582")
        XCTAssertEqual(savedIdentity["configuration_sha256"] as? String, identity.configurationSha256)
        XCTAssertThrowsError(
            try TFTMACRuntimeLease.acquire(
                stateRoot: root,
                identity: identity,
                processIdentifier: getpid()
            )
        )
    }

    private func runtimeModeRegistryData() throws -> Data {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repositoryRoot = testDirectory.deletingLastPathComponent().deletingLastPathComponent()
        return try Data(contentsOf: repositoryRoot.appendingPathComponent("ssot/runtime-modes.json"))
    }
`;
const testsEnd = tests.lastIndexOf("\n}");
assert(testsEnd >= 0 && tests.slice(testsEnd).trim() === "}", "test class terminal brace was not found");
tests = tests.slice(0, testsEnd) + testInsertion + tests.slice(testsEnd);

let project = readText("TFTMAC.xcodeproj/project.pbxproj");
const ids = {
  appModeBuild: "100000000000000000000038",
  testModeBuild: "100000000000000000000039",
  modesResourceBuild: "10000000000000000000003A",
  authorityResourceBuild: "10000000000000000000003B",
  modeFile: "200000000000000000000023",
  modesFile: "200000000000000000000024",
  authorityFile: "200000000000000000000025"
};
for (const id of Object.values(ids)) assert(!project.includes(id), `Xcode object ID collision: ${id}`);
const buildDefinitions = `\t\t${ids.appModeBuild} /* RuntimeMode.swift in Sources */ = {isa = PBXBuildFile; fileRef = ${ids.modeFile} /* RuntimeMode.swift */; };\n\t\t${ids.testModeBuild} /* RuntimeMode.swift in Sources */ = {isa = PBXBuildFile; fileRef = ${ids.modeFile} /* RuntimeMode.swift */; };\n\t\t${ids.modesResourceBuild} /* runtime-modes.json in Resources */ = {isa = PBXBuildFile; fileRef = ${ids.modesFile} /* runtime-modes.json */; };\n\t\t${ids.authorityResourceBuild} /* runtime-authority.json in Resources */ = {isa = PBXBuildFile; fileRef = ${ids.authorityFile} /* runtime-authority.json */; };\n`;
project = insertBefore(project, "/* End PBXBuildFile section */", buildDefinitions, "Xcode build-file section");
const fileDefinitions = `\t\t${ids.modeFile} /* RuntimeMode.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RuntimeMode.swift; sourceTree = "<group>"; };\n\t\t${ids.modesFile} /* runtime-modes.json */ = {isa = PBXFileReference; lastKnownFileType = text.json; path = "ssot/runtime-modes.json"; sourceTree = SOURCE_ROOT; };\n\t\t${ids.authorityFile} /* runtime-authority.json */ = {isa = PBXFileReference; lastKnownFileType = text.json; path = "ssot/runtime-authority.json"; sourceTree = SOURCE_ROOT; };\n`;
project = insertBefore(project, "/* End PBXFileReference section */", fileDefinitions, "Xcode file-reference section");

function appendToGroup(text, groupComment, groupPath, addition, label) {
  const pattern = new RegExp(`(\\t\\t[0-9A-F]{24} /\\* ${groupComment} \\*/ = \\{isa = PBXGroup; children = \\()([^)]*)(\\); path = ${groupPath}; sourceTree = "<group>"; \\};)`);
  const match = text.match(pattern);
  assert(match, `${label}: group was not found`);
  assert(!match[2].includes(addition.split(" ")[0]), `${label}: object already present`);
  return text.replace(pattern, `${match[1]}${match[2]}${addition}${match[3]}`);
}
project = appendToGroup(project, "Runtime", "Runtime", `${ids.modeFile} /* RuntimeMode.swift */, `, "Xcode Runtime group");
project = appendToGroup(
  project,
  "TFTMAC",
  "TFTMAC",
  `${ids.modesFile} /* runtime-modes.json */, ${ids.authorityFile} /* runtime-authority.json */, `,
  "Xcode TFTMAC group"
);

function appendBuildToSourcePhase(text, phaseId, buildId, label) {
  const pattern = new RegExp(`(\\t\\t${phaseId} /\\* Sources \\*/ = \\{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = \\()([^)]*)(\\); runOnlyForDeploymentPostprocessing = 0; \\};)`);
  const match = text.match(pattern);
  assert(match, `${label}: source phase was not found`);
  return text.replace(pattern, `${match[1]}${match[2]}${buildId}, ${match[3]}`);
}
project = appendBuildToSourcePhase(project, "700000000000000000000001", ids.appModeBuild, "TFTMAC app source phase");
project = appendBuildToSourcePhase(project, "700000000000000000000003", ids.testModeBuild, "TFTMAC test source phase");
project = replaceOnce(
  project,
  "\t\t800000000000000000000001 /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };",
  `\t\t800000000000000000000001 /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (${ids.modesResourceBuild}, ${ids.authorityResourceBuild},); runOnlyForDeploymentPostprocessing = 0; };`,
  "TFTMAC resource phase"
);

let verifier = readText("scripts/verify-tftmac.command");
verifier = replaceOnce(
  verifier,
  '  "$ROOT/ssot/runtime-authority.json" \\\n',
  '  "$ROOT/ssot/runtime-authority.json" \\\n  "$ROOT/ssot/runtime-modes.json" \\\n  "$ROOT/tftmac/Runtime/RuntimeMode.swift" \\\n',
  "verifier required Wave B files"
);
const authorityHashAnchor = '[[ "$(sha256_file "$ROOT/ssot/runtime-authority.json")" == "2af6196e08b3f81032b8226fa3a9c25a3b0d99537f0872b7eb21a96aaf2b5d2f" ]]\n';
const registryVerifier = String.raw`
ROOT="$ROOT" node <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = process.env.ROOT;
const modesPath = path.join(root, 'ssot/runtime-modes.json');
const authorityPath = path.join(root, 'ssot/runtime-authority.json');
const registry = JSON.parse(fs.readFileSync(modesPath, 'utf8'));
function fail(message) { throw new Error(message); }
function assert(value, message) { if (!value) fail(message); }
function sha(data) { return crypto.createHash('sha256').update(data).digest('hex'); }
function configurationHash(mode) {
  const fields = [
    ['mode', mode.mode], ['launch_state', mode.launch_state], ['runtime_root', mode.runtime_root],
    ['sdk_root', mode.sdk_root], ['library_root', mode.library_root], ['emulator_path', mode.emulator_path],
    ['emulator_sha256', mode.emulator_sha256 || ''], ['gfxstream_backend_path', mode.gfxstream_backend_path],
    ['gfxstream_backend_sha256', mode.gfxstream_backend_sha256 || ''], ['adb_path', mode.adb_path],
    ['avd_home', mode.avd_home], ['avd_name', mode.avd_name], ['avd_directory', mode.avd_directory],
    ['avd_config_path', mode.avd_config_path], ['avd_config_sha256', mode.avd_config_sha256 || ''],
    ['avd_ini_path', mode.avd_ini_path], ['avd_ini_sha256', mode.avd_ini_sha256 || ''],
    ['adb_server_port', mode.adb_server_port], ['console_port', mode.console_port],
    ['controller_port', mode.controller_port === null ? '' : mode.controller_port], ['serial', mode.serial],
    ['authority_manifest_kind', mode.authority_manifest.kind], ['authority_manifest_path', mode.authority_manifest.path],
    ['authority_manifest_sha256', mode.authority_manifest.sha256 || ''], ['application_bundle_id', mode.application_bundle_id],
    ['application_version', mode.application_version], ['application_build', mode.application_build],
    ['allowed_purpose', mode.allowed_purpose], ['comparability_class', mode.comparability_class],
    ['rollback_target', mode.rollback_target], ['requires_control_stopped', String(mode.requires_control_stopped)]
  ];
  return sha(Buffer.from(fields.map(([key, value]) => key + '=' + value).join('\n')));
}
assert(registry.schema === 1 && registry.default_mode === 'control', 'runtime registry schema/default failed');
assert(registry.active_lease_relative_path === 'State/native-runtime.lease', 'runtime lease path failed');
assert(JSON.stringify(Object.keys(registry.modes).sort()) === JSON.stringify(['advanced_diagnostics', 'candidate', 'control']), 'exact runtime modes failed');
const used = new Map();
for (const [name, mode] of Object.entries(registry.modes)) {
  assert(name === mode.mode, 'mode key mismatch: ' + name);
  assert(configurationHash(mode) === mode.configuration_sha256, 'configuration SHA mismatch: ' + name);
  assert(mode.serial === 'emulator-' + mode.console_port, 'serial mismatch: ' + name);
  for (const [kind, value] of [['adb', mode.adb_server_port], ['console', mode.console_port], ['controller', mode.controller_port]]) {
    if (value === null) continue;
    assert(!used.has(value), 'runtime port collision at ' + value);
    used.set(value, name + '.' + kind);
  }
}
const control = registry.modes.control;
assert(control.launch_state === 'enabled', 'control is not enabled');
assert(control.adb_server_port === 5038 && control.console_port === 5582 && control.controller_port === 8554, 'control ports drifted');
assert(control.serial === 'emulator-5582' && control.rollback_target === 'control' && control.requires_control_stopped === false, 'control identity drifted');
assert(/^[0-9a-f]{64}$/.test(control.emulator_sha256) && /^[0-9a-f]{64}$/.test(control.gfxstream_backend_sha256), 'control binary identities are missing');
assert(control.authority_manifest.sha256 === sha(fs.readFileSync(authorityPath)), 'control authority manifest hash failed');
const diagnostics = registry.modes.advanced_diagnostics;
assert(diagnostics.launch_state === 'blocked_pending_controller_lease' && diagnostics.controller_port === null, 'diagnostics are not fail-closed');
assert(diagnostics.adb_server_port === 5041 && diagnostics.console_port === 5586 && diagnostics.serial === 'emulator-5586', 'diagnostic lease identity drifted');
const candidate = registry.modes.candidate;
assert(candidate.launch_state === 'blocked_not_built' && candidate.controller_port === null, 'candidate is not fail-closed');
NODE
rg -q 'TFTMACRuntimeModeRegistry\.loadBundled' "$ROOT/tftmac/App/AppCoordinator.swift"
rg -q 'runtimeSelection\.validateForLaunch\(\)' "$ROOT/tftmac/Runtime/TFTMACRuntime.swift"
rg -q 'TFTMACRuntimeLease\.acquire\(stateRoot: stateRoot, identity: leaseIdentity\)' "$ROOT/tftmac/Runtime/TFTMACRuntime.swift"
`;
verifier = replaceOnce(
  verifier,
  authorityHashAnchor,
  authorityHashAnchor + registryVerifier,
  "verifier runtime-mode authority block"
);
const appBinaryAnchor = 'test -x "$RELEASE_DERIVED/Build/Products/Release/TFTMAC.app/Contents/MacOS/TFTMAC"\n';
const appResourceVerifier = String.raw`readonly APP_RESOURCES="$RELEASE_DERIVED/Build/Products/Release/TFTMAC.app/Contents/Resources"
test -f "$APP_RESOURCES/runtime-modes.json"
test -f "$APP_RESOURCES/runtime-authority.json"
cmp -s "$ROOT/ssot/runtime-modes.json" "$APP_RESOURCES/runtime-modes.json"
cmp -s "$ROOT/ssot/runtime-authority.json" "$APP_RESOURCES/runtime-authority.json"
`;
verifier = replaceOnce(
  verifier,
  appBinaryAnchor,
  appBinaryAnchor + appResourceVerifier,
  "verifier packaged runtime authority resources"
);
verifier = replaceOnce(verifier, "EXPECTED_TEST_COUNT=43", "EXPECTED_TEST_COUNT=47", "verifier test-count contract");
verifier = replaceOnce(
  verifier,
  "Validated TFTMAC native source ownership, runtime authority, SQL migrations, capture integrity, release build, 43 deterministic unit tests, packaged app resources, and the repo-local source verifier.",
  "Validated TFTMAC native source ownership, runtime-mode authority, fail-closed lease identity, SQL migrations, capture integrity, release build, 47 deterministic unit tests, packaged app resources, and the repo-local source verifier.",
  "verifier completion message"
);

const outputs = new Map([
  ["ssot/runtime-modes.json", registryOutput],
  ["tftmac/Runtime/RuntimeMode.swift", runtimeModeOutput],
  ["tftmac/Runtime/RuntimeLease.swift", runtimeLeaseOutput],
  ["tftmac/App/AppCoordinator.swift", appCoordinatorOutput],
  ["tftmac/Runtime/TFTMACRuntime.swift", runtime],
  ["Tests/TFTMACTests/TFTMACGate1Tests.swift", tests],
  ["TFTMAC.xcodeproj/project.pbxproj", project],
  ["scripts/verify-tftmac.command", verifier]
]);

const staged = [];
for (const [relativePath, content] of outputs) {
  const target = absolute(relativePath);
  const temporary = `${target}.waveb-${process.pid}.tmp`;
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(temporary, content, "utf8");
  const mode = fs.existsSync(target) ? fs.statSync(target).mode & 0o777 : 0o644;
  fs.chmodSync(temporary, mode);
  staged.push({ relativePath, target, temporary, mode, sha256: sha256Text(content) });
}
for (const item of staged) fs.renameSync(item.temporary, item.target);

const receipt = {
  schema: 1,
  project_id: "tftmac",
  change_id: "215ec5a3-6554-4ca3-95db-1525433bb20f",
  operation_id: operationId,
  scope_lock_sha256: expectedInputs[`${planRoot}/SCOPE_LOCK.txt`],
  input_sha256: expectedInputs,
  control_identity: {
    emulator_path: control.emulator_path,
    emulator_sha256: control.emulator_sha256,
    gfxstream_backend_path: control.gfxstream_backend_path,
    gfxstream_backend_sha256: control.gfxstream_backend_sha256,
    configuration_sha256: control.configuration_sha256
  },
  output_sha256: Object.fromEntries(staged.map((item) => [item.relativePath, item.sha256])),
  effects: {
    emulator_launch_attempted: false,
    runtime_replacement_attempted: false,
    control_stop_attempted: false,
    package_launch_attempted: false,
    source_only: true
  },
  next_required_action: "Run the exact managed production validator; do not boot diagnostics unless Wave B acceptance passes and a separate controller-port receipt is approved.",
  applied_at: new Date().toISOString()
};
fs.writeFileSync(
  absolute(`${planRoot}/WAVE_B_APPLY_RECEIPT.json`),
  `${JSON.stringify(receipt, null, 2)}\n`,
  { mode: 0o644 }
);
for (const relativePath of templatePaths) fs.unlinkSync(absolute(relativePath));
console.log(JSON.stringify({
  state: "WAVE_B_SOURCE_APPLIED",
  operation_id: operationId,
  changed_paths: Array.from(outputs.keys()),
  receipt: `${planRoot}/WAVE_B_APPLY_RECEIPT.json`,
  emulator_launch_attempted: false
}, null, 2));
