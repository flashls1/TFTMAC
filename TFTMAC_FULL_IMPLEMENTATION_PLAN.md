# TFTMAC GPU Runtime — Full Implementation Plan

**Version:** 2.0 revised after ZenGate v2.3 remediation  
**Date:** 2026-08-26  
**Governing SSOT:** `TFTMAC_GPU_RUNTIME_SSOT.md` v2.0  
**Status:** Execution plan; implementation must not begin until this plan passes ZenGate v2.3  
**Project:** One project only — `TFTMAC`

---

# 0. Concrete win condition

Build and release one Apple-Silicon Android 3D runtime that:

- uses the official Android 17 Google Play ARM64 guest;
- uses source-built AEMU from one frozen `emu-master-dev` manifest;
- transports required Vulkan capability through gfxstream;
- provides a genuine OpenGL ES 3.2 context through built-in Android ANGLE without nonconformant version exposure;
- renders through MoltenVK/Metal;
- runs the current official Google Play TFT client at 1920×1080;
- meets the frozen performance and latency contract;
- supports audio, microphone transport, input, diagnostics, update, and rollback;
- presents as one native macOS application with emulator chrome hidden;
- passes the frozen non-TFT generality corpus.

No phase is complete merely because a command exits 0. Each phase has an evidence artifact and a behavioral exit gate.

---

# 1. Fixed architecture

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
        selected MoltenVK
                |
              Metal
                |
          Apple Silicon GPU
                |
        native TFTMAC shell
```

Normal production uses one Google Play AVD.

A rootable execution guest and custom ANGLE are a **conditional repair adapter only**. They are not prebuilt or maintained unless Phase 5 proves built-in ANGLE itself is the remaining blocker.

---

# 2. Phase map

```text
PHASE 0 — Authority + preflight freeze
PHASE 1 — Build unmodified source AEMU
PHASE 2 — Build capability laboratory
PHASE 3 — Make host Vulkan capability real
PHASE 4 — Make gfxstream preserve required Vulkan capability
PHASE 5 — Prove genuine built-in-ANGLE GLES 3.2
PHASE 6 — Current official TFT vertical slice
PHASE 7 — Performance, diagnostics, audio, mic, input
PHASE 8 — Native macOS presentation
PHASE 9 — Update, rollback, generality, release
```

Each phase changes only the layer that owns the current failure.

---

# PHASE 0 — Authority and complete preflight freeze

## Objective

Resolve every drift-sensitive critical input before implementation code changes.

At Phase 0 exit:

```text
STACK.lock.yaml contains no unresolved critical-path field.
```

## 0.1 Host identity

Require:

```text
Apple Silicon arm64
supported macOS for Xcode 26.6
Xcode 26.6 / 17F113
```

Record:

```bash
uname -m
sw_vers
xcodebuild -version
xcrun --sdk macosx --show-sdk-path
system_profiler SPHardwareDataType
```

Write:

```text
ssot/host-preflight.json
```

## 0.2 Canonical local roots

Bulk build/runtime data is external and mandatory:

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

If `/Volumes/MAC MINI M4` is not mounted, TFTMAC fails closed and must not create Build or Runtime data on the internal disk. No source file hardcodes the current developer checkout path.

## 0.3 Android command-line tools

Download:

```text
commandlinetools-mac_arm64-15859902_latest.zip
```

Verify:

```text
SHA-256
835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e
```

Install into TFTMAC-local SDK root.

Do not use the user's global Android SDK as production authority.

## 0.4 SDK packages

Using the TFTMAC-local `sdkmanager`, install:

```text
platform-tools
emulator
platforms;android-37.1
build-tools;37.0.0
system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a
```

Run:

```bash
sdkmanager --list_installed
```

Freeze exact revisions.

API 37 Google Play image must be revision >= 5.

Write:

```text
ssot/android-sdk-packages.txt
```

## 0.5 Production AVD

Create:

```bash
avdmanager create avd \
  --name TFTMAC_Live_API37 \
  --package "system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a" \
  --device pixel_tablet \
  --force
