# TFTMAC GPU Runtime — Single Source of Truth

**Version:** 2.0 revised after ZenGate v2.3 remediation  
**Freeze date:** 2026-08-26  
**Status:** Planning authority; implementation must not begin until the companion implementation plan passes ZenGate  
**Project:** One project only — `TFTMAC`  
**Primary production workload:** Current official Teamfight Tactics Android client  
**Shipping render target:** 1920×1080 at 60 Hz  
**North-star objective:** A general, high-performance Android 3D runtime for Apple Silicon that truthfully provides modern Vulkan capability and genuine OpenGL ES 3.2 through ANGLE, renders through Metal, and is surfaced as a native macOS application.

---

# 1. Product win condition

TFTMAC is complete only when all of the following are true:

1. A source-built Android Emulator/AEMU runtime executes on Apple Silicon.
2. The host Vulkan layer is backed by Metal through a locked MoltenVK implementation.
3. gfxstream transports the required Vulkan features into the Android guest.
4. Android's ANGLE path creates a **real GLES 3.2 EGL context** without nonconformant version spoofing.
5. The current official Google Play TFT client passes its graphics-hardware gate and is playable at 1920×1080.
6. The runtime satisfies the frozen performance acceptance contract in this SSOT.
7. Audio, microphone transport, keyboard/mouse/touch, local diagnostics, update, and rollback are operational.
8. The emulator chrome is hidden in normal use and TFTMAC provides one native macOS application window.
9. The frozen non-TFT generality corpus passes, proving the graphics runtime is not a TFT-only special case.

The final product is not “TFT running in an emulator.”

It is:

> **A modern Apple-Silicon Android graphics runtime, surfaced as a native Mac application, with TFT as its first production workload.**

---

# 2. Hard architecture invariants

## 2.1 One project

There is one repository and one product:

```text
TFTMAC
```

AEMU, gfxstream, ANGLE, MoltenVK, Khronos tests, and reference implementations are upstream dependencies or donors, not separate product projects.

## 2.2 No capability spoofing

The following is never sufficient proof of GLES 3.2:

```text
ro.opengles.version=196610
```

TFTMAC must never ship ANGLE with:

```text
exposeNonConformantExtensionsAndVersions
```

enabled as a way to make software believe unsupported functionality exists.

A GLES 3.2 PASS requires:

```text
EGL context request = 3.2
context creation = success
GL_VERSION = OpenGL ES 3.2...
required executable probe cases = PASS
known render output = PASS
```

## 2.3 No Riot binary modification

TFTMAC may:

- install/update through Google Play;
- inspect package metadata;
- observe runtime graphics behavior;
- control the Android runtime around the app.

TFTMAC may not:

- patch Riot gameplay code;
- bypass Riot graphics checks by modifying Riot binaries;
- re-sign Riot binaries;
- use third-party APK mirrors as package authority;
- commit Riot APKs or private Android userdata to Git.

## 2.4 Measurement owns unknowns

A material unknown is resolved by a deterministic probe at its owning boundary.

The normal failure path is:

```text
host Vulkan
    ↓
gfxstream guest Vulkan
    ↓
Android ANGLE / GLES
    ↓
TFT workload
```

A failure is repaired at the first boundary where evidence changes from PASS to FAIL.

---

# 3. Canonical source authority

## 3.1 Android Emulator branch authority

For this project the authoritative Android Emulator development branch is:

```text
emu-master-dev
```

Reason: the official Android Emulator DEVELOPMENT and macOS development documentation identify `emu-master-dev` as the major emulator development branch and instruct developers to initialize the platform manifest from that branch.

Official references:

- https://android.googlesource.com/platform/external/qemu/+/emu-master-dev/android/docs/DEVELOPMENT.md
- https://android.googlesource.com/platform/external/qemu/+/emu-master-dev/android/docs/DARWIN-DEV.md
- https://android.googlesource.com/platform/manifest/+/refs/heads/emu-master-dev/default.xml

`emu-main-dev` is not co-authoritative for TFTMAC. It may exist upstream, but this project does not mix behavior or assumptions between the two branches.

## 3.2 Freeze rule

Phase 0 initializes:

```bash
repo init \
  -u https://android.googlesource.com/platform/manifest \
  -b emu-master-dev
repo sync -c -j8
repo manifest -r > ssot/upstreams-aemu.lock.xml
```

From that point forward:

```text
ssot/upstreams-aemu.lock.xml
```

is the source authority for the integrated AEMU family.

