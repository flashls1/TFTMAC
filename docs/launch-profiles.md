# TFTMAC Launch Profiles

**Reconciled:** 2026-09-10 America/Chicago
**Authority:** read `facts.md` first and `project.md` second. This file is a concise launch-profile reference and cannot override them.

## Current DEV working profile — `DEV-B8-WIN-01`

```text
Application: /Applications/TFTMAC DEV.app
Bundle: com.flashls1.tftmac.dev
Release identity: 2.3.0 build 8
Runtime mode: advanced_diagnostics / StockShadow
Runtime root: /Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow
AVD: TFTMAC_Diagnostic_StockShadow_R1
ADB / console / controller: 5041 / 5586 / 8556
Serial: emulator-5586
Display: 1920x1080 / 320 dpi / 60 Hz
Effective guest: 8 vCPU / 6144 MiB
GPU / audio: host / CoreAudio
Graphics route: Unreal OpenGL ES -> ANGLE -> Vulkan/ranchu -> gfxstream -> host Vulkan/MoltenVK -> Metal
ASG: 1 MiB write buffer / 16 KiB write step / 32 KiB ring / 800 us flush
ANGLE enabled: exposeNonConformant*:exposeES32ForTesting
ANGLE disabled: preferSubmitAtFBOBoundary
Cache: debug.egl.blobcache.multifile=true; syncMonolithicPipelinesToBlobCache removed
Official TFT: 18.1-5423749 / versionCode 8423749
```

The static StockShadow AVD restoration file remains 6 vCPU / 5120 MiB. Current source defaults `advanced_diagnostics` to 8 vCPU and uses the locked 6144-MiB DEV RAM value; live QEMU receipts prove `-cores 8 -memory 6144`. Do not rewrite the static AVD simply to make it resemble the transient effective launch.

Every new optimization candidate starts from `DEV-B8-WIN-01` until a later verified winner is promoted. Verified net improvement is integrated; no-win/inconclusive/regression is logged and not integrated.

## Protected Control profile — historical/playable rollback

```text
Application: /Applications/TFTMAC.app
Bundle: com.flashls1.tftmac
Runtime root: /Volumes/MAC MINI M4/TFTMAC/Runtime
AVD: TFT_Ultra_Tablet
ADB / console / controller: 5038 / 5582 / 8554
Serial: emulator-5582
Historical baseline: 1920x1080 / 320 dpi / 60 Hz / 6 vCPU / 5120 MiB
TFT: High / 60 FPS / Riot Performance Mode OFF
```

Control/LKG stays separate and immutable. Its older client/version/performance receipts remain valid only for their recorded dates and are not the current DEV optimization truth.

## Rejected/historical profiles

- `combat_latency_a`: historical rejected candidate; no current promotion.
- Riot Performance Mode Beta / Home Run A: rejected.
- Direct Unreal Vulkan: current fast-pass NO WIN due compatibility failures.
- `queue_submit_inline`: NO WIN / boot-incompatible.
- `virtual_queue_off`, `fence_contexts_off`: prior official-client NO WIN results.

The legacy launcher table remains archived under `docs/history/2026-08-31-pre-build8/`.
