-- TFTMAC Engineering Knowledge Map
-- Purpose: persistent, queryable systems map for architecture, dependencies,
-- experiments, compatibility, failures, evidence, unknowns, and invention paths.
--
-- Operating rule:
--   A material discovery MUST be recorded here before the next architecture-
--   changing action. This file is not a diary. It is the project's dependency
--   and decision graph.
--
-- SQLite compatible.

PRAGMA foreign_keys = ON;

BEGIN;

CREATE TABLE IF NOT EXISTS map_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS components (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    kind TEXT NOT NULL,
    layer TEXT NOT NULL,
    ownership TEXT NOT NULL CHECK (ownership IN ('TFTMAC','UPSTREAM','APPLE','GOOGLE','RIOT','KHRONOS','REFERENCE','UNKNOWN')),
    status TEXT NOT NULL CHECK (status IN ('PROVEN','AVAILABLE','ACTIVE','BLOCKED','CONDITIONAL','REJECTED','UNKNOWN')),
    purpose TEXT NOT NULL,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS component_versions (
    id TEXT PRIMARY KEY,
    component_id TEXT NOT NULL REFERENCES components(id),
    version TEXT,
    commit_sha TEXT,
    artifact_sha256 TEXT,
    source_authority TEXT,
    frozen INTEGER NOT NULL DEFAULT 0 CHECK (frozen IN (0,1)),
    notes TEXT
);

CREATE TABLE IF NOT EXISTS capabilities (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    layer TEXT NOT NULL,
    description TEXT NOT NULL,
    acceptance_rule TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS component_capabilities (
    component_id TEXT NOT NULL REFERENCES components(id),
    capability_id TEXT NOT NULL REFERENCES capabilities(id),
    state TEXT NOT NULL CHECK (state IN ('PASS','FAIL','PARTIAL','EXPECTED','UNKNOWN','NOT_APPLICABLE')),
    evidence_id TEXT,
    notes TEXT,
    PRIMARY KEY (component_id, capability_id)
);

CREATE TABLE IF NOT EXISTS interfaces (
    id TEXT PRIMARY KEY,
    from_component TEXT NOT NULL REFERENCES components(id),
    to_component TEXT NOT NULL REFERENCES components(id),
    interface_type TEXT NOT NULL,
    contract TEXT NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('PROVEN','VIABLE','BLOCKED','CONDITIONAL','UNKNOWN')),
    notes TEXT
);

CREATE TABLE IF NOT EXISTS dependencies (
    id TEXT PRIMARY KEY,
    consumer_component TEXT NOT NULL REFERENCES components(id),
    provider_component TEXT NOT NULL REFERENCES components(id),
    relationship TEXT NOT NULL,
    required INTEGER NOT NULL DEFAULT 1 CHECK (required IN (0,1)),
    compatibility_state TEXT NOT NULL CHECK (compatibility_state IN ('PASS','FAIL','WORKAROUND','CONDITIONAL','UNKNOWN')),
    evidence_id TEXT,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS constraints (
    id TEXT PRIMARY KEY,
    category TEXT NOT NULL,
    statement TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('HARD','HIGH','MEDIUM','LOW')),
    mutable INTEGER NOT NULL DEFAULT 0 CHECK (mutable IN (0,1)),
    rationale TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS evidence (
    id TEXT PRIMARY KEY,
    observed_at TEXT NOT NULL,
    kind TEXT NOT NULL,
    source_path TEXT,
    source_sha256 TEXT,
    statement TEXT NOT NULL,
    confidence TEXT NOT NULL CHECK (confidence IN ('DIRECT','STRONG','INFERRED','HYPOTHESIS')),
    notes TEXT
);

CREATE TABLE IF NOT EXISTS experiments (
    id TEXT PRIMARY KEY,
    observed_at TEXT NOT NULL,
    title TEXT NOT NULL,
    layer TEXT NOT NULL,
    hypothesis TEXT NOT NULL,
    action TEXT NOT NULL,
    result TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('PASS','FAIL','MIXED','RUNNING','SUPERSEDED')),
    reusable_lesson TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS failures (
    id TEXT PRIMARY KEY,
    experiment_id TEXT REFERENCES experiments(id),
    symptom TEXT NOT NULL,
    root_cause TEXT NOT NULL,
    owning_layer TEXT NOT NULL,
    workaround TEXT,
    permanent_fix TEXT,
    state TEXT NOT NULL CHECK (state IN ('OPEN','WORKAROUND','FIXED','AVOID'))
);

CREATE TABLE IF NOT EXISTS experiment_evidence (
    experiment_id TEXT NOT NULL REFERENCES experiments(id),
    evidence_id TEXT NOT NULL REFERENCES evidence(id),
    PRIMARY KEY (experiment_id, evidence_id)
);

CREATE TABLE IF NOT EXISTS architecture_candidates (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    summary TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('PRIMARY','VIABLE','CONDITIONAL','RESEARCH','REJECTED')),
    integration_cost INTEGER NOT NULL CHECK (integration_cost BETWEEN 1 AND 10),
    invention_level INTEGER NOT NULL CHECK (invention_level BETWEEN 1 AND 10),
    expected_control INTEGER NOT NULL CHECK (expected_control BETWEEN 1 AND 10),
    expected_risk INTEGER NOT NULL CHECK (expected_risk BETWEEN 1 AND 10),
    rationale TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS candidate_components (
    candidate_id TEXT NOT NULL REFERENCES architecture_candidates(id),
    component_id TEXT NOT NULL REFERENCES components(id),
    role TEXT NOT NULL,
    required INTEGER NOT NULL DEFAULT 1 CHECK (required IN (0,1)),
    PRIMARY KEY (candidate_id, component_id, role)
);

CREATE TABLE IF NOT EXISTS decisions (
    id TEXT PRIMARY KEY,
    decided_at TEXT NOT NULL,
    decision TEXT NOT NULL,
    rationale TEXT NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('ACTIVE','CONDITIONAL','SUPERSEDED','REJECTED')),
    evidence_id TEXT,
    supersedes TEXT REFERENCES decisions(id)
);

CREATE TABLE IF NOT EXISTS unknowns (
    id TEXT PRIMARY KEY,
    question TEXT NOT NULL,
    owning_layer TEXT NOT NULL,
    blocking INTEGER NOT NULL DEFAULT 0 CHECK (blocking IN (0,1)),
    next_probe TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('OPEN','TESTING','RESOLVED','DEFERRED')),
    resolution TEXT
);

