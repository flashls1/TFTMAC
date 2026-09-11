# TFTMAC HighPerf + 6GB Experiment Status

> Historical experiment record. Use the [2026-09-06 DEV checkpoint](../AGENT_HANDOFF_2026-09-06.md) for current source, effective-profile evidence and unresolved acceptance.

**Last updated:** 2026-09-04 (America/Chicago)
**Project:** `flashls1/TFTMAC`
**Active DEV worktree:** `clara/fix-dev-launch-keychain-prompts-riot-log-bddd2d6c`
**Scope:** TFTMAC DEV / `advanced_diagnostics` only. Protected Control is intentionally not modified.

## 1. Current bottom line

The 6 GB guest-memory change is **real and runtime-validated**. The HighPerf Unreal profile is **not yet runtime-validated**.

The latest clean 6 GB boot proved:

- Android reported approximately **6,068,552 kB MemTotal**.
- Unreal reported `SRC_TotalPhysicalGB: 6`.
- Riot selected `Android_6GB_Fragment` as intended.
- Riot still classified the ANGLE/Apple-M4 renderer through `OthersPerfSelection` and `LowQualitySelection`.
- The active fragment string remained:

  `Android_LowPerf_Fragment,Android_LowPerf_Frontend_Fragment,Android_6GB_Fragment,Android_GL_Base_Fragment,Android_GL_Others_Fragment`

- The HighPerf values we provision before TFT starts are then overwritten by Riot's LowPerf fragment at `SetByDeviceProfile` priority.

Therefore the correct status is:

- **6 GB:** VALIDATED.
- **HighPerf target values in TFTMAC source:** PRESENT.
- **HighPerf final effective Unreal values:** NOT YET VALIDATED.
- **Current causal blocker:** control of TFT's authoritative private DeviceProfile source / precedence.

Do not call the current build a validated HighPerf build until a fresh boot proves either:

1. `Android_HighPerf_Fragment` is actually included, or
2. LowPerf may still be named by the selector but its restrictive assignments no longer become the final effective values.

---

## 2. Why this investigation started

TFTMAC had repeatedly shown a split between host capability and in-game performance:

- the Apple M4 host graphics path has substantial headroom;
- planning/shop scenes can approach 60 FPS;
- heavier combat can collapse into the 40–50 FPS range or worse;
- the system did not look like a simple host-GPU saturation problem.

The DeviceProfile log finally exposed a concrete upstream policy choke point. TFT sees the virtual renderer as an unknown Android GPU:

- GPU vendor presented through ANGLE: `Google Inc. (Apple)`;
- renderer identifies Apple M4 through ANGLE;
- Riot's Android selector does not classify that identity as a known Adreno/Mali flagship GPU;
- it falls through to `OthersPerfSelection = true` and `LowQualitySelection = true`.

That causes TFT to load the LowPerf fragments even though the underlying host is an M4.

The working engineering hypothesis remains: **LowPerf is a major artificial constraint until a controlled HighPerf run proves otherwise.**

---

## 3. Baseline LowPerf evidence

The original captured boot showed the following selection:

- `OthersPerfSelection = true`
- `LowQualitySelection = true`
- `HighQualitySelection = false`
- selected fragments:
  - `Android_LowPerf_Fragment`
  - `Android_LowPerf_Frontend_Fragment`
  - `Android_6GB_Fragment`
  - `Android_GL_Base_Fragment`
  - `Android_GL_Others_Fragment`

Important LowPerf assignments observed in the boot log included:

| Setting | Pre-LowPerf / incoming value | LowPerf value |
| --- | ---: | ---: |
| `r.OpenGL.ProgramLRUEvictTimeSeconds` | 0 | 20 |
| `r.Streaming.PoolSize` | 1000 | 300 |
| `sg.ResolutionQuality` | 0 / project baseline | 75 |
| `tft.DefaultFrameRateLimit` | 0 | 30 |
| `Android.OpenGL.NumRemoteProgramCompileServices` | 4 | 0 |
| `r.OpenGL.DeferTextureCreation` | 0 | 1 |
| `r.RenderTargetPoolMin` | 350 | 0 |
| `r.Streaming.PoolSizeForMeshes` | -1 | 25 |
| `tft.Audio.DeviceTier` | High | Low |
| `a.Budget.BudgetMs` | 2.0, then 1.5 during setup | final observed 1.85 |

