import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { spawnSync } from "node:child_process";

const root = process.cwd();
const planRoot = ".clara/plans/tftmac-causal-graphics-v1";
const applyReceiptPath = path.join(root, planRoot, "WAVE_B_APPLY_RECEIPT.json");
const passReceiptPath = path.join(root, planRoot, "WAVE_B_VALIDATION_RECEIPT.json");
const failureReceiptPath = path.join(root, planRoot, "WAVE_B_VALIDATION_FAILURE.json");
const outputDirectory = path.join(root, ".clara/tmp/waveb-validation");
const operationId = "tftmac-waveb-production-validate-20260901-v1";

function sha256File(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function countTests() {
  const testsRoot = path.join(root, "Tests/TFTMACTests");
  let count = 0;
  for (const name of fs.readdirSync(testsRoot)) {
    if (!name.endsWith(".swift")) continue;
    const content = fs.readFileSync(path.join(testsRoot, name), "utf8");
    count += (content.match(/^    func test/gm) ?? []).length;
  }
  return count;
}

function writeJSON(filePath, value) {
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o644 });
}

function fail(message, details = {}) {
  const receipt = {
    schema: 1,
    state: "WAVE_B_VALIDATION_FAILED",
    project_id: "tftmac",
    change_id: "215ec5a3-6554-4ca3-95db-1525433bb20f",
    operation_id: operationId,
    message,
    details,
    emulator_launch_attempted: false,
    failed_at: new Date().toISOString()
  };
  writeJSON(failureReceiptPath, receipt);
  console.error(JSON.stringify(receipt, null, 2));
  process.exit(1);
}

try {
  if (!fs.existsSync(applyReceiptPath)) fail("Wave B apply receipt is missing; validation remains closed.");
  const applyReceipt = JSON.parse(fs.readFileSync(applyReceiptPath, "utf8"));
  if (applyReceipt.schema !== 1 || applyReceipt.project_id !== "tftmac") {
    fail("Wave B apply receipt identity is invalid.");
  }
  if (applyReceipt.change_id !== "215ec5a3-6554-4ca3-95db-1525433bb20f") {
    fail("Wave B apply receipt is bound to another change.");
  }
  if (applyReceipt.scope_lock_sha256 !== "dc77b6913d14409adc883dd27a67c42e982c40ab9149a68771b61dc99fae297e") {
    fail("Wave B apply receipt does not match the active scope lock.");
  }
  if (applyReceipt.effects?.emulator_launch_attempted !== false ||
      applyReceipt.effects?.runtime_replacement_attempted !== false ||
      applyReceipt.effects?.control_stop_attempted !== false) {
    fail("Wave B apply receipt reports a forbidden runtime effect.");
  }
  const mismatches = [];
  for (const [relativePath, expected] of Object.entries(applyReceipt.output_sha256 ?? {})) {
    const filePath = path.join(root, relativePath);
    const observed = fs.existsSync(filePath) ? sha256File(filePath) : null;
    if (observed !== expected) mismatches.push({ relativePath, expected, observed });
  }
  if (mismatches.length > 0) fail("Wave B applied source drifted before validation.", { mismatches });

  const requiredMarkers = [
    ["tftmac/App/AppCoordinator.swift", "TFTMACRuntimeModeRegistry.loadBundled"],
    ["tftmac/Runtime/TFTMACRuntime.swift", "runtimeSelection.validateForLaunch()"],
    ["tftmac/Runtime/TFTMACRuntime.swift", "TFTMACRuntimeLease.acquire(stateRoot: stateRoot, identity: leaseIdentity)"],
    ["tftmac/Runtime/RuntimeLease.swift", "let identity: TFTMACRuntimeLeaseIdentity?"],
    ["Tests/TFTMACTests/TFTMACGate1Tests.swift", "testRuntimeModeRegistryDefinesExactlyThreeModesAndDefaultsControl"]
  ];
  for (const [relativePath, marker] of requiredMarkers) {
    const content = fs.readFileSync(path.join(root, relativePath), "utf8");
    if (!content.includes(marker)) fail(`Required Wave B marker is missing from ${relativePath}.`, { marker });
  }
  const testCount = countTests();
  if (testCount !== 47) fail("Wave B deterministic test-count contract failed.", { expected: 47, observed: testCount });

  fs.mkdirSync(outputDirectory, { recursive: true });
  const result = spawnSync("/bin/zsh", ["scripts/verify-tftmac.command"], {
    cwd: root,
    env: process.env,
    encoding: "utf8",
    maxBuffer: 128 * 1024 * 1024
  });
  fs.writeFileSync(path.join(outputDirectory, "stdout.log"), result.stdout ?? "", "utf8");
  fs.writeFileSync(path.join(outputDirectory, "stderr.log"), result.stderr ?? "", "utf8");
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error || result.status !== 0) {
    fail("Wave B production verifier failed.", {
      exit_code: result.status,
      signal: result.signal,
      spawn_error: result.error?.message ?? null,
      stdout_tail: (result.stdout ?? "").slice(-6000),
      stderr_tail: (result.stderr ?? "").slice(-6000)
    });
  }

  const appRoot = path.join(root, ".build-native-release/Build/Products/Release/TFTMAC.app");
  const appBinary = path.join(appRoot, "Contents/MacOS/TFTMAC");
  const appModes = path.join(appRoot, "Contents/Resources/runtime-modes.json");
  const appAuthority = path.join(appRoot, "Contents/Resources/runtime-authority.json");
  for (const required of [appBinary, appModes, appAuthority]) {
    if (!fs.existsSync(required)) fail("Validated package output is missing.", { required });
  }
  const receipt = {
    schema: 1,
    state: "WAVE_B_VALIDATION_PASS",
    project_id: "tftmac",
    change_id: "215ec5a3-6554-4ca3-95db-1525433bb20f",
    operation_id: operationId,
    scope_lock_sha256: applyReceipt.scope_lock_sha256,
    apply_operation_id: applyReceipt.operation_id,
    verifier_sha256: sha256File(path.join(root, "scripts/verify-tftmac.command")),
    deterministic_test_count: testCount,
    package: {
      app_path: appRoot,
      executable_sha256: sha256File(appBinary),
      runtime_modes_sha256: sha256File(appModes),
      runtime_authority_sha256: sha256File(appAuthority)
    },
    source_output_sha256: applyReceipt.output_sha256,
    effects: {
      emulator_launch_attempted: false,
      runtime_replacement_attempted: false,
      control_stop_attempted: false,
      package_launch_attempted: false,
      source_build_test_only: true
    },
    next_required_action: "Review and checkpoint Wave B; diagnostic first boot remains separately gated.",
    validated_at: new Date().toISOString()
  };
  writeJSON(passReceiptPath, receipt);
  if (fs.existsSync(failureReceiptPath)) fs.unlinkSync(failureReceiptPath);
  console.log(JSON.stringify(receipt, null, 2));
} catch (error) {
  fail(error instanceof Error ? error.message : String(error));
}
