# TFTMAC continuation handoff — 2026-09-03

Copy this entire document into the next agent. Treat it as a pointer to current state, then verify the cheap, drift-prone facts locally before changing anything.

## Mission

Continue the TFTMAC causal graphics investigation to a real win condition. The product goal is a correct, playable, full official Teamfight Tactics run at a useful sustained 60 FPS. Do not claim a performance improvement from synthetic probe FPS alone. First make hard work lineage cross the guest-to-host Vulkan transport and Metal completion path, collect three controlled replicated causal epochs, let the evidence name one owner, implement exactly one optimization, then prove it against the full product path.

The user has spent weeks and substantial money on this. Stay evidence-first and narrow. Do not create another source tree, SDK copy, AVD copy, build farm, SQL system, or broad documentation layer.

## Exact workspace and authority

- Local repository/worktree: `/Volumes/MAC MINI M4/Clara/Worktrees/flashls1--tftmac/tftmac--215ec5a3-6554-4ca3-95db-1525433bb20f`
- This is a Clara-generated worktree under `Clara/Worktrees/flashls1--tftmac`.
- It is **not currently listed as its own saved Codex Project**. Do not select the saved project named `CLARA`; that points to `/Volumes/MAC MINI M4/CLARAMCP/CLARA` and is a different repository. Open/work directly at the exact worktree path above.
- GitHub repository: `https://github.com/flashls1/TFTMAC.git`
- Remote: `origin`
- Branch: `clara/implement-wave-b-runtime-mode-selection--215ec5a3`
- Current HEAD and remote-aligned base: `9220cdf497b0ce516e45296758e96d53308b2f58`
- The main worktree is now intentionally dirty with uncommitted investigation changes. Do not reset, discard, clean, or overwrite them.

Read the entire local `AGENTS.md` chain and the accepted plan before implementation:

- `AGENTS.md` files governing the exact worktree
- `.clara/plans/tftmac-causal-graphics-v1/IMPLEMENTATION_PLAN.md`
- `.clara/plans/tftmac-causal-graphics-v1/ZEN_GATE_REPORT.md` and adjacent plan evidence
- `project.md`
- `facts.md`
- `dev.md`
- `benchmark.md`

The material plan already passed ZoeMC and ZenGate (reported score 92/93). Preserve its execution lock. Re-gate only if you materially change scope, architecture, ownership, security, destructive behavior, or the win condition.

## Non-negotiable runtime boundaries

- Build 8 Control at `/Volumes/MAC MINI M4/TFTMAC/Runtime` is the normal-play authority. Never modify it and never stop it.
- StockShadow is the diagnostic authority.
- Diagnostic ports are ADB server `5041`, console/serial `5586`, gRPC `8556`.
- Control uses different identities/ports. If Control appears while diagnostic source/build/runtime work is active, stop or pause only your diagnostic work.
- Launch emulator diagnostics through the packaged host contract using `/usr/bin/open -n -W --env ... --args ...`. Direct service-context spawn previously produced an unauthorized ADB identity.
- The secure Android unlock Keychain item already exists: service `com.flashls1.tftmac.android-unlock.v2`, account `android-user-0`. Never print the PIN or gRPC token.
- No Control, DEV, diagnostic emulator, isolated ADB, source build, or MoltenVK build process was running at this handoff.

## Storage cleanup already completed

Approximately 288 GiB was reclaimed safely. The obsolete duplicate contents of `TFTMAC-RUNTIME-DATA` were removed, but its supported Android build SDK was deliberately retained.

Current measured state:

- `/Volumes/MAC MINI M4`: about 238 GiB free.
- `/Volumes/TFTMAC-Causal-Source`: about 78 GiB free; about 71 GiB used.
- `TFTMAC/Diagnostics/GraphicsRuntimeV1`: about 191 GiB.
- `TFTMAC-RUNTIME-DATA`: about 7.7 GiB; this is now the retained Android SDK, not the former 117 GiB duplicate source/build tree.
- `TFTMAC/Runtime`: about 31 GiB; protected Control runtime.
- Existing causal build root: about 15 GiB.

