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
        marker_type IN ('USER_STUTTER','AUTO_JANK','AUTO_SEVERE_STALL','MATCH_ENTRY','MATCH_RESULT','COMBAT_START','TRANSITION','PACKAGE_UPDATE','GAME_SETTINGS','USER_QUALITY_REPORT','CUSTOM')
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
('control_image','control_system_image','system-images;android-37.1;google_apis_playstore_ps16k;arm64-v8a',NULL,'PROJECT_LOCK','ssot/STACK.lock.yaml','FROZEN','2026-08-28T08:46:32Z','Current official Play-enabled ARM64 image selected after 37.0 rev 6 reproduced a Google GMS MinuteMaid account-flow crash.'),
('control_image_revision','control_system_image_revision','9',NULL,'PROJECT_LOCK','ssot/STACK.lock.yaml','FROZEN','2026-08-28T08:46:32Z','Google SDK catalog current stable android-37.1 Play ps16k ARM64 revision.'),
('control_package','tft_package','com.riotgames.league.teamfighttactics',NULL,'USER_REQUIREMENT','ssot/TFTMAC_DIRECT_PLAY_CONTROL_BUILD.md','FROZEN','2026-08-28T07:50:00Z','Official Google Play/Riot package authority only.');

INSERT INTO runtime_configs (
    id,name,emulator_version,platform_tools_version,system_image_package,system_image_revision,
    avd_name,adb_serial,adb_server_port,emulator_console_port,vcpu,ram_mb,
    display_width,display_height,density_dpi,refresh_hz,gpu_mode,audio_enabled,
    presentation_mode,state,created_at,notes
) VALUES (
    'control_stock_direct_v0',
    'Stock Google direct-play control v0',
    '37.1.11','37.0.1','system-images;android-37.1;google_apis_playstore_ps16k;arm64-v8a',9,
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

-- ---------------------------------------------------------------------------
-- Current playable baseline authority: 2026-08-28 first-place match
-- ---------------------------------------------------------------------------
-- Later rows intentionally supersede stale API37/source-AEMU assumptions while
-- preserving those older rows as historical context elsewhere in the project.

INSERT OR REPLACE INTO lab_meta(key,value) VALUES
('current_playable_baseline','mactician_compatible_official_v0'),
('current_playable_baseline_session','2026-08-28T11-06-18-553Z-e6d3204f-17c2-4b80-9084-e76642089da2'),
('current_guest','Android 16 / API 36 Google Play ARM64 revision >=7'),
('current_emulator','Google Android Emulator 37.1.11'),
('current_tft','18.1-5392842 / versionCode 8392842 / installer com.android.vending'),
('current_renderer_path','TFT Unreal GameActivity -> ANGLE -> Vulkan/ranchu -> virtio-gpu-asg/gfxstream -> MoltenVK -> Metal'),
('current_measurement_gap','gfxinfo does not expose native Unreal/Vulkan gameplay frames; native frame timing is blocking before graphics tuning'),
('current_trace_sources','Perfetto proven available: android.surfaceflinger.frame, android.surfaceflinger.frametimeline, android.surfaceflinger.layers, android.gpu.memory, linux.ftrace, linux.process_stats, linux.sys_stats'),
('current_trace_collector_smoke','5s smoke succeeded: 7479-byte raw pftrace, SHA-256 214dddf456fa94f0ba634dc564f391d576a27bfc6b58610b6e91314376bd9028, four lightweight SurfaceFlinger/GPU-memory sources, zero missed-frame counter delta during idle smoke'),
('logger_guard_policy','Sampler starts before emulator; sampler must survive startup; launch-game requires a live growth health check; MATCH_ENTRY and COMBAT_START require fresh process, memory and logcat streams; status reports LOGGER_FAULT when the gate is not ready.'),
('multi_match_policy','Keep raw telemetry continuous across games. Pair each MATCH_ENTRY with the next MATCH_RESULT; preserve per-match analysis artifacts; ingest match 2+ as distinct <capture-session>-match-N SQL sessions so later games never overwrite earlier evidence.'),
('current_tft_graphics_domain','Low | Medium | High | Ultra High'),
('current_tft_fps_cap_domain','30 | 60 | None'),
('current_tft_graphics_observed','Medium'),
('current_tft_fps_cap_observed','60'),
('current_tft_performance_mode_beta_observed','UNKNOWN'),
('current_optimization_priority','Continuous-run analysis is authoritative. Keep the logger running and analyze the whole capture; treat matches, placements, graphics preset, FPS cap, Performance Mode, app restarts, ANRs and user quality reports as timestamped annotations. Change one variable at a time, but do not require per-match start/stop boundaries.');

INSERT OR REPLACE INTO host_facts VALUES
('control_image','control_system_image','system-images;android-36;google_apis_playstore;arm64-v8a',NULL,'DIRECT_OBSERVATION','gameplay-analysis.json','FROZEN','2026-08-28T18:30:59Z','First full official TFT match completed on this real Google Play image family.'),
('control_image_revision','control_system_image_revision','>=7',NULL,'DIRECT_OBSERVATION','runtime inventory + source.properties','FROZEN','2026-08-28T18:30:59Z','Installed API36 Play ARM64 image satisfies revision-7 minimum used by current control.'),
('control_avd','control_avd_name','TFT_Ultra_Tablet',NULL,'DIRECT_OBSERVATION','runtime-state.json','FROZEN','2026-08-28T18:30:59Z','Single official Play AVD used for package authority and gameplay execution.');

INSERT OR REPLACE INTO runtime_configs (
    id,parent_config_id,name,emulator_version,platform_tools_version,system_image_package,system_image_revision,
    avd_name,adb_serial,adb_server_port,emulator_console_port,vcpu,ram_mb,
    display_width,display_height,density_dpi,refresh_hz,gpu_mode,audio_enabled,
    graphics_transport,angle_mode,vulkan_mode,moltenvk_mode,presentation_mode,state,created_at,notes
) VALUES
('mactician_compatible_official_v0',NULL,'Mactician-compatible official TFT control v0','37.1.11','37.0.1','system-images;android-36;google_apis_playstore;arm64-v8a',7,'TFT_Ultra_Tablet','emulator-5592',5040,5592,6,6144,1920,1080,320,60.0,'host',1,'virtio-gpu-asg','GuestAngle + explicit exposeNonConformantExtensionsAndVersions/exposeES32ForTesting compatibility adapter','ranchu guest Vulkan','gfxstream host Vulkan -> MoltenVK/Metal','direct emulator window','CONTROL','2026-08-28T11:06:18Z','Completed a full first-place official TFT match. Compatibility exposure is a truthful workload adapter, not GLES conformance proof.'),
('mactician_compatible_5gb_v1','mactician_compatible_official_v0','RAM 5 GiB candidate','37.1.11','37.0.1','system-images;android-36;google_apis_playstore;arm64-v8a',7,'TFT_Ultra_Tablet','emulator-5592',5040,5592,6,5120,1920,1080,320,60.0,'host',1,'virtio-gpu-asg','same as baseline','same as baseline','same as baseline','same as baseline','CANDIDATE','2026-08-28T21:31:30Z','One-factor candidate: only guest RAM changes 6144 -> 5120 MB. Direct 4096 MB cut deferred because Game 2 minimum guest available memory (~2.24 GiB at 6144 MB) leaves too little safety margin.');

UPDATE hypotheses
SET status='TESTING', confidence=0.60,
    nominated_from_session_id=NULL,
    notes='First full match: emulator RSS mean about 5155 MiB, max about 6846 MiB; host compressed memory mean about 4.15 GiB; pageouts +12876. Candidate cause only until controlled A/B.'
WHERE id='h_memory_pressure';

INSERT OR REPLACE INTO hypotheses VALUES
('h_guest_ram_host_pressure','Guest RAM allocation amplifies host memory pressure','MEMORY','The 6144 MB Android guest contributes enough host RSS/compression/pageout pressure to worsen gameplay responsiveness on the 16 GiB M4 host.','A 5120 MB one-factor run lowers emulator RSS/host compression while preserving at least about 1 GiB guest headroom under comparable load and without guest OOM or instability.','5120 MB does not reduce pressure, materially degrades guest headroom, or worsens comparable gameplay.','QUEUED',0.72,NULL,'2026-08-28T21:31:30Z','Game 2 and restart-effect analysis strengthen memory pressure as the current intervention target; 5 GiB is the safer first cut.'),
('h_gpu_frame_miss','GPU-side presentation misses contribute to visible lag','SURFACEFLINGER','A meaningful portion of visible gameplay lag is caused by GPU/presentation misses somewhere in the Unreal -> ANGLE -> Vulkan -> gfxstream -> MoltenVK -> Metal path.','TFT-specific SurfaceFlinger frametimeline traces show GPU-missed or late frames correlated with visible stalls while memory state is controlled.','TFT-specific frametimeline remains healthy during visible stalls, or misses disappear without improving perceived performance.','QUEUED',0.35,NULL,'2026-08-28T18:42:01Z','Nominated from cumulative SurfaceFlinger counters only: 2709 total missed, 2163 GPU missed, 546 HWC missed at the latest post-match read. These counters are since boot and are not match-scoped.');

INSERT OR REPLACE INTO experiments VALUES
('exp_ram_5gb_ab','h_guest_ram_host_pressure','Guest RAM 6144 -> 5120 MB A/B','INTERVENTION','mactician_compatible_official_v0','mactician_compatible_5gb_v1','HEAVY',1,'PLANNED',1,'Same official TFT version, renderer path, display, transport and vCPU; compare continuous-run pressure and native frame timing when available.','2026-08-28T21:31:30Z',NULL,'First RAM intervention. One GiB reduction only; 4096 MB is deferred because current guest headroom is insufficient for a safe first cut.'),
('exp_native_frame_trace',NULL,'Native Unreal/Vulkan frame-timing capture','OBSERVATION','mactician_compatible_official_v0',NULL,'HEAVY',0,'PLANNED',0,'Capture android.surfaceflinger.frame + android.surfaceflinger.frametimeline + android.surfaceflinger.layers + android.gpu.memory during real TFT combat; align to the existing host monotonic clock. Add linux.ftrace only in the heavier validation run.','2026-08-28T18:30:59Z',NULL,'Blocking measurement experiment before renderer/transport tuning. All required Perfetto data sources are directly proven available on the current guest.');

UPDATE experiments
SET baseline_config_id='mactician_compatible_official_v0',
    state='COMPLETE',
    notes=COALESCE(notes,'') || ' Superseded runtime identity corrected to the proven playable baseline.'
WHERE id='exp_control_direct_play';

UPDATE experiments
SET state='CANCELLED',
    notes=COALESCE(notes,'') || ' Superseded by mactician_compatible_official_v0 and exp_native_frame_trace.'
WHERE id IN ('exp_control_repeat_warm','exp_transition_capture','exp_heavy_capture')
  AND baseline_config_id='control_stock_direct_v0';

INSERT OR REPLACE INTO unknowns VALUES
('u_native_frame_timing','What is the real Unreal/Vulkan frame-time distribution and which boundary owns visible stalls?','FRAME_TIMING','OPEN',1,NULL,'2026-08-28T18:30:59Z',NULL,'gfxinfo returned zero gameplay frames. Exact available replacement sources: android.surfaceflinger.frame + frametimeline + layers + android.gpu.memory; linux.ftrace/process_stats/sys_stats are available for heavier correlation.'),
('u_drop_reproduction','Does the severe low-performance/laggy behavior reproduce under the clean official-package control?','PERFORMANCE','OPEN',0,NULL,'2026-08-28T07:50:00Z',NULL,'User reported the first full match as laggy/low-performance; resource pressure reproduced, but native frame timing is still missing for quantitative attribution.');

INSERT OR REPLACE INTO experiments VALUES
('exp_tft_performance_mode_ab',NULL,'TFT Performance Mode (Beta) A/B','INTERVENTION','mactician_compatible_official_v0',NULL,'HEAVY',1,'PLANNED',0,'Keep Medium graphics, 60 FPS cap, emulator/runtime/package identical; change only Performance Mode (Beta) ON/OFF and compare native frame timing + memory/GPU pressure.','2026-08-28T20:11:18Z',NULL,'First game-level intervention after the fully labeled Medium/60 baseline.'),
('exp_tft_fps_cap_ab',NULL,'TFT FPS cap A/B','INTERVENTION','mactician_compatible_official_v0',NULL,'HEAVY',1,'PLANNED',0,'Hold graphics preset and Performance Mode constant; compare 60 versus None first, with 30 retained as a diagnostic lower-load control if needed.','2026-08-28T20:11:18Z',NULL,'Do not combine FPS-cap changes with graphics-preset changes.'),
('exp_tft_graphics_preset_ab',NULL,'TFT graphics preset A/B','INTERVENTION','mactician_compatible_official_v0',NULL,'HEAVY',1,'PLANNED',0,'Hold FPS cap and Performance Mode constant; test Low, Medium, High, Ultra High one preset at a time with native frame timing.','2026-08-28T20:11:18Z',NULL,'Target is the highest preset that preserves stable 60-Hz frame pacing and acceptable memory/GPU pressure.');

INSERT OR REPLACE INTO lab_meta(key,value) VALUES
('latest_observed_match_2','placement=1; result=WIN; exact result at 2026-08-28T20:57:14.054Z'),
('latest_observed_match_2_settings','graphics=Medium; fps_cap=60; performance_mode_beta=OFF'),
('latest_observed_match_2_quality','User reported gameplay much better and graphics visibly improved versus Game 1.'),
('latest_observed_match_2_boundary','PARTIAL: exact MATCH_ENTRY missing; resource comparison uses TFT_APP_RESTART_COMPLETE at 2026-08-28T20:17:03.528Z as a non-authoritative start proxy.'),
('latest_observed_match_2_directional_memory','Approximate window vs Game1: host compressed mean -0.783 GiB, host available mean +0.443 GiB, pageout delta difference -2236; emulator CPU/RSS were higher despite better perceived quality.'),
('restart_effect_equal_windows','10/20/30 minute equal pre/post TFT app-restart analysis: host available mean improved by ~0.90-0.94 GiB and host compressed mean fell by ~1.83-1.99 GiB after restart, despite substantially higher emulator CPU/RSS. This supports app-only refresh as a low-risk pressure-relief intervention.'),
('preplay_memory_hygiene_policy','Before a new play run, if host compressed memory >=4.5 GiB or host available <=4.25 GiB, refresh only the TFT app process while preserving emulator and logger. Live application at 2026-08-28T21:32:39Z changed compressed 4.97 -> 2.48 GiB and available 4.23 -> 5.59 GiB.'),
('ram_candidate_revision','First RAM candidate revised from 4096 MB to 5120 MB. Game 2 guest available minimum ~2.24 GiB at 6144 MB means a 2 GiB cut risks low-memory instability; 1 GiB is the safer reversible step.'),
('ram_5gb_candidate_live','5120 MB candidate cold-booted successfully on the same API36 Play/ANGLE/Vulkan/gfxstream/MoltenVK path. TFT GameActivity is running with logger healthy; initial post-launch pressure sample: host compressed 1.48 GiB, host available 5.97 GiB, guest available 2.40 GiB. This is promising but not causal proof until sustained gameplay is captured.'),
('cold_boot_unlock_fix','Cold boot can leave Android user 0 RUNNING_LOCKED even after sys.boot_completed=1, hiding launcher activities. TFTMAC now wakes/dismisses keyguard and verifies RUNNING_UNLOCKED before package launch; this resolved the observed launch failure without changing the RAM candidate.');

COMMIT;

-- Recommended first queries after ingestion:
-- SELECT * FROM v_session_quality;
-- SELECT * FROM v_stall_summary ORDER BY max_frame_interval_ns DESC;
-- SELECT * FROM v_open_hypotheses;
-- SELECT * FROM v_experiment_scorecard;
-- SELECT * FROM v_promoted_facts;
