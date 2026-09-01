import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const root = process.cwd();
const planRoot = ".clara/plans/tftmac-causal-graphics-v1";
const waveRoot = `${planRoot}/wave-b-v2`;
const operationId = "tftmac-waveb-v2-source-apply-20260901-v1";
const expectedHead = "f1ef3f7c067b88e4ce464fc4567fcb03a6accf91";
const expectedScopeLock = "dc77b6913d14409adc883dd27a67c42e982c40ab9149a68771b61dc99fae297e";
const expectedRegistry = "81086498d8a16f2096f8461922731d7cf5c027cf6163d874452c16ffa543fdb2";
const expectedInputs = {
  "ssot/runtime-modes.json": expectedRegistry,
  "ssot/runtime-authority.json": "2af6196e08b3f81032b8226fa3a9c25a3b0d99537f0872b7eb21a96aaf2b5d2f",
  "tftmac/App/AppCoordinator.swift": "ef3dcfa1272726471407836911043118343b375a77e65dbcc6a8ac75f9a1937",
  "tftmac/Runtime/RuntimeLease.swift": "55a44dbd5fc8b112cb48d17e879c00ae068161f2755af1876244e03bf75b498b",
  "tftmac/Runtime/TFTMACRuntime.swift": "8932032d93af01b46e46b5fb5a04eff1ec457f2f0e8f92f364d5a1a703ab5a5f",
  "Tests/TFTMACTests/TFTMACGate1Tests.swift": "3a3307d19d2a48c22ee5504c96b4ee9e428992d2b026bedec2946240abc803d6",
  "TFTMAC.xcodeproj/project.pbxproj": "4961d37cc1802ca179b7f115ff4be3a4f1c222e706a01aff9f137fcb27c57dfd",
  "scripts/verify-tftmac.command": "d587850fef7d5b25bf2a46cf6249824703130761b1ed388e1e93c485be763ccc"
};
const activePlanFiles = [
  `${waveRoot}/RuntimeMode.swift.template`,
  `${waveRoot}/RuntimeLease.swift.template`,
  `${waveRoot}/apply-waveb-v2.mjs`
];

function absolute(relativePath) {
  return path.join(root, relativePath);
}

function sha256(buffer) {
  return crypto.createHash("sha256").update(buffer).digest("hex");
}

function fileHash(relativePath) {
  return sha256(fs.readFileSync(absolute(relativePath)));
}