Other LowPerf behavior observed in the same family of logs included lowering scalability groups, altering shader-pipeline-cache behavior, animation frame stripping, grass/material-quality restrictions, and additional low-power policy choices.

### Important nuance about the old 30 FPS value

The log proves LowPerf assigns `tft.DefaultFrameRateLimit=30`, but earlier SurfaceFlinger telemetry also proved some light-scene windows could still present near 56–60 FPS. Therefore this CVar is **not being treated as proof of a permanent absolute 30 FPS hard cap**. The broader LowPerf policy remains the target because its memory, shader, animation, quality, and pacing restrictions can still hurt heavy combat even when light scenes reach 60.

---

## 4. Changes made during this experiment

### 4.1 Preserved the correct splash/login development line

An early HighPerf experiment was built from older `master` instead of the newer splash/login worktree. That accidentally omitted the custom splash and newer login/session work.

Observed result:

- custom TFTMAC splash disappeared;
- the build was not an acceptable base for graphics testing.

Correction:

- DEV was restored from the active splash + login worktree;
- `TFTMAC-Splash-1920x1080.png` is again part of the DEV build;
- further graphics work is being layered on this newer line rather than the old master line.

### 4.2 Stopped force-restarting TFT during login

During boot-profile testing, TFT was repeatedly force-stopped/relaunched to obtain clean Unreal logs.

Observed result:

- Riot login repeatedly reset while the user was entering credentials.

Correction:

- do not force-stop/relaunch the guest TFT process while login is in progress;
- boot-profile testing must respect the login/session flow.

### 4.3 DEV Keychain namespace separation

DEV now uses a separate Keychain service from protected Control:

- Control: `com.flashls1.tftmac.android-unlock.v2`
- DEV: `com.flashls1.tftmac.dev.android-unlock.v1`

Reason:

- DEV rebuilds/signing changes should not collide with Control's Keychain ACL/authorization history;
- Control remains frozen and independent.

### 4.4 Increased DEV guest RAM from 5120 MiB to 6144 MiB

The DEV authority was changed in both the runtime profile and sealed runtime-mode registry.

Current DEV authority:

- `ram_mib = 6144`
- supported RAM list remains `[4096, 5120, 6144]`
- the DEV registry SHA pin was updated consistently in the runtime authority/build script.

Validated runtime result:

- emulator launched with `-memory 6144`;
- EmulatorController receipt reported `ram_mib: 6144`;
- Android reported approximately `MemTotal: 6068552 kB`;
- Unreal reported `SRC_TotalPhysicalGB: 6`;
- Riot's `MemorySelection...6gb` rule became true;
- `Android_6GB_Fragment` was selected.

This is a successful, real 6 GB change—not merely a source setting.

### 4.5 HighPerf target CVars added to `provisionTFTDeviceProfiles`

The current source provisions a `6gb_highperf_v1` target before TFT launch.

The same key values are written into the matched/Android/LowPerf sections so that, if this file becomes authoritative, the LowPerf section itself resolves to our M4-appropriate target rather than Riot's low-end values.

Current target values are listed in Section 6 below.

---

## 5. Approaches tested and their results

### 5.1 `-DPFragments` through external `UECommandLine.txt`

Attempted concept:

`-DPFragments=Android_HighPerf_Fragment,...,Android_6GB_Fragment,...`

Goal:

- bypass Riot's unknown-GPU fallback and directly select HighPerf + 6GB.

Observed result:

- the external command-line file was written/read back;
- Unreal's own `LogInit: Command Line:` did **not** contain the injected fragment argument;
- Unreal continued selecting LowPerf.

Conclusion:

- the tested external `UECommandLine.txt` location was not consumed by this TFT shipping build.

