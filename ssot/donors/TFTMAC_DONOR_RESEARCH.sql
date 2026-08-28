-- TFTMAC Donor Research Database
--
-- QUARANTINE CONTRACT
-- ===================
-- This file is deliberately separate from ssot/TFTMAC_ENGINEERING_MAP.sql.
-- Nothing in this database is TFTMAC production authority merely because it
-- appears here. Donor facts, public claims, historical measurements, inferred
-- relationships, and black-box observations are isolated so they cannot poison
-- the production SSOT.
--
-- Promotion rule:
--   A donor finding may be copied into TFTMAC_ENGINEERING_MAP.sql only after an
--   explicit TFTMAC reproduction/probe produces direct current evidence on the
--   current host/workload or after the governing SSOT is deliberately revised.
--
-- Reverse-engineering boundary:
--   Open-source code may be inspected, compared, built, forked, and adapted
--   within its license. Proprietary applications such as OS FIGHT TACTICS are
--   treated as black-box/public-evidence donors only. Do not decompile, bypass
--   licensing, or copy proprietary implementation details.
--
-- SQLite compatible.

PRAGMA foreign_keys = ON;
BEGIN;

CREATE TABLE donor_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE donor_projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    project_type TEXT NOT NULL CHECK (project_type IN ('OPEN_SOURCE','PUBLIC_BLACK_BOX','INTERNAL_DONOR','UPSTREAM_COMPONENT')),
    source_url TEXT,
    website_url TEXT,
    license TEXT,
    source_access TEXT NOT NULL CHECK (source_access IN ('FULL','PARTIAL','NONE','LOCAL_SNAPSHOT')),
    current_research_role TEXT NOT NULL,
    trust_boundary TEXT NOT NULL,
    observed_at TEXT NOT NULL,
    notes TEXT
);

CREATE TABLE donor_snapshots (
    id TEXT PRIMARY KEY,
    donor_id TEXT NOT NULL REFERENCES donor_projects(id),
    snapshot_kind TEXT NOT NULL CHECK (snapshot_kind IN ('REPOSITORY_BRANCH','LOCAL_TREE','PUBLIC_WEBSITE','CASE_STUDY','SOURCE_FILE','RELEASE_BINARY','HISTORICAL_DOC')),
    ref TEXT,
    observed_at TEXT NOT NULL,
    source_url TEXT,
    source_path TEXT,
    content_sha256 TEXT,
    evidence_class TEXT NOT NULL CHECK (evidence_class IN ('SOURCE_VERIFIED','PROJECT_LOCAL','AUTHOR_TECHNICAL_WRITEUP','PUBLIC_CLAIM','HISTORICAL','INFERRED','UNVERIFIED')),
    freshness TEXT NOT NULL CHECK (freshness IN ('CURRENT','CURRENT_BUT_VERSION_VOLATILE','HISTORICAL','UNKNOWN')),
    notes TEXT
);

CREATE TABLE donor_components (
    id TEXT PRIMARY KEY,
    donor_id TEXT NOT NULL REFERENCES donor_projects(id),
    name TEXT NOT NULL,
    component_type TEXT NOT NULL,
    version_or_ref TEXT,
    architecture TEXT,
    host_requirement TEXT,
    guest_requirement TEXT,
    role TEXT NOT NULL,
    evidence_class TEXT NOT NULL,
    source_snapshot_id TEXT REFERENCES donor_snapshots(id),
    notes TEXT
);

CREATE TABLE donor_architecture_edges (
    id TEXT PRIMARY KEY,
    donor_id TEXT NOT NULL REFERENCES donor_projects(id),
    from_component TEXT NOT NULL,
    to_component TEXT NOT NULL,
    interface_type TEXT NOT NULL,
    relationship TEXT NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('SOURCE_VERIFIED','AUTHOR_VERIFIED','PUBLIC_CLAIM','INFERRED','UNKNOWN')),
    evidence_snapshot_id TEXT REFERENCES donor_snapshots(id),
    notes TEXT
);

CREATE TABLE donor_capabilities (
    id TEXT PRIMARY KEY,
    donor_id TEXT NOT NULL REFERENCES donor_projects(id),
    capability TEXT NOT NULL,
    layer TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('PROVEN_BY_SOURCE','PROVEN_BY_MEASUREMENT','AUTHOR_CLAIM','PUBLIC_CLAIM','PARTIAL','FAILED','UNKNOWN')),
    exact_result TEXT NOT NULL,
    workload_scope TEXT,
    evidence_snapshot_id TEXT REFERENCES donor_snapshots(id),
    reproducibility TEXT,
    limitations TEXT
);

CREATE TABLE donor_techniques (
    id TEXT PRIMARY KEY,
    donor_id TEXT NOT NULL REFERENCES donor_projects(id),
    technique TEXT NOT NULL,
    layer TEXT NOT NULL,
    problem_solved TEXT NOT NULL,
    implementation_summary TEXT NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('PROMOTED_BY_DONOR','RETAINED','PROVISIONAL','REJECTED','HISTORICAL','UNKNOWN')),
    source_snapshot_id TEXT REFERENCES donor_snapshots(id),
    tftmac_relevance TEXT NOT NULL,
    contamination_risk TEXT NOT NULL CHECK (contamination_risk IN ('LOW','MEDIUM','HIGH')),
    notes TEXT
);

CREATE TABLE donor_failures (
    id TEXT PRIMARY KEY,
    donor_id TEXT NOT NULL REFERENCES donor_projects(id),
    layer TEXT NOT NULL,
    attempted_path TEXT NOT NULL,
    observed_failure TEXT NOT NULL,
    causal_interpretation TEXT NOT NULL,
    donor_decision TEXT NOT NULL,
    source_snapshot_id TEXT REFERENCES donor_snapshots(id),
    tftmac_rule TEXT NOT NULL
);

CREATE TABLE donor_runtime_profiles (
    id TEXT PRIMARY KEY,
    donor_id TEXT NOT NULL REFERENCES donor_projects(id),
    profile_name TEXT NOT NULL,
    emulator_version TEXT,
    android_version TEXT,
    system_image TEXT,
    cpu_config TEXT,
    memory_config TEXT,
    display_config TEXT,
    gpu_mode TEXT,
    graphics_transport TEXT,
    angle_mode TEXT,
    vulkan_mode TEXT,
    moltenvk_mode TEXT,
    package_authority TEXT,
    status TEXT NOT NULL CHECK (status IN ('WORKING_DONOR','HISTORICAL_WORKING','PUBLIC_CLAIM','CONTROL','EXPERIMENTAL','REJECTED','UNKNOWN')),
    evidence_snapshot_id TEXT REFERENCES donor_snapshots(id),
    notes TEXT
);