Current branch names, remembered commits, or web research do not override the resolved manifest.

## 3.3 GuestAngle authority check

Before implementation code changes, the exact locked `external/qemu` revision must be inspected at:

```text
android/android-emu/android/userspace-boot-properties.cpp
```

The preflight must prove that the locked revision:

- supports `GuestAngle`;
- sets Android's hardware EGL implementation to ANGLE when GuestAngle is active;
- enables the Vulkan guest path required by GuestAngle;
- does not automatically enable ANGLE's nonconformant GLES-version exposure.

The verification result is written to:

```text
ssot/guestangle-authority.json
```

If the locked source no longer has materially equivalent semantics, implementation does not guess. The SSOT is revalidated against current source before coding begins.

---

# 4. Frozen production architecture

The primary production guest is **one official Google Play Android 17 ARM64 AVD**.

```text
Official Android 17 Google Play ARM64 guest
                |
        +-------+-------+
        |               |
      GLES           Native Vulkan
        |               |
 Android built-in       |
 ANGLE/Vulkan            |
        +-------+-------+
                |
            gfxstream
                |
       source-built AEMU
                |
             MoltenVK
                |
              Metal
                |
          Apple Silicon GPU
                |
        TFTMAC native shell
```

This is the normal architecture.

---

# 5. Production Android guest

## 5.1 System image

Target packages:

```text
platforms;android-37.1
system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a
```

The exact installed package revisions are resolved by the current Android CLI during Phase 0 and frozen in `STACK.lock.yaml`.

Requirement:

```text
API 37 Google Play image revision >= 5
```

## 5.2 AVD identity

```text
TFTMAC_Live_API37
```

Initial configuration:

```text
Pixel Tablet profile
ARM64
1920x1080
280 DPI
8 vCPU
8192 MB RAM
768 MB VM heap
16 GB data partition minimum
host GPU
audio input enabled
landscape
Google Play enabled
```

No OEM device spoofing beyond the official Pixel Tablet AVD profile.

## 5.3 Runtime ports

```text
Emulator console: 5592
ADB serial: emulator-5592
Isolated ADB server: 5040
```

Development-only gRPC may use:

```text
8554
```

Production control uses the authenticated emulator discovery endpoint and never exposes an unauthenticated fixed control service.

---

# 6. Primary ANGLE strategy

The production GLES path is:

```text
Android built-in ANGLE
<- AEMU GuestAngle
<- guest Vulkan
<- gfxstream
<- MoltenVK
<- Metal
```

Normal launch features:

```text
GuestAngle
Vulkan
GLESDynamicVersion
```

No custom ANGLE build is on the normal critical path.

---

# 7. Conditional custom ANGLE adapter

A custom ANGLE build is allowed only if all of the following are already proven:

1. host Vulkan requirements are green;
2. gfxstream guest Vulkan requirements are green;
3. built-in Android 17 ANGLE still refuses or misimplements a genuine ES 3.2 context;
4. the failure is traced to the built-in ANGLE revision rather than Vulkan capability.

Only then may the plan activate:

```text
Custom ANGLE Adapter
```

Because a non-debuggable app cannot normally select a loose custom ANGLE package without root, this conditional adapter may introduce a **rootable Android 17 execution guest** while retaining the Google Play AVD as package/update authority.

This is a conditional repair route, not a second normal architecture.

It must not be built speculatively.

---

# 8. Frozen toolchain and dependency family

## 8.1 Apple

```text
Xcode 26.6
Build 17F113
```

Official:
- https://developer.apple.com/download/all/
- https://developer.apple.com/xcode/system-requirements/

## 8.2 Android command-line tools

```text
commandlinetools-mac_arm64-15859902_latest.zip
SHA-256:
835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e
```

Official:
- https://developer.android.com/studio
- https://dl.google.com/android/repository/commandlinetools-mac_arm64-15859902_latest.zip

## 8.3 Platform tools and control emulator

Initial control references:

```text
Platform-Tools 37.0.1
Android Emulator 37.1.11
```

The exact installed package revisions are frozen during preflight.

## 8.4 Vulkan SDK

```text
Vulkan SDK 1.4.357.0
macOS SHA-256:
539433589c83522e6f31b1c7b418a4167e21597a4a361ab119e1dc0760cf3865
```

Official:
- https://vulkan.lunarg.com/sdk/home

The SDK is the developer/validation toolchain, not the shipping driver once TFTMAC uses its selected MoltenVK build.

## 8.5 MoltenVK

Reference baseline:

```text
MoltenVK v1.4.2
```

