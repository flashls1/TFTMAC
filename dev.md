# TFTMAC Developer Record

**Development baseline:** TFTMAC 2.2.0 build 7  
**Control:** High / 60 FPS / Riot Performance Mode OFF  
**Active candidate:** `combat_latency_a`  
**Primary objective:** improve heavy-combat 1% lows and tail latency while preserving the proven native app.

This is the engineering working file. It contains code ownership, measurement
contracts, confirmed and rejected experiments, active hypotheses, and the next
implementation gates. Facts that must not drift live in `facts.md`; project
history and handoff live in `project.md`.

## 1. Developer charter

We are not trying to prove that frame loss exists; the player has already
established that major battles lag. Development must identify the first boundary
that becomes late, change an owned boundary, and demonstrate a repeatable combat
gain without correctness, login, audio, memory, launch, or cleanup regression.

Rules:

1. Preserve the working launcher/runtime/app before changing performance code.
2. Change one attributable factor per candidate unless an explicitly named
   screening composite is being tested.
3. Record requested, effective, and observed state separately.
4. Use exact TFT SurfaceFlinger actual-present intervals as gameplay frame truth.
5. Treat SRC, OUT, guest actual-present, and panel visibility as separate clocks.
6. Averages never override 1% low, p95/p99, severe stalls, or the player's
   visible-stutter report.
7. Do not claim Unreal, ANGLE, ASG, gfxstream, MoltenVK, Metal, or the final
   presenter caused a stall until that boundary is the first valid divergence.
8. Do not modify Riot's signed package, shaders, credentials, or process.
9. Retain negative results so they are not recycled as “new” ideas.
10. A launch receipt proves setup, not performance.

“Write a driver” in this project means implementing an owned, measured adapter
or scheduling/transport/cache change in TFTMAC, gfxstream/AEMU, ANGLE, or
MoltenVK when the evidence names that owner. It does not mean overclocking the
M4, modifying Riot's signed shaders, or adding an unmeasured kernel extension.

## 2. Runtime and code ownership map

| Boundary | Owner | Current implementation |
| --- | --- | --- |
| macOS application lifecycle | TFTMAC | `tftmac/App/TFTMACApplication.swift`, `AppCoordinator.swift` |
| native window/fullscreen | TFTMAC | `tftmac/App/MainWindowController.swift` |
| performance settings UI | TFTMAC | `tftmac/App/RuntimeSettingsWindowController.swift` |
| Metal output and Mac input capture | TFTMAC | `tftmac/Presentation/EmbeddedEmulatorView.swift` |
| frame contracts/geometry | TFTMAC | `FrameContract.swift`, `ViewportMapper.swift`, `TouchInput.swift` |
| runtime/ADB/controller orchestration | TFTMAC | `tftmac/Runtime/TFTMACRuntime.swift` |
| profiles/configuration hashes | TFTMAC | `tftmac/Runtime/RuntimeProfile.swift` |
| AVD mutation/rollback | TFTMAC | `AVDTransactionGuard.swift` |
| exclusive runtime ownership | TFTMAC | `RuntimeLease.swift` |
| exact game-frame windows | TFTMAC | `GameFrameTelemetry.swift` |
| signal classification | TFTMAC | `TelemetrySignalClassifier.swift` |
| combat persistence/decision | TFTMAC | `CombatBenchmarkStore.swift`, `CombatBenchmarkAnalysis.swift` |
| logged-in-session emulator launch | packaged host | `RuntimeHost/main.c` |
| controller wire contract | Android Emulator | `Vendor/AndroidEmulator/emulator_controller.proto`, generated Swift |
| Unreal game workload | Riot/TFT | official package; observe only |
| GLES-to-Vulkan translation | ANGLE | emulator/runtime component |
| guest-to-host command transport | gfxstream/ASG | emulator/runtime component |
| Vulkan-to-Metal translation | MoltenVK | emulator/runtime component |
| GPU execution | Apple Metal/M4 | host OS/hardware |
| official delivery/auth | Google Play/Riot | official guest UI only |

## 3. Current control and candidate

### Control

```text
preset: control
display: 1920x1080 @ 320 dpi / 60 Hz
guest: 6 vCPU / 5120 MiB
TFT: High / 60 FPS / Performance Mode OFF
GPU/audio: host / CoreAudio
transport: virtio-gpu-asg
ASG: 1 MiB buffer / 16 KiB write step / 32 KiB ring / 800 us flush
ANGLE enabled: exposeNonConformantExtensionsAndVersions:exposeES32ForTesting
ANGLE disabled: preferSubmitAtFBOBoundary
MoltenVK: async submit / 64 active command buffers / fast math
```

