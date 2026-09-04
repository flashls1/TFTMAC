import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const root = process.cwd();
const planRoot = ".clara/plans/tftmac-causal-graphics-v1";
const destinationRelative = `${planRoot}/protected-local-work/unaccepted-waveb-partial-20260901T215825Z`;
const destination = path.join(root, destinationRelative);
const selfRelative = `${planRoot}/preserve-unaccepted-waveb-partial.mjs`;
const expectedHead = "d96a1caf68b807bbae1a03246666da7eea4df620";
const expectedScopeLock = "dc77b6913d14409adc883dd27a67c42e982c40ab9149a68771b61dc99fae297e";
const expectedAcceptedRegistry = "81086498d8a16f2096f8461922731d7cf5c027cf6163d874452c16ffa543fdb2";
const rejected = {
  "ssot/runtime-modes.json": "457ca5865f1bfcfaca16bd1eee1f32db15f90bd9c8764706ba64db56b7a9e518",
  [`${planRoot}/RuntimeMode.swift.template`]: "f0d2ef201d570c0ca89ed238bbcbff3a5cd729eab51d7e13750af8f3f79172a5",
  [`${planRoot}/RuntimeLease.swift.template`]: "de774fd9bd59020093ec35736374f0dfc6013831132ba42c386c6188a4bbe72e",
  [`${planRoot}/AppCoordinator.swift.template`]: "67ee87bdd7f088a05d7a3a7efc6d0bc320ea2270f52757e3f37fc8093e83fc68",
  [`${planRoot}/apply-waveb-source.mjs`]: "ae2142505ffde36ec847772ecee01856f8f41db9ccfa07e70939ca63ecfe3d9a",
  [`${planRoot}/validate-waveb.mjs`]: "5c5b36e4f695db37d9c0263eddbd7d988d56531648831952f445a5d1fb4b4213"
};

function absolute(relativePath) {
  return path.join(root, relativePath);
}

function sha256(buffer) {
  return crypto.createHash("sha256").update(buffer).digest("hex");
}