Official:
- https://github.com/KhronosGroup/MoltenVK
- https://github.com/KhronosGroup/MoltenVK/releases

TFTMAC first tests the MoltenVK revision resolved by the locked AEMU manifest, then compares it with upstream v1.4.2.

The better required feature set wins only if integration remains clean.

## 8.6 UTM/CrossOver donor

UTM/CrossOver MoltenVK geometry/cull work is a donor/reference only.

Official/reference:
- https://github.com/utmapp/UTM/issues/7575
- https://github.com/utmapp/UTM/releases
- https://github.com/utmapp/MoltenVK/tree/crossovers/v25.1.0

Never replace the selected MoltenVK base wholesale merely because UTM already contains a feature.

Port only the smallest causal patch after probe evidence.

---

# 9. Persistent filesystem authority

Bulk storage authority is the external M4 volume:

```text
/Volumes/MAC MINI M4/TFTMAC/
├── Build/
└── Runtime/
    ├── SDK/
    ├── AVD/
    ├── Packages/
    ├── Probes/
    ├── Manifests/
    └── VulkanSDK/
```

Small control/log state may remain internal:

```text
~/Library/Application Support/TFTMAC/
├── Logs/
├── Diagnostics/
└── Rollback/
```

The external volume is mandatory for default Build and Runtime roots. If `/Volumes/MAC MINI M4` is unavailable, TFTMAC fails closed and must not create bulk Build or Runtime data on the internal disk.

Repository stores only code, lock files, patches, probes, manifests that contain no protected data, documentation, and tests.

The repository must not contain:

```text
Riot APKs
Google credentials
Riot credentials
AVD userdata
session tokens
OAuth tokens
private runtime disks
```

---

# 10. Capability laboratory

The capability laboratory is permanent product infrastructure.

## 10.1 Host Vulkan probe

Produces:

```text
Diagnostics/host-vulkan.json
```

Checks and executes representative workloads for:

- API version;
- device/driver;
- geometry shaders;
- tessellation;
- shader cull distance;
- indirect draw;
- descriptor indexing;
- timeline semaphores;
- synchronization2;
- dynamic rendering;
- buffer device address;
- subgroups;
- sampler/filter features.

Enumeration alone is not proof.

## 10.2 Guest Vulkan probe

Produces:

```text
Diagnostics/guest-vulkan.json
Diagnostics/vulkan-transport-delta.json
```

The delta report is the semantic owner for determining whether a missing capability belongs to MoltenVK or gfxstream/AEMU.

## 10.3 Guest GLES 3.2 probe

Package:

```text
dev.tftmac.gpuprobe
```

Must execute:

- EGL initialization;
- ES3 renderable config;
- 3.2 context creation;
- GL_VERSION / GL_VENDOR / GL_RENDERER;
- extension inventory;
- geometry shader;
- tessellation;
- compute;
- SSBO;
- texture buffer;
- cube-map array;
- multisample/sample shading;
- base-vertex path;
- synchronization;
- deterministic known-image output.

## 10.4 Frame and input probe

Produces:

```text
Diagnostics/frame-performance.json
Diagnostics/input-latency.json
```

Sources:

- SurfaceFlinger timestats;
- gfxinfo framestats where applicable;
- host monotonic timestamps;
- Android display refresh;
- native-shell input injection timestamps;
- first observable changed frame.

---

# 11. Frozen performance acceptance contract

This contract is fixed **before optimization** and must not be changed merely because a candidate misses it.

## 11.1 Display budget

Shipping refresh:

```text
60 Hz
```

One frame budget:

```text
16.667 ms
```

Two-frame budget:

```text
33.334 ms
```

## 11.2 Gameplay measurement window

For TFT performance acceptance:

1. Enter a live rendered match.
2. Exclude the first **120 seconds** as shader/content warm-up.
3. Capture the next **600 continuous seconds**.
4. Use SurfaceFlinger-based presentation timestamps as the primary FPS/frame-time source.
5. If a metric is unavailable for a specific surface, record the fallback source explicitly rather than silently changing methodology.

## 11.3 Absolute graphics thresholds

Over the 600-second measurement window:

```text
Average presented FPS >= 58.0
P95 frame interval <= 20.0 ms
P99 frame interval <= 33.334 ms
Janky frame = interval > 33.334 ms
Janky frames <= 1.0%
Severe stall = interval > 100 ms
Severe stalls <= 3 in 600 seconds
No renderer crash
No Vulkan device loss
No repeated validation-error storm
```