### Combat Latency A

```text
preset: combat_latency_a
all Control graphics, CPU, RAM, display, audio and transport values unchanged
LSSupportsGameMode: true
packaged host requests QOS_CLASS_USER_INTERACTIVE before execv
host records requested, set result, effective class and relative priority
```

Current direct receipt:

```text
requested=user_interactive
set_result=0
pre_exec_effective=user_interactive
relative_priority=0
QEMU child-thread inheritance=NOT_CLAIMED_WITHOUT_COMBAT_EVIDENCE
```

The candidate configuration SHA-256 is
`05039d1fd0987f46fc7da8de5f483d8c7ffaf8f39bd1eaecdd1aee11603bbb07`.
It has passed launch/readiness evidence but has no valid matched combat result.

## 4. Graphics pipeline and observability

```text
Unreal game/render/RHI
  -> guest GLES/Vulkan API choice
  -> ANGLE command/shader translation
  -> gfxstream encoder + ASG guest transport
  -> host gfxstream decode/queues
  -> Vulkan submit
  -> MoltenVK translation/pipeline state
  -> Metal command buffer/GPU completion
  -> Android SurfaceFlinger actual-present
  -> EmulatorController completed RGBA image
  -> TFTMAC mailbox/Metal presenter
  -> macOS drawable completion
```

### What each signal can and cannot prove

| Signal | Can prove | Cannot prove alone |
| --- | --- | --- |
| TFT SurfaceFlinger actual-present timestamps | player-facing guest frame cadence and stalls | which upstream component caused lateness |
| SRC distinct-image rate | completed images reaching TFTMAC | Unreal simulation/render timing |
| OUT Metal presentation rate | final Mac presenter cadence | unique useful game frames |
| final-presenter Metal GPU time | cost of TFTMAC's last Metal pass | MoltenVK/game GPU cost |
| QEMU CPU/RSS | host emulator load/pressure direction | exact worker or serialized wait owner |
| guest TFT PID/memory | process lifetime and memory pressure | GPU/transport stall owner |
| SurfaceFlinger HWC/GPU misses | display-composition pressure | ASG/MoltenVK root cause |
| logcat aggregate | occurrence of known failure classes | absence of all hidden stalls |
| Perfetto scheduler/GPU/process trace | time-correlated execution and waits | valid cross-host cause when clock RTT/observer gate fails |
| requested emulator/MoltenVK flags | intended configuration | effective internal behavior |

The worst Home Run A windows showed the final TFTMAC presenter completing cleanly
with roughly sub-millisecond Metal work while it repeated upstream frames. That
makes final presentation a poor first target for those incidents; it does not by
itself distinguish Unreal, ANGLE, ASG, gfxstream, or MoltenVK.

## 5. SQL and capture contract

Session authority:

```text
~/Library/Application Support/TFTMAC/Captures/<session-id>/
  TFTMAC_NATIVE_RUNTIME.sqlite
```

Persistent comparison authority:

```text
~/Library/Application Support/TFTMAC/TFTMAC_LAB.sqlite
```

### Required cadences

| Cadence | Measurements |
| --- | --- |
| 1 second | exact TFT FPS, 1% low, p50/p95/p99/max, jank, severe, missed-vsync equivalents, layer identity/history status |
| 1 second | source freshness/repetition/loss; native presenter submit/complete/reuse/errors/latency/GPU time |
| 5 seconds | QEMU CPU/RSS, TFT PID/activity, guest memory/swap, host memory/compression/swap/pageouts, thermal/power |
| 30 seconds | host/guest clock sync, renderer/feature receipts, SurfaceFlinger, display geometry/refresh, audio |
| event | benchmark, stutter, trace, process/layer, package, ANR/OOM/crash, correctness and rollback events |
| boundary | complete app/runtime/emulator/system-image/TFT/profile/input/audio identity |

### Privacy contract

Store no typed text, credential values, screenshots of login forms, raw frame
payloads, tokens, cookies, PINs, CAPTCHA, MFA, or unrelated app data. Raw logcat
and trace files stay local and require sanitization before any excerpt leaves the
Mac.

### Useful SQL

