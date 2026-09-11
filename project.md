# TFTMAC Project Record

> **LIVING WIKI / CURRENT DEV STATE — updated 2026-09-11 America/Chicago.** This top section is the current mutable project state. Older dated sections below are preserved as project history and must not override this section when they conflict with newer verified evidence.

**Project:** native macOS TFT client experience using the official Android TFT package  
**Current development line:** `master` remains merged repository authority. OvernightLab authority reconciliation change `ff2f318b-245d-418a-b86f-e07d55b19826` merged through PR #9 at `bf61c21a723f2f132834acedda860efbb2223d42` and is closed. Current post-merge continuity/live-layer recovery is isolated in Clara change `b42fb30e-2f22-45f0-9d27-00d9e67a58bf`; it does not admit a new performance candidate.  
**Protected release/LKG:** TFTMAC 2.3.0 build 8 Control/LKG remains separate, frozen, and available as historical rollback/comparison authority.  
**Current DEV application identity:** TFTMAC 2.3.0 build 8 DEV (`/Applications/TFTMAC DEV.app`, bundle `com.flashls1.tftmac.dev`). Test-ledger versions do not change the product release number.  
**Current official client:** `com.riotgames.league.teamfighttactics` `18.1-5423749`, versionCode `8423749`.  
**Current test series:** `DEV-B8-2026-09-10-A`.  
**Current verified working winner:** **`DEV-B8-WIN-01`**.  
**Project record current through:** 2026-09-11 post-PR-#9 authority rehydration; performance winner remains the 2026-09-10 results-first verification state.

## 0. Living wiki contract

This file is the project wiki/continuity SSOT for the **current** TFTMAC DEV state. It must answer, without reconstructing old chats: what the project is, what is currently installed/running, what the latest verified working configuration is, what version/test series is active, which improvements have been integrated, which candidates are rejected or unresolved, and what baseline the next test must use.

Mandatory companion records:

- `facts.md` — hard facts, boundaries, mandatory authority rules.
- `CHANGELOG.md` — detailed append-only experiment/version ledger with every completed test, measured outcome, integration YES/NO, reasoning, and rollback result.
- `.clara/plans/ff2f318b-245d-418a-b86f-e07d55b19826/RECOVERY_CONSTRAINTS_2026-09-10.md` — active results-first execution constraints for this pass.

**Authority/finalization gate:** `facts.md` is read first and this living wiki must agree with it. Before any plan, change scope, promotion, or completion is finalized, re-read both files. If credible newer machine/runtime evidence conflicts, validate that evidence, update `facts.md` and this wiki first, then finalize the plan/change. Do not select an older plan, handoff, test file, or SSOT/reference document over current `facts.md` without reconciliation.

**Workspace completion gate:** a selected managed change is not finished while its worktree is accidentally dirty. Preserve intended work, remove/restore transient generated files without destroying external authoritative evidence, and finish with clean Git status. Preserve unrelated managed work rather than deleting it.

### Current effective DEV hardware/runtime truth

- Host: Apple M4 Mac mini with **10 physical CPU cores (4 performance + 6 efficiency)** and 16 GiB unified memory.
- Guest: current verified DEV launches use **8 virtual CPUs** (`-cores 8`) and **6144 MiB / 6 GiB guest RAM** (`-memory 6144`). Eight vCPUs do not mean eight dedicated physical host cores; macOS/Hypervisor scheduling remains host-owned.
- Static StockShadow AVD restoration file remains `hw.cpu.ncore=6` / `hw.ramSize=5120` at the accepted baseline SHA. That static file is not the effective current DEV launch: `RuntimeModeAuthority.swift` defaults `advanced_diagnostics` to 8 vCPU, the locked DEV profile supplies 6144 MiB, and live QEMU receipts prove 8/6144.
- Current client: `18.1-5423749` / `8423749`.
- Current game RHI: **OpenGL ES through ANGLE**, with Vulkan/gfxstream/MoltenVK/Metal below it.

### Current DEV working configuration — `DEV-B8-WIN-01`

- 1920x1080, 320 DPI, 60 Hz.
- 8 vCPU, 6144 MiB guest RAM, host GPU.
- OpenGL through ANGLE remains the selected game route.
- `debug.egl.blobcache.multifile=true`.
- `debug.angle.feature_overrides_enabled=exposeNonConformant*:exposeES32ForTesting`.
- `debug.angle.feature_overrides_disabled=preferSubmitAtFBOBoundary`.
- **`syncMonolithicPipelinesToBlobCache` is removed from the preferred working configuration.**
- This is a verified net frame-pacing/tail-latency improvement: the exact 1-5 30-window comparison showed p95 15.9% better, p99 19.4% better, jank/window 67.9% lower, missed-vsync/window 70.3% lower, severe intervals 1 vs 7, and worst interval 42.2% better, with mean FPS 1.5% lower at that stage; earlier 1-2 and 1-4 comparisons also improved mean FPS.

### Current promotion/versioning model

1. Start every new candidate from the latest verified DEV winner, currently `DEV-B8-WIN-01`, not from the frozen LKG unless a matched historical control is specifically required.
2. Change/test one primary hypothesis at a time. Add only a directly-related minimal blocker adjustment when concrete evidence says the intended candidate cannot otherwise execute.
3. Evaluate net system/gameplay improvement, not FPS alone. FPS is heavily weighted, alongside frame pacing, p95/p99/worst-frame latency, jank, missed-vsync, CPU/RHI efficiency, memory behavior, allocation/churn, stalls, input responsiveness, correctness, stability, and compatibility.
4. **VERIFIED NET IMPROVEMENT:** integrate it, assign the next `DEV-B8-WIN-##`, update this wiki and `CHANGELOG.md`, then test the next candidate on top of the new winner.
5. **NOT VERIFIED / INCONCLUSIVE / REGRESSION:** record it in `CHANGELOG.md`, do not integrate it, retain/restore the latest verified winner here, and move forward.
6. Compounding/synergy is desirable but must be measured. A prior verified win remains integrated while the next factor is tested; the combined configuration must itself verify before promotion.
7. Never rewrite the frozen LKG to match the DEV winner. LKG is historical control/rollback; DEV is the evolving optimization line.