58 FPS is the minimum 96.7% delivery rate for a 60 Hz target.

P99 is capped at two frame budgets.

## 11.4 Candidate regression thresholds

A candidate runtime is not promoted if, compared with the currently accepted runtime under the same workload:

```text
Average FPS decreases by > 1.0 FPS
or
P99 frame interval worsens by > 3%
or
jank percentage worsens by > 0.25 percentage points
or
median synthetic input-to-present latency worsens by > 5 ms
or
P95 synthetic input-to-present latency worsens by > 8.334 ms
```

A candidate must satisfy both absolute and regression thresholds.

## 11.5 Native-wrapper input thresholds

The native MMAP/Metal presentation path is compared against the direct emulator Qt control path using the deterministic input probe.

Requirements:

```text
Median native input-to-present <= Qt control + 5 ms
P95 native input-to-present <= Qt control + 8.334 ms
Absolute median input-to-present <= 50 ms
Absolute P95 input-to-present <= 83.334 ms
```

The native shell does not ship if it fails these bounds.

## 11.6 Resource-profile selection

Approved initial profiles:

```text
A: 6 vCPU / 6144 MB
B: 8 vCPU / 8192 MB
```

Both run the same measurement workload.

Selection:

1. profile must satisfy all absolute thresholds;
2. lower P99 wins;
3. if P99 differs by <3%, lower host CPU usage wins;
4. selected profile is written to the runtime manifest.

No third profile is added unless both A and B fail an explicit resource constraint.

---

# 12. Frozen generality acceptance corpus

The corpus is selected now, before graphics implementation.

Implementation agents may not substitute easier tests.

## Corpus A — Khronos OpenGL ES CTS 3.2

Source:

```text
KhronosGroup/VK-GL-CTS
Tag: opengl-es-cts-3.2.14.1
Release commit prefix published by Khronos: 067e883
License: Apache-2.0
API: OpenGL ES 3.2 / EGL
```

Official:
- https://github.com/KhronosGroup/VK-GL-CTS/releases
- https://github.com/KhronosGroup/VK-GL-CTS

Before any implementation mutation, bootstrap resolves the full immutable tag commit with:

```bash
git rev-list -n 1 opengl-es-cts-3.2.14.1
```

and writes it into `STACK.lock.yaml`.

Pass condition:

- build the Android GLES32 CTS;
- run the official GLES 3.2 mustpass case list applicable to the declared context;
- zero `Fail`;
- zero `Crash`;
- zero `Timeout`;
- `NotSupported` is allowed only when the CTS itself treats the feature as optional for the declared API/extension set;
- produce the complete `.qpa` log and summary artifact.

## Corpus B — Khronos Vulkan CTS 1.4.6.1

Source:

```text
KhronosGroup/VK-GL-CTS
Tag: vulkan-cts-1.4.6.1
Commit:
5c8aae22885448d70a2873e94a93b24b49505c32
License: Apache-2.0
API: Vulkan
```

Official:
- https://chromium.googlesource.com/external/github.com/KhronosGroup/VK-GL-CTS/+/refs/tags/vulkan-cts-1.4.6.1

TFTMAC does not claim full Vulkan 1.4 conformance merely by running this corpus.

The project freezes a **runtime-required Vulkan case list** before implementation, derived from:

- features needed by the GLES 3.2 probe;
- core draw/compute/image/synchronization paths used by TFTMAC;
- dynamic rendering and WSI paths used by the host/guest stack.

The exact case list is stored as:

```text
ssot/vulkan-required-cases.txt
```

and hashed in `STACK.lock.yaml`.

Pass condition:

```text
zero Fail
zero Crash
zero Timeout
all cases in vulkan-required-cases.txt executed
```

Unsupported optional cases are not added to the required list after results are known.

## Corpus C — Khronos Vulkan Samples

Source:

```text
KhronosGroup/Vulkan-Samples
Commit:
89dd3af22d41f9244eeab6e0650460112285c0e1
License: Apache-2.0
Android ARM64
```

Pinned workloads:

```text
dynamic_rendering
compute_nbody
```

Official:
- https://github.com/KhronosGroup/Vulkan-Samples

Pass condition for each workload:

1. build the pinned Android sample APK;
2. run at 1920×1080;
3. complete 10,000 rendered frames or 10 minutes, whichever occurs first;
4. zero process crash;
5. zero Vulkan device loss;
6. zero validation-layer errors classified as ERROR;
7. application remains responsive to injected Back/Home/input probe;
8. capture startup, mid-run, and final screenshots; each must contain non-uniform rendered content and the application surface must remain present.