CREATE TABLE IF NOT EXISTS invention_opportunities (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    problem TEXT NOT NULL,
    tftmac_owned_solution TEXT NOT NULL,
    replaces_or_bypasses TEXT NOT NULL,
    benefit TEXT NOT NULL,
    risk TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('RECOMMENDED','VIABLE','RESEARCH','DEFERRED','REJECTED'))
);

CREATE TABLE IF NOT EXISTS paths (
    id TEXT PRIMARY KEY,
    purpose TEXT NOT NULL,
    path TEXT NOT NULL,
    storage_class TEXT NOT NULL CHECK (storage_class IN ('EXTERNAL_BULK','INTERNAL_SMALL','TEMP_ALIAS','SOURCE','RUNTIME','REFERENCE')),
    mandatory INTEGER NOT NULL DEFAULT 0 CHECK (mandatory IN (0,1)),
    fallback_policy TEXT NOT NULL,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS update_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    observed_at TEXT NOT NULL,
    subject TEXT NOT NULL,
    change_summary TEXT NOT NULL,
    evidence_id TEXT REFERENCES evidence(id)
);

CREATE INDEX IF NOT EXISTS idx_components_layer ON components(layer);
CREATE INDEX IF NOT EXISTS idx_dependencies_consumer ON dependencies(consumer_component);
CREATE INDEX IF NOT EXISTS idx_dependencies_provider ON dependencies(provider_component);
CREATE INDEX IF NOT EXISTS idx_experiments_status ON experiments(status);
CREATE INDEX IF NOT EXISTS idx_unknowns_status ON unknowns(status);
CREATE INDEX IF NOT EXISTS idx_evidence_kind ON evidence(kind);

CREATE VIEW IF NOT EXISTS v_open_questions AS
SELECT id, question, owning_layer, blocking, next_probe
FROM unknowns
WHERE status IN ('OPEN','TESTING')
ORDER BY blocking DESC, owning_layer, id;

CREATE VIEW IF NOT EXISTS v_failed_or_workaround_dependencies AS
SELECT d.id,
       c1.name AS consumer,
       c2.name AS provider,
       d.relationship,
       d.compatibility_state,
       d.notes
FROM dependencies d
JOIN components c1 ON c1.id = d.consumer_component
JOIN components c2 ON c2.id = d.provider_component
WHERE d.compatibility_state IN ('FAIL','WORKAROUND','CONDITIONAL')
ORDER BY d.compatibility_state, d.id;

CREATE VIEW IF NOT EXISTS v_architecture_options AS
SELECT id, name, status, integration_cost, invention_level,
       expected_control, expected_risk,
       (expected_control + invention_level) - (integration_cost + expected_risk) AS exploration_score,
       rationale
FROM architecture_candidates
ORDER BY CASE status
           WHEN 'PRIMARY' THEN 0
           WHEN 'VIABLE' THEN 1
           WHEN 'CONDITIONAL' THEN 2
           WHEN 'RESEARCH' THEN 3
           ELSE 4
         END,
         exploration_score DESC;

CREATE VIEW IF NOT EXISTS v_proven_chain AS
SELECT i.id, f.name AS from_name, t.name AS to_name,
       i.interface_type, i.contract, i.state
FROM interfaces i
JOIN components f ON f.id = i.from_component
JOIN components t ON t.id = i.to_component
WHERE i.state IN ('PROVEN','VIABLE')
ORDER BY i.id;

INSERT OR REPLACE INTO map_meta(key, value) VALUES
('schema_version','1'),
('project','TFTMAC'),
('created_at','2026-08-28T05:10:00Z'),
('purpose','Persistent engineering dependency graph and evidence map used to prevent repeated rabbit holes and support invention.'),
('update_rule','Record each material finding, failed path, new dependency, or architecture decision before the next architecture-changing action.'),
('current_phase','Phase 1 source AEMU build / architecture reevaluation'),
('phase0_status','PASS'),
('knowledge_policy','Facts require evidence. Hypotheses stay hypotheses. A workaround must never silently become architecture.'),
('decision_policy','Prefer the smallest owned layer that removes repeated upstream friction. Do not rewrite a proven component merely to avoid one integration bug.');

