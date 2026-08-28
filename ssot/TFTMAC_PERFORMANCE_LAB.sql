-- TFTMAC Performance Laboratory
--
-- CLEAN-ROOM PERFORMANCE EVIDENCE DATABASE
-- ========================================
-- This database is intentionally independent from:
--   ssot/TFTMAC_ENGINEERING_MAP.sql
--   ssot/donors/TFTMAC_DONOR_RESEARCH.sql
--
-- Donor measurements, claims, and historical benchmark numbers MUST NOT be
-- inserted here as current product facts. A donor finding may nominate a
-- hypothesis outside this database, but only a current TFTMAC session or a
-- current controlled experiment may support a performance fact here.
--
-- Runtime rule:
--   High-rate telemetry is captured append-only to raw files during gameplay.
--   This SQLite database is populated after or asynchronously from capture so
--   the observer does not become the bottleneck.
--
-- Promotion rule:
--   A hypothesis NEVER becomes a fact merely by changing its status. A current
--   performance fact requires an explicit performance_facts row backed by a
--   current evidence row. KEEP decisions require controlled metrics and, for a
--   performance promotion, cold confirmation unless the decision is explicitly
--   diagnostic only.
--
-- SQLite compatible.

PRAGMA foreign_keys = ON;
BEGIN;

CREATE TABLE lab_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE host_facts (
    id TEXT PRIMARY KEY,
    fact_key TEXT NOT NULL UNIQUE,
    fact_value TEXT NOT NULL,
    unit TEXT,
    provenance_class TEXT NOT NULL CHECK (
        provenance_class IN ('DIRECT_OBSERVATION','PROJECT_LOCK','USER_REQUIREMENT')
    ),
    source_ref TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('OBSERVED','FROZEN','RETIRED')),
    observed_at TEXT NOT NULL,
    notes TEXT
);

CREATE TABLE runtime_configs (
    id TEXT PRIMARY KEY,
    parent_config_id TEXT REFERENCES runtime_configs(id),
    name TEXT NOT NULL,
    config_sha256 TEXT UNIQUE,
    emulator_version TEXT,
    platform_tools_version TEXT,
    system_image_package TEXT,
    system_image_revision INTEGER,
    avd_name TEXT,
    adb_serial TEXT,
    adb_server_port INTEGER,
    emulator_console_port INTEGER,
    vcpu INTEGER CHECK (vcpu IS NULL OR vcpu > 0),
    ram_mb INTEGER CHECK (ram_mb IS NULL OR ram_mb > 0),
    display_width INTEGER CHECK (display_width IS NULL OR display_width > 0),
    display_height INTEGER CHECK (display_height IS NULL OR display_height > 0),
    density_dpi INTEGER CHECK (density_dpi IS NULL OR density_dpi > 0),
    refresh_hz REAL CHECK (refresh_hz IS NULL OR refresh_hz > 0),
    gpu_mode TEXT,
    audio_enabled INTEGER CHECK (audio_enabled IN (0,1) OR audio_enabled IS NULL),
    graphics_transport TEXT,
    angle_mode TEXT,
    vulkan_mode TEXT,
    moltenvk_mode TEXT,
    presentation_mode TEXT,
    state TEXT NOT NULL CHECK (state IN ('CONTROL','CANDIDATE','PROMOTED','REJECTED','RETIRED')),
    created_at TEXT NOT NULL,
    notes TEXT
);

CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    runtime_config_id TEXT NOT NULL REFERENCES runtime_configs(id),
    started_utc TEXT,
    ended_utc TEXT,
    host_start_mono_ns INTEGER,
    host_end_mono_ns INTEGER,
    boot_class TEXT NOT NULL CHECK (boot_class IN ('COLD','WARM','UNKNOWN')),
    workload_class TEXT NOT NULL CHECK (
        workload_class IN ('BOOT','LOGIN','LOBBY','MATCH_ENTRY','TRANSITION','EARLY_COMBAT','HEAVY_COMBAT','MIXED','UNKNOWN')
    ),
    package_name TEXT,
    package_version_name TEXT,
    package_version_code TEXT,
    package_state_sha256 TEXT,
    renderer_state_sha256 TEXT,
    session_manifest_sha256 TEXT,
    package_updated_during_session INTEGER NOT NULL DEFAULT 0 CHECK (package_updated_during_session IN (0,1)),
    capture_state TEXT NOT NULL CHECK (capture_state IN ('PLANNED','CAPTURING','COMPLETE','PARTIAL','INVALID')),
    semantic_valid INTEGER CHECK (semantic_valid IN (0,1) OR semantic_valid IS NULL),
    invalid_reason TEXT,
    notes TEXT
);

CREATE TABLE clock_sync (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    host_t0_ns INTEGER NOT NULL,
    guest_mono_ns INTEGER NOT NULL,
    host_t1_ns INTEGER NOT NULL,
    host_midpoint_ns INTEGER NOT NULL,
    rtt_ns INTEGER NOT NULL CHECK (rtt_ns >= 0),
    estimated_offset_ns INTEGER NOT NULL,
    source TEXT NOT NULL,
    UNIQUE(session_id, host_t0_ns)
);

CREATE TABLE artifacts (
    id TEXT PRIMARY KEY,
    session_id TEXT REFERENCES sessions(id) ON DELETE CASCADE,
    experiment_id TEXT,
    artifact_kind TEXT NOT NULL,
    path TEXT NOT NULL,
    sha256 TEXT,
    byte_count INTEGER CHECK (byte_count IS NULL OR byte_count >= 0),
    required INTEGER NOT NULL DEFAULT 0 CHECK (required IN (0,1)),
    state TEXT NOT NULL CHECK (state IN ('EXPECTED','PRESENT','MISSING','CORRUPT','OPTIONAL_UNAVAILABLE')),
    created_at TEXT,
    notes TEXT
);

CREATE TABLE markers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    host_mono_ns INTEGER NOT NULL,
    guest_mono_ns INTEGER,
    marker_type TEXT NOT NULL CHECK (
        marker_type IN ('USER_STUTTER','AUTO_JANK','AUTO_SEVERE_STALL','MATCH_ENTRY','COMBAT_START','TRANSITION','PACKAGE_UPDATE','CUSTOM')
    ),
    label TEXT,
    payload_json TEXT
);

CREATE TABLE frame_samples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    source TEXT NOT NULL,
    surface_name TEXT,
    frame_number INTEGER,
    presentation_host_ns INTEGER,
    presentation_guest_ns INTEGER,
    frame_interval_ns INTEGER CHECK (frame_interval_ns IS NULL OR frame_interval_ns >= 0),
    classification TEXT CHECK (classification IN ('NORMAL','JANK','SEVERE_STALL','UNKNOWN')),
    raw_artifact_id TEXT REFERENCES artifacts(id),
    UNIQUE(session_id, source, surface_name, frame_number)
);

CREATE TABLE process_samples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    host_mono_ns INTEGER NOT NULL,
    scope TEXT NOT NULL CHECK (scope IN ('HOST','GUEST')),
    process_name TEXT NOT NULL,
    pid INTEGER,
    tid INTEGER,
    cpu_pct REAL,
    cpu_time_ns INTEGER,
    rss_bytes INTEGER,
    thread_count INTEGER,
    nice_value INTEGER,
    process_state TEXT,
    raw_artifact_id TEXT REFERENCES artifacts(id)
);

CREATE TABLE memory_samples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    host_mono_ns INTEGER NOT NULL,
    host_used_bytes INTEGER,
    host_available_bytes INTEGER,
    host_compressed_bytes INTEGER,
    host_swap_used_bytes INTEGER,
    host_pressure_state TEXT,
    guest_total_bytes INTEGER,
    guest_available_bytes INTEGER,
    emulator_rss_bytes INTEGER,
    pagein_count INTEGER,
    pageout_count INTEGER,
    raw_artifact_id TEXT REFERENCES artifacts(id)
);

