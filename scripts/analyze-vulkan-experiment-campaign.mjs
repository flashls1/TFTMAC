#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";

function fail(message) {
  throw new Error(`TFTMAC Vulkan campaign analysis failed: ${message}`);
}

const campaignDirectory = process.argv[2];
if (!campaignDirectory) fail("campaign directory argument is required");
const runsDirectory = join(campaignDirectory, "runs");
const runReceipts = readdirSync(runsDirectory)
  .filter((name) => name.endsWith(".json"))
  .sort()
  .map((name) => JSON.parse(readFileSync(join(runsDirectory, name), "utf8")));
if (runReceipts.length !== 7) fail(`expected seven runs, found ${runReceipts.length}`);

function sqlJSON(database, query) {
  const output = execFileSync("/usr/bin/sqlite3", ["-json", database, query], { encoding: "utf8" }).trim();
  return output ? JSON.parse(output) : [];
}

function weightedMean(rows, key) {
  const eligible = rows.filter((row) => Number(row.frames) > 0 && Number.isFinite(Number(row[key])));
  const weight = eligible.reduce((sum, row) => sum + Number(row.frames), 0);
  return weight > 0
    ? eligible.reduce((sum, row) => sum + Number(row[key]) * Number(row.frames), 0) / weight
    : null;
}

function summarizeRun(receipt) {
  const eventRows = sqlJSON(
    receipt.database,
    "SELECT payload_json FROM events WHERE kind='OWNED_VULKAN_PROBE_WINDOW' ORDER BY monotonic_ns"
  );
  const payloads = eventRows
    .map((row) => JSON.parse(row.payload_json))
    .filter((payload) => payload.phase === "measurement");
  const grouped = Object.groupBy(payloads, (payload) => payload.workload);
  const workloads = {};
  for (const [workload, rows] of Object.entries(grouped)) {
    const cpuP99 = weightedMean(rows, "cpu_p99_ms");
    const gpuP99 = weightedMean(rows, "gpu_p99_ms");
    const queueP99 = weightedMean(rows, "queue_wait_p99_ms");
    workloads[workload] = {
      windows: rows.length,
      frames: rows.reduce((sum, row) => sum + Number(row.frames), 0),
      fps: weightedMean(rows, "fps"),
      one_percent_low_fps: weightedMean(rows, "one_percent_low_fps"),
      cpu_p99_ms: cpuP99,
      gpu_p99_ms: gpuP99,
      queue_wait_p99_ms: queueP99,
      relevant_pipeline_p99_ms: Math.max(cpuP99 ?? 0, gpuP99 ?? 0, queueP99 ?? 0),
      error_count: Math.max(...rows.map((row) => Number(row.error_count ?? 0))),
    };
  }
  const runRow = sqlJSON(
    receipt.database,
    "SELECT experiment_profile_id,state,correctness_passed,event_loss_count,effective_feature_receipt_json FROM pipeline_experiment_runs LIMIT 1"
  )[0];
  if (!runRow) fail(`missing pipeline_experiment_runs row in ${receipt.database}`);
  return { ...receipt, ...runRow, workloads };
}

const runs = runReceipts.map(summarizeRun);
const expectedOrder = [
  "control",
  "queue_submit_inline",
  "control",
  "virtual_queue_off",
  "control",
  "fence_contexts_off",
  "control",
];
if (runs.some((run, index) => run.experiment_profile_id !== expectedOrder[index])) {
  fail("run order or sealed experiment identity drifted");
}

const focusWorkload = {
  queue_submit_inline: "queue_fence_present_pressure",
  virtual_queue_off: "queue_fence_present_pressure",
  fence_contexts_off: "queue_fence_present_pressure",
};

function percentChange(candidate, control) {
  return control === 0 ? null : ((candidate - control) / control) * 100;
}

const comparisons = [];
for (const candidateIndex of [1, 3, 5]) {
  const control = runs[candidateIndex - 1];
  const candidate = runs[candidateIndex];
  const focus = focusWorkload[candidate.experiment_profile_id];
  const workloadDeltas = {};
  let maximumRegression = 0;
  let valid = true;
  for (const workload of Object.keys(control.workloads)) {
    const baseline = control.workloads[workload];
    const observed = candidate.workloads[workload];
    if (!observed || baseline.windows < 55 || observed.windows < 55) {
      valid = false;
      continue;
    }
    const lowDelta = percentChange(observed.one_percent_low_fps, baseline.one_percent_low_fps);
    const pipelineP99Improvement = percentChange(
      baseline.relevant_pipeline_p99_ms,
      observed.relevant_pipeline_p99_ms
    );
    workloadDeltas[workload] = {
      one_percent_low_delta_percent: lowDelta,
      relevant_pipeline_p99_improvement_percent: pipelineP99Improvement,
    };
    if (workload !== focus) {
      maximumRegression = Math.max(maximumRegression, -(lowDelta ?? 0), -(pipelineP99Improvement ?? 0));
    }
  }
  const focusDelta = workloadDeltas[focus];
  const correctness = Number(candidate.correctness_passed) === 1
    && candidate.state === "PASS"
    && Number(candidate.event_loss_count) === 0
    && Object.values(candidate.workloads).every((workload) => workload.error_count === 0);
  let decision = "REJECT";
  let reason = "THRESHOLDS_NOT_MET";
  if (!valid || !focusDelta) {
    decision = "INVALID";
    reason = "MISSING_OR_INSUFFICIENT_WORKLOAD_WINDOWS";
  } else if (!correctness) {
    reason = "CORRECTNESS_OR_EVENT_LOSS_FAILURE";
  } else if (
    focusDelta.one_percent_low_delta_percent >= 10
    && focusDelta.relevant_pipeline_p99_improvement_percent >= 10
    && maximumRegression <= 3
  ) {
    decision = "ADVANCE_TO_REVERSE_CONFIRMATION";
    reason = "SCREEN_THRESHOLDS_PASSED";
  } else if (maximumRegression > 3) {
    reason = "OTHER_WORKLOAD_REGRESSION_EXCEEDED_3_PERCENT";
  }
  comparisons.push({
    comparison_id: randomUUID(),
    control_run_id: control.session_id,
    candidate_run_id: candidate.session_id,
    candidate_profile_id: candidate.experiment_profile_id,
    focus_workload: focus,
    workload_deltas: workloadDeltas,
    one_percent_low_delta_percent: focusDelta?.one_percent_low_delta_percent ?? null,
    relevant_pipeline_p99_delta_percent: focusDelta?.relevant_pipeline_p99_improvement_percent ?? null,
    maximum_other_workload_regression_percent: maximumRegression,
    correctness_passed: correctness,
    decision,
    decision_reason: reason,
  });
}