INSERT OR REPLACE INTO components(id,name,kind,layer,ownership,status,purpose,notes) VALUES
('host_m4','Apple M4 Mac mini','hardware','host','APPLE','PROVEN','Physical host for TFTMAC','Mac16,10, arm64, 16 GB RAM.'),
('macos','macOS 26.6.2','operating_system','host','APPLE','PROVEN','Host operating system','Build 25G83.'),
('xcode','Xcode 26.6','toolchain','host_build','APPLE','PROVEN','Native compiler/toolchain authority','Build 17F113; selected explicitly.'),
('macos_sdk','macOS SDK 26.5','sdk','host_build','APPLE','PROVEN','Host SDK used for AEMU compilation','Located inside Xcode 26.6.'),
('tftmac_harness','TFTMAC build/runtime harness','owned_code','orchestration','TFTMAC','ACTIVE','Own compatibility, evidence, storage, build and runtime orchestration','This is the correct place to absorb stale upstream build-system assumptions.'),
('tftmac_shell','TFTMAC native macOS shell','owned_code','presentation','TFTMAC','AVAILABLE','Native single-window launcher/runtime UI','Existing SwiftUI/Mactician-derived foundation exists.'),
('android_guest','Android 17 Google Play ARM64 guest','guest_os','guest','GOOGLE','PROVEN','Official production Android guest','API 37; Google Play ARM64 ps16k image revision 6.'),
('google_play','Google Play','package_authority','guest','GOOGLE','PROVEN','Authoritative TFT acquisition/update path','Production app authority; avoid third-party APK mirrors.'),
('tft_android','Teamfight Tactics Android client','workload','application','RIOT','AVAILABLE','Primary production workload','Current live package is com.riotgames.league.teamfighttactics. Current evidence says Riot native Android runtime, not Unreal.'),
('aemu','Android Emulator / AEMU','hypervisor_runtime','virtualization','UPSTREAM','ACTIVE','Android machine/runtime host','Authority branch emu-master-dev.'),
('gfxstream','gfxstream','gpu_transport','graphics_transport','UPSTREAM','AVAILABLE','Transports guest graphics/Vulkan to host','Required boundary between guest Vulkan and host Vulkan.'),
('angle','Android built-in ANGLE','graphics_translation','guest_graphics','GOOGLE','PROVEN','GLES to Vulkan translation path','GuestAngle source semantics proven in locked QEMU.'),
('moltenvk_integrated','AEMU-integrated MoltenVK','graphics_translation','host_graphics','UPSTREAM','AVAILABLE','Vulkan to Metal translation used by integrated stack','Exact locked commit recorded.'),
('moltenvk_reference','MoltenVK v1.4.2 reference','reference','host_graphics','KHRONOS','AVAILABLE','Comparison/donor baseline','Do not wholesale replace integrated revision without evidence.'),
('metal','Metal','graphics_api','host_graphics','APPLE','PROVEN','Final Apple GPU API','Target host graphics backend.'),
('vulkan_sdk','Vulkan SDK 1.4.357.0','toolchain','graphics_validation','KHRONOS','PROVEN','Host Vulkan development and validation tools','Installed externally and phase0-vulkan PASS.'),
('qt_regular','AEMU Qt darwin-aarch64 prebuilt','ui_prebuilt','host_ui','UPSTREAM','BLOCKED','AEMU Qt UI package','Package exists but libexec/uic and moc are absent.'),
('qt_noweb','AEMU Qt darwin-aarch64-nowebengine prebuilt','ui_prebuilt','host_ui','UPSTREAM','AVAILABLE','Complete no-WebEngine Qt host tools','Contains qmake, qtpaths, libexec/uic and libexec/moc.'),
('khronos_gles_cts','Khronos GLES CTS','validation','graphics_validation','KHRONOS','AVAILABLE','Generality/conformance evidence','Pinned opengl-es-cts-3.2.14.1.'),
('khronos_vk_cts','Khronos Vulkan CTS','validation','graphics_validation','KHRONOS','AVAILABLE','Vulkan required-case evidence','Pinned vulkan-cts-1.4.6.1.'),
('tftmac_runtime_donor','Existing TFTMAC runtime/emulator donor work','reference','donor','TFTMAC','AVAILABLE','Prior proof that AEMU can build/run on this Apple Silicon host family','Use as donor/evidence, not as unexamined authority.');

INSERT OR REPLACE INTO component_versions(id,component_id,version,commit_sha,artifact_sha256,source_authority,frozen,notes) VALUES
('ver_xcode','xcode','26.6 / 17F113',NULL,NULL,'Apple Xcode installation',1,'Selected /Applications/Xcode-26.6.0.app.'),
('ver_macos_sdk','macos_sdk','26.5',NULL,NULL,'Xcode 26.6',1,'Verified path in STACK.lock.'),
('ver_android_guest','android_guest','API 37 / image rev 6',NULL,NULL,'Google sdkmanager',1,'system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a.'),
('ver_android_platform_tools','android_guest','platform-tools 37.0.1',NULL,NULL,'Google sdkmanager',1,NULL),
('ver_android_emulator_control','aemu','37.1.11 control reference',NULL,NULL,'Google sdkmanager',1,'Control reference is separate from source-built AEMU authority.'),
('ver_qemu','aemu','emu-master-dev','ae9d18d2b6261179fbd57fffec720a04f7bfb053',NULL,'resolved AOSP manifest',1,NULL),
('ver_aemu_common','aemu','locked','3c1ced8a369417db591eb7cd083af5bb2c317975',NULL,'resolved AOSP manifest',1,NULL),
('ver_gfxstream','gfxstream','locked','d047a57228332d995d36600792fa9ccc26cf8ae6',NULL,'resolved AOSP manifest',1,NULL),
('ver_angle','angle','locked','901e32aa9923b05c3a2af846f8a28fc79c93d0be',NULL,'resolved AOSP manifest',1,NULL),
('ver_moltenvk_integrated','moltenvk_integrated','locked','fb26612eb84576adb974fe7f18a49d263072116f',NULL,'resolved AOSP manifest',1,NULL),
('ver_moltenvk_reference','moltenvk_reference','v1.4.2','db66022459ffb663aa2b50f6b018bc2e124f5edf',NULL,'Khronos upstream reference',1,NULL),
('ver_vulkan_sdk','vulkan_sdk','1.4.357.0',NULL,'539433589c83522e6f31b1c7b418a4167e21597a4a361ab119e1dc0760cf3865','LunarG/Khronos',1,NULL),
('ver_gles_cts','khronos_gles_cts','opengl-es-cts-3.2.14.1','067e8832315e79817ede1c4863804e440f5d1c80',NULL,'Khronos',1,NULL),
('ver_vk_cts','khronos_vk_cts','vulkan-cts-1.4.6.1','5c8aae22885448d70a2873e94a93b24b49505c32',NULL,'Khronos',1,NULL);

INSERT OR REPLACE INTO capabilities(id,name,layer,description,acceptance_rule) VALUES
('cap_guestangle','GuestAngle activation','guest_graphics','AEMU configures Android EGL to ANGLE and guest Vulkan path.','Locked-source proof plus runtime boot proof.'),
('cap_gles32','Genuine OpenGL ES 3.2','guest_graphics','Real GLES 3.2 EGL context and required features.','3.2 context creates; GL_VERSION reports ES 3.2; executable feature probes and known frame pass; no nonconformant exposure.'),
('cap_guest_vulkan','Required guest Vulkan','graphics_transport','Guest sees executable Vulkan features required by ANGLE/TFT.','Guest executable probe passes; host-green/guest-red delta is empty for required set.'),
('cap_host_vulkan','Required host Vulkan','host_graphics','MoltenVK exposes and executes required Vulkan features.','Host executable Vulkan probe passes.'),
('cap_metal','Metal rendering','host_graphics','Final Apple GPU rendering backend.','MoltenVK/Metal runtime renders representative workloads.'),
('cap_play_store','Official Play Store update path','application','Official TFT can install/update without binary modification.','Installer is com.android.vending; package identity/signature captured.'),
('cap_native_ui','Native Mac presentation','presentation','One native macOS window hides emulator chrome.','Latency and usability thresholds pass.'),
('cap_source_build','Source-built AEMU','host_build','Locked AEMU source configures, compiles and produces runnable emulator.','Build + tests + boot acceptance pass.');