### Current completed-test state

- `cache-no-global-sync` — **VERIFIED WIN / INTEGRATED** as `DEV-B8-WIN-01`.
- Buffer-view retention (`dev-observed-reuse-cache-r14`) — **NO WIN / NOT INTEGRATED**.
- Direct Vulkan — **NO WIN / NOT INTEGRATED** for the fast-pass; compatibility failure path preserved.
- Queue Submit Inline — **NO WIN / BOOT-INCOMPATIBLE / NOT INTEGRATED**.
- Virtual Queue Off — **NO WIN / NOT INTEGRATED** from prior official-client combat result.
- Fence Contexts Off — **NO WIN / NOT INTEGRATED** from prior official-client combat result.
- ASG draw flush 400 µs — historical/experimental; **not reopened in this pass**.
- Inverse `preferSubmitAtFBOBoundary` check — **INCONCLUSIVE / NOT ACTUALLY APPLIED / NOT INTEGRATED**.

The exact measurements and reasoning for each entry live in `CHANGELOG.md`; this wiki carries only the current state needed to choose the next action correctly.

### OvernightLab current role — reconciled 2026-09-10

OvernightLab is retained as a **data-preserving telemetry/provenance layer**, not as an autonomous candidate factory. Its current authority is `DEV-B8-WIN-01`, 8 vCPU / 6144 MiB, official TFT `18.1-5423749`, and OpenGL ES through ANGLE.

- The automatic candidate queue contains only the current working control until a new one-factor candidate is deliberately admitted.
- Resolved candidates remain in the manifest with their result/status so historical work is searchable but not silently rerun.
- Minor configuration drift such as CPU/RAM differences does not erase telemetry; the run is retained as `DATA_ONLY_NONCOMPARABLE` unless a valid matched comparison supports current promotion.
- Wrong current-client identity or wrong selected core RHI/pipeline stops the current experiment after identity is recorded; its raw evidence remains available for forensic/historical analysis but cannot promote a DEV winner.
- Root-only cache file inventory is opt-in; ordinary performance logging relies on property readback and native telemetry so the observer does not restart/disrupt ADB just to collect optional metadata.
- The frozen LKG cache set with global pipeline sync remains historical comparator data. OvernightLab's normal control now applies the WIN-01 cache properties with global sync removed.
- Generated campaigns, SQLite state, compiled caches/binaries and reports are runtime evidence, not repository source; they must remain locally retained/ignored rather than continually dirtying Git.

### Mandatory update rule after every test

After **every completed DEV optimization test**, before moving to the next candidate:

- update `CHANGELOG.md` with exact delta, workload/stage, result, key metrics, net decision, integration YES/NO, reasoning, and rollback/integrity state;
- update `project.md` if the current winner, working configuration, test-series state, rejected/unresolved list, runtime/client identity, or next-test baseline changed;
- update `facts.md` if and only if a current hard fact, mandatory process rule, runtime/client identity, protected boundary, or authoritative configuration changed;
- preserve detailed historical evidence rather than deleting/rewording old results into a new conclusion;
- do not begin the next test with stale record books.

This is the continuity document for a new developer or a new chat. Older architecture/history below remains useful background. Exact benchmark formulas and current run findings also live in `benchmark.md`; engineering hypotheses and next code work live in `dev.md`.

## 1. Goal

Deliver a premium native Mac application that lets the user launch, log into,
hear, and play official Teamfight Tactics fullscreen on the target M4 Mac mini.
The Android emulator is part of the runtime implementation but is not exposed as
the product UI. The application must also be an engineering laboratory that
captures the complete runtime behavior well enough to make and reject graphics-
pipeline changes based on evidence.

The completion standard is not “the emulator process exists” and not “the lobby
shows 60 FPS.” The user must be able to play through the native Mac window, and
the logger must preserve every under-target period across the complete run. The
graphics target is at least 60 useful FPS throughout, not only during selected
scenes.

## 2. Current architecture

```text
/Applications/TFTMAC.app
  -> AppKit window, menus, fullscreen space, settings and benchmark controls
  -> native Metal presenter and gameplay-cadence overlay
  -> authenticated loopback EmulatorController gRPC
  -> packaged TFTMAC Emulator Host.app
  -> /usr/bin/open -n -W --env ... --args ...
  -> stock Android Emulator 37.1.11 / TFT_Ultra_Tablet
  -> official API 36 Google Play ARM64 guest
  -> official Google Play TFT package
  -> Riot login, Unreal GameActivity, live TFT gameplay
```

Runtime files live on the external volume at
`/Volumes/MAC MINI M4/TFTMAC/Runtime`. Captures and the normalized laboratory
stay under `~/Library/Application Support/TFTMAC`.

The installed products are intentionally separate:

```text
/Applications/TFTMAC.app
  -> protected playable Control
  -> bundle com.flashls1.tftmac
  -> TFT_Ultra_Tablet / ports 5038, 5582, 8554

/Applications/TFTMAC DEV.app
  -> isolated engineering runtime
  -> bundle com.flashls1.tftmac.dev
  -> TFTMAC_Diagnostic_StockShadow_R1 / ports 5041, 5586, 8556
```

The Desktop contains one launcher symlink for each installed product. The global
runtime lease prevents them from running concurrently. DEV has separate state,
captures, AVD, ports, bundle identity, launch profile, and generated icon; it
does not mutate or replace Control.

### Development and release-promotion doctrine