Do not delete `/Volumes/MAC MINI M4/TFTMAC-RUNTIME-DATA/SDK`; `scripts/build-vulkan-probe.command` currently uses it. Do not perform more cleanup without a new read-only inventory and explicit scope.

## Supported toolchains already found

Use the toolchains that are already installed. Do not download another SDK.

- Supported emulator build toolchain: `/Applications/Xcode.app/Contents/Developer`
- Verified: Xcode `26.4`, build `17E192`, macOS SDK `26.4`.
- `/Applications/Xcode-26.6.0.app` contains Xcode 26.6 but macOS SDK 26.5 and is unsupported by this pinned emulator build. Do not use it.
- Android probe SDK: `/Volumes/MAC MINI M4/TFTMAC-RUNTIME-DATA/SDK`
- Android NDK: `ndk/29.0.14206865`
- Android build tools: `build-tools/36.0.0`
- Android platform jar: `platforms/android-37.0/android.jar`
- StockShadow SDK at `Diagnostics/GraphicsRuntimeV1/StockShadow/SDK` is the runtime/platform-tools/system-image set; it is not the probe compilation SDK.
- The Android emulator clang `r596125` was materialized from the exact local source/project store and previously verified as clang 22.0.2 for arm64 Darwin.

## Pinned case-sensitive source and build

- Mounted source volume: `/Volumes/TFTMAC-Causal-Source`
- Source root: `/Volumes/TFTMAC-Causal-Source/emu-main-dev-2692acc6`
- Build root: `/Volumes/TFTMAC-Causal-Source/Build/causal-stock-20260902/aemu-out`
- Baseline install: `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Install/causal-stock-20260902/emulator`
- Instrumented install: `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Install/causal-instrumented-20260903/emulator`
- Recorder source symlink: `/private/tmp/tftmac-causal-runtime` -> this worktree's `CausalRuntime`
- Source receipt: `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Manifests/causal-source-20260902/source-receipt.json`
- Source receipt state: `CAUSAL_SOURCE_LOCK_PASS`

Pinned revisions:

- manifest: `2692acc620f6563b21995540656674faeb536cdc`
- qemu: `9172e21fe3376fba0585c69dea67060e16c2b376`
- gfxstream: `d093bc2a9a53443347dde9ad2c73ffd828101de2`
- MoltenVK: `4d44e42aacc0734d4c55e26602e5aded66f73f6c`

## Proven baseline results

- The uninstrumented modern emulator Release build completed successfully (10,191/10,191 build actions in the prior full build).
- Its emulator executable retained the baseline SHA-256 `0d1823fea58b22e18928d89871f28b7d75e27506d1a3a9c4dfd2c515f2f8cc42`.
- It booted Android 16 through StockShadow, unlocked through the secure path, and exposed exact 1920x1080 gRPC output.
- The owned Vulkan probe completed 1,022 frames across all five workloads at roughly 60 FPS with zero Vulkan errors.
- The earlier seven-run stock-shadow Vulkan-toggle campaign completed with `NO_CANDIDATE_ADVANCED`. It has no winner. Do not repeat those synthetic toggle candidates blindly.
- Before this dirty work began, the unsigned Release app build and all 54 native tests passed.
- After the recorder implementation changes, `./scripts/test-causal-runtime.command` passed.

These prove build/runtime parity and probe health. They do **not** prove the official game holds 60 FPS or name a root cause.

## Main-worktree changes currently present

Modified, uncommitted files:

- `CausalRuntime/PipelineEventV1.h`
- `CausalRuntime/PipelineEventV1.cpp`
- `CausalRuntime/PipelineEventV1_test.cpp`
- `Probes/TFTMACVulkanProbe/src/main.cpp`
- `scripts/analyze-vulkan-experiment-campaign.mjs`
- `scripts/build-causal-stock-runtime.command`
- `scripts/prepare-causal-source-runtime.command`
- `scripts/run-vulkan-experiment-campaign.command`