function readText(relativePath) {
  return fs.readFileSync(absolute(relativePath), "utf8");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function git(args) {
  const result = spawnSync("git", args, { cwd: root, encoding: "utf8", maxBuffer: 16 * 1024 * 1024 });
  if (result.error || result.status !== 0) {
    throw new Error(`git ${args.join(" ")} failed: ${result.error?.message ?? result.stderr}`);
  }
  return result.stdout;
}

async function externalHash(filePath) {
  return await new Promise((resolve, reject) => {
    const hash = crypto.createHash("sha256");
    const stream = fs.createReadStream(filePath);
    stream.on("data", (chunk) => hash.update(chunk));
    stream.on("error", reject);
    stream.on("end", () => resolve(hash.digest("hex")));
  });
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
  const fields = [
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
  return sha256(Buffer.from(fields.map(([key, value]) => `${key}=${value}`).join("\n"), "utf8"));
}

function assertSHA256(value, label) {
  assert(typeof value === "string" && /^[0-9a-f]{64}$/.test(value), `${label} is not a lowercase SHA-256`);
}

function validateRegistry(registry, requireControlBinaryHashes) {
  assert(registry.schema === 1, "runtime registry schema must remain 1");
  assert(registry.default_mode === "control", "control must remain the default runtime mode");
  assert(registry.active_lease_relative_path === "State/native-runtime.lease", "shared lease path drifted");
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
  assert(control.launch_state === "enabled", "control must remain the only enabled mode");
  assert(control.runtime_root === "/Volumes/MAC MINI M4/TFTMAC/Runtime", "control root drifted");
  assert(control.sdk_root === "/Volumes/MAC MINI M4/TFTMAC/Runtime/SDK", "control SDK root drifted");
  assert(control.avd_home === "/Volumes/MAC MINI M4/TFTMAC/Runtime/AVD", "control AVD home drifted");
  assert(control.avd_name === "TFT_Ultra_Tablet", "control AVD name drifted");
  assert(control.adb_server_port === 5038 && control.console_port === 5582 && control.controller_port === 8554, "control lease ports drifted");
  assert(control.serial === "emulator-5582", "control serial drifted");
  assert(control.authority_manifest.kind === "bundled_resource" && control.authority_manifest.path === "runtime-authority.json", "control authority manifest drifted");
  assert(control.authority_manifest.sha256 === expectedInputs["ssot/runtime-authority.json"], "control authority manifest SHA drifted");
  assert(control.rollback_target === "control" && control.requires_control_stopped === false, "control rollback contract drifted");
  if (requireControlBinaryHashes) {
    assertSHA256(control.emulator_sha256, "control emulator SHA-256");
    assertSHA256(control.gfxstream_backend_sha256, "control gfxstream SHA-256");
  }

  const diagnostics = registry.modes.advanced_diagnostics;
  assert(diagnostics.launch_state === "blocked_pending_controller_lease", "advanced diagnostics must remain fail-closed");
  assert(diagnostics.controller_port === null, "advanced diagnostics cannot allocate a controller port before its receipt");
  assert(diagnostics.adb_server_port === 5041 && diagnostics.console_port === 5586, "diagnostic lease ports drifted");
  assert(diagnostics.serial === "emulator-5586", "diagnostic serial drifted");
  assert(diagnostics.requires_control_stopped === true && diagnostics.rollback_target === "control", "diagnostic noninterference contract drifted");
  assert(diagnostics.authority_manifest.kind === "external_sealed_manifest", "diagnostic manifest authority drifted");
  for (const [value, label] of [
    [diagnostics.authority_manifest.sha256, "diagnostic manifest SHA-256"],
    [diagnostics.emulator_sha256, "diagnostic emulator SHA-256"],
    [diagnostics.gfxstream_backend_sha256, "diagnostic gfxstream SHA-256"],
    [diagnostics.avd_config_sha256, "diagnostic AVD config SHA-256"],
    [diagnostics.avd_ini_sha256, "diagnostic AVD ini SHA-256"]
  ]) assertSHA256(value, label);

  const candidate = registry.modes.candidate;
  assert(candidate.launch_state === "blocked_not_built", "candidate must remain fail-closed");
  assert(candidate.controller_port === null, "candidate cannot allocate a controller port before acceptance");
  assert(candidate.requires_control_stopped === true && candidate.rollback_target === "control", "candidate rollback contract drifted");
}

assert(git(["rev-parse", "HEAD"]).trim() === expectedHead, "managed-change HEAD drifted before Wave B implementation");
assert(fileHash(`${planRoot}/SCOPE_LOCK.txt`) === expectedScopeLock, "active scope-lock SHA drifted");
for (const [relativePath, expectedHash] of Object.entries(expectedInputs)) {
  assert(fs.existsSync(absolute(relativePath)), `required Wave B input is missing: ${relativePath}`);
  const observed = fileHash(relativePath);
  assert(observed === expectedHash, `Wave B input drift for ${relativePath}: expected ${expectedHash}, observed ${observed}`);
}
for (const relativePath of activePlanFiles) {
  assert(fs.existsSync(absolute(relativePath)), `active Wave B plan input is missing: ${relativePath}`);
}
for (const forbidden of [
  "tftmac/Runtime/RuntimeMode.swift",
  `${waveRoot}/WAVE_B_IMPLEMENTATION_RECEIPT.json`,
  `${waveRoot}/WAVE_B_VALIDATION_RECEIPT.json`,
  `${waveRoot}/WAVE_B_VALIDATION_FAILURE.json`
]) assert(!fs.existsSync(absolute(forbidden)), `unexpected preexisting Wave B artifact: ${forbidden}`);

const statusBefore = git(["status", "--porcelain=v1", "--untracked-files=all"])
  .split("\n")
  .filter(Boolean);
const expectedStatus = new Set(activePlanFiles.map((relativePath) => `?? ${relativePath}`));
assert(statusBefore.length === expectedStatus.size, `unexpected dirty-path count before Wave B implementation: ${statusBefore.join(" | ")}`);
for (const line of statusBefore) assert(expectedStatus.has(line), `unexpected dirty path before Wave B implementation: ${line}`);

const registry = JSON.parse(readText("ssot/runtime-modes.json"));
validateRegistry(registry, false);
const control = registry.modes.control;
const diagnostics = registry.modes.advanced_diagnostics;

const controlEmulatorSha256 = await externalHash(control.emulator_path);
const controlGfxstreamSha256 = await externalHash(control.gfxstream_backend_path);
assert(await externalHash(control.authority_manifest.path === "runtime-authority.json" ? absolute("ssot/runtime-authority.json") : control.authority_manifest.path) === control.authority_manifest.sha256, "control authority manifest file does not match the accepted SHA-256");
for (const [filePath, expectedHash, label] of [
  [diagnostics.authority_manifest.path, diagnostics.authority_manifest.sha256, "diagnostic manifest"],
  [diagnostics.emulator_path, diagnostics.emulator_sha256, "diagnostic emulator"],
  [diagnostics.gfxstream_backend_path, diagnostics.gfxstream_backend_sha256, "diagnostic gfxstream backend"],
  [diagnostics.avd_config_path, diagnostics.avd_config_sha256, "diagnostic AVD config"],
  [diagnostics.avd_ini_path, diagnostics.avd_ini_sha256, "diagnostic AVD ini"]
]) {
  assert(fs.existsSync(filePath), `${label} is missing at ${filePath}`);
  const observed = await externalHash(filePath);
  assert(observed === expectedHash, `${label} SHA-256 mismatch: expected ${expectedHash}, observed ${observed}`);
}

control.emulator_sha256 = controlEmulatorSha256;
control.gfxstream_backend_sha256 = controlGfxstreamSha256;
control.configuration_sha256 = configurationHash(control);
validateRegistry(registry, true);
const registryOutput = `${JSON.stringify(registry, null, 2)}\n`;
const finalRegistrySha256 = sha256(Buffer.from(registryOutput, "utf8"));

let runtimeModeOutput = readText(`${waveRoot}/RuntimeMode.swift.template`);
runtimeModeOutput = replaceOnce(
  runtimeModeOutput,
  "__EXPECTED_RUNTIME_MODES_SHA256__",
  finalRegistrySha256,
  "RuntimeMode registry signature"
);
assert(!runtimeModeOutput.includes("__EXPECTED_RUNTIME_MODES_SHA256__"), "RuntimeMode registry signature placeholder remains");
const runtimeLeaseOutput = readText(`${waveRoot}/RuntimeLease.swift.template`);

let coordinator = readText("tftmac/App/AppCoordinator.swift");
const coordinatorAnchor = `        let runtime = TFTMACRuntimeController(
            profile: activeProfile,
            mailbox: controller.frameMailbox,`;
const coordinatorReplacement = `        let runtimeSelection: TFTMACRuntimeSelection
        do {
            let registry = try TFTMACRuntimeModeRegistry.loadBundled()
            runtimeSelection = try registry.selection()
            try runtimeSelection.validateForLaunch()
        } catch {
            controller.showWindow(self)
            NSApplication.shared.activate(ignoringOtherApps: true)
            controller.setStatus(
                "Runtime mode validation failed: \\(error.localizedDescription)",
                isError: true
            )
            return
        }

        let runtime = TFTMACRuntimeController(
            profile: activeProfile,
            runtimeSelection: runtimeSelection,
            mailbox: controller.frameMailbox,`;
coordinator = replaceOnce(coordinator, coordinatorAnchor, coordinatorReplacement, "AppCoordinator runtime selection boundary");

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
            guard runtimeSelection.mode == .control else {
                throw TFTMACRuntimeModeError(
                    message: "Only the accepted control runtime is launch-ready in Wave B."
                )
            }
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
const baselineTestCount = (tests.match(/^    func test/gm) ?? []).length;
assert(baselineTestCount === 43, `expected 43 baseline tests, observed ${baselineTestCount}`);
assert(!tests.includes("testRuntimeModeRegistryDefinesExactlyThreeModesAndDefaultsControl"), "Wave B tests already exist");
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
        XCTAssertFalse(selection.definition.requiresControlStopped)
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
        let diagnostics = try registry.definition(for: .advancedDiagnostics)
        XCTAssertEqual(diagnostics.launchState, .blockedPendingControllerLease)
        XCTAssertNil(diagnostics.controllerPort)
        XCTAssertTrue(diagnostics.requiresControlStopped)
        let candidate = try registry.definition(for: .candidate)
        XCTAssertEqual(candidate.launchState, .blockedNotBuilt)
        XCTAssertNil(candidate.controllerPort)
        XCTAssertTrue(candidate.requiresControlStopped)
    }

    func testRuntimeModeRegistryRejectsAnyPackagedRegistryTampering() throws {
        let data = try runtimeModeRegistryData()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var modes = try XCTUnwrap(object["modes"] as? [String: Any])
        var control = try XCTUnwrap(modes["control"] as? [String: Any])
        control["console_port"] = 5598
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
            processIdentifier: ProcessInfo.processInfo.processIdentifier
        )
        defer { lease.release() }
        let payloadData = try Data(contentsOf: lease.url)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: payloadData) as? [String: Any])
        XCTAssertEqual((payload["schema"] as? NSNumber)?.intValue, 2)
        let savedIdentity = try XCTUnwrap(payload["identity"] as? [String: Any])
        XCTAssertEqual(savedIdentity["mode"] as? String, "control")
        XCTAssertEqual(savedIdentity["registry_sha256"] as? String, identity.registrySha256)
        XCTAssertEqual(savedIdentity["configuration_sha256"] as? String, identity.configurationSha256)
        XCTAssertEqual(savedIdentity["avd_name"] as? String, "TFT_Ultra_Tablet")
        XCTAssertEqual((savedIdentity["adb_server_port"] as? NSNumber)?.intValue, 5038)
        XCTAssertEqual((savedIdentity["console_port"] as? NSNumber)?.intValue, 5582)
        XCTAssertEqual((savedIdentity["controller_port"] as? NSNumber)?.intValue, 8554)
        XCTAssertEqual(savedIdentity["serial"] as? String, "emulator-5582")
        XCTAssertThrowsError(
            try TFTMACRuntimeLease.acquire(
                stateRoot: root,
                identity: identity,
                processIdentifier: ProcessInfo.processInfo.processIdentifier
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
assert((tests.match(/^    func test/gm) ?? []).length === 47, "Wave B test insertion did not produce exactly 47 tests");

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
  "tftmac",
  "tftmac",
  `${ids.modesFile} /* runtime-modes.json */, ${ids.authorityFile} /* runtime-authority.json */, `,
  "Xcode tftmac group"
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
const registryVerifier = `ROOT="$ROOT" EXPECTED_RUNTIME_MODES_SHA256="${finalRegistrySha256}" node <<'NODE'\n` + String.raw`const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = process.env.ROOT;
const expectedRegistrySha256 = process.env.EXPECTED_RUNTIME_MODES_SHA256;
const modesPath = path.join(root, 'ssot/runtime-modes.json');
const authorityPath = path.join(root, 'ssot/runtime-authority.json');
const registryBytes = fs.readFileSync(modesPath);
const registry = JSON.parse(registryBytes);
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
assert(sha(registryBytes) === expectedRegistrySha256, 'runtime registry packaged identity failed');
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
verifier = replaceOnce(verifier, authorityHashAnchor, authorityHashAnchor + registryVerifier, "verifier runtime-mode authority block");
const appBinaryAnchors = [
  'test -x "$APP_BINARY"\n',
  'test -x "$RELEASE_DERIVED/Build/Products/Release/TFTMAC.app/Contents/MacOS/TFTMAC"\n'
];
const matchingAppBinaryAnchors = appBinaryAnchors.filter((anchor) => verifier.includes(anchor));
assert(matchingAppBinaryAnchors.length === 1, "verifier packaged-binary anchor was not uniquely resolved");
const appBinaryAnchor = matchingAppBinaryAnchors[0];
const appResourceVerifier = String.raw`APP_RESOURCES="$(cd "$(dirname "$APP_BINARY")/../Resources" && pwd)"
test -f "$APP_RESOURCES/runtime-modes.json"
test -f "$APP_RESOURCES/runtime-authority.json"
cmp -s "$ROOT/ssot/runtime-modes.json" "$APP_RESOURCES/runtime-modes.json"
cmp -s "$ROOT/ssot/runtime-authority.json" "$APP_RESOURCES/runtime-authority.json"
`;
verifier = replaceOnce(verifier, appBinaryAnchor, appBinaryAnchor + appResourceVerifier, "verifier packaged runtime authority resources");
verifier = replaceOnce(verifier, "EXPECTED_TEST_COUNT=43", "EXPECTED_TEST_COUNT=47", "verifier test-count contract");
assert(verifier.includes("43 deterministic unit tests"), "verifier completion test-count text was not found");
verifier = verifier.replace("43 deterministic unit tests", "47 deterministic unit tests");
verifier = verifier.replace("runtime authority", "runtime-mode authority");

const outputs = new Map([
  ["ssot/runtime-modes.json", registryOutput],
  ["tftmac/Runtime/RuntimeMode.swift", runtimeModeOutput],
  ["tftmac/Runtime/RuntimeLease.swift", runtimeLeaseOutput],
  ["tftmac/App/AppCoordinator.swift", coordinator],
  ["tftmac/Runtime/TFTMACRuntime.swift", runtime],
  ["Tests/TFTMACTests/TFTMACGate1Tests.swift", tests],
  ["TFTMAC.xcodeproj/project.pbxproj", project],
  ["scripts/verify-tftmac.command", verifier]
]);

const staged = [];
for (const [relativePath, content] of outputs) {
  const target = absolute(relativePath);
  const temporary = `${target}.waveb-v2-${process.pid}.tmp`;
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(temporary, content, "utf8");
  const mode = fs.existsSync(target) ? fs.statSync(target).mode & 0o777 : 0o644;
  fs.chmodSync(temporary, mode);
  staged.push({ relativePath, target, temporary, sha256: sha256(Buffer.from(content, "utf8")) });
}
for (const item of staged) fs.renameSync(item.temporary, item.target);

const receipt = {
  schema: 1,
  state: "WAVE_B_IMPLEMENTATION_APPLIED",
  project_id: "tftmac",
  change_id: "215ec5a3-6554-4ca3-95db-1525433bb20f",
  operation_id: operationId,
  base_head_sha: expectedHead,
  scope_lock_sha256: expectedScopeLock,
  input_sha256: expectedInputs,
  plan_input_sha256: Object.fromEntries(activePlanFiles.map((relativePath) => [relativePath, fileHash(relativePath)])),
  output_sha256: Object.fromEntries(staged.map((item) => [item.relativePath, item.sha256])),
  runtime_modes_sha256: finalRegistrySha256,
  control_identity: {
    emulator_path: control.emulator_path,
    emulator_sha256: controlEmulatorSha256,
    gfxstream_backend_path: control.gfxstream_backend_path,
    gfxstream_backend_sha256: controlGfxstreamSha256,
    configuration_sha256: control.configuration_sha256
  },
  diagnostics: {
    launch_state: diagnostics.launch_state,
    controller_port: diagnostics.controller_port,
    serial: diagnostics.serial,
    first_boot_attempted: false
  },
  effects: {
    emulator_launch_attempted: false,
    runtime_replacement_attempted: false,
    control_stop_attempted: false,
    installed_app_replacement_attempted: false,
    package_launch_attempted: false,
    source_only: true
  },
  next_required_action: "Checkpoint this implementation candidate, then run one exact production validation without launching Android.",
  applied_at: new Date().toISOString()
};
fs.writeFileSync(
  absolute(`${waveRoot}/WAVE_B_IMPLEMENTATION_RECEIPT.json`),
  `${JSON.stringify(receipt, null, 2)}\n`,
  { flag: "wx", mode: 0o644 }
);

console.log(JSON.stringify({
  state: receipt.state,
  runtime_modes_sha256: finalRegistrySha256,
  changed_paths: Array.from(outputs.keys()),
  receipt: `${waveRoot}/WAVE_B_IMPLEMENTATION_RECEIPT.json`,
  effects: receipt.effects
}, null, 2));