The corpus therefore contains both standardized conformance evidence and app-like Vulkan workloads.

---

# 13. Patch policy

The patch order is:

```text
1. Existing supported configuration
2. Small local patch
3. Harvest a known donor implementation
4. New compatibility implementation
```

Every patch records:

```text
component
upstream commit
reason
probe failing before
probe passing after
performance delta
upstreamability
```

## 13.1 MoltenVK geometry rule

If the host Vulkan probe reports a required geometry/cull capability missing:

1. reproduce the failure;
2. inspect current MoltenVK;
3. inspect UTM/CrossOver donor work;
4. port the smallest compatible patch;
5. add direct geometry regression coverage;
6. explicitly test indirect-draw interaction;
7. reject the patch if it only changes feature reporting without executing the workload.

---

# 14. Package authority and update chain

Google Play is the semantic owner of production app acquisition.

For each TFT version, TFTMAC records:

```json
{
  "packageName": "com.riotgames.league.teamfighttactics",
  "installer": "com.android.vending",
  "versionName": "...",
  "versionCode": 0,
  "capturedAt": "...",
  "apks": [
    {
      "path": "...",
      "size": 0,
      "sha256": "..."
    }
  ],
  "signingCertificateSHA256": "..."
}
```

The manifest stays outside Git if it contains private local paths.

Normal production updates happen through Google Play in the production AVD.

A runtime update and a game update are separate operations.

---

# 15. Native macOS shell

Final normal-use architecture:

```text
Android runtime hidden
        |
emulator controller
        |
shared/MMAP frame transport
        |
Metal texture
        |
native macOS view
```

The shell owns:

- Play/Stop;
- Back/Home;
- fullscreen/window;
- volume;
- microphone;
- keyboard/mouse/touch;
- screenshot;
- diagnostics;
- Google Play/update navigation;
- rollback/runtime status.

Production gRPC control uses authenticated local discovery.

An unauthenticated fixed gRPC port is development-only.

---

# 16. Audio and microphone

## Audio

Start with the emulator's direct CoreAudio path.

Only replace it with gRPC `streamAudio` if measured latency/underrun evidence demonstrates an improvement.

## Microphone

Final path:

```text
macOS CoreAudio input
-> macOS microphone permission
-> TFTMAC capture
-> emulator controller injectAudio
-> Android virtual microphone
-> Android app
```

Mic acceptance uses a dedicated Android test app before relying on a game feature.

TFTMAC can guarantee microphone transport; it cannot guarantee that every Android application exposes in-app voice chat.

---

# 17. Diagnostics

Default local root:

```text
~/Library/Application Support/TFTMAC/Logs/
```

Each session records:

- runtime build ID;
- AEMU manifest hash;
- qemu/AEMU/gfxstream commits;
- MoltenVK commit and patches;
- Android image revision;
- ANGLE identity;
- app identity/version;
- display/resource profile;
- host model/macOS;
- renderer strings;
- Vulkan/GLES capability hashes;
- boot/launch times;
- frame statistics;
- CPU/memory;
- audio/mic state;
- input latency;
- errors/crashes;
- clean shutdown.

No remote telemetry is required.

---

# 18. Update and rollback

Persistent runtime slots:

```text
Runtime/current
Runtime/previous
```

Promotion:

```text
candidate build
-> source/lock verification
-> capability probes
-> generality corpus smoke subset
-> TFT launch smoke
-> performance regression gate
-> promote current
-> old current becomes previous
```

Failure:

```text
candidate rejected
current remains active
```

AVD userdata is not destroyed by a runtime binary promotion.

---

# 19. Machine SSOT

`STACK.lock.yaml` contains exact resolved values.

Required fields include:

```yaml
schema: 2
frozen_at: "2026-08-26"

aemu:
  authority_branch: "emu-master-dev"
  resolved_manifest_sha256: null
  qemu_commit: null
  aemu_commit: null
  gfxstream_commit: null
  integrated_angle_commit: null
  integrated_moltenvk_commit: null

android:
  api: 37
  play_image_package: "system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a"
  play_image_revision: null

moltenvk:
  reference_tag: "v1.4.2"
  selected_commit: null
  patch_series_sha256: null

generality:
  gles_cts_tag: "opengl-es-cts-3.2.14.1"
  gles_cts_commit: null
  vulkan_cts_tag: "vulkan-cts-1.4.6.1"
  vulkan_cts_commit: "5c8aae22885448d70a2873e94a93b24b49505c32"
  vulkan_required_cases_sha256: null
  vulkan_samples_commit: "89dd3af22d41f9244eeab6e0650460112285c0e1"

performance:
  fps_min: 58.0
  p95_ms_max: 20.0
  p99_ms_max: 33.334
  jank_threshold_ms: 33.334
  jank_pct_max: 1.0
  severe_stall_ms: 100.0
  severe_stalls_per_600s_max: 3
```