```

Normalize configuration:

```text
AvdId=TFTMAC_Live_API37
avd.ini.displayname=TFTMAC Live
hw.device.manufacturer=Google
hw.device.name=pixel_tablet
hw.initialOrientation=Landscape
hw.cpu.arch=arm64
hw.cpu.ncore=8
hw.ramSize=8192
hw.vmHeapSize=768
hw.lcd.width=1920
hw.lcd.height=1080
hw.lcd.density=280
hw.gpu.enabled=yes
hw.gpu.mode=host
hw.audioInput=yes
hw.keyboard=yes
showDeviceFrame=no
skin.name=1920x1080
disk.dataPartition.size=16G
runtime.network.speed=full
runtime.network.latency=none
PlayStore.enabled=true
fastboot.forceColdBoot=yes
fastboot.forceFastBoot=no
```

## 0.6 Vulkan developer SDK

Install:

```text
Vulkan SDK 1.4.357.0
SHA-256:
539433589c83522e6f31b1c7b418a4167e21597a4a361ab119e1dc0760cf3865
```

Require:

```bash
vulkaninfo --summary
```

## 0.7 AEMU source authority

The project uses only:

```text
emu-master-dev
```

Initialize:

```bash
mkdir -p "/Volumes/MAC MINI M4/TFTMAC/Build/aemu"
cd "/Volumes/MAC MINI M4/TFTMAC/Build/aemu"

repo init \
  -u https://android.googlesource.com/platform/manifest \
  -b emu-master-dev

repo sync -c -j8
```

Freeze:

```bash
repo manifest -r > "$TFTMAC_REPO/ssot/upstreams-aemu.lock.xml"
shasum -a 256 "$TFTMAC_REPO/ssot/upstreams-aemu.lock.xml"
```

Record exact commits:

```bash
git -C external/qemu rev-parse HEAD
git -C hardware/google/aemu rev-parse HEAD
git -C hardware/google/gfxstream rev-parse HEAD
git -C external/angle rev-parse HEAD
git -C external/moltenvk rev-parse HEAD
```

Write them into `STACK.lock.yaml`.

## 0.8 GuestAngle source-authority assertion

Inspect the exact locked QEMU revision:

```text
external/qemu/android/android-emu/android/userspace-boot-properties.cpp
```

The preflight script must prove the locked source implements materially equivalent GuestAngle behavior to:

```text
hardware EGL -> angle
hardware Vulkan -> ranchu/guest Vulkan path
nonconformant ES version exposure not automatically enabled
```

Write:

```text
ssot/guestangle-authority.json
```

The JSON contains:

```text
qemu commit
source file hash
GuestAngle symbol/location
hardware EGL value
hardware Vulkan value
nonconformant exposure policy
PASS/FAIL
```

If FAIL, no code mutation begins. The source review updates both planning documents before execution.

This is the only source-authority stop condition.

## 0.9 MoltenVK reference lock

Freeze:

```text
MoltenVK v1.4.2
```

Store reference checkout:

```text
Build/references/MoltenVK-1.4.2
```

Record exact commit.

Do not yet replace the manifest-integrated MoltenVK.

## 0.10 Freeze the generality corpus

### OpenGL ES

Pin:

```text
Khronos VK-GL-CTS
opengl-es-cts-3.2.14.1
Apache-2.0
```

Resolve and lock full commit before implementation:

```bash
git rev-list -n 1 opengl-es-cts-3.2.14.1
```

### Vulkan CTS

Pin:

```text
vulkan-cts-1.4.6.1
5c8aae22885448d70a2873e94a93b24b49505c32
Apache-2.0
```

Create `ssot/vulkan-required-cases.txt` before implementation.

The case list must include only cases required by:

- TFTMAC guest Vulkan probe;
- GLES 3.2 feature dependencies;
- draw;
- compute;
- image;
- synchronization;
- dynamic rendering;
- WSI/presentation used by the runtime.

Hash and lock the case list.

Do not remove cases later because they fail.

### Vulkan Samples

Pin:

```text
Khronos Vulkan-Samples
89dd3af22d41f9244eeab6e0650460112285c0e1
Apache-2.0
```

Frozen sample names:

```text
dynamic_rendering
compute_nbody
```

## 0.11 Freeze performance contract

Copy the SSOT performance values into `STACK.lock.yaml`:

```text
FPS minimum: 58.0
P95 max: 20.0 ms
P99 max: 33.334 ms
jank threshold: >33.334 ms
jank max: 1.0%
severe stall: >100 ms
severe stalls max: 3 / 600 seconds