const advanced = comparisons.filter((comparison) => comparison.decision === "ADVANCE_TO_REVERSE_CONFIRMATION");
const result = {
  schema: 1,
  contract: "TFTMAC_VULKAN_EXPERIMENT_CAMPAIGN_V1",
  campaign_id: basename(campaignDirectory),
  generated_utc: new Date().toISOString(),
  metric_method: "frame-count-weighted mean of one-second probe windows",
  runs,
  comparisons,
  finalist: advanced.length === 1 ? advanced[0].candidate_profile_id : null,
  campaign_state: advanced.length === 1
    ? "SCREEN_PASS_REQUIRES_REVERSE_CONFIRMATION"
    : advanced.length > 1
      ? "MULTIPLE_SCREEN_PASSES_REQUIRE_REVERSE_CONFIRMATION"
      : "NO_CANDIDATE_ADVANCED",
};
const canonical = `${JSON.stringify(result, null, 2)}\n`;
writeFileSync(join(campaignDirectory, "campaign-analysis.json"), canonical, { mode: 0o600 });

function quote(value) {
  if (value === null || value === undefined) return "NULL";
  if (typeof value === "number") return Number.isFinite(value) ? String(value) : "NULL";
  return `'${String(value).replaceAll("'", "''")}'`;
}

let sql = `
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS pipeline_experiment_runs(
  run_id TEXT PRIMARY KEY, session_id TEXT NOT NULL, experiment_profile_id TEXT NOT NULL,
  capture_path TEXT NOT NULL, database_sha256 TEXT NOT NULL, state TEXT NOT NULL,
  correctness_passed INTEGER NOT NULL, workload_summary_json TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS pipeline_experiment_comparisons(
  comparison_id TEXT PRIMARY KEY, control_run_id TEXT NOT NULL, candidate_run_id TEXT NOT NULL,
  candidate_profile_id TEXT NOT NULL, created_utc TEXT NOT NULL, workload_deltas_json TEXT NOT NULL,
  one_percent_low_delta_percent REAL, relevant_pipeline_p99_delta_percent REAL,
  maximum_other_workload_regression_percent REAL, correctness_passed INTEGER NOT NULL,
  decision TEXT NOT NULL, decision_reason TEXT NOT NULL
);
`;
for (const run of runs) {
  sql += `INSERT INTO pipeline_experiment_runs VALUES(${[
    run.session_id,
    run.session_id,
    run.experiment_profile_id,
    run.capture_path,
    run.database_sha256,
    run.state,
    Number(run.correctness_passed),
    JSON.stringify(run.workloads),
  ].map(quote).join(",")});\n`;
}
for (const comparison of comparisons) {
  sql += `INSERT INTO pipeline_experiment_comparisons VALUES(${[
    comparison.comparison_id,
    comparison.control_run_id,
    comparison.candidate_run_id,
    comparison.candidate_profile_id,
    result.generated_utc,
    JSON.stringify(comparison.workload_deltas),
    comparison.one_percent_low_delta_percent,
    comparison.relevant_pipeline_p99_delta_percent,
    comparison.maximum_other_workload_regression_percent,
    comparison.correctness_passed ? 1 : 0,
    comparison.decision,
    comparison.decision_reason,
  ].map(quote).join(",")});\n`;
}
const campaignDatabase = join(campaignDirectory, "TFTMAC_VULKAN_CAMPAIGN.sqlite");
execFileSync("/usr/bin/sqlite3", [campaignDatabase], { input: sql });
const databaseHash = createHash("sha256").update(readFileSync(campaignDatabase)).digest("hex");
writeFileSync(
  join(campaignDirectory, "campaign-receipt.json"),
  `${JSON.stringify({
    schema: 1,
    state: "TFTMAC_VULKAN_CAMPAIGN_ANALYSIS_PASS",
    campaign_database: campaignDatabase,
    campaign_database_sha256: databaseHash,
    campaign_analysis_sha256: createHash("sha256").update(canonical).digest("hex"),
    campaign_state: result.campaign_state,
    finalist: result.finalist,
  }, null, 2)}\n`,
  { mode: 0o600 }
);
process.stdout.write(`${join(campaignDirectory, "campaign-receipt.json")}\n`);