**Control is the protected stable launcher; DEV is the engineering target.** All
normal feature implementation, UI work, graphics experiments, runtime tuning,
and acceptance work must be built into `/Applications/TFTMAC DEV.app` /
`com.flashls1.tftmac.dev` first. Agents must not use `/Applications/TFTMAC.app`
as a convenient test install target and must not overwrite, rebuild, patch, or
otherwise mutate the protected Control app during development.

Control is deliberately retained as the known-good playable rollback while DEV
moves forward. A DEV build may replace only the DEV install. Promotion of an
accepted DEV state into a full production release is a **separate explicit
release operation** requiring Flash's authorization and release acceptance. Until
that promotion is requested and proven, the installed Control artifact remains
unchanged. The exclusive runtime lease may require one app to be cleanly closed
before the other runs; that operational shutdown never grants permission to
change Control's files, AVD, ports, or configuration.

The shipping display path is raw authenticated 1920×1080 RGBA from the emulator
controller into a bounded native Metal presentation ring. MMAP/zero-copy remains
a later controlled experiment because readiness fencing, stride/color integrity,
tearing, frame age, and lifetime ownership have not been proven.

## 3. How the project reached this architecture

### Initial working donor

The Mactician donor had already proven that the Android runtime and TFT could
work on this Mac. Its critical behavior was not only its AVD variables. It
launched the emulator through a packaged Mac application host using
`/usr/bin/open -n -W --env ... --args ...`, inside the logged-in user's macOS
session.

The donor contract was:

```text
ADB server 5038
emulator console 5582
serial emulator-5582
no manual ADB_VENDOR_KEYS injection
```

### The ADB regression

An early TFTMAC path bypassed that architecture and directly spawned the
emulator from Node/Clara. It also moved to ports 5040/5592. The changed service
context presented an untrusted ADB host identity to Android, producing:

```text
emulator-5592 unauthorized
Timed out waiting for emulator ADB device.
```

The failure was not proof that the Android runtime, AVD, TFT, GPU, RAM, or CPU
were broken. Returning to the proven packaged host/session architecture and the
5038/5582 identity restored the correct boundary. This is why Node/Clara is not
part of the shipping app.

### Source-build research and retirement

The repository previously developed an AEMU/gfxstream/ANGLE/MoltenVK source
laboratory. That work produced valuable compatibility and performance evidence,
but it was retired as a required product dependency. The released stock emulator
is the normal runtime. Historical source trees, patches, launchers, and campaigns
remain R&D evidence only unless a future experiment explicitly builds an
isolated variant.

### Specialist council and ZoeMC

The project commissioned separate Unreal, ANGLE, gfxstream/ASG, MoltenVK, Metal,
and Fortnite/Unreal research tracks, then used ZoeMC v0.2 to rank 10,000 modeled
architecture worlds. The simulation was useful for ordering tests but used
subjective priors, so it was never treated as a benchmark. Its decisive
recommendation was to prove authenticated native frame delivery before building
a custom zero-copy or driver layer.

That branch is now resolved: raw authenticated gRPC can deliver correct
1920×1080 frames and native input. MMAP remains optional; direct zero-copy
without producer fencing and direct MoltenVK texture handoff without a supported
sharing contract remain invalid. Fortnite/Unreal material is retained as
transferable observability and pipeline-development guidance, not as proof of a
TFT implementation detail.

### Native app pivot

The product moved from “a script that launches an emulator” to one real native
Mac application:

- AppKit owns normal windowing and fullscreen behavior.
- Metal owns the final completed Android-frame presentation.
- EmulatorController owns authenticated local frames and input.
- the emulator stays hidden;
- CoreAudio stays enabled;
- Google Play/Riot own package and authentication flows;
- local SQL starts before gameplay and survives through clean shutdown.

## 4. Chronology and major milestones

| Date | Milestone | Durable outcome |
| --- | --- | --- |
| 2026-08-26 | Repository began from a live high-end tablet/emulator runtime | Preserved a working control instead of treating all earlier work as disposable |
| 2026-08-27 | AEMU/graphics Phase 0 and required-case research | Established component versions, GLES 3.2 compatibility need, and graphics experiment inventory |
| 2026-08-28 | Donor-compatible direct play, sustained telemetry, fixed-stage campaign | Proved ASG over pipe, selected 16 KiB write step, recorded many negative results |
| 2026-08-29 | Native architecture/ownership convergence | Retired Node/source-build production dependency and vendored the exact EmulatorController protocol |
| 2026-08-30 | Native AppKit/Metal runtime became playable | Hidden emulator, authenticated frames, native input, fullscreen, CoreAudio, official TFT, local logging |
| 2026-08-30 | Login/input repair | Primary Mac click became Android touch; WebView updated; credential boundary documented |
| 2026-08-30 | Permission/unlock/icon release work | Stable local signing retained external-volume consent; non-error unlock overlays removed; official icon installed |
| 2026-08-30/31 | Rapid Combat A/B logger | Exact TFT SurfaceFlinger windows, incidents, bounded Perfetto, SQL comparison/decisions implemented |
| 2026-08-31 UTC | Home Run A rejected | Riot Performance Mode Beta experience rejected and made non-selectable |
| 2026-08-31 UTC | Build 7 Combat Latency A | One-factor pre-exec host QoS candidate built, tested, installed, and live-launched; combat gain still unproven |
| 2026-08-31 UTC | Build 8 automatic graphics logger | Signed 2.3.0/8 installed and live-launched; PID 2704 and the exact TFT SurfaceView opened the logger automatically, periodic receipts reached `COMPLETE`, and every observed frame fact resolved through its run, stack hash, window, and receipt |
| 2026-08-31 UTC | Latest automatic graphics run | 42m27s automatic process/layer run recorded 144,364 exact intervals and 189 degradation incidents; it proves the continuous logger and performance deficit, not an internal root cause |

