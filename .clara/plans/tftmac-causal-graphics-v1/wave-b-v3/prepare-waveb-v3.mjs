#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';

const ROOT = process.cwd();
const CHANGE_ID = '215ec5a3-6554-4ca3-95db-1525433bb20f';
const EXPECTED_HEAD = 'd96a1caf68b807bbae1a03246666da7eea4df620';
const PLAN = '.clara/plans/tftmac-causal-graphics-v1/IMPLEMENTATION_PLAN.md';
const PLAN_SHA = '78785b29815dba26a8da1d2ed56e0e9c256d3e7d9cfb4c4857b3c954846e8d2b';
const LOCK = '.clara/plans/tftmac-causal-graphics-v1/SCOPE_LOCK.txt';
const LOCK_SHA = 'dc77b6913d14409adc883dd27a67c42e982c40ab9149a68771b61dc99fae297e';
const DIR = '.clara/plans/tftmac-causal-graphics-v1/wave-b-v3';
const PROTECTED = '.clara/plans/tftmac-causal-graphics-v1/protected-local-work/unaccepted-waveb-draft-before-v3';
const DIRTY_REGISTRY_SHA = '457ca5865f1bfcfaca16bd1eee1f32db15f90bd9c8764706ba64db56b7a9e518';
const ACCEPTED_BUILD_SHA = '9556ffe5c9d083d3ba90006628b8fc5a94a6989f56fa21d40bb9a30f2f99ef8d';
const ACCEPTED_CLONE_SHA = '09e4b2d21290de582320cb0aee3148af25f5e2e59199e225e604afbb6cb19648';
const ACCEPTED_HOST_SHA = 'a72d10106acb83444a38027ed3978b6ef3bc60e7ec0ae0ba9439f67eb57f6067';

function fail(message) {
  console.error(`WAVE_B_V3_PREPARE_FAILED: ${message}`);
  process.exit(1);
}
function sha256Bytes(bytes) {
  return crypto.createHash('sha256').update(bytes).digest('hex');
}
function sha256File(relativePath) {
  return sha256Bytes(fs.readFileSync(path.join(ROOT, relativePath)));
}
function ensure(condition, message) {
  if (!condition) fail(message);
}
function git(...args) {
  return execFileSync('/usr/bin/git', args, { cwd: ROOT, encoding: 'utf8' });
}
function writeJSON(relativePath, value) {
  const target = path.join(ROOT, relativePath);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, `${JSON.stringify(value, null, 2)}\n`, { flag: 'wx', mode: 0o644 });
}
function writeText(relativePath, value) {
  const target = path.join(ROOT, relativePath);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, value, { flag: 'wx', mode: 0o644 });
}
function copyPreserved(sourceRelative, destinationRelative) {
  const source = path.join(ROOT, sourceRelative);
  const destination = path.join(ROOT, destinationRelative);
  ensure(fs.existsSync(source), `preservation source is missing: ${sourceRelative}`);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.copyFileSync(source, destination, fs.constants.COPYFILE_EXCL);
  return {
    source: sourceRelative,
    preserved_path: destinationRelative,
    sha256: sha256File(sourceRelative),
    bytes: fs.statSync(source).size
  };
}

ensure(git('rev-parse', 'HEAD').trim() === EXPECTED_HEAD, 'managed change HEAD drifted');
ensure(sha256File(PLAN) === PLAN_SHA, 'original implementation plan drifted');
ensure(sha256File(LOCK) === LOCK_SHA, 'execution scope lock drifted');
ensure(!fs.existsSync(path.join(ROOT, PROTECTED)), 'protected draft destination already exists; reconcile instead of replaying');
ensure(sha256File('ssot/runtime-modes.json') === DIRTY_REGISTRY_SHA, 'unaccepted runtime registry draft changed; review before mutation');

const dirtyRegistry = JSON.parse(fs.readFileSync(path.join(ROOT, 'ssot/runtime-modes.json'), 'utf8'));
ensure(dirtyRegistry?.modes?.advanced_diagnostics?.launch_state === 'enabled', 'expected rejected diagnostics-enabled draft was not found');
ensure(dirtyRegistry?.modes?.advanced_diagnostics?.controller_port === 8556, 'expected unreceipted diagnostic controller port was not found');
ensure(dirtyRegistry?.modes?.candidate?.launch_state === 'blocked_not_built', 'candidate draft is not fail-closed');