```sql
-- Exact session and frozen configuration
SELECT * FROM sessions;
SELECT receipt_key, receipt_value, confidence
FROM runtime_receipts ORDER BY id;

-- Actual TFT frame truth
SELECT started_monotonic_ns, status, unavailable_reason,
       effective_fps, one_percent_low_fps,
       p50_interval_ms, p95_interval_ms, p99_interval_ms,
       maximum_interval_ms, jank_count, severe_count,
       missed_vsync_equivalents
FROM game_frame_windows
ORDER BY started_monotonic_ns;

-- Separate upstream freshness from final presentation
SELECT * FROM stream_freshness_windows ORDER BY started_monotonic_ns;
SELECT * FROM host_presentation_windows ORDER BY started_monotonic_ns;

-- User/benchmark boundaries
SELECT kind, observed_utc, monotonic_ns, payload_json
FROM events
WHERE kind IN ('MATCH_ENTRY','COMBAT_START','VISIBLE_STUTTER','MATCH_END',
               'COMBAT_BENCHMARK_STARTED','COMBAT_BENCHMARK_ENDED')
ORDER BY monotonic_ns;

-- Fault counts without exposing raw log lines
SELECT * FROM logcat_aggregates
WHERE anr_count + fatal_count + memory_kill_count + input_timeout_count
    + angle_warning_count + vulkan_warning_count + audio_error_count > 0;

SELECT * FROM pipeline_log_aggregates
WHERE gfxstream_warning_count + asg_stall_count + vulkan_error_count
    + moltenvk_warning_count + shader_error_count + fence_timeout_count > 0;

-- Durable combat evidence
SELECT benchmark_id, session_id, preset_id, configuration_sha256,
       duration_seconds, surface_availability, clock_coverage,
       p95_clock_rtt_ms, correctness_passed, weighted_fps,
       one_percent_low_fps, p95_interval_ms, p99_interval_ms,
       max_interval_ms, jank_rate, severe_rate,
       observer_overhead_invalid, valid, invalid_reason
FROM combat_benchmarks;

SELECT * FROM combat_incidents ORDER BY observed_monotonic_ns;
SELECT * FROM combat_comparisons ORDER BY rowid;
```

## 6. Combat A/B validity and decisions

### Valid run

- at least 300 seconds of representative combat;
- automatic end at 480 seconds;
- at least 95% exact TFT SurfaceView coverage;
- at least 95% clock coverage;
- stable semantic layer identity;
- untruncated frame history;
- same current TFT package and comparison configuration;
- correctness passed;
- clock RTT at most 10 ms for any cross-host ordering claim.

Dynamic SurfaceFlinger tokens differ after every process launch. Control matching
must compare the stable semantic identity—package, activity, SurfaceView/BLAST
role—not the ephemeral token prefix/suffix.

### Trace policy

- one 20-second/32-MiB trace at benchmark start;
- up to two 15-second/32-MiB incident traces;
- automatic trigger requires two adjacent bad one-second windows;
- bad window: 1% low below 30 FPS, p99 at least 50 ms, or severe stalls;
- 120-second cooldown; no concurrent traces;
- SHA-256 seal and normalize with pinned `trace_processor_shell` v58.2;
- if trace overhead changes frame metrics by more than 5%, performance remains
  useful but causal conclusions become `OBSERVER_OVERHEAD_INVALID`.

### Decision engine

| Decision | Rule |
| --- | --- |
| HOME_RUN | 1% low +20%, jank/severe -30%, and either FPS +10% or p95 +15% |
| PROMISING | FPS +5%, 1% low +10%, no correctness or tail regression |
| REJECT | gain below 5%, p95/p99 +10% worse, or any correctness/usability regression |
| INCONCLUSIVE | invalid/mismatched workload, coverage, clock, observer, or threshold gap |

Any HOME_RUN/PROMISING result needs a five-minute cold confirmation. Rollback is
select Control and restart. A failed active candidate records correctness
rejection and saves Control automatically.

## 7. Retained results

### Historical campaign winners

| Candidate | Result | Decision |
| --- | --- | --- |
| ASG vs pipe | 40.1 FPS / 34.85 ms p95 vs 29.6 / 49.75 at same stage | keep ASG |
| 67% effects/LOD | 45.20 / 38.50 / 33.80 FPS at Trial 1-2/1-5/1-8 | historical winner |
| ASG write step 16 KiB | 41.3–43.0 / 34.1–35.1 at 1-5/1-8; paired 4 KiB 38.0 / 32.8 | keep 16 KiB |
| ANGLE `preferSubmitAtFBOBoundary` disabled | 46.90 / 36.10 / 29.60 first pass | retained in current stack; old run alone was provisional |