### 5.2 Android `cmdline` intent extra

The official Android-style command-line intent path was also tried.

Observed result:

- the TFT shipping build still did not expose the desired argument in Unreal's effective command line;
- LowPerf selection remained unchanged.

Conclusion:

- do not spend another cycle assuming command-line injection is currently available through these external routes.

### 5.3 Galaxy Tab S9 / premium Android identity idea

The intended architecture was correct conceptually:

- present a premium Android tablet/performance class to TFT;
- retain the real 6 GB memory class;
- avoid teaching Android/TFT about an `Apple M4` device name.

A manual high-end identity attempt was made around Samsung/Snapdragon-class properties.

Observed result:

- the Google Play system image did not honor the attempted `ro.product.*` identity changes in the simple runtime path;
- the manually launched AVD also lacked the normal application/storage state needed for a meaningful gameplay run.

Conclusion:

- simple runtime property spoofing on this system image is not the current solution;
- do not use a broken manual AVD as a performance benchmark.

### 5.4 External project `Config/Android/DeviceProfiles.ini`

The source was changed from the old `Saved/Config/Android` external path to:

`/sdcard/Android/data/com.riotgames.league.teamfighttactics/files/UnrealGame/TFT/TFT/Config/Android/DeviceProfiles.ini`

Observed result:

- file existed with the expected contents and checksum;
- incoming/base values such as streaming pool 1000 and RT pool 350 were visible;
- Riot's selected `Android_LowPerf_Fragment` subsequently overwrote them at `SetByDeviceProfile` priority.

Conclusion:

- fixing only the external path does not make our file the final DeviceProfile authority.

### 5.5 External `Engine/Config/ConsoleVariables.ini`

Attempted because `SetByConsoleVariablesIni` normally outranks `SetByDeviceProfile` in Unreal.

Observed result:

- file could be written externally;
- TFT logged a normal engine console-variable config pass;
- our intended values did not become the higher-priority final assignments;
- LowPerf values remained effective.

Conclusion:

- this external file route is not functioning as the desired high-priority override in this packaged TFT build.

### 5.6 External `AndroidDeviceProfiles.ini`

The Android platform-specific filename was tested in the external project config hierarchy, including an attempt to replace/clear the LowPerf CVar array rather than merely append duplicates.

Observed result:

- LowPerf's packaged assignments still applied unchanged;
- the effective values remained 300 MB pool, 75% resolution, 30 default limit, Low audio, etc.

Conclusion:

- TFT's authoritative DeviceProfile data is not being controlled by these external `/sdcard` project config files.

### 5.7 Historical proven bind-mounted private DeviceProfile

Project history revealed a previous implementation that had already solved the persistence/authority problem for an earlier TFT/PBE runtime.

That implementation targeted TFT's **private application data**, not the external `/sdcard` copy:

`/data/user/0/<TFT package>/files/UnrealGame/TFT/TFT/Saved/Config/Android/DeviceProfiles.ini`

Historical mechanism:

1. determine the private data owner and SELinux context;
2. upload a known profile;
3. SHA-256 verify it;
4. back up the original profile if present;
5. copy the profile into place;
6. bind-mount the verified profile over the authoritative destination;
7. verify exactly one mount, correct checksum, and correct context;
8. keep the mount active for the full AVD session;
9. restore/remove it transactionally during cleanup.

Historical research explicitly recorded that a normal copied `DeviceProfiles.ini` could be consumed after one launch, while the verified bind mount remained authoritative across the AVD session.

**This is currently the strongest next route.**

The remaining task is to confirm/re-enable the required private/root capability on the current stock-shadow DEV AVD and adapt the proven transactional mount to the current official TFT package without disturbing Control.

---

## 6. Current DEV settings and why

There are two different sets of values that must be kept separate:

1. **TFTMAC configured target** — what we want TFT to run with once our DeviceProfile wins.
2. **Last validated Unreal effective values** — what Riot's LowPerf profile still actually forced in the last boot.