native input median:
  <= Qt control + 5 ms
  <= 50 ms absolute

native input P95:
  <= Qt control + 8.334 ms
  <= 83.334 ms absolute
```

These values cannot be changed during tuning to make a candidate pass.

## 0.12 Generate complete Phase 0 artifacts

Required:

```text
ssot/STACK.lock.yaml
ssot/upstreams-aemu.lock.xml
ssot/host-preflight.json
ssot/android-sdk-packages.txt
ssot/tool-versions.txt
ssot/source-hashes.txt
ssot/guestangle-authority.json
ssot/vulkan-required-cases.txt
ssot/preflight-report.md
```

### Phase 0 exit gate

PASS only if:

```text
host = supported
all downloaded hashes = verified
Android image = exact and rev >=5
AEMU = emu-master-dev
resolved manifest = frozen
GuestAngle locked-source semantics = PASS
MoltenVK reference = frozen
GLES CTS full commit = frozen
Vulkan CTS = frozen
Vulkan required cases = frozen and hashed
Vulkan Samples = frozen
performance contract = frozen
no critical-path null remains
```

---

# PHASE 1 — Build unmodified source AEMU

## Objective

Prove the locked integrated source family builds and boots before graphics modification.

## 1.1 Build

From locked source:

```bash
cd "/Volumes/MAC MINI M4/TFTMAC/Build/aemu/external/qemu"
android/rebuild.sh \
  --out-dir="/Volumes/MAC MINI M4/TFTMAC/Build/aemu-out"
```

## 1.2 Unit tests

```bash
cd "/Volumes/MAC MINI M4/TFTMAC/Build/aemu-out"
ctest -j8 --output-on-failure
```

Also:

```bash
cd "/Volumes/MAC MINI M4/TFTMAC/Build/aemu/external/qemu"
python android/build/python/cmake.py --gfxstream
```

## 1.3 Boot production AVD

Use source-built emulator:

```bash
emulator @TFTMAC_Live_API37 \
  -port 5592 \
  -gpu host \
  -feature GuestAngle,Vulkan,GLESDynamicVersion \
  -no-snapshot \
  -no-boot-anim \
  -no-metrics
