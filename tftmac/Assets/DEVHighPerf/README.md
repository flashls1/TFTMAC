# Existing TFTMAC DEV private HighPerf profile

> **2026-10-02:** Normal DEV startup uses this existing HighPerf injector and verifies all 78 settings, with the documented WIN-01 guest cache properties set/read back before launch. Three matched 18.3 full-Trial captures promoted the launcher default to 1920x1080 at density 416 for playability; the physical displays remain 2560x1440. An explicit `TFTMAC_DEV_DISPLAY=2560x1440` launch remains the control. Current Play and secure-unlock checks are preserved. `riot-defaults.sh` remains dormant recovery/history, not normal startup.

> **2026-09-12 current DEV experiment:** Normal official-game DEV startup now uses `riot-defaults.sh` instead of the historical HighPerf injector described below. It performs a one-time backup/reset of private/public DeviceProfiles.ini and private GameUserSettings.ini, then leaves Riot to regenerate settings. A complete journal makes later launches no-ops; an interrupted reset fails closed; explicit rollback restores the original bytes and metadata. Existing HighPerf assets remain for recovery/history. No custom CVar, explicit HWUI/audio/SF/priority or MVK performance tuning is applied by this path. The four executable/profile assets are hash-checked; the required debug boot and ES3.2 exposure remain. Live reset/rollback tests passed; normal native game boot now passes with automatic DEV Keychain unlock and reaches the Ranked lobby. Fresh logs verify OpenGL ES3.2 through ANGLE. Gameplay performance is not yet measured.

These assets are copied into **TFTMAC DEV only** by `scripts/build-dev-launcher.command`. The native runtime verifies all three SHA-256 values before booting. It also verifies the original stock ramdisk, uses the existing packaged emulator host, and forces a cold boot without snapshots. Control and the owned Vulkan probe keep their existing launch paths.

Validated runtime base: Android emulator37.1.11, Android36 Google Play arm64-v8a rev7, build BE2A.250530.026.D1. The current verified Riot client observation is TFT18.3-5530794 / code 8530794; Google Play remains the update authority: the production package must be Google Play-owned/current, each client update receives the required update audit + matched baseline, and the same HighPerf mechanism is revalidated against the observed current client. The original SDK ramdisk and official Riot APK bytes are never patched by TFTMAC.

`debug-ramdisk.img` retains **all concatenated cpio archives** from stock ramdisk SHA256 `93164613a195fff34efac0517eaa4640b43b7578925f2f96726c260d43503aaa`. A final cpio archive adds `force_debuggable`, `adb_debug.prop` (ro.debuggable=1, ro.force.debuggable=1, ro.adb.secure=1), and the exact installed platform SELinux CIL with diagnostic su-domain IPC grants. Global SELinux remains Enforcing and ADB authentication remains required. The su domain is permissive for bounded provisioning; ADB returns to shell before game launch. The emulator boot argument `androidboot.verifiedbootstate=orange` enables Android's documented debug policy selection. This is a DEV debug boot, not an unlocked production device or modified game.

Source mechanism: AOSP Android16 `system/core/init/{first_stage_init.cpp,selinux.cpp,property_service.cpp}`, `system/core/fs_mgr/libfs_avb/util.cpp`, and `system/sepolicy/private/{su.te,domain.te}`. The policy additions are:

```
(allow adbd su (process (dyntransition)))
(typepermissive su)
(allow domain su (fd (use)))
(allow domain su (unix_stream_socket (connectto getattr getopt read write shutdown)))
(allow domain su (unix_dgram_socket (sendto)))
(allow domain su (fifo_file (write getattr)))
(allow domain su (process (sigchld)))
```

`DeviceProfiles.ini` contains18 target CVars plus60 preserved non-target values. `baseline-device-cvars.json` records all76 explicit baseline assignments from the same official APK and6GB guest before the override. Generated arrays replace inherited arrays, so preserving the baseline is mandatory. In particular, `r.Android.DisableVulkanSupport=1` retains TFT's validated OpenGL-through-ANGLE route. The first override omitted that flag, selected direct Vulkan and caused Metal vertex-descriptor failures during Trials loading; it was rejected. Generated Saved config uses repeated **CVars=** assignments and **DeviceProfileFragment** sections. The native-resolution experiment changes `r.MobileContentScaleFactor` from `1.0` to `0.0` in both base sections; all other values remain unchanged. The current launcher default is 1920x1080, while the 2560x1440 control is explicit and reversible. The target is the game's private `files/UnrealGame/TFT/TFT/Saved/Config/Android/DeviceProfiles.ini`. The native transaction verifies the file hash, root ownership,0444 mode, app SELinux context and zygote mount namespace before unrooting. A fresh engine log must confirm every target before readiness is claimed.

The Android helper journals original presence/hash/metadata/context before touching the target. Shutdown unmounts the known profile and verifies the original content or absence. A cold boot recovers a previous prepared transaction using the same checks. Unknown changes retain the journal and fail; they are never overwritten. Archives remain in DEV `/data/local/tmp/tftmac-native-highperf.rolled-back.*` for diagnosis.

Boot acceptance is **not** proof of sustained60FPS. Use the existing native gameplay recorder and combat benchmark for that claim. Read the active RHI initialization, not the capability string: the baseline initializes OpenGL; the rejected incomplete override created a direct Vulkan device. Native readiness now requires OpenGL initialization, no direct Vulkan device creation, and all78 merged values accepted. Gameplay performance remains separately measured.

The existing native DEV launch also selects Android HWUI `skiagl` before the game starts. Fresh2026-09-05 ANR traces matched the documented WebView Vulkan image-view destruction deadlock. This property only selects Android UI rendering; TFT retains its original OpenGL-through-ANGLE route and ANGLE retains Vulkan. DEV reports ANR dialogs without automatically clicking Close app.