These were collected on the historical M1 Max/userdebug campaign. Do not use the
numbers as M4 native Build 7 measurements.

### Home Run A rejection

| Metric | Value |
| --- | ---: |
| Duration | 480.646 s |
| Weighted FPS | 56.665 |
| 1% low | 17.698 FPS |
| p50 / p95 / p99 | 16.703 / 21.760 / 34.335 ms |
| Maximum | 517.488 ms |
| Jank / severe rate | 4.554% / 0.290% |
| Incident 1% lows | 1.932 and 4.629 FPS |
| Validity | invalid for comparison/cause: clock RTT too high; observer overhead invalid |
| Usability | user rejected as worst-ever experience |

The configuration combined Riot Performance Mode Beta with
`NativeTextureDecompression` and `NoDelayCloseColorBuffer`; formal evidence
cannot allocate blame among those factors. Operationally, the complete preset is
barred and should not be decomposed unless new evidence gives a specific reason.

## 8. Negative-result ledger

Do not repeat these without a changed mechanism and explicit new evidence:

| Candidate | Retained reason |
| --- | --- |
| pipe transport | materially slower than ASG |
| MoltenVK 128 | strong first run failed cold/sustained reproduction; worse tails |
| MoltenVK 256 | incomplete and included 133 ms frame |
| synchronous MoltenVK submit | about -10.3% in retained input test |
| guest submit thread | regression |
| shader prewarm / submit+prewarm | failed promotion |
| upstream ASG screen | failed promotion |
| 50% scale | no complete advantage over 67% profile |
| isolated/extreme effects or LOD | neutral/incomplete/regressive tails |
| ASG 2/4 ms flush | inconsistent or worse tail/reproduction |
| ASG 8/32 KiB steps | failed screen; 32 KiB long frame |
| ASG 64/128 KiB rings | no reproducible gain |
| ASG 512 KiB buffer | two startup failures, `Failed to unbox VkPipeline` |
| `VirtioGpuNativeSync` | regression |
| `VirtioGpuNext` | neutral |
| descriptor batching disabled | regression; keep batching |
| forced half-rate skeletal animation | worse tails |
| `r.OneFrameThreadLag=0` | -21.9% |
| disabled async composition | slower, no proven latency gain |
| explicit native swapchain | no-op/not promoted |
| MSAA2 | black 3D pass |
| material quality 1 | neutral/noisier |
| active-consumer host patch | 11.2 FPS / 334 ms p95 lobby regression |
| native GLES 3.0/3.1 | crash/capability failure |
| direct TFT Vulkan | did not solve verified problem |
| extra RAM / eighth vCPU | did not solve verified problem |
| audio disabled | neutral/slower; sound required |
| Riot Performance Mode Beta | direct user rejection and terrible incident tails |

## 9. Research council and model evidence

Specialist work was performed across Unreal, ANGLE, gfxstream/ASG, MoltenVK,
Metal, and transferable Fortnite/Unreal behavior. ZoeMC v0.2 ranked 10,000
modeled architecture worlds. Its priors were subjective, so its output is a
hypothesis queue—not a measured performance result.

One major branch was resolved empirically: authenticated raw gRPC can deliver a
correct 1920×1080 image and native input. That removes zero-copy/MMAP as a
prerequisite. The council's remaining useful output is the strict ownership map,
the requirement for fencing before MMAP, and the ordering of frame correlation
before deeper transport/translation patches.

Fortnite/Unreal sources may inform shader/pipeline-cache behavior, trace
categories, device-profile reasoning, and render-thread/RHI hypotheses. They do
not establish which path the current signed TFT build chose or authorize shader
replacement.

## 10. Active hypotheses and code gates

### H1 — Combat Latency A / host scheduling

**Mechanism:** the emulator launch thread may enter QEMU with a latency-oriented
QoS class, reducing scheduling delay in critical host work.

**Implemented:** `RuntimeHost/main.c`, profile/receipt/rollback in native Swift,
Game Mode eligibility, unit tests.

**Evidence needed:** matched Control/Candidate actual-present windows, host CPU,
thermal/power, source freshness, final presenter, valid clock sync.

**Accept:** HOME_RUN/PROMISING plus cold confirmation.  
**Reject:** no gain, worse tails, or any correctness/login/audio/cleanup issue.  
**Critical unknown:** QEMU worker inheritance and worker-specific scheduling.

### H2 — allocation-free gfxstream frame correlation ring