Relevant Git milestones:

```text
8d9ce17  Build native full-screen TFTMAC runtime
558c0ea  Add rapid combat A/B benchmark and telemetry
2123cd0  Add official TFTMAC penguin samurai icon
6bdb188  Add Build 7 combat latency candidate and project handoff
a9192ea  Refocus benchmark analysis on continuous FPS
2889cf0  Finish Build 8 automatic graphics logger
```

Build 7 work was developed after `2123cd0` and includes the candidate, guest
power gate, semantic cross-session layer matching, tests, verifier, and authority
updates.

The first Build 7 candidate attempt correctly failed readiness during a stale
listener/teardown race and auto-restored Control. After ports and lease ownership
were proven free, Control launched, then a clean Combat Latency A relaunch passed.
This was a runtime ownership/transient readiness event, not evidence that the
candidate improved or regressed graphics.

## 5. Native runtime achievements

### Window and presentation

- Native `NSWindow` and macOS fullscreen Space behavior are implemented.
- The emulator's UI is hidden.
- Controller frames are exactly 1920×1080 RGBA8888, 8,294,400 bytes.
- The initial gRPC 4 MiB message ceiling was identified and raised to 16 MiB.
- Earlier live acceptance observed source cadence up to about 61.1 Hz and native
  Metal output about 60.5 Hz. Those are transport/output numbers, not Unreal FPS.
- The final presenter is instrumented for submitted/completed frames, repeated
  source use, drawable errors, command completion latency, and Metal GPU time.

### Runtime control

- The app takes an exclusive runtime lease before touching the shared AVD.
- It fails closed on conflicting AVD/console/controller ownership.
- AVD configuration is backed up and hashed before atomic application.
- Owned-process cleanup checks the unique session marker before termination.
- Clean exit seals telemetry, confirms emulator exit, restores the AVD hash, and
  removes lease/transaction state.

### ADB and controller

- ADB uses the donor-compatible 5038/5582/emulator-5582 identity.
- Live sessions have observed `offline -> unauthorized -> device` and continued
  only after `device` authorization.
- Controller discovery is PID-bound and token-authenticated.
- Tokens are kept in memory and excluded from SQL/log output.

### Input

- Primary pointer input is `EmulatorController.sendTouch`, not a desktop mouse
  assumption.
- Identifier `0` remains stable through down/drag/up; release pressure is zero.
- Keyboard uses the controller's evdev path.
- Input telemetry records coordinates/pressure, counts, and special-key names,
  never typed characters.

### Audio

- Emulator launch uses CoreAudio.
- Earlier live evidence saw active 48 kHz stereo output, an active track, and no
  partial/empty underruns.
- Audible sound at the selected physical output remains a user-level acceptance,
  not something software counters can prove alone.

### Power and unlock

- Secure Android PIN unlock remains manual.
- Non-error text overlays that covered the PIN/TFT display were removed.
- Build 7 now proves virtual AC power, stay-awake, and `Awake` wakefulness before
  proceeding, preventing the avoidable secure-screen sleep state.

### External-volume permission

The original repeated drive-access prompt was addressed through stable local
signing/designated identity rather than changing the proven runtime root. A clean
relaunch retained removable-volume consent. Public Developer ID/notarized
distribution is not yet claimed.

### Official launcher artwork

The official icon is a full-bleed square penguin dressed as a samurai with one
sword and stacked `TFT` / `MAC` text. It has no baked outer gutter or rounded
container; macOS supplies the corner mask. The source and derived artwork hashes
are frozen in the release authority.

## 6. Riot login history

The first native login issue had two separate parts:

1. Primary clicks were being delivered as desktop mouse events to an Android
   WebView that expected touch. Build 4 replaced the primary path with real
   Android touch down/move/up.
2. The login form's `USERNAME` field requires the private Riot account login
   username—not the email address and not the public `Name#Tag` Riot ID.

The Android WebView provider was updated from 133.0.6943.137 to 151.0.7922.199.
The user subsequently logged into the Riot account and played.

The current Build 7 live session later reproduced a Riot
`MobileFREWebViewActivity` input-dispatch ANR. The proven narrow recovery did not
restart TFTMAC or the emulator: it restored
`show_ime_with_hard_keyboard=0`, force-stopped only Riot's failed process, and
reopened the official Splash/Game activity. The mutable WebView/IME dependency
therefore remains a tracked runtime risk.

No username, password, email, PIN, cookie, token, screenshot of the form, or
typed content is retained as project evidence.

## 7. Logger evolution

### Why the early logger was insufficient

The early logger could establish runtime health and rough rates, but it could
not truthfully describe the user's core complaint: large FPS loss during major
fights even when averages or the overlay looked high. Lobby/source/output rates
were too easy to misread as gameplay performance.

### Current logger

Every launch now creates a private session SQLite database plus bounded local
sidecars. It separates:

- exact TFT SurfaceFlinger actual-present frame timing;
- raw gRPC source freshness;
- final Metal presentation;
- QEMU/TFT/host resource state;
- audio, ANR, memory, renderer, shader, fence, and transport signal counts;
- host/guest clock synchronization;
- benchmark boundaries, visible-stutter markers, incident traces, and final
  decisions.

The on-screen `SRC` and `OUT` labels are deliberately not called Unreal FPS.
One-second `game_frame_windows` are the gameplay authority and contain effective
FPS, 1% low, p50/p95/p99/max interval, jank, severe stalls, and missed-vsync
equivalents.

### Combat benchmark

- The user starts it at representative heavy combat.
- Five minutes makes it valid; eight minutes closes it automatically.
- A 20-second start trace and at most two 15-second incident traces are bounded
  to 32 MiB each.
- Incident traces require two adjacent bad windows and a 120-second cooldown.
- SQL rejects invalid duration, layer, clock, history, package/configuration, or
  correctness comparisons.