CREATE TABLE donor_build_system (
    id TEXT PRIMARY KEY,
    donor_id TEXT NOT NULL REFERENCES donor_projects(id),
    area TEXT NOT NULL,
    implementation TEXT NOT NULL,
    exact_tool_or_target TEXT,
    status TEXT NOT NULL CHECK (status IN ('SOURCE_VERIFIED','AUTHOR_DOCUMENTED','PUBLIC_CLAIM','INFERRED','UNKNOWN')),
    source_snapshot_id TEXT REFERENCES donor_snapshots(id),
    tftmac_relevance TEXT NOT NULL,
    notes TEXT
);

CREATE TABLE donor_measurements (
    id TEXT PRIMARY KEY,
    donor_id TEXT NOT NULL REFERENCES donor_projects(id),
    workload TEXT NOT NULL,
    comparison TEXT NOT NULL,
    result TEXT NOT NULL,
    classification TEXT NOT NULL CHECK (classification IN ('CONFIRMED','PROVISIONAL','REJECTED','DIAGNOSTIC','PUBLIC_CLAIM')),
    environment TEXT,
    source_snapshot_id TEXT REFERENCES donor_snapshots(id),
    transferable_lesson TEXT NOT NULL,
    transfer_limit TEXT NOT NULL
);

CREATE TABLE donor_public_claims (
    id TEXT PRIMARY KEY,
    donor_id TEXT NOT NULL REFERENCES donor_projects(id),
    claim TEXT NOT NULL,
    claim_scope TEXT NOT NULL,
    observed_at TEXT NOT NULL,
    evidence_snapshot_id TEXT REFERENCES donor_snapshots(id),
    corroboration_state TEXT NOT NULL CHECK (corroboration_state IN ('SOURCE_CORROBORATED','MEASUREMENT_CORROBORATED','PARTIALLY_CORROBORATED','UNVERIFIED','CONTRADICTED')),
    notes TEXT
);

CREATE TABLE donor_deltas (
    id TEXT PRIMARY KEY,
    donor_id TEXT NOT NULL REFERENCES donor_projects(id),
    tftmac_area TEXT NOT NULL,
    donor_state TEXT NOT NULL,
    current_tftmac_state TEXT NOT NULL,
    delta_type TEXT NOT NULL CHECK (delta_type IN ('DONOR_SIMPLER','TFTMAC_STRONGER','INCOMPATIBLE_ASSUMPTION','SAME_APPROACH','UNKNOWN')),
    significance INTEGER NOT NULL CHECK (significance BETWEEN 1 AND 10),
    recommended_action TEXT NOT NULL,
    promotion_test TEXT NOT NULL,
    notes TEXT
);

CREATE TABLE donor_promotion_queue (
    id TEXT PRIMARY KEY,
    donor_id TEXT NOT NULL REFERENCES donor_projects(id),
    finding TEXT NOT NULL,
    target_main_map_area TEXT NOT NULL,
    priority INTEGER NOT NULL CHECK (priority BETWEEN 1 AND 10),
    status TEXT NOT NULL CHECK (status IN ('QUEUED','TESTING','PROMOTED','REJECTED','DEFERRED')),
    required_tftmac_evidence TEXT NOT NULL,
    reason TEXT NOT NULL
);

CREATE TABLE donor_checkout_registry (
    id TEXT PRIMARY KEY,
    donor_id TEXT NOT NULL REFERENCES donor_projects(id),
    repository_url TEXT,
    desired_ref TEXT,
    local_target TEXT,
    license_ok INTEGER NOT NULL CHECK (license_ok IN (0,1)),
    checkout_state TEXT NOT NULL CHECK (checkout_state IN ('NOT_NEEDED','PLANNED','PRESENT','STALE','BLOCKED')),
    reason TEXT NOT NULL,
    notes TEXT
);

CREATE VIEW v_donor_priority AS
SELECT p.name,
       q.finding,
       q.priority,
       q.status,
       q.required_tftmac_evidence,
       q.reason
FROM donor_promotion_queue q
JOIN donor_projects p ON p.id=q.donor_id
ORDER BY q.status='QUEUED' DESC, q.priority DESC, p.name;

CREATE VIEW v_working_donor_profiles AS
SELECT p.name AS donor,
       r.profile_name,
       r.emulator_version,
       r.android_version,
       r.cpu_config,
       r.memory_config,
       r.display_config,
       r.graphics_transport,
       r.angle_mode,
       r.vulkan_mode,
       r.moltenvk_mode,
       r.package_authority,
       r.status
FROM donor_runtime_profiles r
JOIN donor_projects p ON p.id=r.donor_id
WHERE r.status IN ('WORKING_DONOR','HISTORICAL_WORKING','PUBLIC_CLAIM','CONTROL')
ORDER BY p.name,r.profile_name;

CREATE VIEW v_source_verified_techniques AS
SELECT p.name AS donor,
       t.technique,
       t.layer,
       t.problem_solved,
       t.implementation_summary,
       t.state,
       t.tftmac_relevance
FROM donor_techniques t
JOIN donor_projects p ON p.id=t.donor_id
WHERE t.source_snapshot_id IN (
    SELECT id FROM donor_snapshots
    WHERE evidence_class IN ('SOURCE_VERIFIED','PROJECT_LOCAL','AUTHOR_TECHNICAL_WRITEUP')
)
ORDER BY p.name,t.layer,t.id;

CREATE VIEW v_black_box_claims AS
SELECT p.name AS donor,
       c.claim,
       c.claim_scope,
       c.corroboration_state,
       c.notes
FROM donor_public_claims c
JOIN donor_projects p ON p.id=c.donor_id
WHERE p.project_type='PUBLIC_BLACK_BOX'
ORDER BY p.name,c.id;

INSERT INTO donor_meta(key,value) VALUES
('schema_version','1'),
('created_at','2026-08-28T06:00:00Z'),
('project','TFTMAC'),
('quarantine','TRUE'),
('authority','NON_AUTHORITATIVE_DONOR_RESEARCH'),
('promotion_rule','No donor finding enters TFTMAC production truth without independent current reproduction or explicit coupled SSOT/plan revision.'),
('version_policy','Patch/game version strings are volatile. Architecture, component relationships, exact build mechanics, and reproducible capability evidence matter more than README freshness.'),
('source_policy','Prefer source code, exact manifests, runtime scripts and measurements over README text. Public proprietary claims remain black-box claims.'),
('research_goal','Identify the minimum already-working architecture and harvest open-source implementation patterns before inventing replacements.');