const staleFiles = [
  'ssot/runtime-modes.json',
  '.clara/plans/tftmac-causal-graphics-v1/AppCoordinator.swift.template',
  '.clara/plans/tftmac-causal-graphics-v1/RuntimeLease.swift.template',
  '.clara/plans/tftmac-causal-graphics-v1/RuntimeMode.swift.template',
  '.clara/plans/tftmac-causal-graphics-v1/apply-waveb-source.mjs',
  '.clara/plans/tftmac-causal-graphics-v1/preserve-unaccepted-waveb-partial.mjs',
  '.clara/plans/tftmac-causal-graphics-v1/validate-waveb.mjs',
  '.clara/plans/tftmac-causal-graphics-v1/wave-b-v2/RuntimeLease.swift.template',
  '.clara/plans/tftmac-causal-graphics-v1/wave-b-v2/RuntimeMode.swift.template',
  '.clara/plans/tftmac-causal-graphics-v1/wave-b-v2/apply-waveb-v2.mjs',
  '.clara/plans/tftmac-causal-graphics-v1/wave-b-v2/gate-waveb-candidate.mjs'
];
const preserved = staleFiles.map((sourceRelative) => {
  const suffix = sourceRelative === 'ssot/runtime-modes.json'
    ? 'runtime-modes.unaccepted.json'
    : sourceRelative.replace('.clara/plans/tftmac-causal-graphics-v1/', '');
  return copyPreserved(sourceRelative, `${PROTECTED}/${suffix}`);
});

const acceptedRegistryBytes = Buffer.from(git('show', 'HEAD:ssot/runtime-modes.json'));
const acceptedRegistrySha = sha256Bytes(acceptedRegistryBytes);
fs.writeFileSync(path.join(ROOT, 'ssot/runtime-modes.json'), acceptedRegistryBytes, { mode: 0o644 });

for (const stale of staleFiles.slice(1)) {
  fs.rmSync(path.join(ROOT, stale), { force: true });
}
fs.rmSync(path.join(ROOT, '.clara/plans/tftmac-causal-graphics-v1/wave-b-v2'), { recursive: true, force: true });

const observedAt = new Date().toISOString();
const amendment = `# Wave B v3 — Runtime-Mode Integration Continuation Amendment\n\n` +
`Status: ACTIVE APPEND-ONLY AMENDMENT\n\n` +
`This amendment supplements, and does not replace, the original TFTMAC Causal Graphics Optimization plan v1.1. The original plan remains at \`${PLAN}\` with SHA-256 \`${PLAN_SHA}\`. The execution-scope lock remains unchanged at SHA-256 \`${LOCK_SHA}\`.\n\n` +
`## Current accepted authority\n\n` +
`- Active managed change: \`${CHANGE_ID}\`.\n` +
`- Exact base/head before this amendment: \`${EXPECTED_HEAD}\`.\n` +
`- Accepted r9 diagnostic build manifest: \`${ACCEPTED_BUILD_SHA}\`.\n` +
`- Accepted stopped-clone receipt: \`${ACCEPTED_CLONE_SHA}\`.\n` +
`- Accepted native diagnostic host receipt: \`${ACCEPTED_HOST_SHA}\`.\n` +
`- Stock Build 8 remains the protected and default control runtime.\n\n` +
`## New finding and adjudication\n\n` +
`An unaccepted local draft marked \`advanced_diagnostics\` launch-ready on controller port 8556 without a durable controller-port allocation receipt. That draft is rejected, preserved under \`${PROTECTED}\`, and must not become launch authority. The accepted registry is restored before product-source work.\n\n` +
`Five stale Clara watchers were observing operation IDs that never existed. They are observation noise only: they authorize no replay and do not prove any emulator, TFT, clone, build, or validation effect.\n\n` +
`## Effective Wave B implementation scope\n\n` +
`1. Preserve the rejected draft and restore the accepted fail-closed registry.\n` +
`2. Add a typed three-mode registry contract for exactly \`control\`, \`advanced_diagnostics\`, and \`candidate\`.\n` +
`3. Keep \`control\` as the only launch-ready default and preserve its existing Build 8 runtime, AVD, ports, serial, package path, state behavior, and /usr/bin/open app-host chain.\n` +
`4. Give each mode an explicit runtime root, AVD identity, ADB/console/controller identity, state namespace, and lease identity. A single global exclusivity lease remains the collision guard and records the exact selected mode identity.\n` +
`5. Keep \`advanced_diagnostics\` blocked until a separately receipted controller port is written through a later append-only gate. Its sealed build, stopped-clone, and native-host receipts must be structurally and cryptographically validated before it can become launch-ready.\n` +
`6. Keep \`candidate\` blocked until an accepted ROOT_NAMED-derived, stock-compatible candidate exists.\n` +
`7. Remove control-only hard-coded ADB, AVD, serial, console, and controller identities from shared runtime operations; resolve those values from the selected definition.\n` +
`8. Verify selected binary hashes before launch and verify loaded emulator/gfxstream image identity before TFT starts.\n` +
`9. This source-only wave performs no emulator launch, TFT launch, AVD mutation, runtime replacement, application install, or control shutdown.\n` +
`10. Run one decisive changed-head production verifier after implementation. Do not rerun the already-accepted unchanged 43-test baseline separately.\n\n` +
`## Wave B v3 acceptance\n\n` +
`PASS requires: exact three-mode decoding; default control behavior; diagnostics and candidate fail-closed behavior; registry and external-receipt tamper rejection; mode-aware lease persistence; mode-derived runtime commands; unsigned Release build; all native tests; unchanged visible Git state after validation; and a review proving no runtime process was launched.\n\n` +
`After PASS, the next causal stage is a separate controller-port allocation receipt and guarded diagnostic first-boot gate. No later graphics instrumentation, candidate promotion, or production cutover is authorized by this amendment.\n`;
writeText(`${DIR}/CONTINUATION_AMENDMENT.md`, amendment);
const amendmentSha = sha256File(`${DIR}/CONTINUATION_AMENDMENT.md`);