- The result is `HOME_RUN`, `PROMISING`, `REJECT`, or `INCONCLUSIVE`.
- A winning candidate needs a cold confirmation before promotion.

### Full-run analysis

Complete automatic process/layer runs are the preferred product-performance
record because every frame and resource/pipeline sample participates. Match,
combat, and visible-stutter markers are optional annotations only. The current
UI/source-named Combat Benchmark remains the faster bounded one-factor A/B
screen. Root `benchmark.md` is the shared human/AI contract for exact
raw-interval and continuous-60 deficit metrics, complete-timeline processing,
legal clock-domain correlation, and claim/evidence/unknown records.

## 8. Performance development history

### What was learned from the earlier fixed-stage campaign

The earlier campaign ran on an M1 Max/userdebug environment and is historical,
not current M4 performance. It remains valuable for avoiding repeated failures.

- ASG decisively beat pipe at the same Trial stage.
- 16 KiB ASG write steps beat the paired 4 KiB control.
- 1 MiB ASG write buffer and 32 KiB ring remained the stable choice.
- Async MoltenVK submission and 64 active command buffers were retained.
- Effects/LOD changes at 67% improved the controlled Trial proxy.
- Resolution scaling was not automatically decisive: 2560×1440 versus 1600×900
  barely changed one controlled stage despite 2.56× source pixels.
- The selected historical stack still did not meet the 57 FPS heavy-scene goal
  or reproduce the user's worst approximately 15 FPS gameplay period.

The repository preserves full result tables in `docs/benchmarks.md` and the
technical chronology in `docs/research-log.md`.

### Current native run evidence

The user played games through the native app, including a retained match/lobby
capture. Those sessions established playability, not adequate combat
performance. Heavy fights still visibly drop frames.

The first rapid benchmark using combined Home Run A/Riot Performance Mode Beta
looked respectable by weighted average but was unacceptable in play:

```text
duration                 480.646 s
weighted FPS              56.665
1% low                    17.698 FPS
p95 / p99                 21.760 / 34.335 ms
maximum interval         517.488 ms
incident 1% lows           1.932 and 4.629 FPS
```

The user explicitly rejected that experience. Clock RTT and observer-overhead
gates also made cross-boundary causality invalid. Performance Mode Beta is now
retired and cannot be selected.

## 9. Historical Build 7 / early Build 8 state (superseded for current DEV optimization)

Build 7 replaces the rejected composite with `Combat Latency A`:

- retains 1920×1080, 320 dpi, 60 Hz;
- retains 6 vCPU and 5120 MiB;
- retains host GPU, CoreAudio, ANGLE/ASG/gfxstream/MoltenVK values;
- retains TFT High, 60 FPS, Performance Mode OFF;
- changes only the packaged host's requested pre-exec QoS to
  `user_interactive` and declares Game Mode eligibility.

Implementation additions include:

- exact host QoS requested/set/effective receipt before `execv`;
- fail/rollback if the candidate cannot establish that boundary;
- explicit refusal to claim QEMU child-thread inheritance;
- Android virtual-AC/stay-on/awake gate;
- stale Home Run A preference migration to Control;
- semantic cross-session TFT-layer comparison so dynamic SurfaceFlinger tokens
  do not make every Control/Candidate pair incomparable;
- updated correctness rollback and 40 native tests.

The historical Build 7 live capture was:

```text
~/Library/Application Support/TFTMAC/Captures/
  2026-08-31T02-54-28.329Z-14000b50-bf29-44c6-a963-9203d5313494/
```

Direct evidence from that capture:

- profile `tftmac_5gb_native_v1_preset_combat_latency_a`;
- ADB authorized on 5038 / `emulator-5582`;
- 1920×1080 RGBA first frame;
- host QoS set call returned 0 and read back `user_interactive` before exec;
- guest powered/stay-on/awake;
- official TFT 18.1-5402721 receipt;
- logger health gate passed;
- `TFT_READY_FOR_USER` with Unreal Engine and CoreAudio;
- one-second and resource/clock/pipeline tables continued advancing;
- Riot WebView ANR was recorded and recovered without restarting the emulator.
- the user later marked one full run from `2026-08-31T03:19:25Z` through
  `03:51:00Z` (31m35.054s);
- that match recorded 49.449 weighted FPS, 16.300 FPS 1% low, 33.822 ms p95,
  48.746 ms p99, 1,254.162 ms maximum, 19.110% jank, and 0.610% severe
  intervals from 93,724 exact TFT actual-present intervals;
- 58,925 intervals (62.871%) exceeded the 60 FPS frame budget and 1,599 of
  1,693 complete one-second windows (94.448%) were below 60 FPS;
- all overlapping exact-layer windows were available, the TFT layer was stable,
  and no frame history was truncated;
- final Metal output remained near 60 Hz with zero drawable/command errors while
  reusing 23,231 source frames, showing why OUT cadence cannot stand in for
  useful gameplay cadence;
- clock p95 RTT was 86.757 ms, so this match cannot assign the first upstream
  cause or serve as a formal matched candidate-vs-Control decision.

The Desktop launcher `/Users/flash/Desktop/TFTMAC.app` points to the signed
`/Applications/TFTMAC Control Launcher.app`, which launches the unchanged
`/Applications/TFTMAC.app` and unlocks only `5038/emulator-5582`. Direct launch
of the protected app remains the rollback. Runtime process state is not frozen
as a durable fact.

The Desktop launcher `/Users/flash/Desktop/TFTMAC DEV.app` points to
`/Applications/TFTMAC DEV.app`. Its wrapper selects the isolated
`advanced_diagnostics` profile. R11 is retained only as historical
`FAILED_FIRST_NATIVE_FRAME` evidence. The current stock-shadow variant clones
the proven Emulator 37.1.11/API 36 baseline and passed three consecutive
controller/ADB/unlock/native-frame/package/layer/input/audio launches. Control
remains the dependable game launcher and is never replaced by DEV.