`PipelineEventV1` currently implements a fixed 96-byte event, strict owned-ID parsing, a per-thread SPSC ring, background drain, 60-second or 65,536-event segment seals, SHA-256 payload/segment chaining, and explicit loss/overwrite counters. Recorder creation was made lazy because the first integrated run created 17 empty recorder files on unrelated threads.

Known pre-epoch issue: the current ring capacity is 4,096 records. The accepted plan's capacity formula may require approximately 32,768 for the measured event rate and 70-second safety window. Resolve and test this before claiming loss-free Gate 8 acceptance. Do not hide it.

## Dirty upstream source changes

These changes live in the mounted pinned source repositories and are not yet preserved as patches in the main Git repository.

gfxstream repository:
`/Volumes/TFTMAC-Causal-Source/emu-main-dev-2692acc6/hardware/google/gfxstream`

Modified files:

- `host/vulkan/CMakeLists.txt`
- `host/vulkan/vk_decoder.cpp`
- `host/vulkan/vk_decoder_global_state.cpp`
- `host/vulkan/vk_sub_decoder.cpp`

MoltenVK repository:
`/Volumes/TFTMAC-Causal-Source/emu-main-dev-2692acc6/external/moltenvk`

Modified files:

- `MoltenVK/MoltenVK/GPUObjects/MVKQueue.h`
- `MoltenVK/MoltenVK/GPUObjects/MVKQueue.mm`
- `MoltenVK/MoltenVK/Utility/MVKFoundation.cpp`
- `MoltenVK/MoltenVK/Vulkan/vulkan.mm`

Current hooks record source sites 1001/1002 in gfxstream and 2002/2003/2004/2005 in MoltenVK, carry a nonzero transport work ID through asynchronous queue execution, and measure Metal commit-to-completion wall duration. Never call that exact GPU execution time.

After live proof succeeds, preserve these exact upstream diffs as reproducible patch files in the main repository, add an idempotent apply script with pinned-commit checks, and record source-function/line/range and binary SHA/UUID receipts. Do not do that before the transport design actually works.

## Current artifact hashes

- Probe APK: `.build/vulkan-probe/TFTMACVulkanProbe.apk`
  - SHA-256 `4bf1189f5c93cf62b9fa822c3d625d1372247f5014d3d6c58cdfa58ee3fc29b3`
- Instrumented gfxstream backend:
  - SHA-256 `079d653e92f734a0cb64f3720dc836250cc77fa70c4c98c6dc3eaf821b472ba5`
- Instrumented MoltenVK:
  - SHA-256 `5d05b0fea7cd12af55aea313d146fcf7c82150607f13993c30cd6208cd7d4efb`

The instrumented dylibs contain `TFTPIPE1`, `TFTMAC_PIPELINE_EVENT_V1`, and recorder symbols. `lsof` during r2 proved the emulator loaded the instrumented install's exact gfxstream and MoltenVK dylibs.

## What the integrated runs proved

Capture roots:

- r1: `.../Captures/causal-hook-smoke-20260903-r1`
- r2: `.../Captures/causal-hook-lineage-20260903-r2`
- r3: `.../Captures/causal-hook-dispatch-20260903-r3`
- r4: `.../Captures/causal-hook-queue-lineage-20260903-r4`

r1:

- Android 16 boot/unlock and the smoke probe passed: 1,024 frames, five workloads, roughly 60 FPS, zero errors.
- It created 17 empty recorder files because every thread eagerly constructed a recorder.
- No sealed segment existed because the run was shorter than the required 60-second seal and normal `adb emu kill` does not flush sub-60-second TLS rings.
- This led to the lazy-recorder fix.

r2:

- Ran more than 70 seconds at roughly 60 FPS/zero errors but produced zero recorder files.
- Environment variables were present and `lsof` proved the expected instrumented dylibs were loaded.
- Therefore `Record()` was never reached.

r3:

- Probe log proved `debug_labels_available:true` and the command-buffer label API was called.
- Still produced zero recorder files.
- This proves the guest-side debug label did not reach the instrumented gfxstream command-buffer decoder paths.