CREATE TABLE graphics_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    host_mono_ns INTEGER,
    guest_mono_ns INTEGER,
    boundary TEXT NOT NULL CHECK (
        boundary IN (
            'UNREAL_GAME','UNREAL_RHI','PSO_SHADER','DEVICE_PROFILE','TEXTURE_ASTC',
            'GUEST_SCHEDULER','ANGLE','GUEST_VULKAN','GFXSTREAM_ASG','HOST_GFXSTREAM',
            'MOLTENVK','METAL','SURFACEFLINGER','MEMORY','AUDIO','PACKAGE','UNKNOWN'
        )
    ),
    event_type TEXT NOT NULL,
    duration_ns INTEGER CHECK (duration_ns IS NULL OR duration_ns >= 0),
    numeric_value REAL,
    unit TEXT,
    details_json TEXT,
    raw_artifact_id TEXT REFERENCES artifacts(id)
);

CREATE TABLE stall_windows (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    start_host_ns INTEGER NOT NULL,
    end_host_ns INTEGER NOT NULL,
    duration_ns INTEGER NOT NULL CHECK (duration_ns >= 0),
    frame_count INTEGER,
    jank_frame_count INTEGER,
    severe_frame_count INTEGER,
    peak_frame_interval_ns INTEGER,
    nearest_marker_id INTEGER REFERENCES markers(id),
    detected_by TEXT NOT NULL,
    classification TEXT NOT NULL CHECK (
        classification IN ('JANK_BURST','SEVERE_STALL','SUSTAINED_LOW_FPS','TRANSITION_STALL','UNKNOWN')
    ),
    causal_status TEXT NOT NULL CHECK (causal_status IN ('UNATTRIBUTED','CANDIDATE_CAUSE','ATTRIBUTED','DISPUTED')),
    notes TEXT,
    CHECK (end_host_ns >= start_host_ns)
);

CREATE TABLE hypotheses (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    boundary TEXT NOT NULL,
    statement TEXT NOT NULL,
    predicted_signature TEXT NOT NULL,
    falsification_condition TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('QUEUED','TESTING','SUPPORTED','REJECTED','DEFERRED')),
    confidence REAL NOT NULL DEFAULT 0.0 CHECK (confidence >= 0.0 AND confidence <= 1.0),
    nominated_from_session_id TEXT REFERENCES sessions(id),
    created_at TEXT NOT NULL,
    notes TEXT
);

CREATE TABLE experiments (
    id TEXT PRIMARY KEY,
    hypothesis_id TEXT REFERENCES hypotheses(id),
    name TEXT NOT NULL,
    experiment_type TEXT NOT NULL CHECK (experiment_type IN ('CONTROL_CAPTURE','OBSERVATION','INTERVENTION')),
    baseline_config_id TEXT REFERENCES runtime_configs(id),
    candidate_config_id TEXT REFERENCES runtime_configs(id),
    run_class TEXT NOT NULL CHECK (run_class IN ('COLD','WARM','TRANSITION','HEAVY','MIXED')),
    one_factor INTEGER NOT NULL CHECK (one_factor IN (0,1)),
    state TEXT NOT NULL CHECK (state IN ('PLANNED','RUNNING','COMPLETE','INVALID','CANCELLED')),
    required_cold_confirmation INTEGER NOT NULL DEFAULT 0 CHECK (required_cold_confirmation IN (0,1)),
    semantic_gate TEXT NOT NULL,
    created_at TEXT NOT NULL,
    completed_at TEXT,
    notes TEXT
);

CREATE TABLE experiment_sessions (
    experiment_id TEXT NOT NULL REFERENCES experiments(id) ON DELETE CASCADE,
    session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('BASELINE','CANDIDATE','CONFIRMATION','DIAGNOSTIC')),
    PRIMARY KEY (experiment_id, session_id)
);