```

Environment:

```text
ANDROID_ADB_SERVER_PORT=5040
```

## 1.4 Verify runtime parity

Capture:

```text
getprop
SurfaceFlinger
display
logcat
emulator version
host renderer log
Google Play launch
```

### Phase 1 proof

Artifacts:

```text
Diagnostics/phase1-build.json
Diagnostics/phase1-boot.json
```

PASS:

- source build succeeds;
- unit tests green;
- AVD boots;
- GuestAngle active;
- Google Play opens;
- no patch is yet required.

If the source build fails, repair toolchain/build parity only.

---

# PHASE 2 — Build the capability laboratory

## Objective

Make every graphics failure attributable without a game.

## 2.1 Host Vulkan probe

Native macOS executable.

Required executable feature set:

```text
API/device identity
geometry shader
tessellation
shader cull distance
indirect draw
descriptor indexing
timeline semaphore
synchronization2
dynamic rendering
buffer device address
subgroups
sampler/filter behavior
```

Output:

```text
Diagnostics/host-vulkan.json
```

## 2.2 Guest Vulkan probe

Android ARM64 probe.

Same schema.

Output:

```text
Diagnostics/guest-vulkan.json
Diagnostics/vulkan-transport-delta.json
```

## 2.3 Guest GLES 3.2 probe

Package:

```text
dev.tftmac.gpuprobe
```

Tests:

```text
EGL initialization
ES3 renderable config
3.2 context creation
GL_VERSION
GL_RENDERER
GL_VENDOR
extension inventory
geometry compile/link/draw
tessellation compile/link/draw
compute
SSBO
texture buffer
cube-map array
multisample/sample shading
base vertex
fence/sync
known rendered output
```

Output:

```text
Diagnostics/guest-gles32.json
Diagnostics/guest-gles32-frame.png
```

## 2.4 Frame/input probe

Implements deterministic surface animation and visible state change on injected input.

Outputs:

```text
Diagnostics/frame-performance.json
Diagnostics/input-latency.json
```

## 2.5 Probe self-test

The probe suite must intentionally detect:

- a forced feature-disabled configuration;
- a wrong GL version;
- a corrupted expected render checksum.

This proves the verifier can go red.

### Phase 2 exit gate

Every probe compiles, runs, returns structured evidence, and detects intentional negative cases.

---

# PHASE 3 — Make host Vulkan capability real

## Objective

Provide the host Vulkan features actually required by the guest GLES 3.2 path.

## 3.1 Baseline integrated MoltenVK

Run host probe against the MoltenVK revision from the locked AEMU family.

Store:

```text
Diagnostics/moltenvk-integrated.json
```

## 3.2 Baseline upstream v1.4.2

Build:

```bash
./fetchDependencies --macos
make macos
```

Run the same probe.

Store:

```text
Diagnostics/moltenvk-1.4.2.json
```

## 3.3 Select host driver base

Algorithm:

```text
required = host Vulkan features consumed by guest probe / GLES 3.2 dependency map

if integrated satisfies required:
    select integrated
elif v1.4.2 satisfies a strict superset and integrates cleanly:
    select v1.4.2
else:
    select integrated
    port only causal required improvements
```

Record selection in `STACK.lock.yaml`.

## 3.4 Causal geometry/cull repair

If a required feature such as geometry shader or shader cull distance is absent:

1. reproduce failure in host probe;
2. inspect selected MoltenVK;
3. inspect UTM/CrossOver donor;
4. port smallest compatible implementation;
5. run direct feature test;
6. run indirect-draw interaction test;
7. reject any patch that only changes advertised feature bits.

No other MoltenVK changes are permitted until the required host probe says they are causal.

### Phase 3 exit gate

All host Vulkan capabilities required by Phase 5 are executable and green.

---

# PHASE 4 — Make gfxstream preserve required Vulkan capability

## Objective

Ensure the Android guest sees working features, not merely the host.

## 4.1 Boot source AEMU with selected Phase 3 host Vulkan

Features:

```text
GuestAngle
Vulkan
GLESDynamicVersion
```

No nonconformant ANGLE exposure.

## 4.2 Run guest Vulkan probe

Generate transport delta.

## 4.3 Repair only host-green / guest-red features

If:

```text
host feature = PASS
guest feature = FAIL
```

then gfxstream/AEMU owns the repair.

Inspect:

- feature filtering;
- `VkPhysicalDeviceFeatures*`;
- extension filtering;
- encoder/decoder support;
- host feature discovery;
- MoltenVK-specific host policy.

Every patch records before/after probe state.

Never expose a guest feature until its guest executable test passes.

### Phase 4 exit gate

No Vulkan capability required by the frozen GLES 3.2 dependency map is host-green / guest-red.

---

# PHASE 5 — Prove genuine built-in-ANGLE GLES 3.2

## Objective

Pass the exact graphics contract that current TFT requires without lying about capability.

## 5.1 Clean production boot

```bash
emulator @TFTMAC_Live_API37 \
  -port 5592 \
  -gpu host \
  -feature GuestAngle,Vulkan,GLESDynamicVersion \
  -no-snapshot \
  -no-metrics