What the Build 7 run does **not** prove: a Combat Latency A FPS win. It is one
historical candidate baseline, not a compatible A/B pair.

The historical Build 8 full-session authority was capture
`2026-08-31T22-30-26.086Z-8df607d7-a34a-4e2a-b00d-739aa3143200`: a 42m27s
automatic graphics run with 144,364 exact intervals, 99.629% exact-layer
coverage, 189 incidents, 56.98 weighted FPS, 21.49 FPS 1% low, 21.510 ms p95,
and 33.434 ms p99. It historically observed `combat_latency_a` with
High/60/Performance Mode OFF; the current selected profile is `control`, and
the historical observation is not a performance promotion. The run
proves degradation and continuous logging but leaves internal root attribution
`UNKNOWN_UPSTREAM_OF_OR_AT_GUEST_SURFACE`.

The timestamped 2026-08-31 host audit confirmed that the installed main and emulator-
host hashes match the historical Build 8 release receipt. It also found zero
valid local signing identities and a current `CSSMERR_TP_NOT_TRUSTED` result.
Historical signing acceptance and timestamped host trust are separate facts.
A 2026-09-02 recheck after restoring the local identity found two valid signing
identities and deep/strict verification PASS for both Control and DEV.

## 10. Historical repository-state snapshot and authority map (superseded)

Historical repository observation at the time of this section:

```text
branch: clara/implement-wave-b-runtime-mode-selection--215ec5a3
clean handoff HEAD: the branch tip containing this receipt
published upstream HEAD: must equal the clean handoff HEAD
remote: github -> https://github.com/flashls1/TFTMAC.git
```

The Build 8 line is the playable Control authority. The clean-handoff branch tip
containing this section owns the launcher/profile, stock-shadow, owned-probe,
campaign, and partial causal-logger changes. Re-observe the branch tip and live
process state before acting; no document can freeze mutable process state.

Current authority roles:

| File | Role |
| --- | --- |
| `facts.md` | facts, hard boundaries, current observations, explicit unknowns |
| `project.md` | project history, architecture pivots, current state, handoff |
| `benchmark.md` | current full-run/bounded-A/B formulas, validity, AI report contract, and findings |
| `dev.md` | developer map, experiments, hypotheses, next code contracts |
| `ssot/runtime-authority.json` | machine-readable current runtime/release evidence |
| `ssot/STACK.lock.yaml` | frozen stack/profile/toolchain selections |
| `docs/TFTMAC_NATIVE_RUNTIME_KNOWLEDGE_BASE.md` | detailed native outcome and operational knowledge |
| `docs/TFTMAC_UNREAL_PIPELINE_OBSERVABILITY.md` | graphics ownership and attribution rules |
| `docs/benchmarks.md` | historical measured campaign results |
| `docs/research-log.md` | historical R&D chronology and negative results |
| `TFTMACAPP.md` | short current native-app status pointer; historical plan is archived |

The dated archive under `docs/history/2026-08-31-pre-build8/`, retired Node
launch paths, historical source-build directives, and historical Medium-profile
records must not override the current SSOT.

## 11. Historical decisions retained only where not superseded by the current wiki

- Use the packaged Mac host launch chain and ADB 5038/5582 identity.
- Keep official Google Play/Riot package ownership.
- Keep native AppKit/Metal presentation and hidden emulator.
- Keep raw authenticated gRPC as the working presentation control.
- Keep High/60/Performance Mode OFF as the current in-game control.
- **Protected Control/history only:** 6 vCPU and 5120 MiB remain part of the old Control reference. **Current DEV optimization authority is 8 vCPU / 6144 MiB.** Retain the current ASG 16 KiB write step, 32 KiB ring, 1 MiB buffer, 800 microsecond flush and CoreAudio unless a later verified DEV winner changes one of those factors.
- Keep Riot Performance Mode Beta/Home Run A retired.
- Never record or automate credentials.
- Never call SRC/OUT presentation rates Unreal FPS.
- Never assign a graphics bottleneck without the first valid divergent boundary.
- Treat the final Mac presenter as hidden correctness context only, never as a
  user-facing graphics root-cause candidate.
- Keep base graphics logging automatic from TFT process/layer start through
  process/app close; a controlled Combat Benchmark is optional and never gates
  that logging.
- Current DEV optimization is **net-system efficiency**, not graphics-only. FPS remains heavily weighted, but latency/tails, jank, missed-vsync, CPU/RHI efficiency, memory behavior, allocation/churn, stalls, responsiveness, stability and compatibility are legitimate one-factor candidate dimensions when evidence supports testing them.

## 12. Historical next-work list (superseded by current top section and CHANGELOG)

1. Preserve the installed Build 8 automatic-graphics logger, its historical
   release hashes, and live acceptance capture
   `2026-08-31T21-39-18.396Z-fe34e3a1-fb91-44eb-804f-4ca8519dfc31`.
2. Treat automatic `graphics_runs`, stack-receipt SHA, direct per-frame stack
   identity, and per-window joins as live-verified Build 8 behavior. The Mac
   presenter is hidden correctness context, not a causal view.
3. Preserve the automatic latest-run receipt; match markers are optional
   annotations, not a condition of valid full-run evidence. A short bounded
   Control/Candidate A/B remains optional screening, not base logging admission.
4. Compare complete graphics timelines, every sustained under-60 episode,
   receipt completeness, and conservative boundary views using `benchmark.md`.
   CPU/RAM/audio remain correctness context only.
5. The latest automatic run confirms an unresolved internal causal gap below
   the SurfaceFlinger authority. Resume the pinned modern `emu-main-dev`
   preparation, prove the uninstrumented API 36 stock-shadow parity build, then
   integrate source-level work-ID hooks only in that isolated runtime. Do not
   replace Build 8.