INSERT OR REPLACE INTO evidence(id,observed_at,kind,source_path,source_sha256,statement,confidence,notes) VALUES
('ev_phase0_pass','2026-08-28T04:32:56.370Z','phase_gate','ssot/preflight-report.md','0ce58e1a891a3a250f1dcca1bccab5ace8c4ae08ed05877dbd0206327081136b','Phase 0 authority/preflight is PASS with no blockers.','DIRECT',NULL),
('ev_stack_lock','2026-08-28T04:32:56.368Z','machine_lock','ssot/STACK.lock.yaml','a570433d39ecebc1f4dc8c9b08e5c92547ab2b91a0826abc6b70b1f725289f2c','Exact host, Android, AEMU, gfxstream, ANGLE, MoltenVK, CTS and performance authority is frozen.','DIRECT',NULL),
('ev_guestangle','2026-08-28T04:03:25.796Z','source_proof','ssot/guestangle-authority.json','d10e51b341852dafb8aa565c8e2d7e48137d6da6e5700f08a733951b8f6b0bee','Locked QEMU source proves GuestAngle sets hardware EGL=angle, requires Vulkan, sets hardware.vulkan=ranchu, and disables nonconformant exposure.','DIRECT',NULL),
('ev_external_storage','2026-08-28T04:32:56.370Z','architecture','TFTMAC_FULL_IMPLEMENTATION_PLAN.md','81bd386c1d9d47f26659c93af914ec9a92568ee689e7bed47eb0f2afd6dd5f1a','Bulk Build and Runtime storage is external under /Volumes/MAC MINI M4/TFTMAC; internal fallback is forbidden.','DIRECT',NULL),
('ev_phase1_configure','2026-08-28T05:07:45Z','build_log','/Volumes/MAC MINI M4/TFTMAC/Build/logs/phase1-build.stdout.log',NULL,'AEMU CMake configuration completed successfully and generated Ninja build files after host-compatibility adaptations.','DIRECT','Build reported Configuring done / Generating done / Build files written.'),
('ev_phase1_compile','2026-08-28T05:07:45Z','build_log','/Volumes/MAC MINI M4/TFTMAC/Build/logs/phase1-build.stdout.log',NULL,'AEMU entered a 9,854-step Ninja compile and compiled real aemu/gfxstream objects.','DIRECT','Observed through at least steps 1-38 before missing ranlib was exposed.'),
('ev_phase1_running','2026-08-28T05:09:15Z','worker_state','/Volumes/MAC MINI M4/TFTMAC/Runtime/Manifests/phase1-build-worker.json',NULL,'After adding the host-tool wrappers, detached Phase 1 worker is RUNNING in BUILD stage.','DIRECT','Do not launch a duplicate build until this worker is reconciled.'),
('ev_qt_layout','2026-08-28T05:01:17Z','filesystem','AEMU Qt prebuilt tree',NULL,'darwin-aarch64 lacks libexec/uic and moc while darwin-aarch64-nowebengine contains them.','DIRECT',NULL),
('ev_tft_native_runtime','2026-08-27T00:00:00Z','package_inspection','docs/TFTMAC_GRAPHICS_ARCHITECTURE.md',NULL,'Current official TFT Android package contains Riot native runtime evidence and no libUnreal.so/UECommandLine.txt evidence.','STRONG','Treat current client as Riot native Android runtime unless a future package inspection changes this.');

INSERT OR REPLACE INTO constraints(id,category,statement,severity,mutable,rationale) VALUES
('con_external_bulk','storage','Build and Runtime bulk data must live on /Volumes/MAC MINI M4/TFTMAC and must never silently fall back to the internal disk.','HARD',0,'Internal disk exhaustion already caused Phase 0 source failure and wasted recovery time.'),
('con_no_spoof','graphics_truth','Do not satisfy GLES 3.2 by property/version spoof or exposeNonConformantExtensionsAndVersions.','HARD',0,'The product must provide real executable graphics capability.'),
('con_no_riot_patch','workload_integrity','Do not modify or re-sign Riot binaries.','HARD',0,'Preserves app integrity and package authority.'),
('con_play_authority','package_authority','Google Play is production TFT install/update authority.','HIGH',0,'Avoids mirror drift and unverifiable package provenance.'),
('con_one_layer','debug_method','Repair the first boundary where evidence changes from PASS to FAIL.','HIGH',0,'Prevents broad speculative patching.'),
('con_update_map','process','Every material finding must be inserted into this engineering map before the next architecture-changing action.','HIGH',0,'Prevents repeated rabbit holes and lost causal information.'),
('con_no_duplicate_build','process','Do not start another Phase 1 build while the detached worker is alive.','HIGH',1,'Avoids corrupting evidence and wasting CPU/storage.'),
('con_owned_harness','architecture','Stale upstream build-system compatibility belongs in TFTMAC-owned harness code unless runtime behavior itself requires an upstream source change.','HIGH',1,'Separates build plumbing from graphics/runtime invention.');