function fileHash(relativePath) {
  return sha256(fs.readFileSync(absolute(relativePath)));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function git(args, options = {}) {
  const result = spawnSync("git", args, {
    cwd: root,
    encoding: options.encoding ?? "utf8",
    maxBuffer: 16 * 1024 * 1024
  });
  if (result.error || result.status !== 0) {
    throw new Error(`git ${args.join(" ")} failed: ${result.error?.message ?? result.stderr}`);
  }
  return result.stdout;
}

function copyPreserved(relativePath, preservedName = relativePath) {
  const source = absolute(relativePath);
  const target = path.join(destination, preservedName);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(source, target, fs.constants.COPYFILE_EXCL);
  const sourceStat = fs.statSync(source);
  fs.chmodSync(target, sourceStat.mode & 0o777);
  const sourceHash = sha256(fs.readFileSync(source));
  const targetHash = sha256(fs.readFileSync(target));
  assert(sourceHash === targetHash, `preservation hash mismatch for ${relativePath}`);
  return {
    source_path: relativePath,
    preserved_path: path.relative(root, target),
    sha256: targetHash,
    bytes: sourceStat.size,
    mode: (sourceStat.mode & 0o777).toString(8),
    modified_at: sourceStat.mtime.toISOString()
  };
}

assert(git(["rev-parse", "HEAD"]).trim() === expectedHead, "managed-change HEAD drifted");
assert(fileHash(`${planRoot}/SCOPE_LOCK.txt`) === expectedScopeLock, "active scope-lock SHA drifted");
for (const [relativePath, expectedHash] of Object.entries(rejected)) {
  assert(fs.existsSync(absolute(relativePath)), `rejected partial file is missing: ${relativePath}`);
  const observed = fileHash(relativePath);
  assert(observed === expectedHash, `rejected partial drift for ${relativePath}: expected ${expectedHash}, observed ${observed}`);
}
for (const forbidden of [
  `${planRoot}/WAVE_B_APPLY_RECEIPT.json`,
  `${planRoot}/WAVE_B_VALIDATION_RECEIPT.json`,
  `${planRoot}/WAVE_B_VALIDATION_FAILURE.json`,
  "tftmac/Runtime/RuntimeMode.swift"
]) {
  assert(!fs.existsSync(absolute(forbidden)), `unexpected acceptance/product artifact exists: ${forbidden}`);
}
assert(!fs.existsSync(destination), `forensic destination already exists: ${destinationRelative}`);

const statusBefore = git(["status", "--porcelain=v1", "--untracked-files=all"])
  .split("\n")
  .filter(Boolean);
const expectedStatus = new Set([
  " M ssot/runtime-modes.json",
  ...Object.keys(rejected)
    .filter((relativePath) => relativePath !== "ssot/runtime-modes.json")
    .map((relativePath) => `?? ${relativePath}`),
  `?? ${selfRelative}`
]);
assert(statusBefore.length === expectedStatus.size, `unexpected dirty-path count before preservation: ${statusBefore.join(" | ")}`);
for (const line of statusBefore) {
  assert(expectedStatus.has(line), `unexpected dirty path before preservation: ${line}`);
}

fs.mkdirSync(destination, { recursive: false, mode: 0o700 });
const files = [];
for (const relativePath of Object.keys(rejected)) {
  files.push(copyPreserved(relativePath));
}
files.push(copyPreserved(selfRelative));

const acceptedRegistryBytes = git(["show", `HEAD:ssot/runtime-modes.json`], { encoding: "buffer" });
assert(Buffer.isBuffer(acceptedRegistryBytes), "accepted registry was not returned as bytes");
assert(sha256(acceptedRegistryBytes) === expectedAcceptedRegistry, "accepted registry blob SHA drifted");
const acceptedRegistryPath = path.join(destination, "accepted-head-runtime-modes.json");
fs.writeFileSync(acceptedRegistryPath, acceptedRegistryBytes, { flag: "wx", mode: 0o644 });

const beforeStatusPath = path.join(destination, "git-status-before.txt");
fs.writeFileSync(beforeStatusPath, `${statusBefore.join("\n")}\n`, { flag: "wx", mode: 0o644 });
const headPath = path.join(destination, "accepted-head.txt");
fs.writeFileSync(headPath, `${expectedHead}\n`, { flag: "wx", mode: 0o644 });

const registryTemporary = `${absolute("ssot/runtime-modes.json")}.accepted-${process.pid}.tmp`;
fs.writeFileSync(registryTemporary, acceptedRegistryBytes, { flag: "wx", mode: 0o644 });
fs.renameSync(registryTemporary, absolute("ssot/runtime-modes.json"));
assert(fileHash("ssot/runtime-modes.json") === expectedAcceptedRegistry, "accepted registry restoration failed");

for (const relativePath of Object.keys(rejected)) {
  if (relativePath === "ssot/runtime-modes.json") continue;
  fs.unlinkSync(absolute(relativePath));
}

const adjudication = {
  schema: 1,
  state: "UNACCEPTED_PARTIAL_PRESERVED",
  project_id: "tftmac",
  change_id: "215ec5a3-6554-4ca3-95db-1525433bb20f",
  accepted_head_sha: expectedHead,
  active_scope_lock_sha256: expectedScopeLock,
  accepted_registry_sha256: expectedAcceptedRegistry,
  rejected_registry_sha256: rejected["ssot/runtime-modes.json"],
  reason: [
    "The rejected registry enabled advanced_diagnostics and allocated controller port 8556 without the controller-port receipt required by PREFLIGHT.json and AUTHORITY.json.",
    "No WAVE_B_APPLY_RECEIPT.json, WAVE_B_VALIDATION_RECEIPT.json, or newer Clara handoff/scratchpad authority existed.",
    "No product source file, test, Xcode project file, verifier, emulator, installed app, control runtime, or diagnostic runtime was accepted as changed by this partial attempt."
  ],
  preserved_files: files,
  accepted_registry_restored: true,
  effects: {
    emulator_launch_attempted: false,
    runtime_replacement_attempted: false,
    control_stop_attempted: false,
    installed_app_replacement_attempted: false,
    product_source_mutation_attempted: false
  },
  next_required_action: "Resume Wave B from the accepted fail-closed registry and implement source wiring under a new guarded operation identity.",
  adjudicated_at: new Date().toISOString()
};
const adjudicationPath = path.join(destination, "ADJUDICATION.json");
fs.writeFileSync(adjudicationPath, `${JSON.stringify(adjudication, null, 2)}\n`, { flag: "wx", mode: 0o644 });

fs.unlinkSync(absolute(selfRelative));
const statusAfter = git(["status", "--porcelain=v1", "--untracked-files=all"])
  .split("\n")
  .filter(Boolean);
assert(statusAfter.length > 0, "forensic preservation directory was not retained");
assert(!statusAfter.includes(" M ssot/runtime-modes.json"), "registry remains modified after restoration");
assert(statusAfter.every((line) => line.startsWith(`?? ${destinationRelative}/`)), `unexpected post-adjudication state: ${statusAfter.join(" | ")}`);

console.log(JSON.stringify({
  state: adjudication.state,
  accepted_head_sha: expectedHead,
  accepted_registry_sha256: expectedAcceptedRegistry,
  forensic_directory: destinationRelative,
  preserved_file_count: files.length,
  status_after: statusAfter,
  effects: adjudication.effects
}, null, 2));
