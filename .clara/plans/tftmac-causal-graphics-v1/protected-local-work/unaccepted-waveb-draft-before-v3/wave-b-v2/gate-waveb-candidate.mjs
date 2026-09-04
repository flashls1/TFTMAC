import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const root = process.cwd();
const waveRoot = ".clara/plans/tftmac-causal-graphics-v1/wave-b-v2";
const receiptRelative = `${waveRoot}/WAVE_B_IMPLEMENTATION_RECEIPT.json`;
const passRelative = `${waveRoot}/WAVE_B_CANDIDATE_GATE_PASS.json`;
const failureRelative = `${waveRoot}/WAVE_B_CANDIDATE_GATE_FAILURE.json`;
const expectedHead = "f1ef3f7c067b88e4ce464fc4567fcb03a6accf91";
const expectedScopeLock = "dc77b6913d14409adc883dd27a67c42e982c40ab9149a68771b61dc99fae297e";

function absolute(relativePath) { return path.join(root, relativePath); }
function sha256(buffer) { return crypto.createHash("sha256").update(buffer).digest("hex"); }
function fileHash(relativePath) { return sha256(fs.readFileSync(absolute(relativePath))); }
function git(args) {
  const result = spawnSync("git", args, { cwd: root, encoding: "utf8", maxBuffer: 16 * 1024 * 1024 });
  if (result.error || result.status !== 0) throw new Error(`git ${args.join(" ")} failed: ${result.error?.message ?? result.stderr}`);
  return result.stdout;
}
function writeJSON(relativePath, value) {
  fs.writeFileSync(absolute(relativePath), `${JSON.stringify(value, null, 2)}\n`, { flag: "wx", mode: 0o644 });
}
function fail(message, details = {}) {
  const failure = {
    schema: 1,
    state: "WAVE_B_CANDIDATE_GATE_FAILED",
    project_id: "tftmac",
    change_id: "215ec5a3-6554-4ca3-95db-1525433bb20f",
    message,
    details,
    effects: {
      emulator_launch_attempted: false,
      runtime_replacement_attempted: false,
      control_stop_attempted: false,
      installed_app_replacement_attempted: false,
      package_launch_attempted: false
    },
    failed_at: new Date().toISOString()
  };
  if (!fs.existsSync(absolute(failureRelative))) writeJSON(failureRelative, failure);
  console.error(JSON.stringify(failure, null, 2));
  process.exit(1);
}
function assert(condition, message, details) { if (!condition) fail(message, details); }

assert(git(["rev-parse", "HEAD"]).trim() === expectedHead, "Wave B candidate base HEAD drifted.");
assert(fs.existsSync(absolute(receiptRelative)), "Wave B implementation receipt is missing.");
assert(!fs.existsSync(absolute(passRelative)), "Wave B candidate gate pass already exists; refusing replay.");
const receipt = JSON.parse(fs.readFileSync(absolute(receiptRelative), "utf8"));
assert(receipt.schema === 1 && receipt.state === "WAVE_B_IMPLEMENTATION_APPLIED", "Wave B implementation receipt state is invalid.");
assert(receipt.project_id === "tftmac" && receipt.change_id === "215ec5a3-6554-4ca3-95db-1525433bb20f", "Wave B implementation receipt identity is invalid.");
assert(receipt.base_head_sha === expectedHead, "Wave B implementation receipt base HEAD is invalid.");
assert(receipt.scope_lock_sha256 === expectedScopeLock, "Wave B implementation receipt scope lock is invalid.");
assert(receipt.operation_id === "tftmac-waveb-v2-source-apply-20260901-v1", "Wave B implementation operation identity is invalid.");
for (const [key, value] of Object.entries(receipt.effects ?? {})) {
  if (key === "source_only") continue;
  assert(value === false, `Wave B implementation receipt reports forbidden effect ${key}.`);
}
assert(receipt.effects?.source_only === true, "Wave B implementation receipt is not source-only.");

const mismatches = [];
for (const [relativePath, expected] of Object.entries(receipt.output_sha256 ?? {})) {
  const observed = fs.existsSync(absolute(relativePath)) ? fileHash(relativePath) : null;
  if (observed !== expected) mismatches.push({ path: relativePath, expected, observed });
}
assert(mismatches.length === 0, "Wave B implementation outputs do not match the receipt.", { mismatches });
assert(fileHash("ssot/runtime-modes.json") === receipt.runtime_modes_sha256, "Runtime registry SHA does not match the implementation receipt.");