INSERT OR REPLACE INTO interfaces(id,from_component,to_component,interface_type,contract,state,notes) VALUES
('if_tft_angle','tft_android','angle','GLES','TFT requests GLES through Android graphics stack.','VIABLE','Exact required feature set still needs runtime probe.'),
('if_angle_vk','angle','gfxstream','Vulkan guest path','GuestAngle uses Vulkan/ranchu path.','PROVEN','Source semantics proven; runtime execution remains Phase 5 evidence.'),
('if_gfx_mvk','gfxstream','moltenvk_integrated','host Vulkan','gfxstream host Vulkan calls reach MoltenVK.','VIABLE','Exact required feature delta to be measured.'),
('if_mvk_metal','moltenvk_integrated','metal','Metal','MoltenVK translates Vulkan to Metal.','VIABLE',NULL),
('if_play_tft','google_play','tft_android','package install/update','Official package acquisition and updates.','PROVEN',NULL),
('if_shell_aemu','tftmac_shell','aemu','runtime control','Native shell launches/controls emulator and later consumes authenticated control/video interfaces.','VIABLE',NULL),
('if_harness_aemu','tftmac_harness','aemu','build compatibility','Owned harness adapts stale AEMU build assumptions to current Apple/Xcode/storage environment.','PROVEN','This has already turned impossible configuration into a real 9,854-step build.');

INSERT OR REPLACE INTO dependencies(id,consumer_component,provider_component,relationship,required,compatibility_state,evidence_id,notes) VALUES
('dep_aemu_xcode','aemu','xcode','native compiler/toolchain',1,'WORKAROUND','ev_phase1_configure','Locked AEMU helper predates Xcode 26.6/macOS SDK 26.5; TFTMAC harness bridges the gap.'),
('dep_aemu_sdk','aemu','macos_sdk','host SDK',1,'WORKAROUND','ev_phase1_configure','Upstream helper recognized SDKs only through 15.2 and parsed new xcodebuild output incorrectly.'),
('dep_aemu_qt','aemu','qt_regular','host UI tools',1,'WORKAROUND','ev_qt_layout','Regular Darwin ARM64 Qt package lacks libexec/uic/moc; temporary bridge from sibling nowebengine package works.'),
('dep_aemu_qt_noweb','aemu','qt_noweb','host UI tools donor',1,'PASS','ev_qt_layout','Provides qmake, qtpaths, uic and moc.'),
('dep_aemu_harness','aemu','tftmac_harness','host compatibility',1,'PASS','ev_phase1_compile','Owned harness solves path-space, Path typing, SDK parser, Xcode selection, compiler wrappers, Qt host tools and binutils without changing emulator graphics behavior.'),
('dep_angle_guestvk','angle','gfxstream','guest Vulkan transport',1,'CONDITIONAL','ev_guestangle','Source authority proves required path exists; executable feature parity still to be measured.'),
('dep_gfx_mvk','gfxstream','moltenvk_integrated','host Vulkan provider',1,'UNKNOWN',NULL,'Phase 2/3 probes must identify exact host/guest feature delta.'),
('dep_mvk_metal','moltenvk_integrated','metal','Apple GPU backend',1,'PASS',NULL,'Known architectural role; executable required-feature proof still pending.'),
('dep_tft_gles32','tft_android','angle','GLES 3.2 capability',1,'UNKNOWN',NULL,'Must be proven by real EGL 3.2 context and TFT workload.'),
('dep_tft_play','tft_android','google_play','install/update authority',1,'PASS',NULL,NULL);

INSERT OR REPLACE INTO component_capabilities(component_id,capability_id,state,evidence_id,notes) VALUES
('aemu','cap_source_build','PARTIAL','ev_phase1_compile','CMake config succeeds and real compile starts; full build/test/boot not yet complete.'),
('angle','cap_guestangle','PASS','ev_guestangle','Locked-source semantics proven.'),
('android_guest','cap_play_store','PASS','ev_stack_lock','Official Google Play image revision 6.'),
('moltenvk_integrated','cap_host_vulkan','UNKNOWN',NULL,'Requires executable probe.'),
('gfxstream','cap_guest_vulkan','UNKNOWN',NULL,'Requires host-vs-guest delta probe.'),
('angle','cap_gles32','UNKNOWN',NULL,'Do not infer from properties.'),
('metal','cap_metal','EXPECTED',NULL,'Final backend; runtime proof pending.'),
('tftmac_shell','cap_native_ui','EXPECTED',NULL,'Later phase after runtime capability is green.');