CREATE TABLE interventions (
    id TEXT PRIMARY KEY,
    experiment_id TEXT NOT NULL REFERENCES experiments(id) ON DELETE CASCADE,
    boundary TEXT NOT NULL,
    parameter_name TEXT NOT NULL,
    before_value TEXT,
    after_value TEXT NOT NULL,
    reversible INTEGER NOT NULL CHECK (reversible IN (0,1)),
    rollback_action TEXT NOT NULL,
    applied_config_path TEXT,
    notes TEXT
);

CREATE TABLE metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT REFERENCES sessions(id) ON DELETE CASCADE,
    experiment_id TEXT REFERENCES experiments(id) ON DELETE CASCADE,
    metric_scope TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    unit TEXT NOT NULL,
    source_artifact_id TEXT REFERENCES artifacts(id),
    semantic_valid INTEGER NOT NULL DEFAULT 1 CHECK (semantic_valid IN (0,1)),
    notes TEXT,
    CHECK (session_id IS NOT NULL OR experiment_id IS NOT NULL)
);

CREATE TABLE comparisons (
    id TEXT PRIMARY KEY,
    experiment_id TEXT NOT NULL REFERENCES experiments(id) ON DELETE CASCADE,
    metric_name TEXT NOT NULL,
    baseline_value REAL NOT NULL,
    candidate_value REAL NOT NULL,
    unit TEXT NOT NULL,
    delta_absolute REAL NOT NULL,
    delta_percent REAL,
    preferred_direction TEXT NOT NULL CHECK (preferred_direction IN ('HIGHER','LOWER','TARGET','NONE')),
    threshold_value REAL,
    threshold_pass INTEGER CHECK (threshold_pass IN (0,1) OR threshold_pass IS NULL),
    notes TEXT
);

CREATE TABLE evidence (
    id TEXT PRIMARY KEY,
    hypothesis_id TEXT REFERENCES hypotheses(id),
    session_id TEXT REFERENCES sessions(id),
    experiment_id TEXT REFERENCES experiments(id),
    evidence_type TEXT NOT NULL CHECK (
        evidence_type IN ('DIRECT_MEASUREMENT','TRACE_CORRELATION','CONFIG_OBSERVATION','NEGATIVE_RESULT','REPRODUCTION','FALSIFICATION')
    ),
    claim TEXT NOT NULL,
    relation TEXT NOT NULL CHECK (relation IN ('SUPPORTS','REFUTES','NEUTRAL')),
    strength TEXT NOT NULL CHECK (strength IN ('WEAK','MODERATE','STRONG','DECISIVE')),
    source_artifact_id TEXT REFERENCES artifacts(id),
    created_at TEXT NOT NULL,
    notes TEXT,
    CHECK (session_id IS NOT NULL OR experiment_id IS NOT NULL)
);

CREATE TABLE decisions (
    id TEXT PRIMARY KEY,
    experiment_id TEXT NOT NULL REFERENCES experiments(id),
    decision TEXT NOT NULL CHECK (decision IN ('KEEP','REJECT','INCONCLUSIVE','DIAGNOSTIC_ONLY')),
    rationale TEXT NOT NULL,
    cold_confirmation_complete INTEGER NOT NULL DEFAULT 0 CHECK (cold_confirmation_complete IN (0,1)),
    promoted_config_id TEXT REFERENCES runtime_configs(id),
    decided_at TEXT NOT NULL,
    notes TEXT
);

CREATE TABLE performance_facts (
    id TEXT PRIMARY KEY,
    domain TEXT NOT NULL,
    fact_key TEXT NOT NULL,
    fact_value TEXT NOT NULL,
    unit TEXT,
    source_evidence_id TEXT NOT NULL REFERENCES evidence(id),
    status TEXT NOT NULL CHECK (status IN ('PROMOTED','RETIRED')),
    promoted_at TEXT NOT NULL,
    retired_at TEXT,
    notes TEXT,
    UNIQUE(domain, fact_key, status)
);

CREATE TABLE unknowns (
    id TEXT PRIMARY KEY,
    question TEXT NOT NULL,
    boundary TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('OPEN','RESOLVED','DEFERRED')),
    blocking INTEGER NOT NULL DEFAULT 0 CHECK (blocking IN (0,1)),
    resolution_evidence_id TEXT REFERENCES evidence(id),
    opened_at TEXT NOT NULL,
    resolved_at TEXT,
    notes TEXT
);