### 6.1 Emulator / host runtime settings currently configured

| Setting | Current DEV value | Reason |
| --- | --- | --- |
| Display | 1920x1080 | Native target for the current 1080p monitor/runtime; avoids unnecessary supersampling during causal testing. |
| Density | 320 DPI | Existing validated tablet/readability baseline. |
| Refresh | 60 Hz | Win condition is stable useful 60 FPS. |
| vCPU | 6 in the sealed DEV profile | Existing authority value; CPU-count tuning is separate from this DeviceProfile experiment. |
| Guest RAM | **6144 MiB** | Now runtime-validated as Riot's 6 GB memory class; gives more headroom than 5120 without repeating the previously rejected 8 GB host-pressure configuration. |
| GPU mode | `host` | Proven native emulator graphics route. |
| Graphics transport | `virtio-gpu-asg` | Existing validated transport; host graphics latency has not been the primary measured bottleneck. |
| Audio backend | CoreAudio | Existing working baseline; disabling audio previously did not improve graphics FPS. |
| ASG write buffer | 1,048,576 bytes | Existing proven baseline. |
| ASG write step | 16,384 bytes | Existing proven baseline. |
| ASG data ring | 32,768 bytes | Existing proven baseline. |
| ASG draw flush | 800 us | Existing proven baseline; not part of this test. |
| ANGLE enabled | `exposeNonConformantExtensionsAndVersions:exposeES32ForTesting` | Existing validated feature set. |
| ANGLE disabled | `preferSubmitAtFBOBoundary` | Existing validated baseline. |
| Riot Performance Mode Beta | OFF / expected false | Previously rejected as the performance solution; keep the causal baseline stable. |

### 6.2 HighPerf target CVar settings currently in source

| CVar | Target | Why this value is currently favored |
| --- | ---: | --- |
| `tft.DefaultFrameRateLimit` | **60** | Matches the 60 Hz target and removes LowPerf's 30 assignment. |
| `t.MaxFPS` | **60** | Explicit engine ceiling aligned with the target refresh. |
| `sg.ResolutionQuality` | **100** | Restore full 1080p quality; LowPerf forces 75 despite substantial host graphics headroom. |
| `r.VSync` | **1** | Preserve the current synchronized 60 Hz presentation policy. |
| `r.OpenGL.ProgramLRUEvictTimeSeconds` | **0** | Restores the pre-LowPerf value. Avoids LowPerf's aggressive 20-second program eviction policy while shader stalls remain a known concern. |
| `Android.OpenGL.NumRemoteProgramCompileServices` | **4** | Restores the directly observed pre-LowPerf value `4 -> 0`; provides the intended remote OpenGL compile-service capacity. |
| `r.pso.PrecompileThreadPoolPercentOfHardwareThreads` | **0** | Avoids competing percentage sizing when using an explicit worker count. |
| `r.pso.PrecompileThreadPoolSize` | **4** | Matches the observed fixed pool configuration and avoids speculative larger worker counts. |
| `r.ShaderPipelineCache.BatchTime` | **4** | Conservative 60-FPS experiment value; lower than the old 16 ms value and avoids LowPerf's 0.0. Still requires real combat validation. |
| `r.Streaming.PoolSize` | **1000 MB** | Restores the pre-LowPerf 1000 MB value. 1500 MB was deferred until memory pressure is measured under the real 6 GB configuration. |
| `r.Streaming.PoolSizeForMeshes` | **-1** | Restores the pre-LowPerf semantics: meshes share the main streaming pool. `-1` is not an unlimited mesh pool. |
| `r.RenderTargetPoolMin` | **350 MB** | Restores the directly observed pre-LowPerf value `350 -> 0`; preserves a render-target retention floor. |
| `r.OpenGL.DeferTextureCreation` | **0** | Restores the pre-LowPerf value instead of LowPerf's deferred creation path. Requires gameplay validation but is a direct LowPerf reversal. |
| `a.Budget.BudgetMs` | **6.0 ms** | Moderate first-pass animation allowance. Chosen instead of the speculative 10 ms recommendation because no direct evidence established a 5.5–7.8 ms combat animation cost. |
| `tft.Audio.DeviceTier` | **High** | Quality restoration from LowPerf's `High -> Low`; not claimed as the primary FPS fix. |
| `tft.Audio.PlayOnlyOneArenaAtATime` | **false** | Restore non-LowPerf audio behavior / quality. |
| `tft.Audio.RestrictNumberOfAmbientSounds` | **false** | Restore non-LowPerf audio behavior / quality. |