INSERT OR REPLACE INTO experiments(id,observed_at,title,layer,hypothesis,action,result,status,reusable_lesson) VALUES
('exp_phase0','2026-08-28T04:32:56Z','Freeze Phase 0 authority','system','Exact versions and source authority can be made deterministic before mutation.','Resolved host/Android/AEMU/MoltenVK/CTS inputs and generated locked artifacts.','Phase 0 PASS with no blockers.','PASS','Freeze facts first; implementation should not carry version ambiguity.'),
('exp_internal_disk','2026-08-27T00:00:00Z','AEMU source sync on internal disk','storage','Default Application Support Build root is sufficient.','repo sync used internal Build root.','Failed with No space left on device.','FAIL','Bulk build/source data cannot live on the internal disk.'),
('exp_external_migration','2026-08-28T00:00:00Z','Move Build root to external M4','storage','AEMU source can be preserved intact on external storage without a symlinked Xcode Developer tree.','Migrated Build intact and made external root mandatory.','Verified migration; Phase 0 source resumed and completed.','PASS','External storage is viable and should be explicit, not a hidden symlink fallback.'),
('exp_space_path','2026-08-28T04:40:00Z','Run AEMU rebuild from external path with spaces','host_build','Upstream rebuild.sh handles a normal macOS volume path with spaces.','Ran rebuild.sh from /Volumes/MAC MINI M4/...','Shell expanded bundled Python path incorrectly and attempted /Volumes as command.','FAIL','Legacy AEMU shell tooling is not space-safe.'),
('exp_temp_alias','2026-08-28T04:44:00Z','No-space temporary AEMU alias','host_build','A no-space alias can isolate legacy path parsing while keeping bytes external.','Created /private/tmp/tftmac-aemu symlink to external AEMU tree.','Useful but AEMU Python driver canonicalized paths unless explicit --aosp was supplied.','MIXED','Temporary aliases work only if every owning tool is forced to consume the alias.'),
('exp_aosp_type','2026-08-28T04:46:00Z','Explicit --aosp override','host_build','Supplying the no-space alias through --aosp will preserve it.','Passed --aosp /private/tmp/tftmac-aemu.','Driver crashed because argparse returns str while code assumes pathlib.Path.','FAIL','AEMU build driver contains a concrete type bug; compatibility shim can repair this without source fork.'),
('exp_sdk265','2026-08-28T04:51:00Z','Use Xcode 26.6 / SDK 26.5 with locked AEMU','host_build','Old AEMU helper can use current Xcode directly.','Ran CMake driver under selected Xcode 26.6.','Helper recognized SDKs only through 15.2 and parsed current xcodebuild output incorrectly.','FAIL','Modern-host support should be owned by a narrow TFTMAC compatibility layer.'),
('exp_xcode_clang','2026-08-28T04:56:00Z','Use Xcode Clang instead of absent AOSP macOS Clang prebuilt','host_build','Current Xcode compiler can satisfy native AEMU toolchain.','Preseeded compiler wrappers around Xcode clang/clang++.','CMake identified AppleClang 21 and passed compiler ABI checks.','PASS','The resolved manifest does not need a separate macOS Clang prebuilt for native build if TFTMAC owns correct wrappers.'),
('exp_qt_tools','2026-08-28T05:01:00Z','Resolve Qt uic/moc failure','host_build','Required Qt host tools may already exist elsewhere in the manifest.','Inspected Qt prebuilt layouts.','nowebengine sibling contains uic/moc; regular darwin-aarch64 does not.','PASS','Before downloading a dependency, map sibling prebuilts and reuse compatible host-only tools.'),
('exp_webengine_force','2026-08-28T05:05:00Z','Disable unnecessary QtWebEngine','host_build','CLI flag should select no-WebEngine Qt.','Tested branch behavior and inspected configure.py.','Darwin branch hardcodes QTWEBENGINE=True; compatibility launcher override removes injection.','PASS','Stale policy in build orchestration should be bypassed in TFTMAC harness rather than accepted as architecture.'),
('exp_qt_bridge','2026-08-28T05:07:00Z','Bridge Qt libexec host tools','host_build','Host-only uic/moc from sibling Qt package can satisfy regular package configuration.','Temporarily bridged darwin-aarch64/libexec to darwin-aarch64-nowebengine/libexec.','CMake configured completely and generated 9,854 Ninja build steps.','PASS','A narrow host-tool bridge is enough; no Qt rebuild/download required.'),
('exp_host_binutils','2026-08-28T05:09:00Z','Provide Darwin host binutils wrappers','host_build','Compile failure at ranlib is another missing wrapper, not source incompatibility.','Preseeded ranlib/ar/nm/strip/ld/libtool/strings/otool/install_name_tool/dsymutil wrappers from Xcode/macOS.','Detached build remains alive in BUILD stage after prior ranlib failure.','RUNNING','Provide the complete host-tool contract once, not one tool at a time.');

INSERT OR REPLACE INTO experiment_evidence(experiment_id,evidence_id) VALUES
('exp_phase0','ev_phase0_pass'),
('exp_xcode_clang','ev_phase1_configure'),
('exp_qt_tools','ev_qt_layout'),
('exp_qt_bridge','ev_phase1_configure'),
('exp_qt_bridge','ev_phase1_compile'),
('exp_host_binutils','ev_phase1_running');

INSERT OR REPLACE INTO failures(id,experiment_id,symptom,root_cause,owning_layer,workaround,permanent_fix,state) VALUES
('fail_internal_space','exp_internal_disk','repo sync failed with No space left on device','Bulk AEMU Build/source lived on internal disk.','storage','Move Build/Runtime roots to external M4.','External roots are now architecture authority and internal fallback is forbidden.','FIXED'),
('fail_space_unsafe_shell','exp_space_path','rebuild.sh attempted to execute /Volumes','Unquoted legacy shell expansion cannot handle spaces in volume path.','host_build','Use no-space execution alias and argument-safe process APIs.','Keep upstream shell wrappers out of TFTMAC critical path.','WORKAROUND'),
('fail_aosp_str_path','exp_aosp_type','unsupported operand type(s) for /: str and str','AEMU --aosp argparse value is str but code later assumes Path.','host_build','Compatibility launcher converts aosp/out/dist arguments to pathlib.Path.','Owned build adapter should normalize upstream argument types.','WORKAROUND'),
('fail_sdk_parser','exp_sdk265','No supported OSX SDK found despite SDK 26.5 installed','Old helper support list ends at 15.2 and xcodebuild parser does not understand Xcode 26 output.','host_build','Temporary helper adaptation uses xcrun, SDK 26.5 and selected DEVELOPER_DIR.','Move host version detection into TFTMAC harness and pass resolved values downstream.','WORKAROUND'),
('fail_missing_host_clang','exp_xcode_clang','Generated toolchain lacked gcc/g++ wrappers','Resolved manifest has no matching AOSP macOS Clang prebuilt for stale helper assumption.','host_build','Generate wrappers targeting Xcode 26.6 clang/clang++.','Own a deterministic macOS host toolchain adapter.','WORKAROUND'),
('fail_qt_uic','exp_qt_tools','Qt6::uic missing at regular Darwin ARM64 prebuilt path','Regular Qt package lacks libexec host tools; sibling nowebengine package contains them.','host_build','Temporary libexec bridge to sibling package.','Teach harness to resolve Qt host tools by capability rather than hardcoded package directory.','WORKAROUND'),
('fail_webengine_forced','exp_webengine_force','QTWEBENGINE=True emitted even when WebEngine not requested','configure.py hardcodes WebEngine on Darwin targets.','host_build','Compatibility launcher overrides with_webengine for Phase 1.','Owned build adapter should express actual product requirement instead of inherited stale defaults.','WORKAROUND'),
('fail_ranlib','exp_host_binutils','Ninja failed linking static libraries because toolchain/ranlib was missing','Legacy generator omitted required Darwin binutils wrappers.','host_build','Preseed complete host-tool wrapper set.','Own the entire host-tool contract in the TFTMAC build adapter.','WORKAROUND');