CREATE VIEW v_promoted_facts AS
SELECT 'HOST' AS fact_scope,
       hf.id,
       hf.fact_key,
       hf.fact_value,
       hf.unit,
       hf.source_ref,
       hf.observed_at AS promoted_or_observed_at
FROM host_facts hf
WHERE hf.status='FROZEN'
UNION ALL
SELECT pf.domain AS fact_scope,
       pf.id,
       pf.fact_key,
       pf.fact_value,
       pf.unit,
       pf.source_evidence_id AS source_ref,
       pf.promoted_at AS promoted_or_observed_at
FROM performance_facts pf
WHERE pf.status='PROMOTED';

CREATE VIEW v_stall_summary AS
SELECT s.id AS session_id,
       s.boot_class,
       s.workload_class,
       COUNT(sw.id) AS stall_window_count,
       SUM(CASE WHEN sw.classification='SEVERE_STALL' THEN 1 ELSE 0 END) AS severe_stall_windows,
       MAX(sw.peak_frame_interval_ns) AS max_frame_interval_ns,
       SUM(COALESCE(sw.jank_frame_count,0)) AS jank_frames,
       SUM(COALESCE(sw.severe_frame_count,0)) AS severe_frames
FROM sessions s
LEFT JOIN stall_windows sw ON sw.session_id=s.id
GROUP BY s.id,s.boot_class,s.workload_class;

CREATE VIEW v_experiment_scorecard AS
SELECT e.id AS experiment_id,
       e.name,
       e.experiment_type,
       e.run_class,
       e.state,
       h.id AS hypothesis_id,
       h.title AS hypothesis,
       d.decision,
       d.cold_confirmation_complete,
       COUNT(DISTINCT es.session_id) AS session_count,
       COUNT(DISTINCT c.id) AS compared_metric_count
FROM experiments e
LEFT JOIN hypotheses h ON h.id=e.hypothesis_id
LEFT JOIN decisions d ON d.experiment_id=e.id
LEFT JOIN experiment_sessions es ON es.experiment_id=e.id
LEFT JOIN comparisons c ON c.experiment_id=e.id
GROUP BY e.id,e.name,e.experiment_type,e.run_class,e.state,h.id,h.title,d.decision,d.cold_confirmation_complete;

CREATE VIEW v_open_hypotheses AS
SELECT h.id,
       h.title,
       h.boundary,
       h.statement,
       h.predicted_signature,
       h.falsification_condition,
       h.status,
       h.confidence,
       COUNT(DISTINCT ev.id) AS evidence_count,
       COUNT(DISTINCT ex.id) AS experiment_count
FROM hypotheses h
LEFT JOIN evidence ev ON ev.hypothesis_id=h.id
LEFT JOIN experiments ex ON ex.hypothesis_id=h.id
WHERE h.status IN ('QUEUED','TESTING','SUPPORTED')
GROUP BY h.id,h.title,h.boundary,h.statement,h.predicted_signature,h.falsification_condition,h.status,h.confidence
ORDER BY h.status='TESTING' DESC,h.confidence DESC,h.id;

CREATE VIEW v_session_quality AS
SELECT s.id AS session_id,
       s.capture_state,
       s.semantic_valid,
       s.boot_class,
       s.workload_class,
       (SELECT COUNT(*) FROM artifacts a WHERE a.session_id=s.id AND a.required=1) AS required_artifact_count,
       (SELECT COUNT(*) FROM artifacts a WHERE a.session_id=s.id AND a.required=1 AND a.state='PRESENT') AS required_artifacts_present,
       (SELECT COUNT(*) FROM artifacts a WHERE a.session_id=s.id AND a.required=1 AND a.state<>'PRESENT') AS required_artifacts_missing_or_bad,
       (SELECT COUNT(*) FROM frame_samples fs WHERE fs.session_id=s.id) AS frame_sample_count,
       (SELECT COUNT(*) FROM clock_sync cs WHERE cs.session_id=s.id) AS clock_sync_count