**Mechanism:** a 256-frame ring carrying one frame ID through each boundary will
show the first queue that grows late instead of guessing from unrelated clocks.

**Implementation contract:**

```text
fixed 256 entries
no allocation on render/decoder hot paths
frame ID + overwrite/loss counter
guest submit timestamp
host receive timestamp
host decode/queue timestamp
Vulkan submit timestamp
GPU completion timestamp
output-present timestamp
queue depth at each owned handoff
```

**Gate:** activate only after configuration testing fails to deliver/explain a
gain. Clock mapping and overwrite counts are mandatory. Do not log shaders,
frame contents, or credentials.

**Outcome:** identify the first valid divergent boundary. If lateness begins
before host receipt, investigate ANGLE/guest/ASG. If after receipt but before
Vulkan submit, investigate gfxstream decoding/queues. If after submit,
investigate MoltenVK/Metal/pipeline state.

### H3 — adaptive ASG transport

**Mechanism:** fixed batching may either wake too often or hold a frame/release
command too long. Adapt around frame boundaries and queue occupancy rather than
blindly increasing buffers.

**Candidate behavior:**

- flush immediately for frame boundary/release-image work;
- batch while occupancy and latency are healthy;
- wake consumer early as occupancy rises;
- stop batching when guest waits for space;
- prevent one context from monopolizing decode;
- record occupancy, wait duration, wake reason, batch size, and loss.

**Do not do:** enlarge every ring/buffer. Larger prior values did not improve and
512 KiB write buffer failed startup.

**Gate:** frame-ID ring must first show lateness at ASG/host receipt.

### H4 — gfxstream decoder/submission thread scheduling

**Mechanism:** critical decoder/render/submission workers may be delayed or
serialized on the M4 host even when total CPU capacity exists.

**Needed evidence:** per-thread name/ID, runnable delay, wakeup-to-run latency,
queue depth, lock/wait owner, and correlation to bad game-frame windows.

**Candidate:** apply explicit latency QoS to the identified critical worker only,
not every QEMU thread. Keep I/O/background work lower. Verify effective class on
the actual thread.

**Gate:** valid scheduler trace/frame ring shows the worker is the first late
boundary. Reject if CPU contention, thermals, audio, input, or tails regress.

### H5 — persistent MoltenVK pipeline cache

**Mechanism:** repeated SPIR-V-to-MSL/pipeline-state work may cause first-use or
combat-effect stalls. Reusing equivalent pipelines could remove them.

**Cache key must include:** TFT package/build, shader/pipeline hash, MoltenVK
build, M4 GPU identity, effective graphics configuration, and cache schema.

**Instrumentation:** pipeline lookup/create duration, hit/miss, translation time,
Metal pipeline creation time, compile thread, warm/cold state, and invalidation.

**Safety:** no Riot shader modification; cache only owned translation products.
Fail closed on version/hash mismatch. Bound disk size and support complete
invalidations.

**Gate:** frame-ID/trace evidence places first lateness after host receipt and
around pipeline creation. Blind prewarming remains rejected.

### H6 — frame submission and pacing

**Mechanism:** too many/few frames in flight, release signaling, swapchain image
count, queue bubbles, or commit cadence can produce poor tails without saturating
the GPU.

**Variables:** present mode, swapchain images, frames in flight, fence polling vs
callbacks, deferred commands, release-image signaling, command-buffer commit
cadence, and host mailbox depth.

**Evidence:** queue depth, submit-to-complete, complete-to-present, repeated
source, drawable errors, actual-present intervals.

**Gate:** isolate one factor; never reintroduce synchronous submit or 128/256
buffers without a new mechanism.

### H7 — Vulkan/ANGLE capability and Unreal device selection

**Mechanism:** the official game may select a conservative or incompatible
device profile based on exposed Vulkan/GLES/GPU/texture/surface capabilities.

**Method:** compare effective reported capabilities and live code path; implement
only features that pass representative shader/render tests. Never lie that an
unsupported feature exists.

**Evidence needed:** active TFT package/version, Vk/GLES identity/extensions,
selected surface formats/present modes, shader/renderer warnings, and visual
correctness.

Historical PBE DeviceProfiles are reference evidence only. Do not mount an old
overlay into the current signed production client.

### H8 — internal render resolution

**Mechanism:** fewer rendered pixels can help a truly GPU-fill-bound scene while
TFTMAC still outputs fullscreen 1920×1080.