```

Forbidden:

```text
ANGLE_FEATURE_OVERRIDES_ENABLED=exposeNonConformantExtensionsAndVersions
```

## 5.2 Run guest GLES 3.2 probe

Required:

```text
context_requested = 3.2
context_created = true
GL_VERSION = OpenGL ES 3.2...
ANGLE/Vulkan renderer path identified
all executable cases = PASS
known frame = PASS
```

## 5.3 Failure routing

### Host Vulkan red

Return Phase 3.

### Host green, guest Vulkan red

Return Phase 4.

### Guest Vulkan required set green, built-in ANGLE still caps at 3.1

Now inspect the exact locked built-in ANGLE revision and requirement code.

Only if ANGLE revision behavior itself is the blocker activate:

```text
Custom ANGLE Adapter
```

## 5.4 Conditional Custom ANGLE Adapter

This section does not execute unless 5.3 proves it necessary.

Build host:

```text
Ubuntu 24.04 LTS x86_64
```

Build current pinned ANGLE Android arm64 artifact.

Because TFT is non-debuggable and the Google Play guest is not a general root environment, if loose driver selection cannot be applied, create a rootable Android 17 userdebug execution image.

Google Play AVD remains package/update authority.

Exact Google-delivered APK splits are transferred only after package identity/signature/hash verification.

The adapter must pass the same Phase 5 probe.

### Phase 5 exit gate

A real conformant GLES 3.2 context and all required executable tests pass.

---

# PHASE 6 — Current official TFT vertical slice

## Objective

Use a real production workload after the general graphics contract is green.

## 6.1 Official Google Play installation

Inside `TFTMAC_Live_API37`:

- sign into Google Play;
- install/update official TFT;
- record package metadata.

Required manifest fields:

```text
installer=com.android.vending
package=com.riotgames.league.teamfighttactics
versionName
versionCode
package paths
APK/split hashes
signing certificate hash
capture timestamp
```

## 6.2 Pre-launch gate

TFTMAC refuses to call the workload green unless:

```text
guest Vulkan required set PASS
guest GLES 3.2 PASS
nonconformant override absent
display 1920x1080
runtime manifest identity current
```

## 6.3 Launch

First success:

The client no longer reports the ES 3.2 hardware-requirement error.

## 6.4 Gameplay acceptance

Required:

```text
account/lobby flow reachable
current live content loads
queue succeeds
match starts
game renders
audio works
input works
20+ minute crash-free live session
```

### Phase 6 exit gate

Current official TFT is genuinely playable on the final graphics architecture.

---

# PHASE 7 — Performance, diagnostics, audio, microphone, input

## Objective

Turn functional success into measured production quality.

## 7.1 Session diagnostics

Every session produces:

```text
Logs/<session-id>/session.json
Logs/<session-id>/events.jsonl
Logs/<session-id>/frame-times.jsonl
Logs/<session-id>/logcat.txt
Logs/<session-id>/emulator.log
Logs/<session-id>/summary.md
```

Include all locked component identities and capability hashes.

## 7.2 Frozen TFT performance benchmark

Measurement:

```text
2-minute warm-up excluded
600 continuous measured seconds
60 Hz display
SurfaceFlinger timestamps primary
```

PASS:

```text
Average FPS >= 58.0
P95 <= 20.0 ms
P99 <= 33.334 ms
jank (>33.334 ms) <= 1.0%
stalls >100 ms <= 3 / 600 s
no crash
no device loss
no repeated validation-error storm
```

## 7.3 Candidate regression gate

A new candidate must not regress:

```text
Average FPS > 1 FPS
P99 > 3%
jank > 0.25 percentage points
median input-to-present > 5 ms
P95 input-to-present > 8.334 ms
```

and must still satisfy absolute thresholds.

## 7.4 Resource-profile benchmark

Run:

```text
6 vCPU / 6 GB
8 vCPU / 8 GB
```

Selection:

1. both must be measured identically;
2. any failing absolute threshold is rejected;
3. lower P99 wins;
4. if within 3%, lower host CPU wins.

Persist winner.

## 7.5 Renderer tuning

Only benchmark-backed changes are allowed.

Candidate areas:

- MoltenVK synchronization/queue behavior;
- gfxstream batching;
- descriptor behavior;
- shader compilation;
- present pacing.

Every change receives an A/B benchmark ID.

## 7.6 Audio

First use direct emulator CoreAudio.

PASS:

- continuous output during 20+ minute test;
- no blocking underrun condition;
- no audio crash.

## 7.7 Microphone

Implement:

```text
CoreAudio input
-> TFTMAC capture
-> authenticated emulator controller injectAudio
-> Android mic
```

Create a dedicated Android microphone test app.

PASS:

- macOS permission granted;
- selected input device identified;
- input meter responds;
- mute works;
- Android app receives audio;
- 5-minute capture/loopback has no fatal discontinuity.

## 7.8 Input

Use emulator controller APIs.

The probe measures injection-to-visible-frame latency.

This evidence becomes the baseline used by the native shell in Phase 8.

### Phase 7 exit gate

All frozen performance thresholds pass; audio, microphone transport, and input probes pass.

---

# PHASE 8 — Native macOS presentation

## Objective

Hide emulator chrome without sacrificing responsiveness.

## 8.1 Runtime control security

Production discovers the running emulator's authenticated control endpoint from the local discovery file.

No unauthenticated fixed gRPC port in production.

## 8.2 Video transport

Use emulator screenshot streaming with shared-memory/MMAP transport where available.

Path:

```text
emulator MMAP frame
-> TFTMAC mapped memory
-> Metal texture
-> MTKView/native SwiftUI/AppKit container
```

Production does not use PNG/JPEG streaming for normal frame delivery.

## 8.3 Native input

Map:

```text
mouse -> touch
drag -> touch gesture
scroll -> gesture
keyboard -> key event
Back/Home -> emulator control
```

## 8.4 Latency acceptance

Compare native path to direct Qt emulator control path.

Required:

```text
native median <= Qt + 5 ms
native P95 <= Qt + 8.334 ms
native absolute median <= 50 ms
native absolute P95 <= 83.334 ms
```

If any bound fails, emulator chrome is not removed yet.

## 8.5 Native controls

One TFTMAC window exposes:

```text
Play / Stop
Back
Home
Volume
Microphone
Fullscreen
Google Play / Update
Screenshot
Diagnostics
Rollback/Runtime Status
```

### Phase 8 exit gate

One Dock icon; one native Mac window; Android runtime hidden; latency gate green.

---

# PHASE 9 — Generality, updates, rollback, packaging, final release

## Objective

Prove the runtime is general and maintainable.

## 9.1 Generality Corpus A — GLES CTS

Source:

```text
opengl-es-cts-3.2.14.1
locked full commit from Phase 0
Apache-2.0
```

Run Android GLES32 official mustpass applicable cases.

PASS:

```text
zero Fail
zero Crash
zero Timeout
all required cases executed
NotSupported only where CTS/spec allows optional support
```

Archive `.qpa`.

## 9.2 Generality Corpus B — Vulkan CTS

Source:

```text
vulkan-cts-1.4.6.1
5c8aae22885448d70a2873e94a93b24b49505c32
Apache-2.0
```

Run:

```text
ssot/vulkan-required-cases.txt
```

PASS:

```text
zero Fail
zero Crash
zero Timeout
100% case-list execution
```

## 9.3 Generality Corpus C — Vulkan Samples

Source:

```text
89dd3af22d41f9244eeab6e0650460112285c0e1
Apache-2.0
```

Run:

```text
dynamic_rendering
compute_nbody
```

Each:

```text
1920x1080
10,000 frames or 10 minutes
zero crash
zero device loss
zero validation ERROR
responsive input
startup/mid/end screenshots show non-uniform rendered content
```

## 9.4 Runtime identity

Each runtime has:

```text
build ID
AEMU resolved-manifest hash
qemu commit
gfxstream commit
MoltenVK commit
patch-series hash
Android image revision
probe-suite version
```

## 9.5 Two-slot rollback

```text
Runtime/current
Runtime/previous
```

Promotion:

```text
candidate
-> capability probes
-> generality smoke
-> TFT smoke
-> performance regression gate
-> current
```

Failure leaves `current` unchanged.

## 9.6 Game updates

Google Play remains app authority.

After a game update:

1. capture new package identity;
2. rerun capability gate;
3. launch smoke;
4. if workload requirement fails, report compatibility red without corrupting runtime.

## 9.7 macOS packaging

Final bundle:

```text
TFTMAC.app
```

Includes:

```text
native shell
runtime launcher
probe binaries
gRPC client/protobuf
runtime manifest
licenses
```

Large Android image/userdata stays under `/Volumes/MAC MINI M4/TFTMAC/Runtime`; it must not fall back to the internal disk.

## 9.8 Signing

Development:

```text
ad-hoc
```

Release:

```text
Developer ID Application
hardened runtime
notarization
stapling
```

Do not re-sign Riot/Google app binaries.

## 9.9 Reliability matrix

PASS all:

```text
cold boot
warm boot
clean shutdown
forced TFTMAC quit recovery
macOS reboot
runtime candidate rejection
runtime rollback
Google Play game update
30+ minute session
3 sequential sessions
```

### Phase 9 exit gate

Every final requirement in the traceability matrix has a PASS artifact.

---

# 3. Requirement-to-proof traceability matrix

| Requirement | Owner | Evidence | PASS |
|---|---|---|---|
| Reproducible source/toolchain | Phase 0 | locks/hashes | No critical null; hashes match |
| Canonical AEMU source | Phase 0 | resolved manifest + GuestAngle audit | `emu-master-dev` locked; audit PASS |
| Source-built emulator | Phase 1 | build/ctest/boot logs | all green |
| Host Vulkan | Phase 3 | host probe | all required executable cases |
| gfxstream | Phase 4 | transport delta | no required host-green/guest-red |
| Real GLES 3.2 | Phase 5 | guest GLES probe | genuine 3.2 + cases + render |
| No spoof | Phase 5 | env/source audit | nonconformant override absent |
| TFT current | Phase 6 | Play manifest/gameplay | 20+ min live session |
| Performance | Phase 7 | 600s metrics | all absolute bounds |
| Regression protection | Phase 7/9 | A/B report | all regression bounds |
| Audio | Phase 7 | audio test | continuous, no blocking failure |
| Mic | Phase 7 | mic test | CoreAudio→Android verified |
| Input | Phase 7/8 | latency report | absolute + relative bounds |
| Native Mac UX | Phase 8 | UI/latency acceptance | one window, hidden emulator |
| Diagnostics | Phase 7 | session bundle | required fields present |
| Google Play updates | Phase 9 | update receipt | app authority retained |
| Rollback | Phase 9 | rollback test | current protected, previous works |
| GLES generality | Phase 9 | CTS `.qpa` | corpus A PASS |
| Vulkan generality | Phase 9 | CTS/sample logs | corpora B/C PASS |
| Release | Phase 9 | signing/notary | receipts + launch |
| Protected-data boundary | all | Git/package scan | no private binaries/data leaked |

This matrix is authoritative. No new proof subsystem is added unless a material required behavior lacks falsifiable evidence.

---

# 4. Causal failure routing

| Failure | Owner | Route |
|---|---|---|
| source AEMU build fails | host/toolchain | repair parity; remain Phase 1 |
| host Vulkan feature red | MoltenVK | repair Phase 3 |
| host green / guest red | gfxstream/AEMU | repair Phase 4 |
| guest Vulkan green / GLES 3.1 | built-in ANGLE requirement | inspect Phase 5 |
| built-in ANGLE revision is causal blocker | conditional custom ANGLE | activate only then |
| real GLES 3.2 green / TFT red | Riot/Unreal workload | inspect exact new requirement |
| TFT works / performance red | runtime performance | Phase 7 measured tuning |
| mic red | audio bridge | Phase 7 |
| native latency red | presentation | Phase 8 |
| candidate update red | release system | reject/rollback Phase 9 |

No layer is changed merely because another project once needed a similar fix.

---

# 5. Forbidden shortcuts

Do not:

- use `ro.opengles.version` as acceptance;
- ship nonconformant ANGLE version exposure;
- mix `emu-main-dev` evidence into the locked `emu-master-dev` authority;
- change the performance thresholds after seeing benchmark results;
- shrink the generality corpus because cases fail;
- prebuild custom ANGLE/rootable execution infrastructure without Phase 5 evidence;
- replace MoltenVK wholesale with an older donor fork;
- modify Riot binaries;
- use third-party APK mirrors;
- commit APKs, credentials, AVD userdata, or tokens;
- hide causal errors with retries/fallbacks;
- remove the working current runtime before candidate acceptance;
- expose unauthenticated emulator control in production.

---

# 6. Final Definition of Done

Implementation is complete only when:

```text
[PASS] Phase 0 authority/lock
[PASS] Phase 1 source AEMU
[PASS] Phase 2 capability laboratory
[PASS] Phase 3 host Vulkan
[PASS] Phase 4 gfxstream transport
[PASS] Phase 5 genuine GLES 3.2
[PASS] Phase 6 current official TFT gameplay
[PASS] Phase 7 frozen performance contract
[PASS] Phase 7 audio/mic/input
[PASS] Phase 8 native single-window Mac UX
[PASS] Phase 9 generality corpus
[PASS] Phase 9 Google Play update
[PASS] Phase 9 rollback
[PASS] Phase 9 signed/notarized release path
[PASS] protected-data audit
```

No partial phase may be relabeled as completion.

---

# 7. Source anchors

Primary authority links:

- Emulator development branch: https://android.googlesource.com/platform/external/qemu/+/emu-master-dev/android/docs/DEVELOPMENT.md
- Emulator macOS development: https://android.googlesource.com/platform/external/qemu/+/emu-master-dev/android/docs/DARWIN-DEV.md
- Manifest: https://android.googlesource.com/platform/manifest/+/refs/heads/emu-master-dev/default.xml
- gfxstream: https://android.googlesource.com/platform/hardware/google/gfxstream/
- MoltenVK: https://github.com/KhronosGroup/MoltenVK
- UTM donor issue: https://github.com/utmapp/UTM/issues/7575
- GLES CTS: https://github.com/KhronosGroup/VK-GL-CTS/releases
- Vulkan CTS 1.4.6.1: https://chromium.googlesource.com/external/github.com/KhronosGroup/VK-GL-CTS/+/refs/tags/vulkan-cts-1.4.6.1
- Vulkan Samples: https://github.com/KhronosGroup/Vulkan-Samples
- Android SDK: https://developer.android.com/studio
- Vulkan SDK: https://vulkan.lunarg.com/sdk/home

---

# 8. Authority rule

This plan and `TFTMAC_GPU_RUNTIME_SSOT.md` describe the **same architecture**.

They must be revised together if architecture changes.

After Phase 0:

```text
STACK.lock.yaml
```

owns exact machine-resolved versions.

Capability probes own graphics truth.

The frozen performance contract owns optimization acceptance.

The traceability matrix owns completion evidence.