Every `null` critical-path field must be resolved during Phase 0 **before implementation mutation begins**.

After Phase 0:

```text
STACK.lock.yaml contains no unresolved critical-path null.
```

---

# 20. Requirement-to-proof traceability

| Requirement | Semantic owner / phase | Proof artifact | Pass condition |
|---|---|---|---|
| Reproducible toolchain/source | Phase 0 | `STACK.lock.yaml`, resolved manifest, hashes | No unresolved critical-path fields; hashes match |
| One authoritative AEMU branch | Phase 0 | `guestangle-authority.json` | Locked `emu-master-dev` source proves required GuestAngle semantics |
| Source-built AEMU | Phase 1 | build/test logs | Build succeeds; unit tests pass; production AVD boots |
| Real host Vulkan capability | Phase 2–3 | `host-vulkan.json` | Required executable feature probes pass |
| Correct gfxstream transport | Phase 4 | `vulkan-transport-delta.json` | No required host-green capability is guest-red |
| Genuine GLES 3.2 | Phase 5 | `guest-gles32.json`, render image | Real 3.2 context + every required executable case passes |
| No capability spoof | Phase 5 | runtime env/source audit | Nonconformant exposure absent in shipping config |
| Current official TFT works | Phase 6 | Google Play manifest + gameplay acceptance | Current client launches, queues, renders, 20+ min live session |
| 1920×1080 performance | Phase 7 | `frame-performance.json` | Meets every frozen absolute threshold |
| No performance regression | Phase 7 | benchmark comparison | Meets every frozen regression threshold |
| Audio | Phase 7 | audio diagnostic | Continuous output; no blocking underrun/error |
| Microphone transport | Phase 7 | mic loopback/test artifact | CoreAudio→Android input path verified |
| Input | Phase 7/8 | `input-latency.json` | Meets absolute and relative latency bounds |
| Native Mac single window | Phase 8 | UI acceptance + latency comparison | One native window; hidden emulator chrome; latency gate passes |
| Diagnostics | Phase 7–8 | session bundle | Required fields emitted; crash/error evidence retained |
| Google Play update path | Phase 9 | update acceptance | Update through Play retains runtime and package authority |
| Rollback | Phase 9 | rollback acceptance | Failed candidate leaves current active; previous restorable |
| General GLES compatibility | Phase 9 | GLES CTS `.qpa` | Corpus A pass criteria |
| General Vulkan compatibility | Phase 9 | Vulkan CTS + samples logs | Corpora B/C pass criteria |
| Release packaging | Phase 9 | codesign/notary receipts | Signed/notarized app passes local launch |
| No protected binary/data leakage | All phases | Git scan / package audit | No Riot APKs, credentials, userdata, tokens committed or bundled |

This matrix is the canonical requirement-to-proof map.

---

# 21. Known measured unknowns

These are not architecture decisions left open.

They are deterministic measurements:

1. exact resolved commits on `emu-master-dev`;
2. exact selected API 37 Play image revision;
3. exact Vulkan feature delta;
4. whether selected MoltenVK already provides every host requirement;
5. whether gfxstream loses any required feature;
6. whether Android built-in ANGLE creates genuine ES 3.2 after Vulkan is correct;
7. whether the conditional custom ANGLE adapter is needed;
8. current TFT requirements beyond GLES 3.2, if any;
9. which of the two frozen guest resource profiles wins;
10. whether native MMAP/Metal presentation satisfies the frozen latency gate.

Each item has one evidence-producing phase in the companion plan.

---

# 22. Final authority rule

There is no architecture-precedence workaround between documents.

This SSOT and `TFTMAC_FULL_IMPLEMENTATION_PLAN.md` must describe the same production architecture.

For machine-resolved values:

```text
STACK.lock.yaml
```

wins over remembered prose after Phase 0.

For capability decisions:

```text
probe output
```

wins over hypotheses.

For performance:

```text
frozen acceptance contract + benchmark evidence
```

wins over subjective judgment.

Any future architecture change updates the SSOT and implementation plan together before implementation proceeds.