6. Use that evidence to choose an owned code target. Current TFT is direct
   Unreal Vulkan; ANGLE is second-line only if a run receipt proves it is active.
7. Preserve the recurrent Riot WebView ANR as a separate login reliability issue,
   not as a graphics benchmark result.
8. Measure startup phases if the user's observed slow startup remains after login
   reliability is stable; do not trade away logger-before-runtime, ADB, power,
   package, or controller correctness to make a cosmetic startup number smaller.

The native app is launchable and playable. The remaining project objective is
not another wrapper or another generic FPS counter; it is a measured improvement
that holds at least 60 useful FPS across the complete run without destroying
correctness or the official package boundary.

## 13. Clean-stop continuation receipt — 2026-09-02T14:07:33Z

The branch tip containing this receipt is the continuation authority. At the
stop boundary:

- Control was running through `/Applications/TFTMAC Control Launcher.app` on
  `5038/emulator-5582`, capture
  `2026-09-02T14-05-44.327Z-48a72032-8f61-4639-8912-418001248ad5`. It was not
  stopped, restarted, or modified. A resuming agent must re-observe live state
  and must not disturb Control if it is still active.
- No DEV, diagnostic emulator, experiment runner, source-sync, or source-build
  process remained active. Orphaned sync children were terminated explicitly.
- Stock-shadow DEV has three consecutive launch passes. The owned Vulkan probe,
  sealed experiment profiles, campaign/analyzer, Control/DEV launch separation,
  secure-Keychain code path, causal SQL schema, Swift/C++ 96-byte event ABI,
  fixed rings, segment hashing, and deterministic finding states are in source.
- The one-time v2 Android-unlock Keychain item is not configured. When Control
  has exited, run `scripts/setup-android-unlock.command` and enter the PIN only
  in the local secure prompt. Never pass it to a shell, source file, log, or SQL.
- The seven-run campaign did not complete and has no winner. Do not infer a
  candidate from setup attempts.
- The first Android source sync failed on the case-insensitive external volume.
  The corrected script creates `/Volumes/TFTMAC Causal Source` from a sparse
  case-sensitive APFS image. Its sync was intentionally paused for this handoff;
  rerunning `scripts/prepare-causal-source-runtime.command` resumes it.
- After a `CAUSAL_SOURCE_LOCK_PASS` receipt, run
  `scripts/build-causal-stock-runtime.command` and prove API 36 first-frame and
  owned-probe parity before adding any source hooks. The actual modern
  gfxstream/MoltenVK hook integration and custom optimization patch remain
  incomplete.

The shortest valid resume order is: re-observe Control; wait for it to exit;
complete Keychain setup; finish the seven-run stock-shadow probe campaign;
resume the pinned source sync; build/prove uninstrumented parity; add hooks;
then select at most one evidence-owned patch. Riot login and gameplay remain
manual.

## 14. Causal Graphics Investigation & Lineage Receipt — 2026-09-03

**Milestone:** End-to-end causal pipeline tracing across all host graphics boundaries (`causal-hook-timeline-20260903-r6`).

- **Identity Carrier:** Replaced broken debug-utils labels with Vulkan timeline semaphores (`VK_KHR_timeline_semaphore`). Goldfish Vulkan marshals timeline semaphores across the ASG shared-memory ring intact.
- **Decoder Interception:** Goldfish ICD uses `OP_vkQueueSubmitAsyncGOOGLE` (opcode 22300) over the ASG wire. Gfxstream decoder hooks intercept `OP_vkQueueSubmitAsyncGOOGLE` directly, recording Site 1001 (`GfxstreamDecode`) and Site 1002 (`HostVulkanSubmit`).
- **MoltenVK & Metal Interception:** Exported `vkQueueSubmit` in `libMoltenVK.dylib` parses timeline signal values and tracks Site 2002 (`MoltenVKEnqueueEntry`), Site 2003 (`MoltenVKEnqueueQueue`), Site 2004 (`MetalCommit`), and Site 2005 (`MetalGpuComplete`).
- **Decisive Live Acceptance Evidence (`r6`):**
  - **99,480 total events** recorded across 15 active threads.
  - **10,796 fully correlated frames** tracked through all 6 sites.
  - **0 event losses, 0 ring overwrites, 100% SHA-256 payload & segment chain verification**.
- **Stage Latency Profile:**
  - Host Vulkan Submit (Site 1002): mean 0.014 ms, p95 0.029 ms, p99 0.064 ms
  - MoltenVK Translation & Enqueue (Site 2003): mean 0.106 ms, p95 0.199 ms, p99 0.253 ms
  - Metal GPU Execution (Site 2005): mean 0.683 ms, p95 1.338 ms, p99 1.911 ms
  - Total Host Pipeline Latency (Site 1001 -> Site 2005): mean 0.792 ms, p50 0.692 ms, p95 1.489 ms, max 4.005 ms.
- **Scoped causal finding:** in that instrumented capture, the measured correlated host graphics span was small relative to a 16.667-ms frame budget, shifting the observed delay upstream of the measured host-decode boundary. That receipt does **not** establish that every current frame overrun is caused by guest Unreal, Vulkan-driver, or ASG work.
- **Reproducible Upstream Patches:**
  - `artifacts/gfxstream-timeline-causal-instrumentation.patch`
  - `artifacts/moltenvk-timeline-causal-instrumentation.patch`
- **Historical suite receipt:** the suite count at that time was 54 tests. Current source validation inventory is 110 tests.

## 15. Historical experiment: Persistent Pipeline Caching & Gameplay Pre-Warm — 2026-09-03

**Historical objective:** test whether pipeline caching and guest pre-warm could reduce observed combat hitches. The experiment did **not** establish a guarantee of sustained ≥60 FPS, and current authority does not claim a specific Unreal major version.