INSERT INTO donor_projects VALUES
('mactician_upstream','Mactician current upstream','OPEN_SOURCE','https://github.com/tweet9ra/mactician','https://sergeinaumov.dev/mactician','MIT','FULL','Primary open-source working/reference implementation for TFT on Apple Silicon.','Open-source source may be inspected/adapted under MIT; volatile game pins are not authority.','2026-08-28T06:00:00Z','Current public repository and author technical case study sampled.'),
('mactician_local','Mactician donor snapshot embedded in TFTMAC','INTERNAL_DONOR',NULL,NULL,'MIT','LOCAL_SNAPSHOT','Local reproducible donor snapshot for code-level comparison without network drift.','Useful historical/source evidence only; predates current TFTMAC v2 authority.','2026-08-28T06:00:00Z','launcher/, scripts/, artifacts/, docs/ and run-tft-* files in TFTMAC repository.'),
('osft','OS FIGHT TACTICS','PUBLIC_BLACK_BOX',NULL,'https://macosfighttactics.com/en',NULL,'NONE','Independent contemporary implementation proving another design can run TFT locally on Apple Silicon.','Public capability/architecture claims only. No source repository found in current search; application is proprietary.','2026-08-28T06:00:00Z','Do not decompile or bypass license; use only public technical claims and observable behavior.'),
('utm_mvk','UTM/CrossOver MoltenVK donor','UPSTREAM_COMPONENT','https://github.com/utmapp/MoltenVK',NULL,'Apache-2.0','FULL','Lower-layer donor for Metal/Vulkan fixes if a measured MoltenVK gap exists.','Not a TFT implementation; only causal patches may be harvested.','2026-08-28T06:00:00Z','Already referenced by TFTMAC SSOT as conditional donor.');

INSERT INTO donor_snapshots VALUES
('snap_mactician_master','mactician_upstream','REPOSITORY_BRANCH','master','2026-08-28T06:00:00Z','https://github.com/tweet9ra/mactician',NULL,NULL,'SOURCE_VERIFIED','CURRENT_BUT_VERSION_VOLATILE','Repository has SwiftUI launcher, installer, runtime scripts, benchmark tooling, profiles, tests and docs.'),
('snap_mactician_runtime_controller','mactician_upstream','SOURCE_FILE','master','2026-08-28T06:00:00Z','https://github.com/tweet9ra/mactician/blob/master/launcher/Sources/RuntimeController.swift','launcher/Sources/RuntimeController.swift',NULL,'SOURCE_VERIFIED','CURRENT','Source shows runtime environment, ASG, ANGLE, MoltenVK and profile controls.'),
('snap_mactician_installer','mactician_upstream','SOURCE_FILE','master','2026-08-28T06:00:00Z','https://github.com/tweet9ra/mactician/blob/master/launcher/Sources/InstallerService.swift','launcher/Sources/InstallerService.swift',NULL,'SOURCE_VERIFIED','CURRENT','Source shows AVD creation, package installation, overlay creation, state persistence and integrity verification.'),
('snap_mactician_manifest','mactician_upstream','SOURCE_FILE','master','2026-08-28T06:00:00Z','https://github.com/tweet9ra/mactician/blob/master/launcher/Resources/release-manifest.json','launcher/Resources/release-manifest.json',NULL,'SOURCE_VERIFIED','CURRENT_BUT_VERSION_VOLATILE','Pins platform-tools 36.0.2, Emulator37.1.11 and Android36 Google APIs ARM64 r07; bundled game fields may lag hosted feed.'),
('snap_mactician_case','mactician_upstream','CASE_STUDY','2026-08-09','2026-08-28T06:00:00Z','https://sergeinaumov.dev/writing/how-i-built-mactician',NULL,NULL,'AUTHOR_TECHNICAL_WRITEUP','HISTORICAL','Author documents actual causal experiments, rejected paths and measured working graphics chain.'),
('snap_mactician_local_core','mactician_local','LOCAL_TREE','TFTMAC embedded donor','2026-08-28T06:00:00Z',NULL,'launcher/Sources/CoreModels.swift','9e2c332811b38c3d5f1195a3fb10b49b5adc64c3f588d929e9bb7fe72a4d9fa4','PROJECT_LOCAL','HISTORICAL','Contains signed hosted-game feed URL/public key and legacy PBE package validation.'),
('snap_mactician_local_hosted','mactician_local','LOCAL_TREE','TFTMAC embedded donor','2026-08-28T06:00:00Z',NULL,'launcher/Sources/HostedGameUpdate.swift','ce8d437e7a687c0cc8bcc05c5be9be5f7bf26ac64ded561f5e7d61ae38835d5b','PROJECT_LOCAL','HISTORICAL','Ed25519 signed remote game feed, same-origin HTTPS APK restriction, versionCode update logic.'),
('snap_osft_site','osft','PUBLIC_WEBSITE','current public product site','2026-08-28T06:00:00Z','https://macosfighttactics.com/en',NULL,NULL,'PUBLIC_CLAIM','CURRENT_BUT_VERSION_VOLATILE','Claims Apple Hypervisor, local Android, real Google Play, GPU-accelerated OpenGL, macOS12+, Apple Silicon and current TFT/PBE support.'),
('snap_osft_legal','osft','PUBLIC_WEBSITE','legal notice 2026-08-11','2026-08-28T06:00:00Z','https://macosfighttactics.com/en/legal/mentions-legales',NULL,NULL,'PUBLIC_CLAIM','CURRENT','Confirms proprietary OSFT Launcher/IP status; source must not be assumed public.'),
('snap_mactician_arch_local','mactician_local','LOCAL_TREE','TFTMAC embedded donor','2026-08-28T06:00:00Z',NULL,'docs/architecture.md','7132bf652fc1d851cf5479f49d9258f9b6e789c6f299db3a868f657515994c2e','PROJECT_LOCAL','HISTORICAL','Complete donor architecture/state-machine description.'),
('snap_mactician_bench_local','mactician_local','LOCAL_TREE','TFTMAC embedded donor','2026-08-28T06:00:00Z',NULL,'docs/benchmarks.md','526507229e293e92155fc3ba588bc48d6a149cc7c164d24e5d10ac33755d7965','PROJECT_LOCAL','HISTORICAL','Fixed-scene performance evidence and rejected candidate record.');

