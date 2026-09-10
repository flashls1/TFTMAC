PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
PRAGMA foreign_keys=ON;

CREATE TABLE IF NOT EXISTS campaigns(
  campaign_id TEXT PRIMARY KEY,
  started_utc TEXT NOT NULL,
  ended_utc TEXT,
  state TEXT NOT NULL,
  authority_sha256 TEXT NOT NULL,
  candidate_manifest_sha256 TEXT NOT NULL,
  lkg_integrity_passed INTEGER NOT NULL DEFAULT 0,
  pbe_evidence_admitted INTEGER NOT NULL DEFAULT 0,
  note TEXT
);
CREATE TABLE IF NOT EXISTS candidates(
  candidate_id TEXT PRIMARY KEY,
  family TEXT NOT NULL,
  kind TEXT NOT NULL,
  build_scope TEXT NOT NULL,
  restart_class TEXT NOT NULL,
  definition_json TEXT NOT NULL,
  definition_sha256 TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS builds(
  build_id TEXT PRIMARY KEY,
  campaign_id TEXT NOT NULL,
  candidate_id TEXT NOT NULL,
  build_scope TEXT NOT NULL,
  build_key TEXT,
  started_utc TEXT NOT NULL,
  ended_utc TEXT,
  duration_ms REAL,
  cache_hit INTEGER NOT NULL DEFAULT 0,
  exit_code INTEGER,
  artifact_manifest_path TEXT,
  artifact_manifest_sha256 TEXT,
  state TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS runs(
  run_id TEXT PRIMARY KEY,
  campaign_id TEXT NOT NULL,
  candidate_id TEXT NOT NULL,
  build_id TEXT,
  session_id TEXT,
  capture_path TEXT,
  started_utc TEXT NOT NULL,
  ended_utc TEXT,
  state TEXT NOT NULL,
  classification TEXT,
  failure_fingerprint TEXT,
  rollback_verified INTEGER NOT NULL DEFAULT 0,
  package_verified INTEGER NOT NULL DEFAULT 0,
  runtime_verified INTEGER NOT NULL DEFAULT 0,
  selected_game_rhi TEXT,
  raw_native_classifier_value TEXT,
  result_json TEXT
);
CREATE TABLE IF NOT EXISTS experiment_variables(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id TEXT NOT NULL,
  category TEXT NOT NULL,
  variable_name TEXT NOT NULL,
  baseline_value TEXT,
  requested_value TEXT,
  effective_value TEXT,
  verification_source TEXT NOT NULL,
  verification_status TEXT NOT NULL,
  changed_from_control INTEGER NOT NULL,
  observed_monotonic_ns INTEGER NOT NULL,
  UNIQUE(run_id, category, variable_name)
);
CREATE TABLE IF NOT EXISTS evidence_provenance(
  evidence_id TEXT PRIMARY KEY,
  campaign_id TEXT NOT NULL,
  candidate_id TEXT,
  run_id TEXT,
  client_scope TEXT NOT NULL,
  package_name TEXT,
  package_version TEXT,
  version_code TEXT,
  package_pid INTEGER,
  runtime_configuration_sha256 TEXT,
  graphics_stack_sha256 TEXT,
  evidence_kind TEXT NOT NULL,
  evidence_path TEXT NOT NULL,
  evidence_sha256 TEXT,
  identity_verification_method TEXT NOT NULL,
  identity_confidence TEXT NOT NULL,
  decision_admissible INTEGER NOT NULL,
  created_utc TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS telemetry_coverage(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id TEXT NOT NULL,
  producer TEXT NOT NULL,
  expected INTEGER NOT NULL,
  schema_version TEXT,
  first_sequence INTEGER,
  last_sequence INTEGER,
  produced_count INTEGER NOT NULL,
  persisted_count INTEGER NOT NULL,
  lost_count INTEGER NOT NULL,
  malformed_count INTEGER NOT NULL,
  parse_error_count INTEGER NOT NULL,
  started_monotonic_ns INTEGER,
  ended_monotonic_ns INTEGER,
  status TEXT NOT NULL,
  UNIQUE(run_id, producer)
);
CREATE TABLE IF NOT EXISTS state_transitions(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id TEXT NOT NULL,
  observed_monotonic_ns INTEGER NOT NULL,
  previous_state TEXT,
  current_state TEXT NOT NULL,
  stage TEXT,
  phase TEXT,
  reason TEXT,
  evidence_json TEXT NOT NULL,
  screenshot_path TEXT,
  screenshot_sha256 TEXT,
  action_selected TEXT,
  action_result TEXT
);
CREATE TABLE IF NOT EXISTS mechanism_events(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id TEXT NOT NULL,
  observed_monotonic_ns INTEGER NOT NULL,
  component TEXT NOT NULL,
  event_kind TEXT NOT NULL,
  resource_id TEXT,
  allocation_id TEXT,
  key_hash TEXT,
  reason TEXT,
  duration_ns INTEGER,
  payload_json TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS performance_windows(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id TEXT NOT NULL,
  stage TEXT NOT NULL,
  phase TEXT NOT NULL,
  sequence INTEGER NOT NULL,
  started_monotonic_ns INTEGER NOT NULL,
  ended_monotonic_ns INTEGER NOT NULL,
  frame_count INTEGER NOT NULL,
  weighted_fps REAL,
  one_percent_low_fps REAL,
  p50_ms REAL,
  p95_ms REAL,
  p99_ms REAL,
  max_ms REAL,
  over_25ms INTEGER NOT NULL,
  over_50ms INTEGER NOT NULL,
  over_100ms INTEGER NOT NULL,
  history_truncated INTEGER NOT NULL,
  semantic_gate_passed INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS failures(
  failure_id TEXT PRIMARY KEY,
  campaign_id TEXT NOT NULL,
  candidate_id TEXT,
  run_id TEXT,
  component TEXT NOT NULL,
  phase TEXT NOT NULL,
  error_class TEXT NOT NULL,
  normalized_error TEXT NOT NULL,
  fingerprint TEXT NOT NULL,
  first_seen_utc TEXT NOT NULL,
  last_seen_utc TEXT NOT NULL,
  occurrence_count INTEGER NOT NULL,
  quarantined INTEGER NOT NULL DEFAULT 0,
  UNIQUE(campaign_id, fingerprint)
);
CREATE TABLE IF NOT EXISTS rollbacks(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id TEXT NOT NULL,
  observed_utc TEXT NOT NULL,
  dev_core_stopped INTEGER NOT NULL,
  emulator_stopped INTEGER NOT NULL,
  angle_restored INTEGER,
  profile_restored INTEGER,
  cache_properties_restored INTEGER,
  installed_app_integrity INTEGER NOT NULL,
  lkg_integrity INTEGER NOT NULL,
  verified INTEGER NOT NULL,
  detail_json TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS artifacts(
  artifact_id TEXT PRIMARY KEY,
  run_id TEXT,
  campaign_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  path TEXT NOT NULL,
  sha256 TEXT,
  byte_count INTEGER,
  created_utc TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS comparisons(
  comparison_id TEXT PRIMARY KEY,
  campaign_id TEXT NOT NULL,
  control_run_id TEXT NOT NULL,
  candidate_run_id TEXT NOT NULL,
  created_utc TEXT NOT NULL,
  metric_json TEXT NOT NULL,
  decision TEXT NOT NULL,
  decision_reason TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS decisions(
  decision_id TEXT PRIMARY KEY,
  campaign_id TEXT NOT NULL,
  candidate_id TEXT,
  run_id TEXT,
  created_utc TEXT NOT NULL,
  classification TEXT NOT NULL,
  reason TEXT NOT NULL,
  evidence_json TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_runs_campaign ON runs(campaign_id, started_utc);
CREATE INDEX IF NOT EXISTS idx_vars_run ON experiment_variables(run_id, variable_name);
CREATE INDEX IF NOT EXISTS idx_perf_run_stage ON performance_windows(run_id, stage, sequence);
CREATE INDEX IF NOT EXISTS idx_failure_fingerprint ON failures(campaign_id, fingerprint);
CREATE INDEX IF NOT EXISTS idx_mechanism_run ON mechanism_events(run_id, observed_monotonic_ns);