FROM sessions s;

INSERT INTO lab_meta(key,value) VALUES
('schema_version','1'),
('created_at','2026-08-28T07:50:00Z'),
('project','TFTMAC'),
('database_role','CURRENT_PERFORMANCE_EVIDENCE_ONLY'),
('donor_contamination_policy','Donor claims and historical benchmarks never enter this database as current facts. Current TFTMAC measurement is required.'),
('capture_policy','Record high-rate telemetry to append-only raw artifacts first; normalize into SQLite after or asynchronously from capture.'),
('promotion_policy','Hypothesis status is not fact promotion. performance_facts requires explicit current evidence.'),
('experiment_policy','One causal factor per intervention where separable; automatic rollback; cold confirmation required before performance baseline promotion.'),
('control_policy','No tweak experiments execute until the direct-play control has produced valid current evidence.'),
('jank_threshold_ns','33334000'),
('severe_stall_threshold_ns','100000000'),
('optimization_target_avg_fps','58.0'),
('optimization_target_p95_ms','20.0'),
('optimization_target_p99_ms','33.334'),
('optimization_target_jank_pct','1.0'),
('optimization_target_severe_stalls_per_600s','3');

INSERT INTO host_facts VALUES
('host_model','hardware_model','Mac16,10',NULL,'PROJECT_LOCK','ssot/STACK.lock.yaml','FROZEN','2026-08-28T04:32:04Z','Target control host.'),
('host_chip','chip','Apple M4',NULL,'DIRECT_OBSERVATION','ssot/host-preflight.json','FROZEN','2026-08-28T04:07:47Z','Apple Silicon target.'),
('host_memory','physical_memory','16','GiB','DIRECT_OBSERVATION','ssot/host-preflight.json','FROZEN','2026-08-28T04:07:47Z','Unified-memory host; memory pressure must be measured.'),
('host_arch','architecture','arm64',NULL,'PROJECT_LOCK','ssot/STACK.lock.yaml','FROZEN','2026-08-28T04:32:04Z',NULL),
('host_macos','macos_version','26.6.2',NULL,'PROJECT_LOCK','ssot/STACK.lock.yaml','FROZEN','2026-08-28T04:32:04Z',NULL),
('host_macos_build','macos_build','25G83',NULL,'PROJECT_LOCK','ssot/STACK.lock.yaml','FROZEN','2026-08-28T04:32:04Z',NULL),
('control_emulator','control_emulator_version','37.1.11',NULL,'PROJECT_LOCK','ssot/STACK.lock.yaml','FROZEN','2026-08-28T04:32:04Z','Released Google emulator control.'),
('control_platform_tools','control_platform_tools_version','37.0.1',NULL,'PROJECT_LOCK','ssot/STACK.lock.yaml','FROZEN','2026-08-28T04:32:04Z',NULL),
('control_image','control_system_image','system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a',NULL,'PROJECT_LOCK','ssot/STACK.lock.yaml','FROZEN','2026-08-28T04:32:04Z','Official Play-enabled ARM64 image.'),
('control_image_revision','control_system_image_revision','6',NULL,'PROJECT_LOCK','ssot/STACK.lock.yaml','FROZEN','2026-08-28T04:32:04Z',NULL),
('control_package','tft_package','com.riotgames.league.teamfighttactics',NULL,'USER_REQUIREMENT','ssot/TFTMAC_DIRECT_PLAY_CONTROL_BUILD.md','FROZEN','2026-08-28T07:50:00Z','Official Google Play/Riot package authority only.');