INSERT INTO donor_components VALUES
('mac_comp_host','mactician_upstream','Apple Silicon Mac','host',NULL,'arm64','macOS12+',NULL,'Host hardware','AUTHOR_TECHNICAL_WRITEUP','snap_mactician_case',NULL),
('mac_comp_emulator','mactician_upstream','Google Android Emulator','emulator','37.1.11','darwin-aarch64','Apple Silicon','Android36 ARM64','Virtual device host','SOURCE_VERIFIED','snap_mactician_manifest','Stock released Google emulator, not a source-built custom AEMU requirement.'),
('mac_comp_guest','mactician_upstream','Android 36 Google APIs ARM64','guest_os','r07','arm64',NULL,NULL,'Guest OS','SOURCE_VERIFIED','snap_mactician_manifest','Source AVD config explicitly uses Google APIs image with PlayStore.enabled=false in the provisioning guest.'),
('mac_comp_angle','mactician_upstream','Android/system ANGLE','graphics_translation',NULL,'arm64',NULL,NULL,'Package GLES->Vulkan translation','AUTHOR_TECHNICAL_WRITEUP','snap_mactician_case','Source runtime sets package-specific ANGLE controls.'),
('mac_comp_gfxstream','mactician_upstream','gfxstream','graphics_transport',NULL,NULL,NULL,NULL,'Guest/host graphics transport','AUTHOR_TECHNICAL_WRITEUP','snap_mactician_case',NULL),
('mac_comp_mvk','mactician_upstream','MoltenVK','graphics_translation',NULL,'darwin-aarch64',NULL,NULL,'Host Vulkan->Metal','AUTHOR_TECHNICAL_WRITEUP','snap_mactician_case',NULL),
('mac_comp_metal','mactician_upstream','Apple Metal','host_graphics',NULL,'arm64',NULL,NULL,'Final GPU API','AUTHOR_TECHNICAL_WRITEUP','snap_mactician_case',NULL),
('mac_comp_swiftui','mactician_upstream','Native SwiftUI launcher','native_ui',NULL,'arm64','macOS12+',NULL,'Install/state/runtime orchestration UI','SOURCE_VERIFIED','snap_mactician_master',NULL),
('mac_comp_gamefeed','mactician_upstream','Signed hosted game update feed','package_update',NULL,NULL,NULL,NULL,'Move fast-moving game payload/version outside static app release','PROJECT_LOCAL','snap_mactician_local_hosted','Ed25519 envelope validation and same-origin HTTPS APK URLs.'),
('osft_comp_hypervisor','osft','Apple Hypervisor local Android runtime','emulator','unknown','arm64','macOS12+',NULL,'Local Android execution','PUBLIC_CLAIM','snap_osft_site','Exact emulator implementation/version not public.'),
('osft_comp_opengl','osft','GPU-accelerated OpenGL path','graphics','unknown','arm64','macOS12+',NULL,'TFT renderer path','PUBLIC_CLAIM','snap_osft_site','Claims guaranteed OpenGL3.2; exact ANGLE/gfxstream/MoltenVK implementation not published.'),
('osft_comp_play','osft','Google Play','package_authority','current',NULL,NULL,NULL,'Official TFT install/update path','PUBLIC_CLAIM','snap_osft_site',NULL);

INSERT INTO donor_architecture_edges VALUES
('edge_mac_tft_angle','mactician_upstream','TFT GLES','Android/system ANGLE','GLES','TFT remains a GLES-rendered application while ANGLE translates below it.','AUTHOR_VERIFIED','snap_mactician_case',NULL),
('edge_mac_angle_vk','mactician_upstream','Android/system ANGLE','Vulkan','graphics API translation','ANGLE emits Vulkan for emulator graphics stack.','AUTHOR_VERIFIED','snap_mactician_case',NULL),
('edge_mac_vk_gfx','mactician_upstream','Vulkan','gfxstream','guest-host transport','Vulkan commands cross emulator graphics transport.','AUTHOR_VERIFIED','snap_mactician_case',NULL),
('edge_mac_gfx_mvk','mactician_upstream','gfxstream','MoltenVK','host Vulkan backend','gfxstream host path reaches MoltenVK.','AUTHOR_VERIFIED','snap_mactician_case',NULL),
('edge_mac_mvk_metal','mactician_upstream','MoltenVK','Metal','Vulkan-to-Metal','MoltenVK targets Apple Metal.','AUTHOR_VERIFIED','snap_mactician_case',NULL),
('edge_mac_launcher_runtime','mactician_upstream','SwiftUI launcher','runtime project','process/state control','Launcher refreshes owned runtime scripts, validates hashes and starts runtime helper.','SOURCE_VERIFIED','snap_mactician_runtime_controller',NULL),
('edge_osft_hv_android','osft','OSFT Launcher','local Android device','Hypervisor','Public site says Android runs locally on Apple Hypervisor.','PUBLIC_CLAIM','snap_osft_site',NULL),
('edge_osft_play_game','osft','Google Play','TFT','package install','User installs official TFT from Google Play.','PUBLIC_CLAIM','snap_osft_site',NULL),
('edge_osft_game_gpu','osft','TFT','GPU-accelerated OpenGL','graphics','Public site claims OpenGL direct GPU rendering.','PUBLIC_CLAIM','snap_osft_site','Do not infer exact lower translation layers without evidence.');

INSERT INTO donor_runtime_profiles VALUES
('profile_mac_source','mactician_upstream','Source-verified runtime baseline','37.1.11','Android36','Google APIs ARM64 r07','6 logical vCPU baseline; host sizing can vary','6144MB baseline; user-selectable validated values','1920x1080/320 baseline with higher profiles','host','virtio-gpu-asg at runtime despite AVD baseline pipe','package/system ANGLE with donor controls','Vulkan under ANGLE','async; 64 active Metal command buffers; fast math enabled','bundled/signed hosted game feed in source design','WORKING_DONOR','snap_mactician_runtime_controller','RuntimeController sets TFT_GLTRANSPORT=virtio-gpu-asg, write step 16384, MVK async/64, fast math and disables ANGLE preferSubmitAtFBOBoundary.'),
('profile_mac_case','mactician_upstream','Author measured working graphics path','37.1.11','Android16/36 family','ARM64','7 vCPU measured M1 Max','guest had ample free RAM; more RAM not causal','2560x1440 historical quality profile','host','ASG','ANGLE controlled ES3.2 exposure','Vulkan','MoltenVK->Metal','historical pinned TFT PBE payload','HISTORICAL_WORKING','snap_mactician_case','Author entered real matches and ran fixed-stage performance experiments.'),
('profile_osft_public','osft','OSFT public working profile','unknown','local Android','unknown','tuned per machine','tuned per machine','fullscreen/user-facing','GPU accelerated','unknown','OpenGL 3.2 claimed','unknown','unknown','real Google Play','PUBLIC_CLAIM','snap_osft_site','Useful proof of product feasibility; internal implementation remains unknown.');