r4:

- The probe was extended to call both command-buffer and queue debug labels around each submit.
- Probe log proved `debug_labels_available:true` and `queue_labels_available:true`.
- It ran normally at about 60 FPS with zero errors.
- Still produced zero recorder files.
- Therefore the pinned guest goldfish/gfxstream driver exposes these debug-utils calls but consumes or drops both label forms before the host decoder. **Debug labels are not a valid cross-transport identity carrier in this runtime.**

All r4 diagnostic processes and its isolated ADB server were stopped cleanly before this handoff. Control was not touched.

## Exact next technical move

Do not spend another long run on debug labels. Replace the failed carrier with the smallest diagnostic-only sideband that is part of the actual `VkSubmitInfo` transport.

Recommended next implementation:

1. In the owned Vulkan probe, create one probe-owned timeline semaphore using `VK_KHR_timeline_semaphore` or core Vulkan 1.2 features already supported by the reported Apple M4 Vulkan 1.3 device.
2. Add that semaphore as a second signal semaphore on each `vkQueueSubmit`.
3. Attach `VkTimelineSemaphoreSubmitInfo` and signal a strictly increasing value (`frame + 1`). Call this `transport_work_id`, never `frame_id`.
4. Preserve the existing FNV command checksum/identity separately; do not violate `workload-manifest.json` by silently redefining it.
5. In gfxstream's actual `OP_vkQueueSubmit` decoder, extract the last signal value from the timeline submit structure, validate that it belongs to the probe-owned submit shape, set TLS `transport_work_id`, record site 1001, then record 1002 begin/end around `on_vkQueueSubmit`.
6. In MoltenVK's exported `vkQueueSubmit`, extract the same timeline signal value and set MoltenVK's TLS before `MVKQueue::submit` constructs `MVKQueueSubmission`. Existing constructors then carry it into async execution and Metal completion.
7. Do not infer ownership from any arbitrary application's timeline semaphore. Gate the parser on the diagnostic environment plus the exact owned submit shape, and document collision/false-positive limits.
8. Remove or clearly classify the failed queue/command debug-label carrier code once the submit sideband works; do not leave two ambiguous authorities.

Relevant pinned source locations:

- gfxstream queue submit decoder: `hardware/google/gfxstream/host/vulkan/vk_decoder.cpp`, generated `OP_vkQueueSubmit` case near the current 1002 hook.
- MoltenVK exported submit: `external/moltenvk/MoltenVK/MoltenVK/Vulkan/vulkan.mm`, `vkQueueSubmit` near line 433.
- MoltenVK already parses `VkTimelineSemaphoreSubmitInfo` in `GPUObjects/MVKQueue.mm` near the command-buffer submission constructor.

## Build sequence after that edit

1. Stop only diagnostic processes and verify Control is not running before starting any build/runtime action.
2. Run recorder unit/ABI tests:

   `./scripts/test-causal-runtime.command`

3. Rebuild the probe using the retained supported Android SDK:

   `./scripts/build-vulkan-probe.command`