- **MoltenVK Global Persistent Pipeline Cache:**
  - Implemented in `external/moltenvk/MoltenVK/MoltenVK/GPUObjects/MVKDevice.h`, `MVKDevice.mm`, and `MVKPipeline.mm`.
  - The historical experiment observed pipeline creation calls with `pipelineCache == VK_NULL_HANDLE` in its scoped path and tested a default-cache interception. Do not generalize that observation to every current Unreal pipeline call.
  - Custom implementation intercepts null pipeline caches and transparently binds to `_defaultPipelineCache`.
  - Automatically loads and flushes persistent cache file at `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Cache/moltenvk_pso.cache`.
  - Live proof: `moltenvk_pso.cache` generated (3,709 bytes), Apple M4 Vulkan 1.4 header verified, zero crash/leak regressions.
- **Guest Gameplay Pre-Warm & Asset Pre-Faulting (`scripts/prewarm-tft-gameplay.command`):**
  - Forces full Android ART Ahead-Of-Time (AOT) compilation to native ARM64 (`cmd package compile -m speed com.riotgames.league.teamfighttactics`). Verified status: `[status=speed]` on `base.odex`.
  - Pre-faults all game APKs and `.pak` assets into Linux guest RAM pagecache (>2 GB cached in guest RAM), eliminating virtual disk I/O stalls during combat round transitions.
  - SurfaceFlinger compositor tuned (`setprop debug.sf.latch_unsignaled 1`, `setprop debug.sf.enable_gl_backpressure 0`).
  - Prioritizes Unreal Engine `:psoprogramservice` worker threads (`renice -n -10`).
- **Live Runtime Validation:**
  - Instrumented diagnostic runtime booted cleanly on port 5041 with persistent cache enabled.
  - Causal pipeline events recorded: 5,857 events across all 6 pipeline sites with 0 losses, 0 overwrites, 100% SHA-256 integrity.
  - Pre-warm command executed and verified in live guest.

## 16. Historical experiment: Combat Telemetry, Memory Audit & 8-vCPU Allocation — 2026-09-04

**Historical objective:** diagnose combat frame dips, compare host/guest memory pressure and test 8-vCPU DEV behavior. Current authority proves Unreal Engine but does not claim a specific Unreal major version or a guaranteed locked-60 outcome.

- **32-Minute Live Match Forensic Audit (`2026-09-04T17-50-10.043Z`):**
  - Analyzed 892 2-second windows (~32 minutes of live match play).
  - **Overall Average FPS**: **55.80 FPS** (58.6% of all sample windows ran at flat 58–61 FPS).
  - **Planning / Shopping Phases**: Consistently locked at **58.6–59.8 FPS**, frame times 17.3–18.4 ms, guest CPU load ~320%.
  - **Combat Drops**: During large late-game combat rounds (16–22+ moving champions casting spells), CPU load surged to **380%–510%**, stretching frame times to 25–31 ms and pulling frame rates down into the **45–53 FPS** range (1% low: 33.27 FPS).
  - **Host Presentation**: Flat **60.00 FPS** (P95 Metal GPU time: 0.72 ms, 0 dropped frames).
- **Definitive Memory Audit (Host vs. Guest):**
  - **Guest Android RAM (5,120 MB)**: Android consumed only ~3.2 GB out of 5.1 GB. Available memory averaged **1,705 MB** (minimum 1,533 MB). Zero LowMemoryKiller events occurred; Android had >1.5 GB of free headroom at all times.
  - **macOS Host RAM (16 GB Unified)**: Available host RAM was **2,938 MB average** (min 2,620 MB) with 7.2 GB compressed and 1.7 GB swap.
  - **Historical 8-GB interpretation:** that run showed substantial host compression/swap while 5120 MiB guest RAM retained headroom, so an 8-GiB increase was not justified by that evidence. It did **not** prove 5120 MiB is an eternal exact sweet spot. Current verified DEV uses **6144 MiB**.
- **8-vCPU DEV allocation (`RuntimeModeAuthority.swift`):**
  - Current DEV launches are verified at `-cores 8`. This gives Android eight virtual CPUs scheduled by the hypervisor/host; it does **not** dedicate two physical host cores or prove that Unreal GameThread/RHIThread are unconstrained.
- **Historical Unreal in-game combat optimization (`provisionTFTDeviceProfiles`):**
  - `p.ClothPhysics=0`: Disables CPU vertex cloth simulation on 20–30 combat units, reclaiming 5–8 ms of GameThread frame budget.
  - `r.DynamicRes.OperationMode=1`: Activates the Dynamic Resolution master switch with an 85% safety floor (`r.DynamicRes.MinScreenPercentage=85`) and 16.67 ms budget (`r.DynamicRes.FrameTimeBudget=16.666666`).
  - `r.pso.PrecompileThreadPoolSize=2`: Restricts PSO precompile threads to 2, preventing worker threads from swamping vCPUs during combat.
- **Clean Snapshot Teardown (`TFTMACRuntime.swift -> stop()`):**
  - In `stop()`, issuing `am force-stop com.riotgames.league.teamfighttactics` 300 ms before `adb emu kill` closes active Vulkan swapchains and device instances, eliminating QEMU's `UNSUPPORTED_VK_APP` snapshot save failure and enabling 2–3 second fast snapshot resumes on subsequent boots.
- **Validation & Receipts:**
  - `./scripts/verify-tftmac.command`: 55 native tests passed (0 failures).
  - `./scripts/build-dev-launcher.command`: Built and signed `TFTMAC DEV.app`.
  - `./scripts/install-desktop-launchers.command`: Installed to `/Applications/TFTMAC DEV.app` and linked to `/Users/flash/Desktop/TFTMAC DEV.app`.