INSERT INTO donor_capabilities VALUES
('cap_mac_real_match','mactician_upstream','Game reaches UI/content/authentication/match','workload','PROVEN_BY_MEASUREMENT','Author defines working result as UI + content + auth + entered match, not process existence.','Historical TFT PBE research','snap_mactician_case','Author technical case study with benchmark work.','Historical workload/version; architecture lessons transfer, current live compatibility must be separately verified.'),
('cap_mac_stock_emulator','mactician_upstream','Stock Emulator37.1.11 sufficient for donor runtime','emulator','PROVEN_BY_SOURCE','Donor ships/pins Google Emulator37.1.11 binary rather than requiring source-built AEMU.','Mactician release architecture','snap_mactician_manifest','Source and author documentation agree on stock emulator dependency.','Does not prove TFTMAC v2 genuine-conformance requirement.'),
('cap_mac_asg','mactician_upstream','ASG transport improves controlled match performance','graphics_transport','PROVEN_BY_MEASUREMENT','40.1 FPS / 34.85ms p95 ASG vs 29.6 FPS / 49.75ms p95 old pipe in exact stage1-1 A/B.','Historical fixed TFT scene','snap_mactician_bench_local','Controlled A/B.','Different host/workload; direction is stronger evidence than absolute numbers.'),
('cap_mac_native_window','mactician_upstream','Native emulator window removes scrcpy CPU/video path','presentation','PROVEN_BY_MEASUREMENT','Moving off scrcpy removed software guest video encode path and intermittent freezes.','Historical runtime','snap_mactician_case','Author causal diagnosis.','Native single-window TFTMAC UX may later use a different presentation transport.'),
('cap_mac_bg_nice','mactician_upstream','QEMU process priority correction','host_runtime','PROVEN_BY_MEASUREMENT','unsetopt BG_NICE prevents zsh background QEMU from inheriting nice=5; QEMU runs nice=0.','Historical runtime','snap_mactician_case','Author causal diagnosis.','TFTMAC should preserve this launch invariant if shell backgrounding is used.'),
('cap_mac_update_feed','mactician_upstream','Fast-moving game payload decoupled from static app manifest','package_update','PROVEN_BY_SOURCE','Hosted signed feed supports versionCode comparison, per-APK hashes and same-origin HTTPS downloads.','Mactician app update flow','snap_mactician_local_hosted','Local source direct.','Legacy validation hardcodes PBE package; concept remains valuable even if exact package logic changes.'),
('cap_osft_local','osft','Runs TFT locally on Apple Silicon','runtime','PUBLIC_CLAIM','Public product site says local Android on Apple Hypervisor, no cloud streaming.','Current product','snap_osft_site','Public commercial claim.','No source or independent TFTMAC measurement in this database.'),
('cap_osft_play','osft','Real Google Play acquisition','package_authority','PUBLIC_CLAIM','Public site instructs user to sign into Google Play and install TFT officially.','Current product','snap_osft_site','Public commercial claim.','Exact image/Play Services architecture unknown.'),
('cap_osft_gl32','osft','OpenGL 3.2 support','graphics','PUBLIC_CLAIM','Product site advertises guaranteed OpenGL3.2 support and GPU-accelerated OpenGL.','Current product','snap_osft_site','Public claim only.','No source evidence of whether this is conformant, spoofed, ANGLE-backed, or another method.');

INSERT INTO donor_techniques VALUES
('tech_mac_stock_pin','mactician_upstream','Pin a released stock emulator instead of source-building AEMU','emulator','Reduce build-system/toolchain surface while retaining known runtime behavior.','Manifest pins Emulator37.1.11 download/hash; launcher installs it as a verified runtime component.','PROMOTED_BY_DONOR','snap_mactician_manifest','Highest-value TFTMAC comparison: prove whether stock37.1.11 + our guest/capability probes makes source AEMU unnecessary.','LOW','This directly challenges our source-first assumption.'),
('tech_mac_asg','mactician_upstream','Promote ASG transport over legacy pipe','graphics_transport','Reduce guest-host transport overhead.','Runtime sets virtio-gpu-asg; measured exact-scene A/B selected ASG.','PROMOTED_BY_DONOR','snap_mactician_case','Use as prior for current control profile, but remeasure current stack.','LOW',NULL),
('tech_mac_write_step','mactician_upstream','Use 16KiB ASG write step','graphics_transport','Reduce transport syscall/MMIO/ring overhead.','RuntimeController exports TFT_ASG_WRITE_STEP_SIZE=16384.','PROMOTED_BY_DONOR','snap_mactician_runtime_controller','Candidate current control parameter; already represented in historical TFTMAC donor.','MEDIUM','Revalidate because source/guest changed.'),
('tech_mac_mvk_async','mactician_upstream','MoltenVK async queue + bounded active command buffers','host_graphics','Improve host submission throughput without pathological buffer growth.','Runtime exports TFT_MVK_QUEUE_MODE=async and MAX_ACTIVE_METAL_COMMAND_BUFFERS_PER_QUEUE=64.','PROMOTED_BY_DONOR','snap_mactician_runtime_controller','Strong donor default for host-side performance experiments after capability correctness.','MEDIUM','Performance setting, not correctness proof.'),
('tech_mac_no_fbo_submit','mactician_upstream','Disable ANGLE preferSubmitAtFBOBoundary','guest_graphics','Reduce unnecessary submit boundaries.','Runtime exports TFT_ANGLE_DISABLED_FEATURES=preferSubmitAtFBOBoundary.','PROMOTED_BY_DONOR','snap_mactician_runtime_controller','Potential current candidate only after matching ANGLE version/behavior.','MEDIUM','Historical evidence originally provisional; current source promotion indicates donor accepted it later.'),
('tech_mac_device_profile','mactician_upstream','Transactional DeviceProfiles/overlay with hash + rollback','workload_profile','Prevent game restart from reverting framebuffer/profile and preserve exact rendering assumptions.','Launcher verifies source/hash, applies profile for AVD session, stores sidecar backups and restores on cleanup.','PROMOTED_BY_DONOR','snap_mactician_case','Strong implementation pattern if current live client still consumes equivalent profile/overlay mechanism.','HIGH','Engine/layout specific; do not apply to Riot-native client without evidence.'),
('tech_mac_native_window','mactician_upstream','Use native Emulator window rather than scrcpy','presentation','Avoid guest software video encode and wrong right-click semantics.','Removed scrcpy display loop after causal failures.','PROMOTED_BY_DONOR','snap_mactician_case','Keep native emulator as control even if TFTMAC later wraps presentation.','LOW',NULL),
('tech_mac_bg_nice','mactician_upstream','Disable zsh BG_NICE for background emulator launch','host_runtime','Avoid QEMU silently running at nice=5.','unsetopt BG_NICE before orchestration.','PROMOTED_BY_DONOR','snap_mactician_case','Add as explicit TFTMAC launch invariant if relevant.','LOW',NULL),
('tech_mac_signed_feed','mactician_upstream','Signed remote game-update feed','package_update','Riot patches quickly; avoid shipping a new launcher binary for every game payload update.','Ed25519 envelope + same-host HTTPS + per-APK size/hash + monotonic versionCode handling.','PROMOTED_BY_DONOR','snap_mactician_local_hosted','Very useful architectural idea independent of game version.','LOW','TFTMAC prefers Google Play production authority; feed pattern may instead apply to compatibility metadata, not distributing Riot binaries.'),
('tech_osft_googleplay','osft','User installs TFT through real Google Play','package_authority','Avoid stale bundled game payloads and mirror/update burden.','Public product flow: login to Google Play once; install/update TFT there.','PROMOTED_BY_DONOR','snap_osft_site','Matches TFTMAC v2 package-authority goal exactly.','LOW','Public black-box claim, but architecture is independently reasonable.'),
('tech_osft_machine_tuning','osft','Tune RAM/cores by host model','resource_management','Avoid one-size-fits-all guest sizing.','Public site says RAM and cores tuned to machine; implementation unpublished.','UNKNOWN','snap_osft_site','We can implement independently using our own measured resource profiles.','LOW','No proprietary details needed.');