**Current caution:** live TFT SurfaceView has often been 1280×720 inside the
1920×1080 guest, and a historical 2560×1440/1600×900 A/B barely changed FPS.
Lowering resolution may therefore reduce quality without fixing CPU/RHI/
transport stalls.

**Gate:** prove Metal/game GPU saturation or pixel-dependent scaling first. Test
100/83/75% one factor at a time, record exact SurfaceView buffer size, and reject
quality loss without tail gain.

### H9 — MMAP/shared-memory frame delivery

**Mechanism:** remove the final raw gRPC copy or reduce frame age/host CPU.

**Preconditions:** producer readiness/fencing, stable stride/format/color,
bounded ownership, no overwrite while Metal reads, tear/corruption detector,
sequence/age measurement, and clean rollback to raw gRPC.

**Gate:** isolated A/B shows material CPU/frame-age gain with zero integrity or
input regression. Raw gRPC remains production control otherwise.

### H10 — startup phase latency

**User observation:** native startup felt slow. No valid phase budget has yet
been measured.

**Instrumentation:** record duration for lease/preflight, ADB server, host/QEMU
launch, controller discovery, Android boot, power gate, secure unlock wait,
package receipt, logger health, TFT process start, and first ready frame.

**Code rule:** optimize only the measured slow owned phase. Never move logging
after launch, bypass ADB authorization, skip the power/package/controller gates,
or weaken AVD rollback merely to report a smaller startup number.

## 11. Fastest next development sequence

1. Preserve Build 7 and run a valid Control combat benchmark.
2. Run a comparable Combat Latency A benchmark.
3. Let SQL classify it; cold-confirm only a winner.
4. If it fails or remains causally unknown, implement H2's fixed frame-ID ring.
5. Use the first divergent boundary to choose exactly one of H3, H4, H5, or H6.
6. Run a five-to-eight-minute heavy-combat A/B; do not require full matches for
   screening.
7. Promote only after repeated gain and no correctness/user-experience failure.

This sequence does not mean “test forever.” The first two runs decide whether
the code already developed in Build 7 is useful. If not, the frame-ID ring is
the shortest path to writing the correct deeper code instead of another blind
emulator flag.

## 12. Login reliability track

Keep login reliability separate from graphics performance:

- record exact Riot activity and WebView version;
- primary click remains Android touch;
- `show_ime_with_hard_keyboard=0` is the known recovered state;
- if `MobileFREWebViewActivity` hits an input-dispatch ANR, restart only Riot's
  process and reopen the official Splash activity;
- do not restart a healthy emulator or destroy the current AVD/session;
- never inspect or persist credential values;
- count ANR/input timeouts in SQL and invalidate any affected correctness run.

The repository contains older credential-automation helpers from historical
work. They conflict with the current strict manual-auth boundary and must not be
used as product behavior or benchmark prerequisites.

## 13. Build, test, release, and rollback

Authoritative commands:

```text
scripts/test-native-app.command
scripts/build-native-app.command
scripts/verify-tftmac.command
scripts/summarize-native-session.command
```

Toolchain:

```text
Xcode: /Applications/Xcode-26.6.0.app
Swift: 6.3.3
target: arm64 macOS
app: /Applications/TFTMAC.app
runtime: /Volumes/MAC MINI M4/TFTMAC/Runtime
```

Verification claims must be scoped:

- unit tests prove parsers, configuration, comparison logic, and local contracts;
- build/sign verification proves the bundle, not playability;
- launch receipts prove runtime readiness, not combat gain;
- SQL combat comparison proves measured change, not internal cause when clock or
  observer gates fail;
- user acceptance proves playability/experience, not the first software boundary.

Build 6 rollback was preserved at:

```text
/Applications/TFTMAC.app.build6-backup-20260830-2150
```

Do not replace or restart the currently running app during live user gameplay.
Apply restart-bound changes only after the user is out of a game and the current
session can seal and restore its AVD transaction.

## 14. Current gaps to close

- valid matched Control/Combat Latency A comparison;
- actual worker-thread QoS/inheritance evidence;
- first-boundary frame correlation under a true heavy fight;
- recurrent Riot WebView/IME reliability;
- audible-sound user acceptance;
- fully marked Build 7 start-to-result match;
- public signing/notarization if distribution beyond this Mac becomes a goal;
- source-level gfxstream/MoltenVK code only after the relevant boundary is named.
- measured startup-phase budget if the user's slow-launch observation persists.

The current engineering posture is: preserve the proven app, reject generic
averages and recycled settings, and write the next code at the first boundary
that the synchronized combat data actually shows is late.