INSERT INTO runtime_configs (
    id,name,emulator_version,platform_tools_version,system_image_package,system_image_revision,
    avd_name,adb_serial,adb_server_port,emulator_console_port,vcpu,ram_mb,
    display_width,display_height,density_dpi,refresh_hz,gpu_mode,audio_enabled,
    presentation_mode,state,created_at,notes
) VALUES (
    'control_stock_direct_v0',
    'Stock Google direct-play control v0',
    '37.1.11','37.0.1','system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a',6,
    'TFTMAC_Live_API37','emulator-5592',5040,5592,6,6144,
    1920,1080,320,60.0,'host',1,
    'direct_native_emulator','CONTROL','2026-08-28T07:50:00Z',
    'config_sha256 and observed graphics selections are intentionally NULL until the implementation captures exact runtime state.'
);

INSERT INTO hypotheses VALUES
('h_pso_compile','PSO/shader compilation causes visible stalls','PSO_SHADER','Bursts of Unreal/ANGLE shader or PSO compilation correlate tightly with severe frame-time windows.','Compile/cache events or compiler-process CPU spikes begin immediately before or during stalls and diminish on warm repetition.','Equivalent stalls reproduce without compile/cache activity, or eliminating/warming the compile path does not reduce matched stall windows.','QUEUED',0.0,NULL,'2026-08-28T07:50:00Z','Current measurement required.'),
('h_rhi_serialization','Unreal RHI/command serialization is the throughput limiter','UNREAL_RHI','Heavy scenes serialize enough render/RHI work that downstream graphics layers starve or wait even when host GPU headroom exists.','Heavy frame windows show dominant game/RHI thread time, serialized submission, and host decoder/Metal idle gaps.','Host GPU/Metal is saturated while RHI remains non-dominant, or intervention at RHI serialization does not change matched heavy windows.','QUEUED',0.0,NULL,'2026-08-28T07:50:00Z',NULL),
('h_asg_backpressure','gfxstream/ASG backpressure contributes to frame collapse','GFXSTREAM_ASG','Guest-host transport packing, ring wait, kick/MMIO, or downstream backpressure expands during stall windows.','ASG-related waits/events rise before frame-time spikes and fall under a causal transport intervention.','Stalls occur with stable transport timing or matched transport changes do not alter the frame-time distribution.','QUEUED',0.0,NULL,'2026-08-28T07:50:00Z',NULL),
('h_mvk_queue_wait','MoltenVK queue or command-buffer waits contribute to stalls','MOLTENVK','Vulkan-to-Metal queue synchronization or command-buffer pressure creates long downstream waits.','MoltenVK/Metal timing events cluster with stalls while upstream work is available.','Matched stalls occur without MoltenVK/Metal wait expansion or queue interventions fail controlled confirmation.','QUEUED',0.0,NULL,'2026-08-28T07:50:00Z',NULL),
('h_texture_astc_stream','Texture streaming or ASTC decompression causes transition/combat stalls','TEXTURE_ASTC','New content/effects trigger texture streaming, ASTC decode, upload, or residency work that blocks timely frames.','Stalls align with new texture/decompression/upload events and are reduced on warm repeats or targeted cache/residency changes.','Cold/warm traces show the same stalls without texture/decompression activity or targeted changes have no effect.','QUEUED',0.0,NULL,'2026-08-28T07:50:00Z',NULL),
('h_memory_pressure','Unified-memory pressure causes severe frame drops','MEMORY','The 16 GiB host crosses compression/swap or pressure thresholds during heavy transitions, delaying emulator and graphics work.','Host compressed/swap/pressure metrics rise immediately before or during stalls and a lower-pressure configuration improves matched windows.','Severe stalls reproduce under low stable memory pressure or memory reductions do not affect matched stalls.','QUEUED',0.0,NULL,'2026-08-28T07:50:00Z',NULL),
('h_present_pacing','Presentation/frame pacing creates apparent FPS collapse','SURFACEFLINGER','Rendering work completes but presentation cadence, SurfaceFlinger, swapchain, or host-window pacing introduces long visible intervals.','Producer work remains timely while presentation timestamps develop gaps or cadence aliasing.','Producer/RHI/GPU timing itself is late by the same amount or presentation changes do not alter matched gaps.','QUEUED',0.0,NULL,'2026-08-28T07:50:00Z',NULL),
('h_guest_scheduler','Guest scheduling/affinity starves critical Unreal or compiler work','GUEST_SCHEDULER','Android scheduling, affinity, or priority leaves critical game/compiler workers unable to run promptly during bursts.','Critical threads are runnable but delayed/preempted or constrained to overloaded CPUs around stalls.','Critical threads receive timely CPU service and scheduling interventions do not improve matched stalls.','QUEUED',0.0,NULL,'2026-08-28T07:50:00Z',NULL),
('h_unreal_device_profile','Unreal selects a poor virtual-device profile','DEVICE_PROFILE','The official TFT build classifies the emulator GPU/device into a profile that imposes inappropriate quality, threading, cache, or renderer settings for Apple M4 execution.','Observed Unreal/device-profile state is generic/low/incorrect and a minimal reversible profile correction changes the intended engine behavior plus measured frame results.','The selected profile is already appropriate or profile correction changes no causal engine behavior/performance.','QUEUED',0.0,NULL,'2026-08-28T07:50:00Z',NULL);