INSERT INTO donor_failures VALUES
('fail_mac_generic_gles','mactician_upstream','guest_graphics','Plain emulator GLES2/3.0/3.1','TFT PBE would not complete startup because workload required ES3.2.','Installed APK != graphics compatibility; game requirement lives above emulator package installation.','Select package ANGLE + Vulkan-backed path.','snap_mactician_case','Never use install/process existence as graphics acceptance.'),
('fail_mac_direct_vk','mactician_upstream','workload_graphics','Force Unreal direct Vulkan RHI','Did not solve compatibility; device profile kept game on OpenGL.','Changing game RHI was not the correct boundary.','Keep game GLES; use Vulkan beneath ANGLE.','snap_mactician_case','Do not force a different workload API without proof the exact game build supports it.'),
('fail_mac_scrcpy','mactician_upstream','presentation','scrcpy display path','Guest software video encoding caused stalls and right-click mapped to Android Back.','Presentation layer introduced its own CPU/input failure modes.','Use native emulator window.','snap_mactician_case','Keep direct emulator presentation as baseline/control.'),
('fail_mac_more_resources','mactician_upstream','resource_management','Increase guest CPU/RAM blindly','Measurements showed CPUs idle and RAM available while active bottleneck remained elsewhere.','Resource quantity was not the constrained boundary.','Measure before increasing resources.','snap_mactician_case','Do not use more vCPU/RAM as generic performance cure.'),
('fail_mac_prewarm','mactician_upstream','shader_pipeline','Aggressive PSO prewarming','Reproducible crash in OpenGL program-binary cache.','Broad shader warmup disturbed a fragile cache path.','Reject broad prewarm; preserve persistent cache.','snap_mactician_case','Do not revive broad prewarm without new causal evidence.'),
('fail_mac_submit_thread','mactician_upstream','graphics_transport','Forced submit thread','Heavy-stage performance regressed to about25.8 FPS in donor campaign.','Threading change increased submission/marshalling overhead or synchronization cost.','Reject default submit-thread path.','snap_mactician_bench_local','Historical negative prior; only retest if current traces identify same boundary differently.'),
('fail_mac_mvk128','mactician_upstream','host_graphics','128 active Metal command buffers','Strong first result failed cold repeat; heavy stage fell to23.3 FPS.','Single-run improvement was not reproducible.','Keep experimental only.','snap_mactician_case','Never promote isolated FPS win without cold confirmation.'),
('fail_mac_fileprovider','mactician_upstream','storage','Keep stateful AVD under File Provider-managed directory','Large qcow2 files became compressed/dataless placeholders and AVD became unrecoverable.','Stateful virtual disks cannot tolerate cloud/offload semantics.','Dedicated local Application Support runtime.','snap_mactician_case','Our external M4 runtime must remain ordinary local filesystem storage, not File Provider/cloud-synced.');

INSERT INTO donor_build_system VALUES
('build_mac_native','mactician_upstream','macOS app','SwiftUI app compiled as native arm64 macOS app','arm64-apple-macosx12.0','SOURCE_VERIFIED','snap_mactician_master','Confirms no requirement for Xcode26.6 specifically to build donor application; minimum deployment target12.0 is deliberate.',NULL),
('build_mac_emulator_delivery','mactician_upstream','Android emulator','Download verified Google Emulator37.1.11 archive','emulator-darwin_aarch64-15917651.zip','SOURCE_VERIFIED','snap_mactician_manifest','Avoids AEMU source compile entirely for donor shipping runtime.',NULL),
('build_mac_guest_delivery','mactician_upstream','Android guest','Download verified Android36 ARM64 system image','android-36 Google APIs r07','SOURCE_VERIFIED','snap_mactician_manifest','Guest image is treated as immutable verified dependency.',NULL),
('build_mac_state_machine','mactician_upstream','installation','Durable install state stages empty->downloading->sdk_installed->avd_created->ready','InstallState','SOURCE_VERIFIED','snap_mactician_installer','Useful production pattern; separates resumable setup from runtime launch.',NULL),
('build_mac_avd_manual','mactician_upstream','AVD construction','Create config.ini + qcow2 userdata + encryption key directly','qemu-img create 12G','SOURCE_VERIFIED','snap_mactician_installer','Avoids Android Studio; exact AVD configuration is deterministic.',NULL),
('build_mac_integrity','mactician_upstream','integrity','SHA256 every downloaded component/game split; transactional staging','SHA-256','SOURCE_VERIFIED','snap_mactician_installer','Useful unchanged principle for TFTMAC runtime components.',NULL),
('build_mac_release','mactician_upstream','distribution','Native app bundle, hardened runtime/DeveloperID/notarization, Sparkle updates','macOS release pipeline','AUTHOR_DOCUMENTED','snap_mactician_case','Donor proves normal signed/notarized macOS packaging is independent of Android runtime complexity.',NULL),
('build_osft_engine','osft','engine install','One-time engine installation then launcher controls local Android','unknown','PUBLIC_CLAIM','snap_osft_site','Evidence that user-facing runtime can be packaged as an installed engine rather than a developer build tree.',NULL);

INSERT INTO donor_measurements VALUES
('measure_mac_asg','mactician_upstream','Exact TFT stage1-1 combat','virtio-gpu ASG vs old pipe','40.1 FPS /34.85ms p95 vs29.6 FPS /49.75ms p95','CONFIRMED','M1 Max donor environment','snap_mactician_case','Prefer ASG as the stock donor transport baseline.','Absolute FPS does not transfer to M4/API37/current client.'),
('measure_mac_resolution','mactician_upstream','TFT stage1-5','1600x900 vs2560x1440','30.5 vs31.3 FPS despite2.56x pixels','CONFIRMED','M1 Max donor environment','snap_mactician_case','The tested scene was CPU/RHI/transport-bound; lowering resolution was not the causal fix.','Scene-specific; no general resolution-free claim.'),
('measure_mac_control','mactician_upstream','Tocker Trial fixed stages','reproducible donor baseline','40.60 /36.03 /27.83 FPS stages1-2/1-5/1-8','CONFIRMED','M1 Max donor environment','snap_mactician_case','Use fixed-scene repeatability instead of lobby FPS.','Historical PBE workload.'),
('measure_mac_mvk128','mactician_upstream','Heavy TFT scene','MVK128 first vs cold repeat','32.4 FPS first; cold repeat23.3 FPS heavy stage','REJECTED','M1 Max donor environment','snap_mactician_case','Cold repeat is required before promotion.','Historical setting/driver behavior.'),
('measure_osft_ranked','osft','Live ranked TFT','Public site points to Master-ranked users playing on OSFT','Product feasibility claim','PUBLIC_CLAIM','Current commercial product','snap_osft_site','Treat as feasibility signal only.','No controlled technical measurement or source evidence.');