const registry = JSON.parse(fs.readFileSync(absolute("ssot/runtime-modes.json"), "utf8"));
assert(registry.default_mode === "control", "Control is not the default mode.");
assert(JSON.stringify(Object.keys(registry.modes).sort()) === JSON.stringify(["advanced_diagnostics", "candidate", "control"]), "Runtime registry does not contain exactly three modes.");
assert(registry.modes.control.launch_state === "enabled", "Control is not enabled.");
assert(registry.modes.control.controller_port === 8554 && registry.modes.control.serial === "emulator-5582", "Control lease identity drifted.");
assert(registry.modes.advanced_diagnostics.launch_state === "blocked_pending_controller_lease", "Advanced diagnostics is not fail-closed.");
assert(registry.modes.advanced_diagnostics.controller_port === null, "Advanced diagnostics has an unaccepted controller port.");
assert(registry.modes.candidate.launch_state === "blocked_not_built", "Candidate is not fail-closed.");
assert(registry.modes.candidate.controller_port === null, "Candidate has an unaccepted controller port.");

const markers = [
  ["tftmac/App/AppCoordinator.swift", "TFTMACRuntimeModeRegistry.loadBundled()"],
  ["tftmac/App/AppCoordinator.swift", "runtimeSelection.validateForLaunch()"],
  ["tftmac/Runtime/TFTMACRuntime.swift", "guard runtimeSelection.mode == .control"],
  ["tftmac/Runtime/TFTMACRuntime.swift", "TFTMACRuntimeLease.acquire(stateRoot: stateRoot, identity: leaseIdentity)"],
  ["tftmac/Runtime/RuntimeLease.swift", "let identity: TFTMACRuntimeLeaseIdentity?"],
  ["TFTMAC.xcodeproj/project.pbxproj", "RuntimeMode.swift in Sources"],
  ["TFTMAC.xcodeproj/project.pbxproj", "runtime-modes.json in Resources"],
  ["TFTMAC.xcodeproj/project.pbxproj", "runtime-authority.json in Resources"],
  ["scripts/verify-tftmac.command", "EXPECTED_TEST_COUNT=47"],
  ["scripts/verify-tftmac.command", "runtime-modes.json"],
  ["Tests/TFTMACTests/TFTMACGate1Tests.swift", "testRuntimeModeRegistryDefinesExactlyThreeModesAndDefaultsControl"]
];
for (const [relativePath, marker] of markers) {
  assert(fs.readFileSync(absolute(relativePath), "utf8").includes(marker), `Required Wave B marker is missing from ${relativePath}.`, { marker });
}
const tests = fs.readFileSync(absolute("Tests/TFTMACTests/TFTMACGate1Tests.swift"), "utf8");
assert((tests.match(/^    func test/gm) ?? []).length === 47, "Wave B test-count contract is not 47.");

const allowedPaths = new Set([
  "ssot/runtime-modes.json",
  "tftmac/Runtime/RuntimeMode.swift",
  "tftmac/Runtime/RuntimeLease.swift",
  "tftmac/App/AppCoordinator.swift",
  "tftmac/Runtime/TFTMACRuntime.swift",
  "Tests/TFTMACTests/TFTMACGate1Tests.swift",
  "TFTMAC.xcodeproj/project.pbxproj",
  "scripts/verify-tftmac.command",
  `${waveRoot}/RuntimeMode.swift.template`,
  `${waveRoot}/RuntimeLease.swift.template`,
  `${waveRoot}/apply-waveb-v2.mjs`,
  `${waveRoot}/gate-waveb-candidate.mjs`,
  receiptRelative
]);
const status = git(["status", "--porcelain=v1", "--untracked-files=all"])
  .split("\n")
  .filter(Boolean)
  .map((line) => ({ line, path: line.slice(3) }));
const unexpected = status.filter(({ path: relativePath }) => !allowedPaths.has(relativePath));
assert(unexpected.length === 0, "Unexpected paths are dirty in the Wave B candidate.", { unexpected });
for (const required of allowedPaths) {
  assert(status.some(({ path: relativePath }) => relativePath === required), `Required Wave B candidate path is not dirty: ${required}`);
}

const pass = {
  schema: 1,
  state: "WAVE_B_CANDIDATE_GATE_PASS",
  project_id: "tftmac",
  change_id: "215ec5a3-6554-4ca3-95db-1525433bb20f",
  base_head_sha: expectedHead,
  scope_lock_sha256: expectedScopeLock,
  implementation_receipt_sha256: fileHash(receiptRelative),
  runtime_modes_sha256: receipt.runtime_modes_sha256,
  output_sha256: receipt.output_sha256,
  deterministic_test_count: 47,
  diagnostics_launch_state: registry.modes.advanced_diagnostics.launch_state,
  diagnostics_controller_port: registry.modes.advanced_diagnostics.controller_port,
  checkpoint_paths: [...allowedPaths, passRelative].sort(),
  effects: {
    emulator_launch_attempted: false,
    runtime_replacement_attempted: false,
    control_stop_attempted: false,
    installed_app_replacement_attempted: false,
    package_launch_attempted: false,
    build_attempted: false,
    tests_attempted: false
  },
  next_required_action: "Checkpoint the implementation candidate, then run one exact production validator on the committed head.",
  passed_at: new Date().toISOString()
};
writeJSON(passRelative, pass);
if (fs.existsSync(absolute(failureRelative))) fs.unlinkSync(absolute(failureRelative));
console.log(JSON.stringify(pass, null, 2));