INSERT INTO experiments VALUES
('exp_control_direct_play',NULL,'First current official direct-play control','CONTROL_CAPTURE','control_stock_direct_v0',NULL,'COLD',0,'PLANNED',0,'Official package observed; match entry valid; logger complete enough for current control metrics.','2026-08-28T07:50:00Z',NULL,NULL),
('exp_control_repeat_warm',NULL,'Warm repeat of direct-play control','CONTROL_CAPTURE','control_stock_direct_v0',NULL,'WARM',0,'PLANNED',0,'Same runtime/package/config as cold control; semantic workload comparable.','2026-08-28T07:50:00Z',NULL,NULL),
('exp_transition_capture',NULL,'Loading and transition stall capture','OBSERVATION','control_stock_direct_v0',NULL,'TRANSITION',0,'PLANNED',0,'Timestamped transition with valid frame timing, clocks, process/memory samples, and renderer state.','2026-08-28T07:50:00Z',NULL,NULL),
('exp_heavy_capture',NULL,'Combat-heavy control capture','OBSERVATION','control_stock_direct_v0',NULL,'HEAVY',0,'PLANNED',0,'Combat-heavy window is semantically valid and not compared to lobby/login data.','2026-08-28T07:50:00Z',NULL,NULL);

INSERT INTO unknowns VALUES
('u_current_tft_version','What exact versionName/versionCode/signing digest does Google Play install at the first direct-play control?','PACKAGE','OPEN',0,NULL,'2026-08-28T07:50:00Z',NULL,'Resolve from PackageStateManager after official install/update.'),
('u_observed_renderer_path','What graphics path does the current official TFT build actually select under the direct-play control?','GRAPHICS','OPEN',0,NULL,'2026-08-28T07:50:00Z',NULL,'Resolve from renderer-state capture; do not infer from intended flags.'),
('u_drop_reproduction','Does the severe light-state-to-single-digit-FPS collapse reproduce under the clean official-package control?','PERFORMANCE','OPEN',0,NULL,'2026-08-28T07:50:00Z',NULL,'Prior user observation is diagnostic only until reproduced here.'),
('u_storage_bom','What is the exact shipping/control storage bill of materials after TFT is fully patched?','STORAGE','OPEN',0,NULL,'2026-08-28T07:50:00Z',NULL,'Initial ceiling is 35 GiB; measure actual bytes.'),
('u_one_guest_controls','Can one official Play AVD provide every runtime control needed for compatibility and measurement?','RUNTIME','OPEN',0,NULL,'2026-08-28T07:50:00Z',NULL,'Only activate authority/execution split if current evidence says no.');

COMMIT;

-- Recommended first queries after ingestion:
-- SELECT * FROM v_session_quality;
-- SELECT * FROM v_stall_summary ORDER BY max_frame_interval_ns DESC;
-- SELECT * FROM v_open_hypotheses;
-- SELECT * FROM v_experiment_scorecard;
-- SELECT * FROM v_promoted_facts;