INSERT INTO donor_public_claims VALUES
('claim_osft_mac12','osft','Supports Apple Silicon M1+ on macOS12+','host compatibility','2026-08-28T06:00:00Z','snap_osft_site','UNVERIFIED','Public product requirement.'),
('claim_osft_local_android','osft','Runs a real Android device locally using Apple Hypervisor','virtualization','2026-08-28T06:00:00Z','snap_osft_site','UNVERIFIED','Exact virtual-machine/emulator stack is not public.'),
('claim_osft_gl32','osft','Guarantees OpenGL3.2 support with GPU-accelerated OpenGL','graphics','2026-08-28T06:00:00Z','snap_osft_site','UNVERIFIED','Important feasibility claim; exact conformance/translation technique unknown.'),
('claim_osft_play','osft','Uses real Google Play for user-installed TFT','package authority','2026-08-28T06:00:00Z','snap_osft_site','PARTIALLY_CORROBORATED','Architecture independently matches TFTMAC goal; implementation is proprietary.'),
('claim_osft_disk','osft','Requires about10GB disk space','resource footprint','2026-08-28T06:00:00Z','snap_osft_site','UNVERIFIED','Potentially much smaller than our 131GB AEMU source workspace because it ships/installs runtime artifacts rather than development source.'),
('claim_mactician_current','mactician_upstream','Current public project positions Mactician as a native TFT launcher for Apple Silicon','product scope','2026-08-28T06:00:00Z','snap_mactician_master','SOURCE_CORROBORATED','Do not use patch string as blocker; source architecture is the relevant evidence.');

INSERT INTO donor_deltas VALUES
('delta_stock_vs_source','mactician_upstream','emulator acquisition','Ships verified stock Emulator37.1.11 binary.','TFTMAC v2 currently mandates source-built emu-master-dev.','DONOR_SIMPLER',10,'Run TFTMAC capability probes against stock37.1.11 before continuing source-build critical path.','Stock37.1.11 + current guest must pass host/guest Vulkan, genuine GLES3.2 and live TFT smoke without prohibited spoofing.','Potentially removes almost the entire Phase1 source-build burden.'),
('delta_guest36_37','mactician_upstream','guest OS','Android36 ARM64 known donor stack.','TFTMAC v2 freezes Android17/API37 Google Play.','INCOMPATIBLE_ASSUMPTION',8,'Keep Android36 as a control candidate, not authority.','Measure current live TFT install/launch and graphics capability on a clean donor-compatible Android36 guest.','Older guest may be simpler and sufficiently compatible.'),
('delta_package_authority','osft','package acquisition','Real Google Play user install/update.','TFTMAC v2 also requires Google Play authority.','SAME_APPROACH',9,'Preserve Google Play authority; do not distribute Riot binaries as production mechanism.','Current Play guest can install/update official live TFT and package identity/signature can be recorded.','Strong convergence between independent implementations.'),
('delta_storage_size','osft','runtime footprint','Public product claims ~10GB installed space.','TFTMAC development source tree alone is ~131GB.','DONOR_SIMPLER',8,'Separate development-source workspace from shippable runtime footprint; stop assuming source checkout is a production dependency.','Build a runtime bill-of-materials and measure only required shipping artifacts.','This may expose huge simplification.'),
('delta_native_window','mactician_upstream','presentation','Native Emulator window is known stable donor path.','TFTMAC SSOT ultimately wants a single native shell with hidden emulator chrome.','TFTMAC_STRONGER',5,'Keep native emulator window as control; native wrapping is a later UX optimization.','Do not hide emulator chrome until latency/control acceptance proves wrapper parity.','Avoid reintroducing scrcpy-like cost.'),
('delta_gles_truth','mactician_upstream','GLES3.2 acceptance','Historical donor used controlled ES3.2 exposure to make PBE workload run.','TFTMAC v2 forbids nonconformant version exposure as final proof.','TFTMAC_STRONGER',10,'Harvest transport/performance/runtime mechanics but do not inherit donor ES3.2 acceptance shortcut.','TFTMAC guest probe must create real3.2 context and execute required features without nonconformant exposure.','This is exactly why donor success is not automatically production truth.'),
('delta_dynamic_updates','mactician_upstream','fast game patch handling','Signed hosted feed decouples fast Riot payload updates from app binary updates.','TFTMAC v2 prefers Google Play for game delivery but has no equivalent rapidly-updated compatibility metadata channel yet.','DONOR_SIMPLER',6,'Borrow the signed-manifest concept for compatibility metadata/runtime profiles, not necessarily Riot APK distribution.','Implement signed compatibility manifest and prove downgrade/replay resistance.','Solves user point that Riot patch strings should not block architecture progress.');

INSERT INTO donor_promotion_queue VALUES
('promote_stock37111','mactician_upstream','Stock Google Emulator37.1.11 may make source-built AEMU unnecessary for production.','architecture_candidates',10,'QUEUED','Run the same current host Vulkan, guest Vulkan, genuine GLES3.2 and live TFT probes against stock37.1.11.','Largest potential reduction in complexity and build time.'),
('promote_android36_control','mactician_upstream','Android36 ARM64 donor guest may be simpler than API37 for current workload.','version_catalog/stack_profiles',9,'QUEUED','Create clean isolated Android36 control with official package authority where possible; run live package compatibility + graphics probes.','Older working guest may satisfy requirements with fewer preview/current API complications.'),
('promote_asg','mactician_upstream','ASG should be current graphics transport control baseline.','runtime_profile',8,'QUEUED','Verify active transport and run one current capability/frame smoke comparison against pipe only if pipe control is needed.','Strongest measured donor transport improvement.'),
('promote_mvk_async64','mactician_upstream','Async MoltenVK +64 active command buffers is a high-value donor default.','performance_candidates',5,'DEFERRED','Only test after current host/guest capability correctness is green and profiling indicates host submission relevance.','Performance tuning should not precede correctness.'),
('promote_signed_compat_feed','mactician_upstream','Use signed rapidly-updated compatibility metadata so Riot patch strings do not require hardcoded app releases.','update_architecture',6,'QUEUED','Design a signed non-Riot-binary compatibility manifest with exact runtime/profile/package metadata and rollback rules.','Makes fast game patches non-blocking while preserving integrity.'),
('promote_native_control','mactician_upstream','Native emulator window should remain the presentation latency/control baseline.','phase8_control',6,'QUEUED','Boot current working runtime in direct native emulator window and capture control latency before any custom native presentation.','Avoids unnecessary presentation invention before runtime works.'),
('promote_osft_feasibility','osft','Independent product claims Google Play + local Android + OpenGL3.2 on macOS12+ with ~10GB footprint.','architecture_research',4,'DEFERRED','Only compare behavior through lawful public/demo/user-owned execution; do not infer private implementation.','Useful independent feasibility signal but not source authority.');

INSERT INTO donor_checkout_registry VALUES
('checkout_mactician','mactician_upstream','https://github.com/tweet9ra/mactician','master','/Volumes/MAC MINI M4/TFTMAC/Donors/mactician-upstream',1,'PLANNED','A clean external checkout can enable exact source diff against embedded donor without polluting repository history.','Do not vendor the entire donor into TFTMAC Git unless a specific source subset is adopted; keep checkout under external build/research storage.'),
('checkout_utm_mvk','utm_mvk','https://github.com/utmapp/MoltenVK','crossovers/v25.1.0','/Volumes/MAC MINI M4/TFTMAC/Donors/utm-moltenvk',1,'NOT_NEEDED','Only needed if current host Vulkan probe proves a MoltenVK-owned missing feature.','Avoid speculative donor checkout.'),
('checkout_osft','osft',NULL,NULL,NULL,0,'BLOCKED','OSFT is proprietary/public black-box; no open-source repository was found in current search.','Do not attempt to decompile or bypass licensing.');