INSERT OR REPLACE INTO decisions(id,decided_at,decision,rationale,state,evidence_id,supersedes) VALUES
('dec_external_storage','2026-08-28T04:32:56Z','External M4 is mandatory Build/Runtime storage authority.','Internal storage exhaustion was proven and external migration completed successfully.','ACTIVE','ev_external_storage',NULL),
('dec_locked_aemu','2026-08-28T04:32:56Z','Use one frozen emu-master-dev manifest as AEMU source authority.','Prevents mixing branch behavior and makes capability evidence reproducible.','ACTIVE','ev_stack_lock',NULL),
('dec_guestangle_primary','2026-08-28T04:03:25Z','Built-in Android ANGLE via GuestAngle remains the primary GLES path.','Locked source proves correct EGL/Vulkan/nonconformant semantics.','ACTIVE','ev_guestangle',NULL),
('dec_host_compat_owned','2026-08-28T05:09:00Z','Treat stale macOS AEMU build plumbing as a TFTMAC-owned compatibility layer, not as graphics architecture.','Multiple failures were build-system assumptions; the same source progressed once the harness supplied modern host contracts.','ACTIVE','ev_phase1_compile',NULL),
('dec_no_full_rewrite_yet','2026-08-28T05:10:00Z','Do not rewrite the Android emulator/runtime yet.','AEMU has now fully configured and entered real compilation; the difficult failures so far are host-build integration, not proof that AEMU runtime architecture is unusable.','ACTIVE','ev_phase1_compile',NULL),
('dec_invention_allowed','2026-08-28T05:10:00Z','New TFTMAC-owned code is preferred where it can replace repeated brittle upstream adaptation with a small stable contract.','The build adapter already demonstrates that invention at the right boundary can remove multiple unrelated blockers.','ACTIVE','ev_phase1_compile',NULL);

INSERT OR REPLACE INTO architecture_candidates(id,name,summary,status,integration_cost,invention_level,expected_control,expected_risk,rationale) VALUES
('arch_a','Locked AEMU + TFTMAC compatibility/build adapter','Keep AEMU/gfxstream/ANGLE/MoltenVK runtime architecture, but own the macOS build/runtime compatibility boundary in TFTMAC instead of relying on stale upstream helper assumptions.','PRIMARY',5,5,8,4,'Current evidence strongly supports this: locked source fully configured and entered real compilation once the owned adapter supplied modern host contracts.'),
('arch_b','Stock Google emulator + TFTMAC native shell','Use official emulator binary wherever its graphics capability is already sufficient; avoid source build unless a measured capability gap requires source control.','VIABLE',2,2,4,3,'Could dramatically reduce maintenance if stock emulator passes the future Vulkan/GLES probes. Must be decided by capability evidence, not convenience.'),
('arch_c','Hybrid stock AEMU + TFTMAC-owned graphics adapter','Keep machine/runtime from official AEMU but own only the minimum graphics bridge/driver integration required to supply missing guest capability.','RESEARCH',6,7,9,6,'Potentially a better long-term product if the failure is isolated to graphics transport, but feasibility depends on extension points discovered in Phase 2-5.'),
('arch_d','Google Play authority guest + custom execution guest','Use official Play guest for package/update authority and a controlled execution guest only if built-in ANGLE is proven to be the remaining blocker.','CONDITIONAL',7,6,8,7,'Already defined as a conditional path. Do not build unless guest Vulkan is green and built-in ANGLE is causally red.'),
('arch_e','TFTMAC-owned minimal Android VM/runtime','Replace substantial AEMU machinery with owned virtualization/device/runtime code.','RESEARCH',10,10,10,10,'This is true invention but enormous scope: CPU/VM, devices, Binder/Android boot, graphics, input, audio, Play compatibility. Only rational if AEMU runtime itself is proven unworkable, which has not happened.'),
('arch_f','Native/non-Android TFT translation layer','Run/translate TFT without Android runtime.','REJECTED',10,10,10,10,'Would require recreating Android/Riot runtime assumptions and likely package/update/security behavior. Current evidence gives no reason to choose this over a functioning Android guest architecture.'),
('arch_g','Reuse existing TFTMAC-runtime donor emulator','Harvest known-good prior AEMU build/signing/launch solutions from the separate donor project where versions/components align.','VIABLE',3,2,5,3,'Can reduce duplicate discovery. Must compare exact versions and copy only compatible causal fixes.');

INSERT OR REPLACE INTO candidate_components(candidate_id,component_id,role,required) VALUES
('arch_a','aemu','Android runtime',1),
('arch_a','gfxstream','GPU transport',1),
('arch_a','angle','GLES translation',1),
('arch_a','moltenvk_integrated','Vulkan-to-Metal',1),
('arch_a','tftmac_harness','Owned host compatibility boundary',1),
('arch_a','tftmac_shell','Native product surface',1),
('arch_b','aemu','Official prebuilt emulator runtime',1),
('arch_b','tftmac_shell','Native product surface',1),
('arch_c','aemu','Machine/runtime host',1),
('arch_c','tftmac_harness','Owned runtime/graphics integration',1),
('arch_c','gfxstream','Potential replace/extend boundary',1),
('arch_d','android_guest','Package authority guest',1),
('arch_d','angle','Potential custom execution ANGLE',1),
('arch_g','tftmac_runtime_donor','Prior solution donor',1);

INSERT OR REPLACE INTO unknowns(id,question,owning_layer,blocking,next_probe,status,resolution) VALUES
('unk_phase1_result','Does the current 9,854-step AEMU build complete with the full host-tool wrapper set?','host_build',1,'Reconcile the existing detached worker; do not start another build.','TESTING',NULL),
('unk_stock_capability','Does official Emulator 37.1.11 already provide every required guest Vulkan/GLES capability for current TFT?','graphics_capability',0,'Run the permanent host/guest Vulkan and GLES probes against stock control runtime before choosing source patches.','OPEN',NULL),
('unk_host_vulkan_delta','Which required Vulkan features are missing on integrated MoltenVK?','host_graphics',0,'Run executable host Vulkan probe against integrated MoltenVK and v1.4.2 reference.','OPEN',NULL),
('unk_transport_delta','Which host-green Vulkan features become guest-red through gfxstream?','graphics_transport',0,'Run guest Vulkan probe and compare structured deltas.','OPEN',NULL),
('unk_angle32','After Vulkan is correct, will built-in Android 17 ANGLE create a genuine ES 3.2 context?','guest_graphics',0,'Run guest GLES 3.2 executable probe without nonconformant exposure.','OPEN',NULL),
('unk_tft_exact_req','What exact graphics/runtime requirement makes current TFT pass or fail after genuine GLES 3.2 is available?','application',0,'Launch current official Play TFT only after general probes are green and capture precise failure boundary.','OPEN',NULL),
('unk_donor_reuse','Which fixes from tftmac-runtime are version-compatible with this locked AEMU family?','donor_analysis',0,'Diff exact build/runtime approaches against current commits and classify reusable vs stale.','OPEN',NULL),
('unk_owned_gpu_bridge','Can gfxstream/MoltenVK be isolated behind a smaller TFTMAC-owned adapter while retaining stock AEMU machine/runtime?','architecture',0,'Map AEMU graphics plugin/host interfaces after Phase 2 capability evidence.','OPEN',NULL);