### 6.3 Settings intentionally *not* changed in the current target

These remain deferred or unchanged until evidence justifies them:

| Setting | Current decision | Why |
| --- | --- | --- |
| `r.MSAACount` | leave at existing **4** | The project already had 4 before LowPerf (`4 -> 4`). LowPerf did not create this value, and previous MSAA2 testing caused a black 3D pass. |
| `r.OpenGL.TextureEvictionFrameCount` | leave **500** | No proof that 500 means a destructive full purge every 500 frames; changing it is not needed for the first causal pass. |
| `gc.TimeBetweenPurgingPendingKillObjects` | leave **75** | The proposed 300-second interval was not backed by correlated GC hitch evidence. |
| `fx.NiagaraStateless.ComputeManager.CPUThreshold` | leave **256** | Direction/impact was not proven, particularly with GPU-particle policy interactions. |
| `a.StripFramesOnCompression` | no current Pass-1 override | May be cook/compression-time behavior; a runtime DeviceProfile change cannot be assumed to restore frames already stripped from packaged animation data. |
| `a.StripOddFramesWhenFrameStripping` | no current Pass-1 override | Same reason as above. |
| `r.SkeletalMeshForceLOD` | no current Pass-1 override | The CVar appeared unregistered in this build and the `0` versus automatic-LOD semantics were not sufficiently proven for a safe first pass. |
| Guest RAM 8 GB | rejected for this pass | Earlier testing showed host compression/swap pressure and risk of starving Metal. 6 GB is the current target. |

---

## 7. Last validated effective Unreal values

The latest validated 6 GB boot still showed Riot's LowPerf fragment winning. The important effective transitions were:

| CVar | Our/pre-LowPerf value | What LowPerf still forced |
| --- | ---: | ---: |
| `r.OpenGL.ProgramLRUEvictTimeSeconds` | 0 | **20** |
| `r.Streaming.PoolSize` | 1000 | **300** |
| `sg.ResolutionQuality` | target 100 / incoming 0 | **75** |
| `tft.DefaultFrameRateLimit` | target 60 / incoming 0 | **30** |
| `Android.OpenGL.NumRemoteProgramCompileServices` | 4 | **0** |
| `r.OpenGL.DeferTextureCreation` | 0 | **1** |
| `r.RenderTargetPoolMin` | 350 | **0** |
| `r.Streaming.PoolSizeForMeshes` | -1 | **25** |
| `tft.Audio.DeviceTier` | High | **Low** |
| `a.Budget.BudgetMs` | target 6.0 | **1.85 final observed** |

That table is the most important status receipt in this document: **the source target is HighPerf-like, but the running game has not yet accepted those final values.**

---

## 8. The red “TFTMAC needs attention” incident

During validation, DEV twice showed the red startup error reporting that the selected runtime lease conflicted with an active emulator or port listener.

The first assumption was a stale DEV ADB/listener. Cleanup removed the obvious DEV state, but the error reproduced with the ports actually clear.

Source inspection then exposed the real issue:

- `assertRuntimeUnoccupied` scans `ps` output for `qemu-system-aarch64` plus the AVD name;
- the validation shell command itself contained those exact strings;
- TFTMAC therefore mistook the monitoring shell command for a running emulator.

Correction:

- kill/remove the interfering monitoring shell;
- launch DEV with a minimal command that does not contain the emulator identity strings;
- do not start an external ADB listener before TFTMAC finishes its own ownership preflight.

Validated result after correction:

- `RUNTIME_OWNERSHIP_PREFLIGHT_PASSED`;
- existing emulator count 0;
- existing listener count 0;
- emulator launched normally;
- controller authenticated;
- `ram_mib: 6144` was confirmed.

Operational lesson: **diagnostic scripts must not contain strings that can satisfy TFTMAC's process-name conflict guard while the guard is running.**

---

## 9. Control protection

Throughout this work the production/Control app was treated as protected.

Previously verified protected hashes remained:

- Control executable SHA-256: `d3bf7c249a3e5f11b81f778b063e1a8cfe2e7fdeec0537ee6bd8447b1c2268d2`
- Control emulator-host executable SHA-256: `ea028ec1d74cc025638c2a0e5f8c783748803c1b0ba9012962c038251fb3eb63`

Graphics experiments belong in `advanced_diagnostics` / TFTMAC DEV until acceptance proves a change should move toward Control.

---

## 10. What should happen next

Do **not** restart the investigation from the CVar list.

The next causal task is specifically:

1. verify whether the current stock-shadow DEV AVD can access/mount TFT's private application-data DeviceProfile path with the required privilege;
2. adapt the project's historically proven checksum-verified transactional bind-mount mechanism to the current official TFT package;
3. mount the current `6gb_highperf_v1` profile over the authoritative private `Saved/Config/Android/DeviceProfiles.ini` for the AVD session;
4. launch TFT once;
5. inspect the fresh boot log;
6. require proof that the final effective target values are no longer overwritten by LowPerf;
7. only after that proof, play a real heavy-combat match and compare exact TFT SurfaceFlinger telemetry.

### HighPerf boot acceptance gate

A boot is considered a successful HighPerf test only if the final effective log shows the intended values, including at minimum:

- 6 GB memory selection active;
- 60 FPS target;
- 100 resolution quality;
- 1000 MB streaming pool;
- shared mesh pool (`-1`) or another explicitly accepted final value;
- RT pool minimum 350;
- OpenGL program-LRU eviction time 0;
- four remote OpenGL compile services;
- immediate texture creation (`DeferTextureCreation=0`);
- animation budget 6.0 ms for this first test;
- High audio tier;
- no later LowPerf assignment silently replacing those values.

If that boot gate passes, then and only then is it useful to judge whether HighPerf materially improves combat.

---

## 11. Repository/workspace state at time of this document

This document was created in the active splash/login DEV worktree because that is the line currently carrying the real application state being tested.

At the start of documentation, that worktree contained uncommitted changes across the runtime, DEV authority, login/Keychain handling, tests, and validation scripts. The branch's last already-pushed commit was `8c653209cf3a535102e76cf56e9497bb029228d8`.

A separate earlier HighPerf experiment branch existed and was already pushed at `8647239010328bd92c982399d2b8ff72e5d45e2c`, but it was based on the wrong older application line and therefore must **not** be treated as the authoritative current DEV state.

The current splash/login + 6GB + HighPerf-target work must be checkpointed/committed/pushed together as a nonterminal development snapshot before further experimentation.

---

## 12. Short handoff summary

If another Zoe/agent resumes this work, the key facts are:

- Do not debate whether M4 should be treated as LowPerf; the runtime directly proves Riot currently does exactly that.
- Do not use `Apple M4` as an Android device-profile identity.
- 6 GB is real and already validated.
- HighPerf is not yet real because LowPerf still wins the final DeviceProfile assignments.
- External `/sdcard` DeviceProfile/ConsoleVariables approaches have already failed to become authoritative.
- Command-line `-DPFragments` injection through the tested external routes did not reach Unreal.
- The project's historically proven solution used a transactional **private `/data/user/0/.../Saved/Config/Android/DeviceProfiles.ini` bind mount**.
- Reuse/adapt that proven mount mechanism next.
- Preserve the current custom splash and login/session line.
- Do not force-restart TFT while the user is logging in.
- Do not let diagnostic scripts falsely trigger the runtime ownership guard.
- Keep Control untouched until DEV has a real accepted HighPerf combat result.