-- Target-M4 real-run evidence captured after installing current Mactician.
INSERT INTO donor_snapshots VALUES
('snap_mactician_target_m4_live','mactician_upstream','LOCAL_TREE','target M4 live runtime log','2026-08-28T06:39:17Z',NULL,'artifacts/mactician-live.log','8042a71ff6b22dc1e0791653fde5068b269c84352b78ccf738e54436c2dacc75','PROJECT_LOCAL','CURRENT','Actual Mactician session log from Mac16,10 Apple M4. Contains successful TFT launch, exact active graphics/runtime profile, later hosted-feed failures, post-patch version-state failure, and repeated controlled shutdowns.');

INSERT INTO donor_runtime_profiles VALUES
('profile_mac_target_m4_observed','mactician_upstream','Target Mac M4 observed gameplay profile','37.1.11','Android36','Google APIs ARM64','6 vCPU','6144MB','1920x1080@320dpi@60','host','virtio-gpu-asg','guest ANGLE; exposeNonConformantExtensionsAndVersions/exposeES32ForTesting observed','Vulkan beneath ANGLE','async queue; 64 active Metal command buffers; fast math','Mactician hosted/fallback package mechanism; later invalid feed','CONTROL','snap_mactician_target_m4_live','Log reports ASG writeBufferSize1048576, writeStepSize16384, dataRingSize32768, graphics profile osft, audio enabled, PSO watcher active, and TFT Unreal OpenGL ES -> guest ANGLE -> Vulkan -> Metal.');

INSERT INTO donor_capabilities VALUES
('cap_mac_target_m4_launch','mactician_upstream','Current donor runtime launches TFT on target Apple M4','workload','PROVEN_BY_MEASUREMENT','TFT launched as com.riotgames.league.teamfighttactics, real process PID observed, login path operated, game patched, and user reached party/lobby before Riot rejected match start for version mismatch.','Target Mac M4 actual session','snap_mactician_target_m4_live','Direct runtime log plus user-observed party/version-mismatch sequence.','Does not prove current package version parity or complete live-match stability.'),
('cap_mac_target_m4_graphics','mactician_upstream','Target M4 executes donor ANGLE/Vulkan/MoltenVK/Metal path','graphics','PROVEN_BY_MEASUREMENT','Runtime log reports TFT Unreal OpenGL ES -> guest ANGLE -> Vulkan -> Metal, Apple M4 MoltenVK device, gfxstream initialized, ASG transport active.','Target Mac M4 actual session','snap_mactician_target_m4_live','Direct runtime log.','Donor also enables nonconformant ES3.2 exposure; do not treat as genuine conformance proof.');

INSERT INTO donor_failures VALUES
('fail_mac_target_feed','mactician_upstream','package_update','Hosted TFT feed during target-M4 session','Hosted feed repeatedly returned Invalid TFT release; launcher fell back to bundled metadata. User could patch/login/join party but Riot then reported game versions did not match.','Third-party package metadata/feed was not synchronized with current Riot live client state.','Remove third-party TFT package feed from TFTMAC production architecture; use official Google Play/Riot authority.','snap_mactician_target_m4_live','A community feed must never be the authoritative current-live package source for TFTMAC.'),
('fail_mac_target_postpatch','mactician_upstream','package_state','Restart after in-game patch/version mismatch','Android booted normally, then launcher found /data/user/0/com.riotgames.league.teamfighttactics missing, could not determine owner, and intentionally shut emulator down.','Package/private-data assumptions were invalid after the patch/update sequence; snapshot warning was only shutdown noise.','TFTMAC recovery must classify package missing/not initialized/updating/damaged and route to official package repair instead of generic shutdown.','snap_mactician_target_m4_live','Repeated across multiple launches in the copied log.');

INSERT INTO donor_measurements VALUES
('measure_mac_target_user_drop','mactician_upstream','Target M4 real use during patch/loading','FPS overlay light-state vs user-observed transition drop','Approximately 60 FPS in light state with a reported transient drop to roughly 6 FPS while entering/loading activity','DIAGNOSTIC','Mac16,10 Apple M4, 16GB; session included patching and cache activity','snap_mactician_target_m4_live','Do not accept lobby/light-scene FPS as product performance; measure transitions and heavy combat explicitly.','User observation is not a controlled benchmark; exact frame-time trace still required.');

INSERT INTO donor_deltas VALUES
('delta_target_direct_delivery','mactician_upstream','game delivery','Current donor depends on hosted/bundled package metadata and exact APKs; target session demonstrated feed/version drift.','Rebuild requirement is Google Play/Riot direct authority with no third-party TFT feed.','TFTMAC_STRONGER',10,'Use Play-enabled guest first; inspect installed package/version/signature locally and let Google Play/Riot own update state.','Clean Play-enabled ARM64 guest installs current live TFT, reaches Riot login, and after update can enter a party/match without version mismatch.','Tonight provided direct target-host evidence that feed drift is a user-visible production failure.'),
('delta_target_fullscreen','mactician_upstream','presentation','Donor uses launcher plus separate resizable/window-fill emulator window.','Rebuild requires one native-feeling macOS fullscreen product surface with emulator chrome hidden.','TFTMAC_STRONGER',9,'Prototype native fullscreen presentation while retaining direct-emulator frame/input path as the control.','Fullscreen prototype must preserve FPS/frame time/input latency within the product acceptance envelope.','Do not reintroduce scrcpy/software encode path.');

INSERT INTO donor_promotion_queue VALUES
('promote_direct_google_target','mactician_upstream','Replace donor hosted/bundled TFT delivery with direct Google Play/Riot authority.','package_update_architecture',10,'QUEUED','Prove a clean Play-enabled ARM64 guest installs and updates current live TFT and reaches a match without version mismatch.','Direct target-M4 failure demonstrated the third-party feed is a reliability dependency we do not need.'),
('promote_target_profile_control','mactician_upstream','Use the exact successful M4 donor runtime profile as a comparison control, not as final product truth.','performance_control',9,'QUEUED','Reproduce stock37.1.11 + ASG16KiB + 6/6144 + 1080p on official package-authority guest and collect transition/heavy-scene frame-time data.','Gives TFTMAC a proven starting control while allowing measured performance improvement.');

COMMIT;

-- High-value queries
-- SELECT * FROM v_donor_priority;
-- SELECT * FROM v_working_donor_profiles;
-- SELECT * FROM v_source_verified_techniques;
-- SELECT * FROM donor_deltas ORDER BY significance DESC;
-- SELECT * FROM donor_failures ORDER BY donor_id,layer;
-- SELECT * FROM v_black_box_claims;