const preflight = {
  schema: 1,
  state: 'READY_FOR_WAVE_B_V3_SOURCE_ONLY',
  project_id: 'tftmac',
  change_id: CHANGE_ID,
  observed_at: observedAt,
  base_head_sha: EXPECTED_HEAD,
  original_plan: { path: PLAN, sha256: PLAN_SHA },
  scope_lock: { path: LOCK, sha256: LOCK_SHA, unchanged: true },
  amendment: { path: `${DIR}/CONTINUATION_AMENDMENT.md`, sha256: amendmentSha },
  accepted_registry_sha256: acceptedRegistrySha,
  rejected_draft: {
    sha256: DIRTY_REGISTRY_SHA,
    reason: 'advanced_diagnostics enabled on controller port 8556 without durable allocation receipt',
    preserved_root: PROTECTED
  },
  accepted_external_receipts: {
    diagnostic_build: ACCEPTED_BUILD_SHA,
    diagnostic_avd_clone: ACCEPTED_CLONE_SHA,
    diagnostic_native_host: ACCEPTED_HOST_SHA
  },
  verified: [
    'Original v1.1 plan and execution-scope lock are intact.',
    'Current managed change is based on the accepted published Wave B registry head.',
    'Rejected draft is preserved before restoration.',
    'Stock Build 8 is not modified or stopped by this source wave.',
    'No diagnostic first boot, TFT launch, runtime rebuild, clone replay, or installed-app replacement is authorized.',
    'Changed-head production validation subsumes a separate unchanged-baseline rerun.'
  ],
  next_safe_action: 'Apply the bounded mode-aware source integration, then run one changed-head production validation.'
};
writeJSON(`${DIR}/PREFLIGHT.json`, preflight);
const preflightSha = sha256File(`${DIR}/PREFLIGHT.json`);

const zenGate = {
  schema: 1,
  result: 'PASS',
  gate: 'TARGETED_WAVE_B_V3_ZENGATE',
  project_id: 'tftmac',
  change_id: CHANGE_ID,
  observed_at: observedAt,
  original_plan_sha256: PLAN_SHA,
  scope_lock_sha256: LOCK_SHA,
  amendment_sha256: amendmentSha,
  preflight_sha256: preflightSha,
  score_preserved: true,
  production_requirement: 'MANDATORY',
  risks: [
    { risk: 'unreceipted diagnostic launch', mitigation: 'diagnostics remains blocked pending a later controller-port receipt' },
    { risk: 'control-path regression', mitigation: 'control remains default and exact control identity is asserted in registry and tests' },
    { risk: 'cross-mode collision', mitigation: 'lease persists registry/configuration/AVD/port/serial identity and rejects concurrent ownership' },
    { risk: 'receipt or binary drift', mitigation: 'SHA-256, state, identity, and pre-launch binary checks fail closed' },
    { risk: 'scope expansion', mitigation: 'no runtime launch, installed-app replacement, broad refactor, dependency update, or later phase work in this wave' }
  ],
  execution_scope_lock: 'Implement only this amendment and the minimum source/test/project-file changes required for its acceptance. No unsolicited refactor, cleanup, rename, generalization, optimization, dependency upgrade, reformatting, future-proofing, or unrelated behavior change.'
};
writeJSON(`${DIR}/ZENGATE_RECEIPT.json`, zenGate);

const inventory = {
  schema: 1,
  state: 'UNACCEPTED_WAVE_B_DRAFT_PRESERVED',
  project_id: 'tftmac',
  change_id: CHANGE_ID,
  observed_at: observedAt,
  rejected_registry_sha256: DIRTY_REGISTRY_SHA,
  accepted_registry_restored_sha256: acceptedRegistrySha,
  preserved
};
writeJSON(`${PROTECTED}/INVENTORY.json`, inventory);

const receipt = {
  schema: 1,
  state: 'WAVE_B_V3_PREPARATION_PASS',
  project_id: 'tftmac',
  change_id: CHANGE_ID,
  operation_id: process.env.CLARA_OPERATION_ID ?? null,
  observed_at: observedAt,
  base_head_sha: EXPECTED_HEAD,
  original_plan_sha256: PLAN_SHA,
  scope_lock_sha256: LOCK_SHA,
  amendment_sha256: amendmentSha,
  preflight_sha256: preflightSha,
  zengate_sha256: sha256File(`${DIR}/ZENGATE_RECEIPT.json`),
  accepted_registry_restored_sha256: acceptedRegistrySha,
  preserved_root: PROTECTED,
  product_source_mutated: false,
  runtime_effect_attempted: false,
  next_safe_action: 'Checkpoint this preparation, then apply Wave B v3 product source.'
};
writeJSON(`${DIR}/PREPARATION_RECEIPT.json`, receipt);
console.log(JSON.stringify(receipt, null, 2));