4. Rebuild MoltenVK with the supported Xcode:

   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make macos`

   from `/Volumes/TFTMAC-Causal-Source/emu-main-dev-2692acc6/external/moltenvk`.

5. Copy:

   `external/moltenvk/Package/Release/MoltenVK/dynamic/dylib/macOS/libMoltenVK.dylib`

   to:

   `prebuilts/android-emulator-build/common/vulkan/darwin-aarch64/icds/libMoltenVK.dylib`

6. Rebuild the existing target outputs in the existing build root. The prior invocation used the pinned source-tree ninja and targeted:

   - `lib64/libgfxstream_backend.dylib`
   - `lib64/vulkan/libMoltenVK.dylib`

   The last run rebuilt many dependencies because the ninja log version changed; it completed successfully. Do not create another build directory.

7. Copy only those two resulting dylibs into the existing instrumented install and record new SHA-256 and Mach-O UUIDs.

8. Do not rebuild or modify protected Control.

## Fail-fast runtime acceptance

Use a new capture directory; never overwrite r1-r4.

1. Boot the instrumented StockShadow emulator with the existing forwarder:

   `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/Install/gate4-r9-forwarder-r1/TFTMAC Diagnostic Forwarder.app`

2. Use ADB server port 5041, serial `emulator-5586`, console 5586, gRPC 8556, StockShadow AVD/SDK, and these opt-in recorder variables:

   - `TFTMAC_PIPELINE_EVENT_V1=1`
   - `TFTMAC_PIPELINE_EVENTS_DIR=<new-capture>/events`

3. Unlock without printing secrets. The sequence that worked reliably was wake, swipe to the PIN field, inject the Keychain PIN without logging it, then Enter. The earlier generic gRPC Enter/text sequence did not activate the field.
4. Install the freshly built `.build/vulkan-probe/TFTMACVulkanProbe.apk`, not the stale APK bundled in `/Applications/TFTMAC DEV.app`.
5. Start smoke mode and inspect within 5-10 seconds.
6. **Required immediate proof:** at least one recorder file appears as soon as the first owned timeline submit crosses the host. If it does not, stop immediately and inspect the exact submit structure. Do not wait another 60 seconds blindly.
7. Once files appear, run long enough for at least one full 60-second sealed segment.
8. Stop the probe, then validate the segment header, payload SHA-256, segment-chain SHA-256, event size/schema, site counts, loss/overwrite counters, and shared nonzero `transport_work_id` across 1001, 1002, 2002, 2003, 2004, and 2005.
9. Completion duration is Metal commit-to-callback wall time, not exact GPU time.

Binary layout currently expected:

- Header: 152 packed bytes.
- Event: 96 packed bytes.
- Segment seal: SHA-256 over previous hash + payload hash + little-endian sequence/start/end fields as implemented in `PipelineEventV1.cpp`.

Add a deterministic parser/test in the main repository if one does not yet exist. Reject unsupported schema rather than guessing.

## Remaining gates and final requested work

After the fail-fast lineage proof:

1. Prove loss/overwrite counts are zero and observer overhead is inside the accepted plan's budget. Increase the ring capacity if the formula requires it, then re-run the nearest decisive test.
2. Implement and prove separate `present_lineage_id` handling if it is still absent. Transport completion alone is not full presentation lineage.
3. Run three controlled, replicated causal epochs with fixed package, runtime, workload, power state, display configuration, and binaries.
4. Name a root only if the same earliest owned failing boundary repeats across all three. Otherwise report `UNKNOWN` or the plan's allowed conservative state.
5. Implement exactly one optimization only after the replicated evidence names its owner.
6. Run the relevant controlled A/B and then the full official TFT product path. A synthetic probe win is only screening evidence.
7. Run complete repository verification, including the unsigned Release build and all 54 native tests:

   `./scripts/verify-tftmac.command`

8. Update `project.md`, `facts.md`, `dev.md`, and `benchmark.md` with verified results, explicit unknowns, artifact hashes, and capture paths. Do not inflate them with plans or claims unsupported by runtime evidence.
9. Perform the ZenGate final scope-diff audit. Remove unrelated changes.
10. Preserve reproducible upstream patches/scripts, commit the justified main-repository changes on the current branch, and push to `origin` only after all required tests and runtime gates pass. Report any remaining product-performance gap honestly.

## Final truth boundary

At this handoff:

- Supported local SDKs are found and working.
- Space has been reclaimed and no new duplicate tree is needed.
- The uninstrumented modern runtime and owned Vulkan workload are healthy.
- Recorder unit tests pass.
- Instrumented dylibs build and load.
- Debug-utils labels are proven unusable as a cross-transport work-ID carrier in this guest/runtime.
- The timeline-semaphore submit sideband is the next candidate but is **not implemented or proven yet**.
- No causal owner, optimization win, or full-game 60-FPS win has been proven.

Do not claim completion until the last three bullets change through replicated runtime evidence.
