---
title: TFTMAC DEV HighPerf + 6GB DeviceProfile Experiment
plan_version: 1.0
request_class: IMPLEMENT
project: TFTMAC
change_id: 3aaccd05-c3ca-4d88-8b3a-de87e0694036
base_sha: 74c74c48e75db9dc04e105d8e6f2574002fb787d
---

# Win condition

Boot the official TFT client in the isolated TFTMAC DEV runtime with TFT's own high-performance Android DeviceProfile fragments while retaining the 6GB memory and current GL fragments. Prove the effective fragment/CVar state from the Unreal boot log before any combat benchmark. Leave protected Control unchanged.

# Implementation

## 1. DEV-only startup profile selection

Replace the current DEV behavior that attempts to fight LowPerf through broad CVar overrides with a startup command-line fragment selection:

`-DPFragments=Android_HighPerf_Fragment,Android_HighPerf_Frontend_Fragment,Android_6GB_Fragment,Android_GL_Base_Fragment,Android_GL_Others_Fragment`

Use Unreal's Android command-line mechanism. The command-line file must contain the required TFT project selector before the flags if this build requires it. Prefer a path proven by the running build / Unreal Android command-file convention; record the final guest path and SHA in telemetry.

The HighPerf experiment applies only when `paths.mode == .advancedDiagnostics`. Do not change Control startup behavior.

## 2. Remove stale DEV CVar interference

For this first architecture test, do not let the existing broad `[Android_MatchedFragments]` / `[Android_LowPerf_Fragment]` CVar block mask what TFT's native HighPerf tier actually chooses. In DEV HighPerf mode, remove/avoid the stale copied LowPerf override file before launch and provision only the command-line fragment selection needed for the experiment.

Do not delete user/account/session data. Only TFTMAC-owned diagnostic profile/command-line artifacts may be created or removed.

## 3. Delivery correctness and receipts

Before TFT launch:

- provision the command-line artifact;
- read it back;
- verify exact contents and SHA-256;
- record a telemetry receipt/event containing mode, guest path, SHA, and selected fragment list;
- fail the DEV experiment closed if the artifact cannot be verified.

## 4. Source-level validation

Add focused tests/static verifier assertions proving:

- HighPerf + HighPerf frontend + 6GB + GL base + GL others are present in the DEV command line;
- LowPerf fragments are absent from that DEV command line;
- the feature is gated to `advanced_diagnostics` and does not alter Control;
- legacy broad LowPerf override content is not provisioned for the DEV HighPerf experiment.

Run existing TFTMAC verification and Release DEV build gates.

## 5. Install and isolated boot

- Verify protected Control executable and emulator-host identities before install.
- Build `/dist/TFTMAC DEV.app` from this managed worktree.
- Install only the DEV application through the existing protected installer path.
- Confirm Control remains stopped and unchanged.
- Launch TFTMAC DEV and allow the isolated AVD/TFT package to reach Unreal boot.

## 6. Boot acceptance

Pull/read the new TFT log and require direct evidence of the effective fragment list. PASS requires HighPerf + 6GB + current GL fragments and no effective LowPerf fragment.

Also report final observed values for at least:

- `tft.DefaultFrameRateLimit`
- `sg.ResolutionQuality`
- `r.Streaming.PoolSize`
- `r.Streaming.PoolSizeForMeshes`
- `Android.OpenGL.NumRemoteProgramCompileServices`
- `r.OpenGL.ProgramLRUEvictTimeSeconds`
- `tft.Audio.DeviceTier`
- animation budget values if logged.

If command-line fragment selection is ignored, do not repeat the same launch. Inspect the consumed command line / log parser result and move to the next causal mechanism, such as a named high-tier profile through `-DP`, without changing Control.

## 7. Combat gate

Only after the boot acceptance passes is the configuration eligible for a representative combat benchmark. The source/boot implementation can reach ACCEPTANCE_PASS without pretending a manual combat match occurred; combat is the next performance-validation gate.