INSERT OR REPLACE INTO invention_opportunities(id,title,problem,tftmac_owned_solution,replaces_or_bypasses,benefit,risk,status) VALUES
('inv_build_adapter','TFTMAC Host Build Adapter','AEMU build helpers encode stale assumptions about paths, SDK versions, Clang prebuilts, Qt layout and Darwin tools.','Create a first-class TFTMAC-owned macOS build adapter that resolves Xcode/SDK/tool paths, creates a no-space execution view, supplies compiler/binutils wrappers, resolves Qt tools by capability, and invokes CMake directly.','rebuild.sh, stale SDK parser, stale toolchain wrapper generator, stale WebEngine policy','Turns repeated build rabbit holes into one stable host contract and keeps upstream runtime source clean.','Must track upstream CMake contract changes.','RECOMMENDED'),
('inv_capability_graph','Executable Capability Graph','Graphics decisions are currently spread across components and guesses.','Represent each required GLES feature as a dependency on concrete guest Vulkan, gfxstream and host Vulkan capabilities, with probe results updating graph edges.','human memory and broad trial-and-error patching','Makes causal failure routing mechanical and exposes smallest code layer to invent or patch.','Requires disciplined probe schema.','RECOMMENDED'),
('inv_runtime_adapter','TFTMAC Graphics Runtime Adapter','If stock AEMU is good except for a narrow graphics boundary, rebuilding all AEMU may be unnecessary.','Define a TFTMAC-owned interface around host Vulkan/gfxstream integration and replace only the proven failing sublayer.','full emulator forks for graphics-only defects','Could reduce long-term maintenance while preserving official Android machine behavior.','Feasibility unknown until interfaces are mapped.','RESEARCH'),
('inv_package_execution_split','Package Authority / Execution Split','A custom execution environment may conflict with Google Play/root constraints.','Keep official Play guest as package authority and copy verified official splits to a controlled execution guest only when necessary.','forcing one guest to satisfy mutually incompatible package-authority and driver-injection requirements','Preserves official package provenance while enabling controlled graphics experimentation.','Complexity and app integrity/runtime compatibility.','VIABLE'),
('inv_probe_first_release','Probe-First Runtime Promotion','Game launch currently risks becoming the diagnostic tool for the entire graphics stack.','Make host Vulkan, guest Vulkan and GLES probes mandatory runtime promotion gates; TFT is only the final workload.','game-driven debugging','Prevents Riot/TFT behavior from obscuring lower-layer defects and makes future game updates diagnosable.','Requires maintaining representative probes.','RECOMMENDED');

INSERT OR REPLACE INTO paths(id,purpose,path,storage_class,mandatory,fallback_policy,notes) VALUES
('path_build','AEMU source/build bulk data','/Volumes/MAC MINI M4/TFTMAC/Build','EXTERNAL_BULK',1,'FAIL_CLOSED','Never fall back to internal disk.'),
('path_runtime','Android SDK/AVD/packages/probes/runtime bulk data','/Volumes/MAC MINI M4/TFTMAC/Runtime','EXTERNAL_BULK',1,'FAIL_CLOSED','Never fall back to internal disk.'),
('path_logs','Small TFTMAC control/log state','~/Library/Application Support/TFTMAC/Logs','INTERNAL_SMALL',0,'ALLOW_INTERNAL_SMALL','Do not place bulk compiler/runtime data here.'),
('path_diag','Small diagnostics metadata','~/Library/Application Support/TFTMAC/Diagnostics','INTERNAL_SMALL',0,'ALLOW_INTERNAL_SMALL',NULL),
('path_aemu_alias','Space-free execution alias','/private/tmp/tftmac-aemu','TEMP_ALIAS',0,'RECREATE','Alias only; bytes remain on external M4.'),
('path_repo','TFTMAC managed worktree','/Volumes/MAC MINI M4/Clara/Worktrees/flashls1--tftmac/tftmac--7774a669-d9f7-4188-a1d4-fa185fb7eec8','SOURCE',1,'NONE',NULL);

INSERT INTO update_log(observed_at,subject,change_summary,evidence_id) VALUES
('2026-08-28T05:10:00Z','Engineering process','Created persistent SQL engineering map to replace memory-driven integration work.',NULL),
('2026-08-28T05:10:00Z','Architecture','Reclassified repeated Phase 1 failures as host-build compatibility defects rather than evidence that the AEMU runtime architecture is invalid.','ev_phase1_compile'),
('2026-08-28T05:10:00Z','Invention direction','Promoted TFTMAC-owned Host Build Adapter and Executable Capability Graph as recommended owned-code opportunities.','ev_phase1_compile');

COMMIT;

-- Recommended queries during every future work session:
--
--   SELECT * FROM v_open_questions;
--   SELECT * FROM v_failed_or_workaround_dependencies;
--   SELECT * FROM v_architecture_options;
--   SELECT * FROM v_proven_chain;
--   SELECT * FROM experiments ORDER BY observed_at DESC;
--
-- Before an architecture-changing action:
--   1. Insert/update the new evidence.
--   2. Update the experiment or dependency edge it affects.
--   3. Resolve or create the corresponding unknown.
--   4. Re-query v_architecture_options and v_open_questions.
--   5. Only then choose the next mutation.
