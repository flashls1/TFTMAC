# Riot 18.2 + TFTMAC DEV Adjustable Settings Map

**Purpose:** exhaustive discoverability map of fields that the current TFTMAC project or the current Riot 18.2 / Unreal boot exposes as intentionally adjustable. This is **not** a recommendation list and does not claim that changing a field is safe, useful, or performance-positive.

**Authority:** `facts.md` first, `project.md` second. This file is a generated catalog/reference and must not override those records. Old PBE-derived artifact profiles and stale prose in `settings.md` were **not** used to add active Riot CVars; current Riot 18.2 boot evidence and current source/configuration are used instead.

**Current Riot evidence:** production package `com.riotgames.league.teamfighttactics` 18.2 (`18.2-5450971`), current boot capture `/Users/flash/Library/Application Support/TFTMAC/Modes/advanced_diagnostics/Captures/2026-09-12T01-41-57.116Z-6e7ff61f-5067-4fea-9092-b04e8f4640cd/highperf-engine-boot.log`.

## Catalog contract

- **Included:** behavior/configuration fields with a demonstrated adjustment surface: Unreal CVar/DeviceProfile entries, AVD/INI keys, Android `settings`/properties/commands, environment variables, UserDefaults, runtime profile/registry fields, emulator arguments/features, ANGLE/MoltenVK/gfxstream controls, and executable experiment/tool inputs.
- **Excluded:** passwords/tokens/account identifiers, package signatures, SHA/UUID integrity receipts, timestamps/session IDs, derived telemetry/result fields, and names that exist only as immutable validation/identity constants.
- A blank candidate value means **mapped but not currently assigned for a new experiment**.
- `Riot 18.2 observed` means a value was directly seen being configured in the current 18.2 boot log. Multiple values can appear because Unreal loads several quality/device-profile branches during configuration.
- `DEV override` is populated only where current `DEVHighPerf/DeviceProfiles.ini` actually overrides the CVar.

## Inventory counts

| Surface | Mapped fields |
| --- | --- |
| Current Riot 18.2 Unreal boot CVars | 388 |
| Current DEV DeviceProfile overrides (subset of above) | 78 |
| Advanced-diagnostics AVD `config.ini` fields | 145 |
| AVD stub fields | 3 |
| Native runtime profile fields | 18 |
| Android guest settings/properties/commands | 27 |
| ANGLE/EGL controls | 16 |
| MoltenVK/project wrapper controls | 14 |
| Executable project environment inputs discovered | 119 |

## 1. Native TFTMAC runtime profile controls

| Field | Known/accepted values | Adjustment surface | Function |
| --- | --- | --- | --- |
| `runtime.vcpu` | `4, 6, 8` | UserDefaults / profile; DEV may also use TFTMAC_DEV_VCPU | Virtual CPU count |
| `runtime.ramMiB` | `4096, 5120, 6144` | UserDefaults / profile | Guest Android RAM |
| `runtime.refreshHz` | `30, 60` | UserDefaults / profile | Guest/emulator refresh target |
| `runtime.asgDrawFlushInterval` | `400, 800 µs` | UserDefaults / profile | ASG draw flush interval |
| `asgDrawFlushInterval` |  | Runtime profile / AVD transaction | Raw runtime-profile ASG draw flush field |
| `runtime.experimentPreset` | `control; DEV env also accepts queue_submit_inline, virtual_queue_off, fence_contexts_off` | UserDefaults / DEV experiment profile | Emulator experiment preset |
| `width` |  | Runtime locked profile / registry | Guest display width |
| `height` |  | Runtime locked profile / registry | Guest display height |
| `densityDPI` |  | Runtime locked profile / registry | Guest display density |
| `gpuMode` |  | Runtime locked profile / registry | Emulator -gpu mode |
| `audioBackend` |  | Runtime locked profile / registry | Emulator -audio backend |
| `graphicsTransport` |  | Runtime locked profile / AVD transaction | hw.gltransport |
| `asgWriteBufferSize` |  | Runtime locked profile / AVD transaction | ASG write buffer bytes |
| `asgWriteStepSize` |  | Runtime locked profile / AVD transaction | ASG write step bytes |
| `asgDataRingSize` |  | Runtime locked profile / AVD transaction | ASG data ring bytes |
| `controllerPort` |  | Runtime mode registry / profile | Emulator gRPC controller port |
| `angleEnabledFeatures` |  | Runtime locked profile | ANGLE enabled feature override string |
| `angleDisabledFeatures` |  | Runtime locked profile | ANGLE disabled feature override string |

### 1.1 UserDefaults / persistent app preferences

| Key | Function |
| --- | --- |
| `runtime.vcpu` | Runtime profile vCPU preference |
| `runtime.ramMiB` | Runtime profile RAM preference |
| `runtime.refreshHz` | Runtime profile refresh preference |
| `runtime.asgDrawFlushInterval` | Runtime profile ASG flush preference |
| `runtime.experimentPreset` | Runtime experiment preset |
| `TFTMACDEVRememberRiotLogin` | Remember/use locally stored DEV Riot login preference |

### 1.2 Native app/runtime environment inputs

| Variable | Known values / shape | Function |
| --- | --- | --- |
| `TFTMAC_RUNTIME_MODE` | `control / advanced_diagnostics / candidate (candidate currently blocked)` | Runtime mode selection |
| `TFTMAC_DEV_WORKLOAD` | `official_tft / owned_vulkan_probe` | DEV workload selection |
| `TFTMAC_DEV_EXPERIMENT_PROFILE` | `control / queue_submit_inline / virtual_queue_off / fence_contexts_off` | DEV experiment selection |
| `TFTMAC_DEV_VCPU` | `4 / 6 / 8` | Advanced-diagnostics vCPU override |
| `TFTMAC_AUTONOMOUS_SILENT` | `0/1` | Suppress normal UI activation/menu for automation |
| `TFTMAC_UNLOCK_SETUP_ONLY` | `0/1` | Run unlock/setup-only path |
| `TFTMAC_ENABLE_AUTO_PERFETTO` | `0/1` | Allow automatic Perfetto capture path |
| `TFTMAC_PIPELINE_EVENT_V1` | `0/1` | Enable PipelineEventV1 sideband path when supported |
| `TFTMAC_ANGLE_DRIVER_MANIFEST` | `path` | Select external ANGLE driver override manifest |
| `TFTMAC_REPO_ROOT` | `path` | Native wrapper repository/resources root |
| `TFTMAC_NATIVE_FULLSCREEN` | `0/1` | Native wrapper fullscreen behavior |
| `TFTMAC_HOST_SCREEN_WIDTH` | `pixels` | Host screen width supplied to wrapper |
| `TFTMAC_HOST_SCREEN_HEIGHT` | `pixels` | Host screen height supplied to wrapper |
| `TFTMAC_HOST_BACKING_SCALE` | `scale` | Host backing scale |
| `TFTMAC_NATIVE_CONTROL_WIDTH` | `points/pixels` | Native control-bar width |
| `TFTMAC_NATIVE_TOPBAR_HEIGHT` | `points/pixels` | Native top-bar height |
| `TFT_EMULATOR` | `path` | RuntimeHost emulator executable override |
| `TFT_HOST_LATENCY_QOS` | `QoS selector` | RuntimeHost latency/QoS request |
| `TFT_HOST_STDOUT` | `path/fd route` | RuntimeHost stdout route |
| `TFT_HOST_STDERR` | `path/fd route` | RuntimeHost stderr route |

## 2. Runtime mode, routing, lease and host selection controls

These are behavior/routing fields in the runtime registry or supplemental authority. Integrity hashes/UUIDs are intentionally omitted.

| Field | Current advanced-diagnostics value | Surface | Function |
| --- | --- | --- | --- |
| `default_mode` | `control` | runtime-modes.json | Default runtime selector |
| `mode` | `advanced_diagnostics` | runtime-modes.json | Mode name |
| `launch_state` | `enabled` | runtime-modes.json | Whether the mode is launchable |
| `runtime_root` | `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow` | runtime-modes.json | Runtime root |
| `sdk_root` | `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow/SDK` | runtime-modes.json | Android SDK root |
| `library_root` | `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow/SDK/emulator/lib64` | runtime-modes.json | Emulator library root |
| `emulator_path` | `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow/SDK/emulator/emulator` | runtime-modes.json | Emulator executable |
| `gfxstream_backend_path` | `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow/SDK/emulator/lib64/libgfxstream_backend.dylib` | runtime-modes.json | gfxstream backend path |
| `adb_path` | `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow/SDK/platform-tools/adb` | runtime-modes.json | ADB executable |
| `avd_home` | `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow/AVD` | runtime-modes.json | AVD home |
| `avd_name` | `TFTMAC_Diagnostic_StockShadow_R1` | runtime-modes.json | AVD name |
| `avd_directory` | `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow/AVD/TFTMAC_Diagnostic_StockShadow_R1.avd` | runtime-modes.json | AVD directory |
| `avd_config_path` | `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow/AVD/TFTMAC_Diagnostic_StockShadow_R1.avd/config.ini` | runtime-modes.json | AVD config path |
| `avd_ini_path` | `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow/AVD/TFTMAC_Diagnostic_StockShadow_R1.ini` | runtime-modes.json | AVD stub path |
| `adb_server_port` | `5041` | runtime-modes.json | ADB server port |
| `console_port` | `5586` | runtime-modes.json | Emulator console/serial port |
| `controller_port` | `8556` | runtime-modes.json | gRPC controller port |
| `serial` | `emulator-5586` | runtime-modes.json | ADB serial |
| `state_namespace` | `advanced_diagnostics` | runtime-modes.json | Application-support state namespace |
| `runtime_variant` | `stock_shadow` | runtime-modes.json | Runtime variant label used for routing |
| `emulator_identifier` | `TFTMAC-DIAGNOSTIC` | runtime-modes.json | Emulator -id value |
| `launch_strategy` | `external_native_host` | runtime-modes.json | Host launch strategy |
| `profile_policy` | `fixed_registry_profile` | runtime-modes.json | Profile source policy |
| `requires_control_stopped` | `True` | runtime-modes.json | Control/DEV mutual-exclusion policy |
| `rollback_target` | `control` | runtime-modes.json | Rollback mode |
| `uses_legacy_application_support_root` | `False` | runtime-modes.json | State-root selection |
| `adb_vendor_keys_policy` | `USER_DEFAULT_KEY` | runtime-modes.json | ADB key inheritance policy |
| `expected_emulator_version_contains` | `37.1.11` | runtime-modes.json | Accepted emulator-version selector |

## 3. Emulator launch arguments and feature flags

### 3.1 Launch argument fields

| Field / argument | Current/example value | Surface | Function |
| --- | --- | --- | --- |
| `-id` | `TFTMAC-DIAGNOSTIC` | TFTMACRuntime.swift / runtime registry | Emulator instance identifier |
| `-port` | `5586` | runtime mode registry | Emulator console port |
| `-gpu` | `host` | runtime profile | GPU acceleration backend |
| `-audio` | `coreaudio` | runtime profile | Host audio backend |
| `-feature` | `comma-separated emulator features` | RuntimeExperimentPreset | Emulator feature enable/disable list |
| `androidboot.opengles.version` | `196610` | -append-userspace-opt | Guest OpenGL ES capability |
| `androidboot.tftmac.graphics_profile` | `tftmac` | -append-userspace-opt | TFTMAC guest graphics profile marker |
| `-skin` | `1920x1080` | runtime profile | Emulator skin/display size |
| `-vsync-rate` | `60` | runtime profile | Virtual display vsync rate |
| `-dns-server` | `1.1.1.1,8.8.8.8` | TFTMACRuntime.swift | Guest DNS servers |
| `-cores` | `profile.vCPU` | runtime profile | Guest vCPU count |
| `-memory` | `profile.ramMiB` | runtime profile | Guest RAM MiB |
| `-no-hidpi-scaling` | `boolean flag` | TFTMACRuntime.swift | Disable emulator host HiDPI scaling |
| `-no-metrics` | `boolean flag` | TFTMACRuntime.swift | Disable emulator metrics collection |
| `-no-boot-anim` | `boolean flag` | TFTMACRuntime.swift | Disable Android boot animation |
| `-qt-hide-window` | `boolean flag` | TFTMACRuntime.swift | Hide stock emulator Qt window |
| `-grpc` | `controllerPort` | runtime mode/profile | Emulator controller gRPC port |
| `-grpc-use-token` | `boolean flag` | TFTMACRuntime.swift | Require controller auth token |
| `-idle-grpc-timeout` | `300` | TFTMACRuntime.swift | Controller idle timeout seconds |
| `-ramdisk` | `DEVHighPerf/debug-ramdisk.img` | DEV runtime assets | Boot ramdisk selection |
| `androidboot.verifiedbootstate` | `orange` | -append-userspace-opt | Guest verified-boot state marker |
| `-no-snapshot` | `boolean flag` | DEV launch path | Disable QuickBoot snapshot use |
| `-crash-report-mode` | `disabled` | DEV launch path | Emulator crash-reporting mode |
| `-timezone` | `America/Chicago` | DEV launch path | Guest timezone |

### 3.2 Emulator feature toggles

| Feature | Current / selectable state | Surface |
| --- | --- | --- |
| `GLESDynamicVersion` | enabled | baseline emulator feature list |
| `Vulkan` | enabled | baseline emulator feature list |
| `GuestAngle` | enabled | baseline emulator feature list |
| `GLPipeChecksum` | disabled | baseline emulator feature list |
| `VulkanBatchedDescriptorSetUpdate` | enabled | baseline emulator feature list |
| `AsyncComposeSupport` | enabled | baseline emulator feature list |
| `VirtioGpuFenceContexts` | enabled | baseline emulator feature list |
| `VulkanQueueSubmitWithCommands` | toggleable off by queue_submit_inline | DEV experiment preset |
| `VulkanVirtualQueue` | toggleable off by virtual_queue_off | DEV experiment preset |
| `VirtioGpuFenceContexts` | toggleable off by fence_contexts_off | DEV experiment preset |

## 4. Android Emulator AVD field map

All 145 currently present advanced-diagnostics `config.ini` keys are listed. Persistent AVD values may differ from the temporary launch transaction (for example, DEV can apply 8 vCPU / 6144 MiB and restore the persistent AVD afterward).

### 4.1 Audio, camera, battery & modem

| AVD field | Current persistent value | Adjustment surface |
| --- | --- | --- |
| `hw.arc` | `false` | AVD `config.ini` |
| `hw.audioInput` | `yes` | AVD `config.ini` |
| `hw.audioOutput` | `yes` | AVD `config.ini` |
| `hw.battery` | `yes` | AVD `config.ini` |
| `hw.camera.back` | `emulated` | AVD `config.ini` |
| `hw.camera.back.orientation` | `90` | AVD `config.ini` |
| `hw.camera.front` | `none` | AVD `config.ini` |
| `hw.camera.front.orientation` | `90` | AVD `config.ini` |
| `hw.gsmModem` | `yes` | AVD `config.ini` |

### 4.2 Boot, snapshot & kernel

| AVD field | Current persistent value | Adjustment surface |
| --- | --- | --- |
| `fastboot.forceChosenSnapshotBoot` | `no` | AVD `config.ini` |
| `fastboot.forceColdBoot` | `yes` | AVD `config.ini` |
| `fastboot.forceFastBoot` | `no` | AVD `config.ini` |
| `firstboot.bootFromDownloadableSnapshot` | `yes` | AVD `config.ini` |
| `firstboot.bootFromLocalSnapshot` | `yes` | AVD `config.ini` |
| `firstboot.saveToLocalSnapshot` | `yes` | AVD `config.ini` |
| `kernel.newDeviceNaming` | `autodetect` | AVD `config.ini` |
| `kernel.supportsYaffs2` | `autodetect` | AVD `config.ini` |

### 4.3 CPU, RAM & VM heap

| AVD field | Current persistent value | Adjustment surface |
| --- | --- | --- |
| `hw.cpu.arch` | `arm64` | AVD `config.ini` |
| `hw.cpu.ncore` | `6` | AVD `config.ini` |
| `hw.ramSize` | `5120` | AVD `config.ini` |
| `hw.vmHeapSize` | `768` | AVD `config.ini` |
| `vm.heapSize` | `96M` | AVD `config.ini` |

### 4.4 Display, density & multi-display

| AVD field | Current persistent value | Adjustment surface |
| --- | --- | --- |
| `display.settings.xml` | `freeform` | AVD `config.ini` |
| `environment.height` | `0` | AVD `config.ini` |
| `environment.width` | `0` | AVD `config.ini` |
| `hw.display1.density` | `0` | AVD `config.ini` |
| `hw.display1.flag` | `0` | AVD `config.ini` |
| `hw.display1.height` | `0` | AVD `config.ini` |
| `hw.display1.width` | `0` | AVD `config.ini` |
| `hw.display1.xOffset` | `-1` | AVD `config.ini` |
| `hw.display1.yOffset` | `-1` | AVD `config.ini` |
| `hw.display2.density` | `0` | AVD `config.ini` |
| `hw.display2.flag` | `0` | AVD `config.ini` |
| `hw.display2.height` | `0` | AVD `config.ini` |
| `hw.display2.width` | `0` | AVD `config.ini` |
| `hw.display2.xOffset` | `-1` | AVD `config.ini` |
| `hw.display2.yOffset` | `-1` | AVD `config.ini` |
| `hw.display3.density` | `0` | AVD `config.ini` |
| `hw.display3.flag` | `0` | AVD `config.ini` |
| `hw.display3.height` | `0` | AVD `config.ini` |
| `hw.display3.width` | `0` | AVD `config.ini` |
| `hw.display3.xOffset` | `-1` | AVD `config.ini` |
| `hw.display3.yOffset` | `-1` | AVD `config.ini` |
| `hw.displayRegion.0.1.height` | `0` | AVD `config.ini` |
| `hw.displayRegion.0.1.width` | `0` | AVD `config.ini` |
| `hw.displayRegion.0.1.xOffset` | `-1` | AVD `config.ini` |
| `hw.displayRegion.0.1.yOffset` | `-1` | AVD `config.ini` |
| `hw.displayRegion.0.2.height` | `0` | AVD `config.ini` |
| `hw.displayRegion.0.2.width` | `0` | AVD `config.ini` |
| `hw.displayRegion.0.2.xOffset` | `-1` | AVD `config.ini` |
| `hw.displayRegion.0.2.yOffset` | `-1` | AVD `config.ini` |
| `hw.displayRegion.0.3.height` | `0` | AVD `config.ini` |
| `hw.displayRegion.0.3.width` | `0` | AVD `config.ini` |
| `hw.displayRegion.0.3.xOffset` | `-1` | AVD `config.ini` |
| `hw.displayRegion.0.3.yOffset` | `-1` | AVD `config.ini` |
| `hw.hotplug_multi_display` | `no` | AVD `config.ini` |
| `hw.initialOrientation` | `Landscape` | AVD `config.ini` |
| `hw.lcd.backlight` | `yes` | AVD `config.ini` |
| `hw.lcd.circular` | `false` | AVD `config.ini` |
| `hw.lcd.density` | `320` | AVD `config.ini` |
| `hw.lcd.depth` | `32` | AVD `config.ini` |
| `hw.lcd.height` | `1080` | AVD `config.ini` |
| `hw.lcd.transparent` | `false` | AVD `config.ini` |
| `hw.lcd.vsync` | `60` | AVD `config.ini` |
| `hw.lcd.width` | `1920` | AVD `config.ini` |
| `hw.multi_display_window` | `no` | AVD `config.ini` |
| `showDeviceFrame` | `no` | AVD `config.ini` |
| `skin.name` | `1920x1080` | AVD `config.ini` |

### 4.5 Emulator test/boot controls

| AVD field | Current persistent value | Adjustment surface |
| --- | --- | --- |
| `test.delayAdbTillBootComplete` | `0` | AVD `config.ini` |
| `test.monitorAdb` | `0` | AVD `config.ini` |
| `test.quitAfterBootTimeOut` | `-1` | AVD `config.ini` |

### 4.6 GPU, gfxstream & ASG transport

| AVD field | Current persistent value | Adjustment surface |
| --- | --- | --- |
| `hw.gltransport` | `virtio-gpu-asg` | AVD `config.ini` |
| `hw.gltransport.asg.dataRingSize` | `32768` | AVD `config.ini` |
| `hw.gltransport.asg.writeBufferSize` | `1048576` | AVD `config.ini` |
| `hw.gltransport.asg.writeStepSize` | `16384` | AVD `config.ini` |
| `hw.gltransport.drawFlushInterval` | `800` | AVD `config.ini` |
| `hw.gpu.enabled` | `yes` | AVD `config.ini` |
| `hw.gpu.mode` | `host` | AVD `config.ini` |

### 4.7 Identity, system image & target

| AVD field | Current persistent value | Adjustment surface |
| --- | --- | --- |
| `AvdId` | `TFTMAC_Diagnostic_StockShadow_R1` | AVD `config.ini` |
| `abi.type` | `arm64-v8a` | AVD `config.ini` |
| `avd.id` | `TFTMAC_Diagnostic_StockShadow_R1` | AVD `config.ini` |
| `avd.ini.displayname` | `TFTMAC DEV Stock Shadow` | AVD `config.ini` |
| `avd.ini.encoding` | `UTF-8` | AVD `config.ini` |
| `avd.name` | `TFTMAC_Diagnostic_StockShadow_R1` | AVD `config.ini` |
| `image.sysdir.1` | `system-images/android-36/google_apis_playstore/arm64-v8a/` | AVD `config.ini` |
| `tag.display` | `Google Play` | AVD `config.ini` |
| `tag.displaynames` | `Google Play` | AVD `config.ini` |
| `tag.id` | `google_apis_playstore` | AVD `config.ini` |
| `tag.ids` | `google_apis_playstore` | AVD `config.ini` |
| `target` | `android-36` | AVD `config.ini` |

### 4.8 Input devices

| AVD field | Current persistent value | Adjustment surface |
| --- | --- | --- |
| `hw.dPad` | `no` | AVD `config.ini` |
| `hw.keyboard` | `yes` | AVD `config.ini` |
| `hw.keyboard.charmap` | `qwerty2` | AVD `config.ini` |
| `hw.keyboard.lid` | `yes` | AVD `config.ini` |
| `hw.mainKeys` | `no` | AVD `config.ini` |
| `hw.rotaryInput` | `no` | AVD `config.ini` |
| `hw.screen` | `multi-touch` | AVD `config.ini` |
| `hw.touchpad0` | `no` | AVD `config.ini` |
| `hw.touchpad0.height` | `400` | AVD `config.ini` |
| `hw.touchpad0.width` | `600` | AVD `config.ini` |
| `hw.trackBall` | `no` | AVD `config.ini` |

### 4.9 Network emulation

| AVD field | Current persistent value | Adjustment surface |
| --- | --- | --- |
| `runtime.network.latency` | `none` | AVD `config.ini` |
| `runtime.network.speed` | `full` | AVD `config.ini` |

### 4.10 Other AVD controls

| AVD field | Current persistent value | Adjustment surface |
| --- | --- | --- |
| `PlayStore.enabled` | `true` | AVD `config.ini` |
| `hw.device.hash2` | `MD5:0237e3449d1a413e8957020f46bb7927` | AVD `config.ini` |
| `hw.device.manufacturer` | `Google` | AVD `config.ini` |
| `hw.device.name` | `13.5in Freeform` | AVD `config.ini` |

### 4.11 Sensors & location

| AVD field | Current persistent value | Adjustment surface |
| --- | --- | --- |
| `hw.accelerometer` | `yes` | AVD `config.ini` |
| `hw.accelerometer_uncalibrated` | `yes` | AVD `config.ini` |
| `hw.gps` | `yes` | AVD `config.ini` |
| `hw.gyroscope` | `yes` | AVD `config.ini` |
| `hw.sensor.hinge` | `no` | AVD `config.ini` |
| `hw.sensor.hinge.count` | `0` | AVD `config.ini` |
| `hw.sensor.hinge.fold_to_displayRegion.0.1_at_posture` | `1` | AVD `config.ini` |
| `hw.sensor.hinge.resizable.config` | `1` | AVD `config.ini` |
| `hw.sensor.hinge.sub_type` | `0` | AVD `config.ini` |
| `hw.sensor.hinge.type` | `0` | AVD `config.ini` |
| `hw.sensor.roll` | `no` | AVD `config.ini` |
| `hw.sensor.roll.count` | `0` | AVD `config.ini` |
| `hw.sensor.roll.resize_to_displayRegion.0.1_at_posture` | `6` | AVD `config.ini` |
| `hw.sensor.roll.resize_to_displayRegion.0.2_at_posture` | `6` | AVD `config.ini` |
| `hw.sensor.roll.resize_to_displayRegion.0.3_at_posture` | `6` | AVD `config.ini` |
| `hw.sensors.gyroscope_uncalibrated` | `yes` | AVD `config.ini` |
| `hw.sensors.heading` | `no` | AVD `config.ini` |
| `hw.sensors.heart_rate` | `no` | AVD `config.ini` |
| `hw.sensors.humidity` | `yes` | AVD `config.ini` |
| `hw.sensors.light` | `yes` | AVD `config.ini` |
| `hw.sensors.magnetic_field` | `yes` | AVD `config.ini` |
| `hw.sensors.magnetic_field_uncalibrated` | `yes` | AVD `config.ini` |
| `hw.sensors.orientation` | `yes` | AVD `config.ini` |
| `hw.sensors.pressure` | `yes` | AVD `config.ini` |
| `hw.sensors.proximity` | `yes` | AVD `config.ini` |
| `hw.sensors.rgbclight` | `no` | AVD `config.ini` |
| `hw.sensors.temperature` | `yes` | AVD `config.ini` |
| `hw.sensors.wrist_tilt` | `no` | AVD `config.ini` |

### 4.12 Storage & filesystem

| AVD field | Current persistent value | Adjustment surface |
| --- | --- | --- |
| `disk.cachePartition` | `yes` | AVD `config.ini` |
| `disk.cachePartition.size` | `66MB` | AVD `config.ini` |
| `disk.dataPartition.path` | `<temp>` | AVD `config.ini` |
| `disk.dataPartition.size` | `16G` | AVD `config.ini` |
| `disk.systemPartition.size` | `0` | AVD `config.ini` |
| `disk.vendorPartition.size` | `0` | AVD `config.ini` |
| `hw.sdCard` | `yes` | AVD `config.ini` |
| `hw.useext4` | `yes` | AVD `config.ini` |
| `sdcard.size` | `512 MB` | AVD `config.ini` |
| `userdata.useQcow2` | `no` | AVD `config.ini` |

### 4.13 AVD stub (`.ini`) fields

| Field | Current value | Adjustment surface |
| --- | --- | --- |
| `avd.ini.encoding` | `UTF-8` | AVD stub `.ini` |
| `path` | `/Volumes/MAC MINI M4/TFTMAC/Diagnostics/GraphicsRuntimeV1/StockShadow/AVD/TFTMAC_Diagnostic_StockShadow_R1.avd` | AVD stub `.ini` |
| `target` | `android-36` | AVD stub `.ini` |

## 5. Android guest OS, compositor, audio, power and scheduler controls

| Namespace/type | Field / command | Current/example value | Project surface | Function |
| --- | --- | --- | --- | --- |
| settings/global | `stay_on_while_plugged_in` | `7` | active native DEV | Keep guest awake while powered |
| settings/system | `min_refresh_rate` | `60.0` | active native DEV | Minimum Android refresh rate |
| settings/system | `peak_refresh_rate` | `60.0` | active native DEV | Peak Android refresh rate |
| settings/secure | `show_ime_with_hard_keyboard` | `0` | active native DEV | Software keyboard visibility with hardware keyboard |
| settings/global | `auto_time` | `1` | direct-control tooling | Automatic guest time |
| settings/global | `auto_time_zone` | `1` | direct-control tooling | Automatic guest timezone |
| settings/system | `accelerometer_rotation` | `0` | runtime bridge/direct-control tooling | Automatic rotation enable/disable |
| settings/system | `user_rotation` | `0..3` | runtime bridge/direct-control tooling | Forced display rotation |
| settings/global | `angle_gl_driver_selection_pkgs` | `package list` | run-tft-gles32.command | Packages forced onto ANGLE |
| settings/global | `angle_gl_driver_selection_values` | `angle/native/etc.` | run-tft-gles32.command | Per-package ANGLE selection |
| settings/global | `angle_egl_features` | `feature string` | run-tft-gles32.command | ANGLE EGL feature string |
| settings/global | `show_angle_in_use_dialog_box` | `0/1` | run-tft-gles32.command | ANGLE notification dialog toggle |
| property | `service.sf.present_timestamp` | `1` | active native DEV | SurfaceFlinger presentation timestamps |
| property | `debug.sf.showupdates` | `0` | active native DEV | SurfaceFlinger update-flash overlay |
| property | `debug.stagefright.audio.sink` | `1` | active native DEV | Stagefright audio sink route |
| property | `af.fast_track_multiplier` | `2` | active native DEV (requested) | Audio fast-track multiplier |
| property | `audio.deep_buffer.media` | `1` | active native DEV (requested) | Media deep-buffer mode |
| property | `debug.hwui.renderer` | `skiagl` | native/legacy launch tooling | Android HWUI renderer |
| property | `debug.sf.latch_unsignaled` | `1` | prewarm tooling | SurfaceFlinger latch-unsignaled behavior |
| property | `debug.sf.enable_gl_backpressure` | `0` | prewarm tooling | SurfaceFlinger GL backpressure |
| property | `debug.tftmac.probe.profile` | `experiment id` | owned Vulkan probe | Probe experiment marker |
| property | `debug.tftmac.probe.smoke` | `0/1` | owned Vulkan probe | Probe smoke/test marker |
| power command | `dumpsys battery set ac` | `0/1` | active native DEV power setup | Virtual AC power state |
| package command | `pm disable-user --user 0 com.google.android.apps.wellbeing` | `enabled/disabled` | active native DEV | Wellbeing background package state |
| package command | `cmd package compile -m` | `speed / other package compile modes` | prewarm tooling | Android package compilation mode |
| scheduler | `renice TFT PID` | `-20` | active native DEV | Guest TFT process nice value request |
| scheduler | `renice PSO TID/PID` | `script-configurable` | prewarm/watch tooling | PSO worker scheduling preference |

## 6. ANGLE / EGL driver, cache and capture controls

| Field | Known values / shape | Surface | Function |
| --- | --- | --- | --- |
| `debug.egl.blobcache.multifile` | `true/false` | OvernightLab current working-cache property | ANGLE/EGL blob cache layout |
| `debug.angle.feature_overrides_enabled` | `colon-delimited feature list` | native profile / ANGLE transaction | Enable ANGLE feature overrides |
| `debug.angle.feature_overrides_disabled` | `colon-delimited feature list` | native profile / OvernightLab | Disable ANGLE feature overrides |
| `debug.angle.capture.enabled` | `0/1` | ANGLE driver transaction | ANGLE frame capture enable |
| `debug.angle.capture.trigger` | `frame count` | ANGLE driver transaction | Capture trigger/count |
| `debug.angle.capture.out_dir` | `path` | ANGLE driver transaction | Capture output directory |
| `debug.angle.capture.label` | `text` | ANGLE driver transaction | Capture label |
| `debug.angle.capture.frame_start` | `frame index/blank` | ANGLE driver transaction | Explicit capture start frame |
| `debug.angle.capture.frame_end` | `frame index/blank` | ANGLE driver transaction | Explicit capture end frame |
| `debug.angle.capture.compression` | `0/1` | ANGLE driver transaction | Capture compression |
| `debug.angle.tftmac_view_stats` | `0/1` | ANGLE driver transaction | TFTMAC ANGLE view diagnostics |
| `variant` | `reference / reuse / capture` | prepare-driver-manifest.py | Driver-override variant |
| `reuseEnabled` | `false/true` | prepare-driver-manifest.py | TFTMAC retain/reuse behavior |
| `captureFrames` | `0..300` | prepare-driver-manifest.py | Number of capture frames |
| `viewDiagnosticsEnabled` | `false/true` | observed-reuse variants / manifest | View-diagnostics toggle |
| `TFTMAC_ANGLE_DRIVER_MANIFEST` | `manifest path` | native DEV environment | External boot-scoped ANGLE driver manifest |

## 7. gfxstream / virtio-gpu / ASG transport controls

| Field | Known values / range | Surface | Function |
| --- | --- | --- | --- |
| `hw.gltransport` | `transport name` | AVD/runtime profile | Graphics transport |
| `hw.gltransport.drawFlushInterval` | `integer µs` | AVD/runtime profile | ASG draw flush interval |
| `hw.gltransport.asg.writeBufferSize` | `bytes` | AVD/runtime profile / legacy env | ASG write buffer |
| `hw.gltransport.asg.writeStepSize` | `bytes` | AVD/runtime profile / legacy env | ASG write step |
| `hw.gltransport.asg.dataRingSize` | `bytes` | AVD/runtime profile / legacy env | ASG data ring |
| `TFT_GLTRANSPORT` | `transport name` | legacy executable launcher | Legacy graphics transport selector |
| `TFT_GL_DRAW_FLUSH_INTERVAL` | `100..10000 µs in run-asg-experiment` | legacy experiment tooling | Draw flush interval override |
| `TFT_ASG_WRITE_BUFFER_SIZE` | `65536..1048576 bytes in run-asg-experiment` | legacy experiment tooling | ASG write buffer override |
| `TFT_ASG_WRITE_STEP_SIZE` | `1024..1048576 bytes in run-asg-experiment` | legacy experiment tooling | ASG write step override |
| `TFT_ASG_DATA_RING_SIZE` | `4096..1048576 bytes in run-asg-experiment` | legacy experiment tooling | ASG data ring override |
| `TFT_GUEST_SUBMIT_THREAD` | `on-demand / 0 / 1` | legacy experiment tooling | Guest gfxstream submit-thread behavior |
| `TFT_VIRTIO_GPU_NATIVE_SYNC` | `0/1` | legacy experiment tooling | virtio-gpu native-sync toggle |
| `TFT_VIRTIO_GPU_NEXT` | `0/1` | legacy experiment tooling | virtio-gpu-next toggle |
| `TFT_VULKAN_BATCHED_DESCRIPTORS` | `0/1` | legacy launcher | Vulkan descriptor batching toggle |
| `TFT_GRAPHICS_PROFILE` | `profile id` | legacy experiment tooling | Named emulator graphics feature profile |

## 8. MoltenVK controls exposed by the project

MoltenVK is a downstream host graphics component in the emulator stack even when TFT/Unreal itself selects OpenGL ES through ANGLE. These fields are exposed by current launch code and/or executable project experiment tooling.

| Field | Function / adjustable dimension | Surface |
| --- | --- | --- |
| `MVK_CONFIG_ACTIVITY_PERFORMANCE_LOGGING_STYLE` | MoltenVK performance logging style | launch environment / executable experiment tooling |
| `MVK_CONFIG_FAST_MATH_ENABLED` | MoltenVK fast-math toggle | launch environment / executable experiment tooling |
| `MVK_CONFIG_LOG_LEVEL` | MoltenVK log level | launch environment / executable experiment tooling |
| `MVK_CONFIG_MAX_ACTIVE_METAL_COMMAND_BUFFERS_PER_QUEUE` | Maximum active Metal command buffers per queue | launch environment / executable experiment tooling |
| `MVK_CONFIG_PERFORMANCE_LOGGING_FRAME_COUNT` | Frames per performance logging window | launch environment / executable experiment tooling |
| `MVK_CONFIG_PERFORMANCE_TRACKING` | Performance tracking enable | launch environment / executable experiment tooling |
| `MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS` | Metal command-buffer prefill behavior | launch environment / executable experiment tooling |
| `MVK_CONFIG_SHOULD_MAXIMIZE_CONCURRENT_COMPILATION` | Concurrent shader/pipeline compilation preference | launch environment / executable experiment tooling |
| `MVK_CONFIG_SUPPORT_LARGE_QUERY_POOLS` | Large query-pool support toggle | launch environment / executable experiment tooling |
| `MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS` | Synchronous vs asynchronous queue submission | launch environment / executable experiment tooling |
| `MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS` | Metal argument-buffer use | launch environment / executable experiment tooling |
| `MVK_CONFIG_USE_MTLHEAP` | MTLHeap use | launch environment / executable experiment tooling |
| `MVK_CONFIG_VK_SEMAPHORE_SUPPORT_STYLE` | Vulkan semaphore implementation style | launch environment / executable experiment tooling |
| `TFT_MVK_QUEUE_MODE` | Project wrapper queue mode (sync/async) | launch environment / executable experiment tooling |

## 9. Riot 18.2 / Unreal configurable CVar map

Every CVar below was directly discovered from the current Riot 18.2 boot log as a `Set CVar` or DeviceProfile push. The `DEV override` column identifies the 78 fields currently overridden by TFTMAC DEV. Fields with no DEV value remain Riot/Unreal-configurable surfaces but are not presently changed by our DEV profile.

### 9.1 Advanced rendering features

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `r.HairStrands.Binding` | `0` |  | Riot/Unreal config/CVar surface |
| `r.HairStrands.Simulation` | `0` |  | Riot/Unreal config/CVar surface |
| `r.HairStrands.SkyAO.SampleCount` | `4` |  | Riot/Unreal config/CVar surface |
| `r.HairStrands.SkyLighting.IntegrationType` | `2` |  | Riot/Unreal config/CVar surface |
| `r.HairStrands.Strands` | `0` |  | Riot/Unreal config/CVar surface |
| `r.HairStrands.Visibility.MSAA.SamplePerPixel` | `4` |  | Riot/Unreal config/CVar surface |
| `r.HeterogeneousVolumes` | `0` |  | Riot/Unreal config/CVar surface |
| `r.HeterogeneousVolumes.DownsampleFactor` | `2` |  | Riot/Unreal config/CVar surface |
| `r.HeterogeneousVolumes.MaxStepCount` | `256 ; 96` |  | Riot/Unreal config/CVar surface |
| `r.HeterogeneousVolumes.Shadows.Precision` | `0` |  | Riot/Unreal config/CVar surface |
| `r.HeterogeneousVolumes.Shadows.Resolution` | `256 ; 512` |  | Riot/Unreal config/CVar surface |
| `r.HeterogeneousVolumes.UseExistenceMask` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Nanite` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Nanite.ProjectEnabled` | `0` |  | Riot/Unreal config/CVar surface |
| `r.VirtualTextures` | `0` |  | Riot/Unreal config/CVar surface |
| `r.VRS.ContrastAdaptiveShading` | `0` |  | Riot/Unreal config/CVar surface |
| `r.VRS.EnableSoftware` | `0` |  | Riot/Unreal config/CVar surface |
| `r.VT.MaxAnisotropy` | `4 ; 8` |  | Riot/Unreal config/CVar surface |

### 9.2 Animation

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `a.Budget.BudgetMs` | `2` | `6.0` | DEV DeviceProfile override |
| `a.Budget.Enabled` | `1` |  | Riot/Unreal config/CVar surface |
| `a.Budget.InterpolationFalloffAggression` | `0.2` |  | Riot/Unreal config/CVar surface |
| `a.Budget.MaxTickedOffsreen` | `0` |  | Riot/Unreal config/CVar surface |
| `a.StripFramesOnCompression` | `0` | `1` | DEV DeviceProfile override |
| `a.StripOddFramesWhenFrameStripping` | `0` | `1` | DEV DeviceProfile override |
| `a.UseFrameTimeStampsForPacing` | `0` | `1` | DEV DeviceProfile override |

### 9.3 Async loading / level streaming

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `s.AsyncLoadingThreadEnabled` | `1` |  | Riot/Unreal config/CVar surface |
| `s.EventDrivenLoaderEnabled` | `1` |  | Riot/Unreal config/CVar surface |
| `s.FlushStreamingOnExit` | `1` |  | Riot/Unreal config/CVar surface |
| `s.LevelStreamingActorsUpdateTimeLimit` | `5.0` |  | Riot/Unreal config/CVar surface |
| `s.LevelStreamingComponentsRegistrationGranularity` | `10` |  | Riot/Unreal config/CVar surface |
| `s.LevelStreamingComponentsUnregistrationGranularity` | `5` |  | Riot/Unreal config/CVar surface |
| `s.MinBulkDataSizeForAsyncLoading` | `131072` |  | Riot/Unreal config/CVar surface |
| `s.PriorityAsyncLoadingExtraTime` | `15.0` |  | Riot/Unreal config/CVar surface |
| `s.PriorityLevelStreamingActorsUpdateExtraTime` | `5.0` |  | Riot/Unreal config/CVar surface |
| `s.StreamableStripDebugName` | `1` |  | Riot/Unreal config/CVar surface |
| `s.StreamableStripDebugNameInShipping` | `1` |  | Riot/Unreal config/CVar surface |
| `s.TimeLimitExceededMinTime` | `0.005` |  | Riot/Unreal config/CVar surface |
| `s.TimeLimitExceededMultiplier` | `1.5` |  | Riot/Unreal config/CVar surface |
| `s.UnregisterComponentsTimeLimit` | `1.0` |  | Riot/Unreal config/CVar surface |
| `s.UseBackgroundLevelStreaming` | `1` |  | Riot/Unreal config/CVar surface |
| `s.WarnIfTimeLimitExceeded` | `0` |  | Riot/Unreal config/CVar surface |

### 9.4 FX / Niagara / particles

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `FX.AllowGPUParticles` | `0` |  | Riot/Unreal config/CVar surface |
| `fx.Niagara.EnableTraversalCache` | `1` |  | Riot/Unreal config/CVar surface |
| `fx.Niagara.PSOPrecache.ReverseCulling` | `1` | `0` | DEV DeviceProfile override |
| `fx.Niagara.QualityLevel` | `1 ; 2` |  | Riot/Unreal config/CVar surface |
| `fx.Niagara.QualityLevel.Max` | `3` |  | Riot/Unreal config/CVar surface |
| `fx.Niagara.QualityLevel.Min` | `0` |  | Riot/Unreal config/CVar surface |
| `fx.NiagaraStateless.ComputeManager.CPUThreshold` | `256` |  | Riot/Unreal config/CVar surface |
| `r.EmitterSpawnRateScale` | `0.25 ; 0.5 ; 1.0` |  | Riot/Unreal config/CVar surface |
| `r.ParticleLightQuality` | `0 ; 1 ; 2` |  | Riot/Unreal config/CVar surface |

### 9.5 Foliage / grass

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `foliage.DensityScale` | `1.0` |  | Riot/Unreal config/CVar surface |
| `grass.CullDistanceScale` | `1.0` |  | Riot/Unreal config/CVar surface |
| `grass.DensityScale` | `1.0` |  | Riot/Unreal config/CVar surface |
| `grass.Enable` | `1` | `0` | DEV DeviceProfile override |

### 9.6 Gameplay / ability system

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `AbilitySystem.AbilityTask.MaxCount` | `6000` |  | Riot/Unreal config/CVar surface |
| `AbilitySystem.AbilityTask.TFTWarnThreshold` | `4000` |  | Riot/Unreal config/CVar surface |

### 9.7 Gameplay / controller

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `Controller.IsPushBased` | `1` |  | Riot/Unreal config/CVar surface |
| `PlayerController.IsPushBased` | `1` |  | Riot/Unreal config/CVar surface |

### 9.8 Garbage collection / UObject lifetime

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `gc.ActorClusteringEnabled` | `0` |  | Riot/Unreal config/CVar surface |
| `gc.AllowParallelGC` | `1` |  | Riot/Unreal config/CVar surface |
| `gc.AssetClustreringEnabled` | `0` |  | Riot/Unreal config/CVar surface |
| `gc.CreateGCClusters` | `1` |  | Riot/Unreal config/CVar surface |
| `gc.DumpObjectCountsToLogWhenMaxObjectLimitExceeded` | `1` |  | Riot/Unreal config/CVar surface |
| `gc.FlushStreamingOnGC` | `0` |  | Riot/Unreal config/CVar surface |
| `gc.GarbageEliminationEnabled` | `1` |  | Riot/Unreal config/CVar surface |
| `gc.IncrementalBeginDestroyEnabled` | `1` |  | Riot/Unreal config/CVar surface |
| `gc.MaxObjectsInEditor` | `25165824` |  | Riot/Unreal config/CVar surface |
| `gc.MaxObjectsInGame` | `750000` |  | Riot/Unreal config/CVar surface |
| `gc.MaxObjectsNotConsideredByGC` | `1` |  | Riot/Unreal config/CVar surface |
| `gc.MinGCClusterSize` | `5` |  | Riot/Unreal config/CVar surface |
| `gc.NumRetriesBeforeForcingGC` | `10` |  | Riot/Unreal config/CVar surface |
| `gc.TimeBetweenPurgingPendingKillObjects` | `75.0` |  | Riot/Unreal config/CVar surface |
| `gc.VerifyUObjectsAreNotFGCObjects` | `0` |  | Riot/Unreal config/CVar surface |

### 9.9 General rendering

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `r.AllowGlobalClipPlane` | `0` |  | Riot/Unreal config/CVar surface |
| `r.AllowOcclusionQueries` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Android.DisableVulkanSupport` | `0` | `1` | DEV DeviceProfile override |
| `r.Android.EnableAdrenoTilingHint` | `1` | `2` | DEV DeviceProfile override |
| `r.AnisotropicMaterials` | `1` |  | Riot/Unreal config/CVar surface |
| `r.AOQuality` | `1 ; 2` |  | Riot/Unreal config/CVar surface |
| `r.CustomDepth` | `3` |  | Riot/Unreal config/CVar surface |
| `r.DefaultBackBufferPixelFormat` | `4` | `0` | DEV DeviceProfile override |
| `r.DefaultFeature.AmbientOcclusion` | `0` |  | Riot/Unreal config/CVar surface |
| `r.DefaultFeature.AmbientOcclusionStaticFraction` | `0` |  | Riot/Unreal config/CVar surface |
| `r.DefaultFeature.AutoExposure` | `0` |  | Riot/Unreal config/CVar surface |
| `r.DefaultFeature.AutoExposure.Method` | `2` |  | Riot/Unreal config/CVar surface |
| `r.DefaultFeature.Bloom` | `0` |  | Riot/Unreal config/CVar surface |
| `r.DefaultFeature.LightUnits` | `0` |  | Riot/Unreal config/CVar surface |
| `r.DefaultFeature.MotionBlur` | `0` |  | Riot/Unreal config/CVar surface |
| `r.DetailMode` | `1 ; 3` |  | Riot/Unreal config/CVar surface |
| `r.DFShadowQuality` | `0 ; 1 ; 2` |  | Riot/Unreal config/CVar surface |
| `r.DiscardUnusedQuality` | `0` | `1` | DEV DeviceProfile override |
| `r.Fog` | `0` |  | Riot/Unreal config/CVar surface |
| `r.ForceSceneHasDecals` | `0` | `1` | DEV DeviceProfile override |
| `r.Forward.LightGridSizeZ` | `8` |  | Riot/Unreal config/CVar surface |
| `r.Forward.MaxCulledLightsPerCell` | `8` |  | Riot/Unreal config/CVar surface |
| `r.ForwardShading` | `1` |  | Riot/Unreal config/CVar surface |
| `r.FreeSkeletalMeshBuffers` | `0` | `1` | DEV DeviceProfile override |
| `r.GPUCrashDebugging` | `0` |  | Riot/Unreal config/CVar surface |
| `r.grass.DensityQualityLevel` | `0` |  | Riot/Unreal config/CVar surface |
| `r.HZB.BuildUseCompute` | `1` | `0` | DEV DeviceProfile override |
| `r.HZBOcclusion` | `0` |  | Riot/Unreal config/CVar surface |
| `r.MaterialQualityLevel` | `1` | `0` | DEV DeviceProfile override |
| `r.MaxAnisotropy` | `1 ; 2 ; 4` |  | Riot/Unreal config/CVar surface |
| `r.MeshCardRepresentation` | `0` |  | Riot/Unreal config/CVar surface |
| `r.MSAACount` | `4` | `4` | DEV DeviceProfile override |
| `r.NeverOcclusionTestDistance` | `200` |  | Riot/Unreal config/CVar surface |
| `r.OIT.SortedTriangles` | `0` |  | Riot/Unreal config/CVar surface |
| `r.RenderTargetPoolMin` | `400` | `350` | DEV DeviceProfile override |
| `r.SceneColorFormat` | `3 ; 4` |  | Riot/Unreal config/CVar surface |
| `r.SkinCache.AsyncCompute` | `0` |  | Riot/Unreal config/CVar surface |
| `r.SkinCache.CompileShaders` | `1` |  | Riot/Unreal config/CVar surface |
| `r.SkinCache.Mode` | `0` |  | Riot/Unreal config/CVar surface |
| `r.SkinCache.SkipCompilingGPUSkinVF` | `0` |  | Riot/Unreal config/CVar surface |
| `r.SupportLocalFogVolumes` | `0` |  | Riot/Unreal config/CVar surface |
| `r.TFTCustomRenderPass` | `1` |  | Riot/Unreal config/CVar surface |
| `r.VertexFoggingForOpaque` | `0` |  | Riot/Unreal config/CVar surface |
| `r.ViewDistanceScale` | `1.0` |  | Riot/Unreal config/CVar surface |
| `r.Visibility.DynamicMeshElements.Parallel` | `0` |  | Riot/Unreal config/CVar surface |
| `r.VSync` | `0` | `1` | DEV DeviceProfile override |

### 9.10 Lighting / shadows / atmosphere / GI

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `r.AmbientOcclusionLevels` | `-1` |  | Riot/Unreal config/CVar surface |
| `r.AmbientOcclusionMaxQuality` | `100 ; 60` |  | Riot/Unreal config/CVar surface |
| `r.AmbientOcclusionMipLevelFactor` | `0.4 ; 0.6 ; 1.0` |  | Riot/Unreal config/CVar surface |
| `r.AmbientOcclusionRadiusScale` | `1.0 ; 1.5` |  | Riot/Unreal config/CVar surface |
| `r.CapsuleShadows` | `1` |  | Riot/Unreal config/CVar surface |
| `r.ContactShadows` | `0` |  | Riot/Unreal config/CVar surface |
| `r.DistanceFieldAO` | `1` |  | Riot/Unreal config/CVar surface |
| `r.DistanceFields` | `0` |  | Riot/Unreal config/CVar surface |
| `r.DistanceFieldShadowing` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.LightFunctionQuality` | `1` |  | Riot/Unreal config/CVar surface |
| `r.LightMaxDrawDistanceScale` | `0.5 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.LightShaftQuality` | `0` |  | Riot/Unreal config/CVar surface |
| `r.LocalFogVolume.ApplyOnTranslucent` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.DiffuseIndirect.Allow` | `1` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.Reflections.Allow` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.Reflections.DownsampleFactor` | `1 ; 2` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.Reflections.MaxRoughnessToTraceForFoliage` | `0.2 ; 0.4` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.Reflections.ScreenSpaceReconstruction.MinWeight` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.Reflections.ScreenSpaceReconstruction.NumSamples` | `3 ; 5` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.ScreenProbeGather.DownsampleFactor` | `16 ; 32` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.ScreenProbeGather.FullResolutionJitterWidth` | `1` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.ScreenProbeGather.IrradianceFormat` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.ScreenProbeGather.MaxRoughnessToEvaluateRoughSpecularForFoliage` | `0.4 ; 0.8` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.ScreenProbeGather.NumAdaptiveProbes` | `16 ; 8` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.ScreenProbeGather.RadianceCache.NumProbesToTraceBudget` | `100` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.ScreenProbeGather.RadianceCache.ProbeResolution` | `16 ; 32` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.ScreenProbeGather.ScreenTraces.HZBTraversal.FullResDepth` | `1` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.ScreenProbeGather.ShortRangeAO.BentNormal` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.ScreenProbeGather.ShortRangeAO.HorizonSearch.ForegroundSampleRejectPower` | `1 ; 1.5` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.ScreenProbeGather.ShortRangeAO.HorizonSearch.HZB` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.ScreenProbeGather.StochasticInterpolation` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.ScreenProbeGather.TracingOctahedronResolution` | `8` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.ScreenProbeGather.TwoSidedFoliageBackfaceDiffuse` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.TraceMeshSDFs.Allow` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.TranslucencyReflections.FrontLayer.Allow` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.TranslucencyReflections.FrontLayer.Enable` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.TranslucencyVolume.GridPixelSize` | `32 ; 64` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.TranslucencyVolume.RadianceCache.NumProbesToTraceBudget` | `70` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.TranslucencyVolume.RadianceCache.ProbeResolution` | `8` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.TranslucencyVolume.TraceFromVolume` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.Lumen.TranslucencyVolume.TracingOctahedronResolution` | `3` |  | Riot/Unreal config/CVar surface |
| `r.LumenScene.DirectLighting.MaxLightsPerTile` | `4 ; 8` |  | Riot/Unreal config/CVar surface |
| `r.LumenScene.DirectLighting.UpdateFactor` | `32 ; 64` |  | Riot/Unreal config/CVar surface |
| `r.LumenScene.Radiosity.HemisphereProbeResolution` | `3 ; 4` |  | Riot/Unreal config/CVar surface |
| `r.LumenScene.Radiosity.ProbeSpacing` | `4 ; 8` |  | Riot/Unreal config/CVar surface |
| `r.LumenScene.Radiosity.UpdateFactor` | `128 ; 64` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.CSM.MaxCascades` | `1` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.CSM.TransitionScale` | `0.25 ; 0.8 ; 1.0` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.DistanceScale` | `1` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.MaxCSMResolution` | `1024 ; 2048` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.MaxResolution` | `1024 ; 2048` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.PreShadowResolutionFactor` | `0.5 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.RadiusThreshold` | `0.001` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.UnbuiltNumWholeSceneDynamicShadowCascades` | `1` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.UnbuiltWholeSceneDynamicShadowRadius` | `5000` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.Virtual.MarkCoarsePagesLocal` | `1` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.Virtual.MaxPhysicalPages` | `2048 ; 4096 ; 512` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.Virtual.ResolutionLodBiasDirectional` | `-1.5 ; 0.0` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.Virtual.ResolutionLodBiasDirectionalMoving` | `-1.5 ; 0.0` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.Virtual.ResolutionLodBiasLocal` | `0.0 ; 1.0` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.Virtual.ResolutionLodBiasLocalMoving` | `1.0 ; 2.0` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.Virtual.SMRT.RayCountDirectional` | `4 ; 8` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.Virtual.SMRT.RayCountLocal` | `4 ; 8` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.Virtual.SMRT.SamplesPerRayDirectional` | `2 ; 4` |  | Riot/Unreal config/CVar surface |
| `r.Shadow.Virtual.SMRT.SamplesPerRayLocal` | `2 ; 4` |  | Riot/Unreal config/CVar surface |
| `r.ShadowQuality` | `1 ; 2` |  | Riot/Unreal config/CVar surface |
| `r.SkyAtmosphere.AerialPerspectiveLUT.DepthResolution` | `4` |  | Riot/Unreal config/CVar surface |
| `r.SkyAtmosphere.AerialPerspectiveLUT.FastApplyOnOpaque` | `1 ; Always have FastSkyLUT 1 in this case to avoid wrong sky` |  | Riot/Unreal config/CVar surface |
| `r.SkyAtmosphere.AerialPerspectiveLUT.SampleCountMaxPerSlice` | `1` |  | Riot/Unreal config/CVar surface |
| `r.SkyAtmosphere.FastSkyLUT` | `1` |  | Riot/Unreal config/CVar surface |
| `r.SkyAtmosphere.FastSkyLUT.Height` | `50` |  | Riot/Unreal config/CVar surface |
| `r.SkyAtmosphere.FastSkyLUT.SampleCountMax` | `8.0` |  | Riot/Unreal config/CVar surface |
| `r.SkyAtmosphere.FastSkyLUT.SampleCountMin` | `1.0` |  | Riot/Unreal config/CVar surface |
| `r.SkyAtmosphere.FastSkyLUT.Width` | `96` |  | Riot/Unreal config/CVar surface |
| `r.SkyAtmosphere.MultiScatteringLUT.SampleCount` | `15.0` |  | Riot/Unreal config/CVar surface |
| `r.SkyAtmosphere.SampleCountMax` | `128.0 ; 32.0 ; 64.0` |  | Riot/Unreal config/CVar surface |
| `r.SkyAtmosphere.SampleCountMin` | `4.0` |  | Riot/Unreal config/CVar surface |
| `r.SkyAtmosphere.TransmittanceLUT.SampleCount` | `10.0` |  | Riot/Unreal config/CVar surface |
| `r.SkyAtmosphere.TransmittanceLUT.UseSmallFormat` | `1` |  | Riot/Unreal config/CVar surface |
| `r.SkyLight.RealTimeReflectionCapture.ResolutionOverride` | `0` | `32` | DEV DeviceProfile override |
| `r.SkyLight.RealTimeReflectionCapture.TimeSlice.SkyCloudCubeFacePerFrame` | `2` | `1` | DEV DeviceProfile override |
| `r.SkylightIntensityMultiplier` | `1.0` |  | Riot/Unreal config/CVar surface |
| `r.SupportCloudShadowOnForwardLitTranslucent` | `0` |  | Riot/Unreal config/CVar surface |
| `r.SupportPointLightWholeSceneShadows` | `1` |  | Riot/Unreal config/CVar surface |
| `r.SupportSkyAtmosphereAffectsHeightFog` | `0` |  | Riot/Unreal config/CVar surface |
| `r.SupportStationarySkylight` | `0` |  | Riot/Unreal config/CVar surface |
| `r.VolumetricCloud.Support` | `0` |  | Riot/Unreal config/CVar surface |
| `r.VolumetricFog` | `0` |  | Riot/Unreal config/CVar surface |
| `r.VolumetricFog.GridPixelSize` | `16 ; 8` |  | Riot/Unreal config/CVar surface |
| `r.VolumetricFog.GridSizeZ` | `128 ; 64` |  | Riot/Unreal config/CVar surface |
| `r.VolumetricFog.HistoryMissSupersampleCount` | `4` |  | Riot/Unreal config/CVar surface |
| `r.VolumetricFog.LightFunction` | `0` |  | Riot/Unreal config/CVar surface |

### 9.11 Mesh / LOD / skinning

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `lod.TemporalLag` | `0` |  | Riot/Unreal config/CVar surface |
| `r.SkeletalMesh.MinLodQualityLevel` | `0` |  | Riot/Unreal config/CVar surface |
| `r.SkeletalMesh.StripMinLodDataDuringCooking` | `1` |  | Riot/Unreal config/CVar surface |
| `r.SkeletalMeshLODBias` | `0` |  | Riot/Unreal config/CVar surface |
| `r.SkinnedMesh.SyncStreamingLODClamp` | `0` |  | Riot/Unreal config/CVar surface |
| `r.StaticMesh.MinLodQualityLevel` | `0` |  | Riot/Unreal config/CVar surface |

### 9.12 Mobile renderer / dynamic resolution

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `APT.DynamicRes.LockedScreenPercentage` | `60` |  | Riot/Unreal config/CVar surface |
| `r.Mobile.AmbientOcclusionQuality` | `0 ; 2 ; 3` |  | Riot/Unreal config/CVar surface |
| `r.Mobile.AntiAliasing` | `1` |  | Riot/Unreal config/CVar surface |
| `r.Mobile.CustomDepthForTranslucency` | `1` | `1` | DEV DeviceProfile override |
| `r.Mobile.DisableVertexFog` | `1` |  | Riot/Unreal config/CVar surface |
| `r.Mobile.EarlyZPass` | `2` |  | Riot/Unreal config/CVar surface |
| `r.Mobile.EyeAdaptation` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Mobile.PixelFogQuality` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Mobile.PropagateAlpha` | `1` |  | Riot/Unreal config/CVar surface |
| `r.Mobile.SceneColorFormat` | `3` |  | Riot/Unreal config/CVar surface |
| `r.Mobile.ShadingPath` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Mobile.SupportInsetShadows` | `1` |  | Riot/Unreal config/CVar surface |
| `r.Mobile.SupportsGen4TAA` | `0` |  | Riot/Unreal config/CVar surface |
| `r.MobileContentScaleFactor` | `1` | `0.0` | DEV DeviceProfile override |

### 9.13 Networking / replication

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `net.Iris.UseIrisReplication` | `1` |  | Riot/Unreal config/CVar surface |
| `net.IsPushModelEnabled` | `1` |  | Riot/Unreal config/CVar surface |
| `net.PushModelSkipUndirtiedFastArrays` | `1` |  | Riot/Unreal config/CVar surface |
| `net.PushModelSkipUndirtiedReplication` | `1` |  | Riot/Unreal config/CVar surface |
| `net.SubObjects.DefaultUseSubObjectReplicationList` | `1` |  | Riot/Unreal config/CVar surface |

### 9.14 OpenGL / GLES program & texture management

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `Android.OpenGL.NumRemoteProgramCompileServices` | `4` | `4` | DEV DeviceProfile override |
| `r.OpenGL.DeferTextureCreation` | `0` | `0` | DEV DeviceProfile override |
| `r.OpenGL.DeferTextureCreationKeepLowerMipCount` | `-1` | `16` | DEV DeviceProfile override |
| `r.OpenGL.EnableProgramLRUCache` | `0` | `1` | DEV DeviceProfile override |
| `r.OpenGL.ProgramLRUEvictTimeSeconds` | `0` | `0` | DEV DeviceProfile override |
| `r.OpenGL.ProgramLRUKeepBinaryResident` | `0` | `1` | DEV DeviceProfile override |
| `r.OpenGL.TextureEvictionFrameCount` | `500` | `500` | DEV DeviceProfile override |
| `r.OpenGL.TextureEvictionMinLRUCapacity` | `0` | `200` | DEV DeviceProfile override |
| `r.OpenGL.TextureEvictsPerFrame` | `10` | `10` | DEV DeviceProfile override |

### 9.15 Other engine/game controls

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `Android.EnableHardwareKeyboard` | `1` |  | Riot/Unreal config/CVar surface |
| `Android.EnableMouse` | `1` |  | Riot/Unreal config/CVar surface |
| `t.MaxFPS` | `0` | `60` | DEV DeviceProfile override |

### 9.16 Physics / Chaos / animation physics

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `p.AnimDynamics` | `0` |  | Riot/Unreal config/CVar surface |
| `p.AnimDynamicsWind` | `0` |  | Riot/Unreal config/CVar surface |
| `p.Chaos.AccelerationStructureUseDynamicTree` | `0` |  | Riot/Unreal config/CVar surface |
| `p.ClothPhysics` | `0` | `0` | DEV DeviceProfile override |
| `p.RigidBodyNode` | `true` | `0` | DEV DeviceProfile override |

### 9.17 Post-processing / AA / upscaling

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `r.AntiAliasingMethod` | `3` |  | Riot/Unreal config/CVar surface |
| `r.Bloom.ScreenPercentage` | `35.355 ; 50.000` |  | Riot/Unreal config/CVar surface |
| `r.BloomQuality` | `0` |  | Riot/Unreal config/CVar surface |
| `r.DepthOfFieldQuality` | `1` |  | Riot/Unreal config/CVar surface |
| `r.DOF.Gather.AccumulatorQuality` | `0 ; lower gathering accumulator quality ; 1 ; higher gathering accumulator quality` |  | Riot/Unreal config/CVar surface |
| `r.DOF.Gather.EnableBokehSettings` | `0 ; no bokeh simulation when gathering` |  | Riot/Unreal config/CVar surface |
| `r.DOF.Gather.PostfilterMethod` | `1 ; Median3x3 postfilering method ; 2 ; Max3x3 postfilering method` |  | Riot/Unreal config/CVar surface |
| `r.DOF.Gather.ResolutionDivisor` | `2 ; lower gathering resolution` |  | Riot/Unreal config/CVar surface |
| `r.DOF.Gather.RingCount` | `3 ; low number of samples when gathering ; 4 ; medium number of samples when gathering` |  | Riot/Unreal config/CVar surface |
| `r.DOF.Kernel.MaxBackgroundRadius` | `0.006 ; required because low gathering and no scattering and not looking great at 1080p ; 0.012 ; required because of AccumulatorQuality=0 ; 0.025` |  | Riot/Unreal config/CVar surface |
| `r.DOF.Kernel.MaxForegroundRadius` | `0.006 ; required because low gathering and no scattering and not looking great at 1080p ; 0.012 ; required because of AccumulatorQuality=0 ; 0.025` |  | Riot/Unreal config/CVar surface |
| `r.DOF.Recombine.EnableBokehSettings` | `0 ; no bokeh simulation on slight out of focus` |  | Riot/Unreal config/CVar surface |
| `r.DOF.Recombine.Quality` | `0` |  | Riot/Unreal config/CVar surface |
| `r.DOF.Scatter.BackgroundCompositing` | `0 ; no foreground scattering ; 1 ; no background occlusion ; 2 ; additive background scattering` |  | Riot/Unreal config/CVar surface |
| `r.DOF.Scatter.EnableBokehSettings` | `0 ; no bokeh simulation when scattering ; 1 ; bokeh simulation when scattering` |  | Riot/Unreal config/CVar surface |
| `r.DOF.Scatter.ForegroundCompositing` | `0 ; no foreground scattering ; 1 ; additive foreground scattering` |  | Riot/Unreal config/CVar surface |
| `r.DOF.Scatter.MaxSpriteRatio` | `0.04 ; only a maximum of 4% of scattered bokeh ; 0.1 ; only a maximum of 10% of scattered bokeh` |  | Riot/Unreal config/CVar surface |
| `r.DOF.TemporalAAQuality` | `0 ; faster temporal accumulation ; 1 ; more stable temporal accumulation` |  | Riot/Unreal config/CVar surface |
| `r.EyeAdaptation.ExponentialTransitionDistance` | `0` |  | Riot/Unreal config/CVar surface |
| `r.EyeAdaptationQuality` | `0` |  | Riot/Unreal config/CVar surface |
| `r.FastBlurThreshold` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Filter.SizeScale` | `0.7 ; 0.8 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.FXAA.Quality` | `0` |  | Riot/Unreal config/CVar surface |
| `r.LensFlareQuality` | `0` |  | Riot/Unreal config/CVar surface |
| `r.MotionBlur.HalfResGather` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.MotionBlurQuality` | `0` |  | Riot/Unreal config/CVar surface |
| `r.PostProcessing.PropagateAlpha` | `1` |  | Riot/Unreal config/CVar surface |
| `r.Refraction.OffsetQuality` | `1` |  | Riot/Unreal config/CVar surface |
| `r.RefractionQuality` | `0 ; 2` |  | Riot/Unreal config/CVar surface |
| `r.SceneColorFringeQuality` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.SeparateTranslucency` | `0` |  | Riot/Unreal config/CVar surface |
| `r.SSGI.Quality` | `1 ; 2 ; 3` |  | Riot/Unreal config/CVar surface |
| `r.SSR.HalfResSceneColor` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.SSR.Quality` | `0 ; 2` |  | Riot/Unreal config/CVar surface |
| `r.SSS.HalfRes` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.SSS.Quality` | `-1 ; 0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.SSS.SampleSet` | `0 ; 1 ; 2` |  | Riot/Unreal config/CVar surface |
| `r.SSS.Scale` | `0.75 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.TemporalAA.Mobile.UseCompute` | `0` |  | Riot/Unreal config/CVar surface |
| `r.TemporalAA.Quality` | `1 ; 2` |  | Riot/Unreal config/CVar surface |
| `r.TemporalAA.R11G11B10History` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Tonemapper.Quality` | `2 ; 3` |  | Riot/Unreal config/CVar surface |
| `r.Tonemapper.Sharpen` | `0` |  | Riot/Unreal config/CVar surface |
| `r.TonemapperGamma` | `2.2` |  | Riot/Unreal config/CVar surface |
| `r.TranslucencyLightingVolume.Blur` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.TranslucencyLightingVolume.Dim` | `32 ; 48 ; 64` |  | Riot/Unreal config/CVar surface |
| `r.TSR.History.R11G11B10` | `1` |  | Riot/Unreal config/CVar surface |
| `r.TSR.History.ScreenPercentage` | `100 ; 200` |  | Riot/Unreal config/CVar surface |
| `r.TSR.History.UpdateQuality` | `1 ; 2 ; 3` |  | Riot/Unreal config/CVar surface |
| `r.TSR.RejectionAntiAliasingQuality` | `1 ; 2` |  | Riot/Unreal config/CVar surface |
| `r.TSR.ReprojectionField` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.TSR.Resurrection` | `1` |  | Riot/Unreal config/CVar surface |
| `r.TSR.ShadingRejection.Flickering` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.Upscale.Quality` | `2 ; 3` |  | Riot/Unreal config/CVar surface |

### 9.18 Replay / demo

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `demo.HoldLivePlaybackTimeWhenStarved` | `1` |  | Riot/Unreal config/CVar surface |
| `demo.RecordHz` | `30` |  | Riot/Unreal config/CVar surface |
| `demo.WithLevelStreamingFixes` | `1` |  | Riot/Unreal config/CVar surface |
| `httpReplay.BufferedPlaybackTimeInSeconds` | `3.0` |  | Riot/Unreal config/CVar surface |
| `httpReplay.ChunkUploadDelayInSeconds` | `0.5` |  | Riot/Unreal config/CVar surface |
| `httpReplay.MinWaitForNextChunkInSeconds` | `0.25` |  | Riot/Unreal config/CVar surface |
| `Replay.UseReplayConnection` | `1` |  | Riot/Unreal config/CVar surface |

### 9.19 Scalability groups

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `sg.AntiAliasingQuality` | `3` | `1` | DEV DeviceProfile override |
| `sg.EffectsQuality` | `3` | `1` | DEV DeviceProfile override |
| `sg.PostProcessQuality` | `3` | `1` | DEV DeviceProfile override |
| `sg.ReflectionQuality` | `3` | `1` | DEV DeviceProfile override |
| `sg.ResolutionQuality` | `0` | `100` | DEV DeviceProfile override |
| `sg.ShadowQuality` | `3` | `1` | DEV DeviceProfile override |
| `sg.TextureQuality` | `3` | `1` | DEV DeviceProfile override |
| `sg.ViewDistanceQuality` | `3` | `1` | DEV DeviceProfile override |

### 9.20 Shader / PSO compilation & precache

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `android.PSOService.MaxPriPSOPrecacheAffinity` | `0` | `0` | DEV DeviceProfile override |
| `android.PSOService.MinPriPSOPrecacheAffinity` | `0` | `7` | DEV DeviceProfile override |
| `android.PSOService.NormalPriPSOPrecacheAffinity` | `0` | `31` | DEV DeviceProfile override |
| `r.MeshDrawCommands.AllowOnDemandShaderCreation` | `1` | `1` | DEV DeviceProfile override |
| `r.pso.CreateOnRHIThread` | `false` | `1` | DEV DeviceProfile override |
| `r.pso.PrecompileThreadPoolPercentOfHardwareThreads` | `75` | `0` | DEV DeviceProfile override |
| `r.pso.PrecompileThreadPoolSize` | `0` | `4` | DEV DeviceProfile override |
| `r.PSOPrecache.Components` | `1 # PSO-Precache all components of an actor` |  | Riot/Unreal config/CVar surface |
| `r.PSOPrecache.CustomDepth` | `2 ; Precache custom depth-stencil pass PSOs` |  | Riot/Unreal config/CVar surface |
| `r.PSOPrecache.DrawnComponentBoostStrategy` | `0` | `1` | DEV DeviceProfile override |
| `r.PSOPrecache.LightMapPolicyMode` | `0 # Precache all lightmap variation PSOs` |  | Riot/Unreal config/CVar surface |
| `r.PSOPrecache.NiagaraComponentPSOPrecachePriority` | `1 # Boost priority of Niagara PSO Precaches` |  | Riot/Unreal config/CVar surface |
| `r.PSOPrecache.PrecacheAlphaColorChannel` | `1` | `0` | DEV DeviceProfile override |
| `r.PSOPrecache.ProjectedShadows` | `1` | `0` | DEV DeviceProfile override |
| `r.PSOPrecache.ProxyCreationDelayStrategy` | `0` | `1` | DEV DeviceProfile override |
| `r.PSOPrecache.ProxyCreationWhenPSOReady` | `1` | `1` | DEV DeviceProfile override |
| `r.PSOPrecache.Resources` | `1 # PSO-Precache all possible used PSOs used by resources during PostLoad` |  | Riot/Unreal config/CVar surface |
| `r.PSOPrecache.StaticMeshComponentPSOPrecachePriority` | `false` | `1` | DEV DeviceProfile override |
| `r.PSOPrecache.TranslucencyAllPass` | `1 # Precache Translucency PSOs` |  | Riot/Unreal config/CVar surface |
| `r.PSOPrecache.TranslucencyLightingVolumeMaterial` | `1 # Precache Translucency+StaticLighting PSOs` |  | Riot/Unreal config/CVar surface |
| `r.PSOPrecache.Validation` | `1 # Minimal PSOPrecache tracking` |  | Riot/Unreal config/CVar surface |
| `r.PSOPrecaching.PermitPriorityEscalation` | `true` | `0` | DEV DeviceProfile override |
| `r.PSOPrecaching.WaitForHighPriorityRequestsOnly` | `0` | `1` | DEV DeviceProfile override |
| `r.ShaderCompiler.JobCacheDDC` | `1` |  | Riot/Unreal config/CVar surface |
| `r.ShaderPipelineCache.BackgroundBatchSize` | `1` | `20` | DEV DeviceProfile override |
| `r.ShaderPipelineCache.BatchSize` | `50` | `20` | DEV DeviceProfile override |
| `r.ShaderPipelineCache.BatchTime` | `16` | `4` | DEV DeviceProfile override |
| `r.ShaderPipelineCache.Enabled` | `1` |  | Riot/Unreal config/CVar surface |
| `r.ShaderPipelineCache.LazyLoadShadersWhenPSOCacheIsPresent` | `0` | `1` | DEV DeviceProfile override |

### 9.21 Slate / UI

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `Slate.EnableGlobalInvalidation` | `1` |  | Riot/Unreal config/CVar surface |

### 9.22 TFT-specific audio

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `tft.Audio.DeviceTier` | `High` | `High` | DEV DeviceProfile override |
| `tft.Audio.PlayOnlyOneArenaAtATime` | `false` | `false` | DEV DeviceProfile override |
| `tft.Audio.RestrictNumberOfAmbientSounds` | `false` | `false` | DEV DeviceProfile override |

### 9.23 TFT-specific game/runtime

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `tft.DefaultFrameRateLimit` | `0` | `60` | DEV DeviceProfile override |

### 9.24 Texture / mesh streaming

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `r.Streaming.AllowFastForceResident` | `0` | `1` | DEV DeviceProfile override |
| `r.Streaming.AmortizeCPUToGPUCopy` | `1` |  | Riot/Unreal config/CVar surface |
| `r.Streaming.Boost` | `1` |  | Riot/Unreal config/CVar surface |
| `r.Streaming.LimitPoolSizeToVRAM` | `0 ; 1` |  | Riot/Unreal config/CVar surface |
| `r.Streaming.MaxEffectiveScreenSize` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Streaming.MaxNumTexturesToStreamPerFrame` | `10 ; 15 ; 5` |  | Riot/Unreal config/CVar surface |
| `r.Streaming.MaxTempMemoryAllowed` | `50` | `20` | DEV DeviceProfile override |
| `r.Streaming.MipBias` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Streaming.PoolSize` | `1000` | `1000` | DEV DeviceProfile override |
| `r.Streaming.PoolSizeForMeshes` | `-1` | `-1` | DEV DeviceProfile override |
| `r.Streaming.UseFixedPoolSize` | `0` | `0` | DEV DeviceProfile override |

### 9.25 Vulkan RHI / pipeline management

| CVar | Riot 18.2 observed / baseline | DEV override | Adjustment surface |
| --- | --- | --- | --- |
| `Android.Vulkan.NumRemoteProgramCompileServices` | `6` | `0` | DEV DeviceProfile override |
| `r.Vulkan.AllowAsyncCompute` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Vulkan.AllowPSOPrecaching` | `true` | `1` | DEV DeviceProfile override |
| `r.Vulkan.AllowSparseResidency` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Vulkan.AllowSplitBarriers` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Vulkan.CompressSPIRV` | `0` | `1` | DEV DeviceProfile override |
| `r.Vulkan.Depth24Bit` | `1` |  | Riot/Unreal config/CVar surface |
| `r.Vulkan.DiagnosticBuffer` | `1` |  | Riot/Unreal config/CVar surface |
| `r.Vulkan.EnablePipelineLRUCache` | `0` | `1` | DEV DeviceProfile override |
| `r.Vulkan.EnableTransientResourceAllocator` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Vulkan.MemoryBacktrace` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Vulkan.PipelineCacheFromShaderPipelineCache` | `1` | `1` | DEV DeviceProfile override |
| `r.Vulkan.PipelineLRUCacheEvictBinary` | `0` | `1` | DEV DeviceProfile override |
| `r.Vulkan.PSOLRUEvictAfterUnusedFrames` | `0` | `1000` | DEV DeviceProfile override |
| `r.Vulkan.ReleaseShaderModuleWhenEvictingPSO` | `0` | `1` | DEV DeviceProfile override |
| `r.Vulkan.RHIThread` | `1` |  | Riot/Unreal config/CVar surface |
| `r.Vulkan.Submission.AllowTimelineSemaphores` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Vulkan.Submission.UseInterruptThread` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Vulkan.Submission.UseSubmissionThread` | `0` |  | Riot/Unreal config/CVar surface |
| `r.Vulkan.UseChunkedPSOCache` | `0` | `0` | DEV DeviceProfile override |
| `r.Vulkan.UseMinimalSubmits` | `1` |  | Riot/Unreal config/CVar surface |

## 10. Riot/TFT game-facing settings explicitly evidenced outside the CVar map

Only game-facing fields explicitly evidenced by current project authority are included; additional UI options are not guessed.

| Field | Current/known state | Surface | Note |
| --- | --- | --- | --- |
| `Riot/TFT graphics quality` | `current project baseline records High` | In-game setting / runtime comparison receipt | Field is explicitly tracked by current project; exact full UI choice list is not inferred here. |
| `Riot/TFT frame-rate cap` | `current project baseline records 60 FPS` | In-game setting / runtime comparison receipt | Also controlled by `tft.DefaultFrameRateLimit` and `t.MaxFPS` at DeviceProfile level. |
| `Riot Performance Mode Beta` | `toggle; current authority OFF/retired` | In-game setting | Explicitly evidenced project setting; not selectable as a current TFTMAC experiment preset. |

## 11. Google Play, Riot update, audit and optimization-lab controls

| Field / option | Values / shape | Source | Function |
| --- | --- | --- | --- |
| `OvernightLab campaign --duration` | `duration string; default 10h` | OvernightLab/overnight_lab.py | Campaign duration |
| `OvernightLab campaign --resume` | `boolean` | OvernightLab/overnight_lab.py | Resume active campaign |
| `OvernightLab run-candidate candidate` | `candidate id` | OvernightLab/overnight_lab.py | Single candidate selection |
| `OvernightLab run-candidate --campaign` | `campaign id` | OvernightLab/overnight_lab.py | Attach run to campaign |
| `OvernightLab report --campaign` | `campaign id` | OvernightLab/overnight_lab.py | Report selection |
| `IncrementalLab campaign --duration` | `duration string; default 4h` | OvernightLab/incremental_lab.py | Incremental campaign duration |
| `IncrementalLab campaign --resume` | `boolean` | OvernightLab/incremental_lab.py | Resume incremental campaign |
| `IncrementalLab campaign --impact-only` | `boolean` | OvernightLab/incremental_lab.py | Impact-only campaign mode |
| `incremental manifest maximum_seconds_per_run` | `integer` | OvernightLab/manifests/incremental-candidates.json | Per-run bound |
| `incremental manifest target_stages` | `stage list` | OvernightLab/manifests/incremental-candidates.json | Measurement stages |
| `incremental candidate cvar` | `CVar name` | OvernightLab/manifests/incremental-candidates.json | Candidate setting |
| `incremental candidate from` | `value` | OvernightLab/manifests/incremental-candidates.json | Expected baseline value |
| `incremental candidate to` | `value` | OvernightLab/manifests/incremental-candidates.json | Candidate value |
| `official candidate enabled` | `boolean` | OvernightLab/manifests/official-candidates.json | Candidate admission toggle |
| `official candidate guest_properties` | `property map` | OvernightLab/manifests/official-candidates.json | Guest property candidate payload |
| `official candidate maximum_seconds` | `integer` | OvernightLab/manifests/official-candidates.json | Per-candidate bound |
| `official candidate target_stages` | `stage list` | OvernightLab/manifests/official-candidates.json | Target measurement stages |
| `riot-update-audit --adb` | `path` | scripts/riot-update-audit.py | ADB executable |
| `riot-update-audit --adb-server-port` | `integer` | scripts/riot-update-audit.py | ADB server port |
| `riot-update-audit --serial` | `serial` | scripts/riot-update-audit.py | Target emulator/device |
| `riot-update-audit --output-root` | `path` | scripts/riot-update-audit.py | Audit evidence root |
| `riot-update-audit --audit-id` | `id` | scripts/riot-update-audit.py | Audit identity |
| `riot-update-audit snapshot --phase` | `PRE_UPDATE / POST_PLAY_UPDATE / POST_RIOT_INIT` | scripts/riot-update-audit.py | Snapshot phase |
| `riot-update-audit diff --before` | `audit phase` | scripts/riot-update-audit.py | Diff starting phase |
| `riot-update-audit diff --after` | `audit phase` | scripts/riot-update-audit.py | Diff ending phase |
| `run-tft-best-verified --resolution` | `1440p / 1620p / 1800p / 2160p` | legacy executable launcher | Display preset |
| `run-tft-best-verified --ui-scale` | `1.0 / 1.25 / 1.5 / 1.75 / 2.0` | legacy executable launcher | UI scale |

### 11.1 Exact command-line option token index

| Option | Command family | Function |
| --- | --- | --- |
| `--duration` | OvernightLab / IncrementalLab campaign | Campaign duration |
| `--resume` | OvernightLab / IncrementalLab campaign | Resume active campaign |
| `--impact-only` | IncrementalLab campaign | Impact-only execution mode |
| `--campaign` | OvernightLab run/report | Campaign selection |
| `--adb` | riot-update-audit | ADB executable |
| `--adb-server-port` | riot-update-audit | ADB server port |
| `--serial` | riot-update-audit | Target emulator/device serial |
| `--output-root` | riot-update-audit | Evidence output root |
| `--audit-id` | riot-update-audit | Audit identity |
| `--phase` | riot-update-audit snapshot | Snapshot phase |
| `--before` | riot-update-audit diff | Before phase |
| `--after` | riot-update-audit diff | After phase |
| `--resolution` | run-tft-best-verified | Resolution preset |
| `--ui-scale` | run-tft-best-verified | UI scale |
| `--print-config` | run-tft-best-verified | Print effective launcher configuration |
| `--list-resolutions` | run-tft-best-verified | List resolution presets |

## 12. Executable project environment-variable input map

This section maps environment inputs discovered in executable source/tooling. It includes legacy/experimental launcher surfaces so a field remains discoverable, but **does not make historical/PBE-derived candidates current authority**.

### 12.1 TFTMAC/native/build inputs

| Variable | Function | Discovered in |
| --- | --- | --- |
| `TFTMAC_ANDROID_NDK_ROOT` | Android NDK root for native-clock build | scripts/build-native-clock.command |
| `TFTMAC_ANGLE_DRIVER_MANIFEST` | Executable project input; see source for accepted values/defaults. | tftmac/Runtime/TFTMACRuntime.swift |
| `TFTMAC_AUTONOMOUS_SILENT` | Executable project input; see source for accepted values/defaults. | native app constant-backed environment input |
| `TFTMAC_BUILD_COMMIT` | Build commit identity supplied to direct-control build tooling | tools/tftmac-direct-control.mjs |
| `TFTMAC_CAPTURE_ROOT` | Capture root override for summarization tooling | scripts/summarize-native-session.command |
| `TFTMAC_CLOCK_SIGN_IDENTITY` | Signing identity for native clock helper | scripts/build-native-clock.command |
| `TFTMAC_CODE_SIGN_IDENTITY_NAME` | macOS code-sign identity for app/launcher builds | scripts/build-control-launcher.command<br>scripts/build-dev-launcher.command<br>scripts/build-native-app.command |
| `TFTMAC_DEV_EXPERIMENT_PROFILE` | Executable project input; see source for accepted values/defaults. | native app constant-backed environment input |
| `TFTMAC_DEV_VCPU` | Executable project input; see source for accepted values/defaults. | tftmac/Runtime/RuntimeModeAuthority.swift |
| `TFTMAC_DEV_WORKLOAD` | Executable project input; see source for accepted values/defaults. | native app constant-backed environment input |
| `TFTMAC_ENABLE_AUTO_PERFETTO` | Executable project input; see source for accepted values/defaults. | tftmac/Runtime/TFTMACRuntime.swift |
| `TFTMAC_FORBIDDEN_TOKEN` | Verification-token override used by verification tooling | scripts/verify-tftmac.command |
| `TFTMAC_HOST_BACKING_SCALE` | Executable project input; see source for accepted values/defaults. | tftmac/Sources/TFTMACRuntimeBridge.swift<br>tools/tftmac-direct-control.mjs |
| `TFTMAC_HOST_SCREEN_HEIGHT` | Executable project input; see source for accepted values/defaults. | tftmac/Sources/TFTMACRuntimeBridge.swift<br>tools/tftmac-direct-control.mjs |
| `TFTMAC_HOST_SCREEN_WIDTH` | Executable project input; see source for accepted values/defaults. | tftmac/Sources/TFTMACRuntimeBridge.swift<br>tools/tftmac-direct-control.mjs |
| `TFTMAC_KEYCHAIN_SERVICE` | Keychain service selector for login helper | scripts/login-tft-from-keychain.command |
| `TFTMAC_NATIVE_CONTROL_WIDTH` | Executable project input; see source for accepted values/defaults. | tftmac/Sources/TFTMACRuntimeBridge.swift<br>tools/tftmac-direct-control.mjs |
| `TFTMAC_NATIVE_FULLSCREEN` | Executable project input; see source for accepted values/defaults. | tftmac/Sources/TFTMACRuntimeBridge.swift<br>tools/tftmac-direct-control.mjs |
| `TFTMAC_NATIVE_TOPBAR_HEIGHT` | Executable project input; see source for accepted values/defaults. | tftmac/Sources/TFTMACRuntimeBridge.swift<br>tools/tftmac-direct-control.mjs |
| `TFTMAC_OPENSSL` | OpenSSL executable/path override | scripts/ensure-local-signing-identity.command |
| `TFTMAC_PIPELINE_EVENT_V1` | Executable project input; see source for accepted values/defaults. | tftmac/Runtime/TFTMACRuntime.swift |
| `TFTMAC_REPO_ROOT` | Executable project input; see source for accepted values/defaults. | tftmac/Sources/TFTMACRuntimeBridge.swift<br>tools/tftmac-direct-control.mjs |
| `TFTMAC_RUNTIME_MODE` | Executable project input; see source for accepted values/defaults. | native app constant-backed environment input |
| `TFTMAC_TEST_PYTHON` | Python interpreter override for native-clock tests | scripts/build-native-clock.command<br>scripts/test-native-clock.command |
| `TFTMAC_UNLOCK_SETUP_ONLY` | Executable project input; see source for accepted values/defaults. | tftmac/App/AppCoordinator.swift |
| `TFTMAC_VULKAN_CAMPAIGN_DIR` | Resume/target directory for Vulkan campaign tooling | scripts/run-vulkan-experiment-campaign.command |
| `TFTMAC_VULKAN_RECOVERY_CAPTURE` | Retained recovery capture supplied to Vulkan campaign tooling | scripts/run-vulkan-experiment-campaign.command |
| `TFT_EMULATOR` | Executable project input; see source for accepted values/defaults. | RuntimeHost/main.c<br>scripts/android-environment.sh |
| `TFT_HOST_LATENCY_QOS` | Executable project input; see source for accepted values/defaults. | RuntimeHost/main.c |
| `TFT_HOST_STDERR` | Executable project input; see source for accepted values/defaults. | RuntimeHost/main.c |
| `TFT_HOST_STDOUT` | Executable project input; see source for accepted values/defaults. | RuntimeHost/main.c |

### 12.2 Legacy/experimental TFT_* script inputs

| Variable | Function | Discovered in |
| --- | --- | --- |
| `TFT_60FPS_CAMPAIGN_DIR` | Executable project input; see source for accepted values/defaults. | scripts/run-60fps-win-campaign.command |
| `TFT_60FPS_COMBAT_HOLD_SECONDS` | Executable project input; see source for accepted values/defaults. | scripts/run-60fps-win-campaign.command |
| `TFT_60FPS_MAX_CANDIDATES` | Executable project input; see source for accepted values/defaults. | scripts/run-60fps-win-campaign.command |
| `TFT_60FPS_NAVIGATION_TIMEOUT` | Executable project input; see source for accepted values/defaults. | scripts/run-60fps-win-campaign.command |
| `TFT_ADB` | Executable project input; see source for accepted values/defaults. | scripts/android-environment.sh |
| `TFT_ADB_SERVER_PORT` | Executable project input; see source for accepted values/defaults. | run-tft-fast-quality.command<br>run-tft-gles32.command<br>scripts/capture-frame-pacing.command<br>scripts/capture-input-latency.command<br>scripts/login-tft-from-keychain.command<br>scripts/measure-frame-pacing.command<br>scripts/prewarm-tft-gameplay.command<br>scripts/run-asg-experiment.command<br>scripts/run-autonomous-trial-benchmark.command<br>scripts/run-performance-campaign.command<br>scripts/verify-environment.sh<br>scripts/watch-root-pso.command |
| `TFT_ALLOW_REJECTED_ASG_PATCH` | Executable project input; see source for accepted values/defaults. | run-tft-fast-quality-asg-active-consumer.command |
| `TFT_ALLOW_REJECTED_GLES30_GATE` | Executable project input; see source for accepted values/defaults. | run-tft-fast-quality-native-gles30.command |
| `TFT_ALLOW_REJECTED_GLES31_GATE` | Executable project input; see source for accepted values/defaults. | run-tft-fast-quality-native-gles31.command |
| `TFT_ANGLE_DISABLED_FEATURES` | Executable project input; see source for accepted values/defaults. | run-tft-fast-quality-angle-no-fbo-submit.command<br>run-tft-performance-max.command<br>scripts/performance-candidates.json |
| `TFT_ANGLE_OPENGL_PROFILE` | Executable project input; see source for accepted values/defaults. | run-tft-fast-quality-shader-prewarm.command |
| `TFT_ANGLE_OPENGL_PROFILE_SHA256` | Executable project input; see source for accepted values/defaults. | run-tft-fast-quality-shader-prewarm.command |
| `TFT_ASG_DATA_RING_SIZE` | Executable project input; see source for accepted values/defaults. | run-tft-fast-quality-upstream-asg.command<br>scripts/performance-candidates.json<br>scripts/run-asg-experiment.command |
| `TFT_ASG_WRITE_BUFFER_SIZE` | Executable project input; see source for accepted values/defaults. | scripts/performance-candidates.json<br>scripts/run-asg-experiment.command |
| `TFT_ASG_WRITE_STEP_SIZE` | Executable project input; see source for accepted values/defaults. | run-tft-fast-quality-upstream-asg.command<br>run-tft-performance-max.command<br>scripts/performance-candidates.json<br>scripts/run-asg-experiment.command |
| `TFT_AUDIO_ENABLED` | Executable project input; see source for accepted values/defaults. | scripts/performance-candidates.json |
| `TFT_AUTONOMOUS_TRIAL_ROOT` | Executable project input; see source for accepted values/defaults. | scripts/run-autonomous-trial-benchmark.command |
| `TFT_AVD_HOME` | Executable project input; see source for accepted values/defaults. | run-tft-fast-quality.command<br>scripts/android-environment.sh |
| `TFT_AVD_NAME` | Executable project input; see source for accepted values/defaults. | run-tft-fast-quality.command<br>run-tft-gles32.command<br>scripts/run-asg-experiment.command<br>scripts/run-autonomous-trial-benchmark.command<br>scripts/run-performance-campaign.command<br>scripts/verify-environment.sh |
| `TFT_CAMPAIGN_CAFFEINATED` | Executable project input; see source for accepted values/defaults. | scripts/run-performance-campaign.command |
| `TFT_CPU_CORES` | Executable project input; see source for accepted values/defaults. | run-tft-angle-opengl.command |
| `TFT_DISPLAY_DENSITY` | Executable project input; see source for accepted values/defaults. | run-tft-angle-opengl.command<br>run-tft-best-verified.command<br>run-tft-fast-quality.command<br>run-tft-mvk128-experimental.command |
| `TFT_DISPLAY_SIZE` | Executable project input; see source for accepted values/defaults. | run-tft-angle-opengl.command<br>run-tft-best-verified.command<br>run-tft-fast-quality.command<br>run-tft-mvk128-experimental.command |
| `TFT_EMULATOR_LIB_DIR` | Executable project input; see source for accepted values/defaults. | scripts/restore-emulator-graphics.command |
| `TFT_EXPECTED_GLTRANSPORT_BASELINE` | Executable project input; see source for accepted values/defaults. | run-tft-fast-quality.command<br>scripts/run-asg-experiment.command |
| `TFT_EXPECTED_PHASE` | Executable project input; see source for accepted values/defaults. | scripts/capture-frame-pacing.command |
| `TFT_EXPECTED_STAGE` | Executable project input; see source for accepted values/defaults. | scripts/capture-frame-pacing.command |
| `TFT_GLTRANSPORT` | Executable project input; see source for accepted values/defaults. | run-tft-fast-quality.command<br>scripts/run-asg-experiment.command |
| `TFT_GL_DRAW_FLUSH_INTERVAL` | Executable project input; see source for accepted values/defaults. | run-tft-fast-quality-upstream-asg.command<br>scripts/performance-candidates.json<br>scripts/run-asg-experiment.command |
| `TFT_GO_COMMAND` | Executable project input; see source for accepted values/defaults. | scripts/build-android-egl-capability-probe.command |
| `TFT_GRAPHICS_PROFILE` | Executable project input; see source for accepted values/defaults. | run-tft-angle-opengl.command<br>run-tft-direct-vulkan.command<br>run-tft-fast-quality-shader-prewarm.command<br>scripts/performance-candidates.json |
| `TFT_GUEST_GL_DRIVER` | Executable project input; see source for accepted values/defaults. | scripts/capture-frame-pacing.command |
| `TFT_GUEST_SUBMIT_THREAD` | Executable project input; see source for accepted values/defaults. | scripts/performance-candidates.json |
| `TFT_INPUT_EVENT_DEVICE` | Executable project input; see source for accepted values/defaults. | scripts/capture-input-latency.command |
| `TFT_INPUT_LATENCY_DRY_RUN` | Executable project input; see source for accepted values/defaults. | scripts/run-input-latency-experiment.command |
| `TFT_INPUT_LATENCY_ROOT` | Executable project input; see source for accepted values/defaults. | scripts/capture-input-latency.command<br>scripts/run-input-latency-experiment.command |
| `TFT_INPUT_LATENCY_ROUNDS` | Executable project input; see source for accepted values/defaults. | scripts/capture-input-latency.command |
| `TFT_INPUT_LATENCY_WINDOW_SECONDS` | Executable project input; see source for accepted values/defaults. | scripts/capture-input-latency.command |
| `TFT_JQ` | Executable project input; see source for accepted values/defaults. | scripts/build-performance-leaderboard.command<br>scripts/capture-frame-pacing.command<br>scripts/run-autonomous-trial-benchmark.command<br>scripts/run-performance-campaign.command<br>scripts/summarize-android-ui-transport.command<br>scripts/test-tft-screen-classifier.command |
| `TFT_LAUNCHER` | Executable project input; see source for accepted values/defaults. | run-tft-fast-quality.command<br>scripts/run-asg-experiment.command |
| `TFT_MEASUREMENT_ROOT` | Executable project input; see source for accepted values/defaults. | scripts/capture-frame-pacing.command |
| `TFT_MEASUREMENT_ROUNDS` | Executable project input; see source for accepted values/defaults. | scripts/capture-frame-pacing.command |
| `TFT_MEASUREMENT_WINDOW_SECONDS` | Executable project input; see source for accepted values/defaults. | scripts/capture-frame-pacing.command |
| `TFT_MEMORY_MB` | Executable project input; see source for accepted values/defaults. | run-tft-angle-opengl.command |
| `TFT_MVK_QUEUE_MODE` | Executable project input; see source for accepted values/defaults. | run-tft-angle-opengl.command |
| `TFT_NODE` | Executable project input; see source for accepted values/defaults. | scripts/login-tft-from-keychain.command |
| `TFT_PATCHED_EMULATOR_RUNTIME` | Executable project input; see source for accepted values/defaults. | scripts/build-asg-active-consumer-runtime.command |
| `TFT_PERFORMANCE_CAMPAIGN_ROOT` | Executable project input; see source for accepted values/defaults. | scripts/run-performance-campaign.command |
| `TFT_PERFORMANCE_CANDIDATES` | Executable project input; see source for accepted values/defaults. | scripts/run-autonomous-trial-benchmark.command |
| `TFT_PROFILE_PATH` | Executable project input; see source for accepted values/defaults. | scripts/capture-frame-pacing.command |
| `TFT_PSO_CPU_LIST` | Executable project input; see source for accepted values/defaults. | scripts/watch-root-pso.command |
| `TFT_PSO_WATCH_INTERVAL` | Executable project input; see source for accepted values/defaults. | scripts/watch-root-pso.command |
| `TFT_RENDERER` | Executable project input; see source for accepted values/defaults. | scripts/capture-frame-pacing.command |
| `TFT_ROOT_AVD_HOME` | Executable project input; see source for accepted values/defaults. | run-tft-best-verified.command<br>run-tft-fast-quality.command<br>scripts/run-autonomous-trial-benchmark.command<br>scripts/run-performance-campaign.command |
| `TFT_ROOT_SDK` | Executable project input; see source for accepted values/defaults. | scripts/android-environment.sh<br>scripts/run-host-angle-capability-probe.command |
| `TFT_SCENE` | Executable project input; see source for accepted values/defaults. | scripts/capture-frame-pacing.command<br>scripts/capture-input-latency.command |
| `TFT_SCREEN_CLASSIFIER_BINARY` | Executable project input; see source for accepted values/defaults. | scripts/build-tft-screen-classifier.command<br>scripts/capture-frame-pacing.command<br>scripts/run-autonomous-trial-benchmark.command<br>scripts/test-tft-screen-classifier.command |
| `TFT_SCREEN_CLASSIFIER_DEBUG` | Screen-classifier debug output toggle | tools/tft-screen-classifier.swift |
| `TFT_SCREEN_CLASSIFIER_FIXTURE` | Executable project input; see source for accepted values/defaults. | scripts/test-tft-screen-classifier.command |
| `TFT_SCREEN_CLASSIFIER_MODULE_CACHE` | Executable project input; see source for accepted values/defaults. | scripts/build-tft-screen-classifier.command |
| `TFT_SEMANTIC_BEFORE_IMAGE` | Executable project input; see source for accepted values/defaults. | scripts/capture-frame-pacing.command |
| `TFT_SERIAL` | Executable project input; see source for accepted values/defaults. | run-tft-fast-quality.command<br>scripts/capture-frame-pacing.command<br>scripts/capture-input-latency.command<br>scripts/login-tft-from-keychain.command<br>scripts/measure-frame-pacing.command<br>scripts/prewarm-tft-gameplay.command<br>scripts/run-asg-experiment.command<br>scripts/run-autonomous-trial-benchmark.command<br>scripts/run-performance-campaign.command<br>scripts/watch-root-pso.command |
| `TFT_SOURCE_EMULATOR_RUNTIME` | Executable project input; see source for accepted values/defaults. | scripts/build-asg-active-consumer-runtime.command |
| `TFT_SQLITE3` | Executable project input; see source for accepted values/defaults. | scripts/summarize-native-session.command |
| `TFT_TRIAL_MAX_ATTEMPTS` | Executable project input; see source for accepted values/defaults. | scripts/run-autonomous-trial-benchmark.command |
| `TFT_TRIAL_MAX_CAPTURE_ATTEMPTS` | Executable project input; see source for accepted values/defaults. | scripts/run-autonomous-trial-benchmark.command |
| `TFT_TRIAL_MEASUREMENT_ROUNDS` | Executable project input; see source for accepted values/defaults. | scripts/run-autonomous-trial-benchmark.command |
| `TFT_TRIAL_MEASUREMENT_WINDOW_SECONDS` | Executable project input; see source for accepted values/defaults. | scripts/run-autonomous-trial-benchmark.command |
| `TFT_TRIAL_NAVIGATION_TIMEOUT` | Executable project input; see source for accepted values/defaults. | scripts/run-autonomous-trial-benchmark.command |
| `TFT_TRIAL_TARGET_PHASE` | Executable project input; see source for accepted values/defaults. | scripts/run-autonomous-trial-benchmark.command |
| `TFT_TRIAL_UNKNOWN_TIMEOUT` | Executable project input; see source for accepted values/defaults. | scripts/run-autonomous-trial-benchmark.command |
| `TFT_UI_SCALE` | Executable project input; see source for accepted values/defaults. | run-tft-best-verified.command<br>run-tft-fast-quality.command |
| `TFT_UI_TRANSPORT_ROOT` | Executable project input; see source for accepted values/defaults. | scripts/summarize-android-ui-transport.command |
| `TFT_UNREAL_SOURCE_LIB` | Executable project input; see source for accepted values/defaults. | scripts/build-native-gles30-lib.command<br>scripts/build-native-gles31-lib.command |
| `TFT_VARIANT` | Executable project input; see source for accepted values/defaults. | scripts/capture-frame-pacing.command |
| `TFT_VIRTIO_GPU_NATIVE_SYNC` | Executable project input; see source for accepted values/defaults. | scripts/performance-candidates.json |
| `TFT_VIRTIO_GPU_NEXT` | Executable project input; see source for accepted values/defaults. | scripts/performance-candidates.json |

### 12.3 Build/tool inputs with explicit behavior

| Variable | Function |
| --- | --- |
| `TFTMAC_ANDROID_NDK_ROOT` | Android NDK root for native-clock build |
| `TFTMAC_BUILD_COMMIT` | Build commit identity supplied to direct-control build tooling |
| `TFTMAC_CAPTURE_ROOT` | Capture root override for summarization tooling |
| `TFTMAC_CLOCK_SIGN_IDENTITY` | Signing identity for native clock helper |
| `TFTMAC_CODE_SIGN_IDENTITY_NAME` | macOS code-sign identity for app/launcher builds |
| `TFTMAC_FORBIDDEN_TOKEN` | Verification-token override used by verification tooling |
| `TFTMAC_KEYCHAIN_SERVICE` | Keychain service selector for login helper |
| `TFTMAC_OPENSSL` | OpenSSL executable/path override |
| `TFTMAC_TEST_PYTHON` | Python interpreter override for native-clock tests |
| `TFTMAC_VULKAN_CAMPAIGN_DIR` | Resume/target directory for Vulkan campaign tooling |
| `TFTMAC_VULKAN_RECOVERY_CAPTURE` | Retained recovery capture supplied to Vulkan campaign tooling |
| `TFT_SCREEN_CLASSIFIER_DEBUG` | Screen-classifier debug output toggle |

### 12.4 Host input-bridge configuration

These are runtime-adjustable arguments accepted by `tools/tft-input-bridge.swift`. Coordinate fields are normalized `X,Y` values in the inclusive `0..1` range.

| Field | Accepted value / default | Function |
| --- | --- | --- |
| `--target-pid` | positive PID | Target TFTMAC host process |
| `--target-bundle-id` | bundle identifier; default empty | Alternate frontmost-app identity check |
| `--adb` | path | ADB executable |
| `--adb-port` | port | ADB server port |
| `--serial` | device/emulator serial | Target Android device |
| `--display-width` | positive integer | Guest display width used for normalized tap conversion |
| `--display-height` | positive integer | Guest display height used for normalized tap conversion |
| `--diagnostics` | `0` / `1` | Input diagnostics enable |
| `--diagnostics-log` | path; default empty | Input diagnostics destination |
| `--shop-point` | normalized X,Y; default `0.96,0.93` | Shop hotkey tap target |
| `--reroll-point` | normalized X,Y; default `0.955,0.79` | Reroll hotkey tap target |
| `--xp-point` | normalized X,Y; default `0.032,0.925` | Buy-XP hotkey tap target |
| `--traits-point` | normalized X,Y; default `0.029,0.04` | Traits-view tap target |
| `--items-point` | normalized X,Y; default `0.059,0.04` | Items-view tap target |
| `--damage-point` | normalized X,Y; default `0.947,0.04` | Damage-view tap target |
| `--players-point` | normalized X,Y; default `0.975,0.04` | Players-view tap target |

### 12.5 ANGLE driver-manifest builder options

These options create the boot-scoped ANGLE override manifest consumed through `TFTMAC_ANGLE_DRIVER_MANIFEST`.

| Field | Accepted value / shape | Function |
| --- | --- | --- |
| `--exchange` | directory path | Source exchange/build directory |
| `--variant` | `reference`, `reuse`, `capture`, `observed-reuse`, `observed-reuse-cache-r14` | ANGLE driver build/behavior variant |
| `--reuse` | boolean flag | Enable retained/reuse behavior where allowed |
| `--capture-frames` | integer `0..300` | Number of ANGLE capture frames; nonzero only for capture variant |
| `--output` | directory path | Generated driver-manifest/output directory |

## 13. Host presentation/window and legacy display controls

| Field | Known values / shape | Surface | Function |
| --- | --- | --- | --- |
| `TFTMAC_NATIVE_FULLSCREEN` | `0/1` | native wrapper environment | Fullscreen request |
| `TFTMAC_HOST_SCREEN_WIDTH` | `pixels` | native wrapper environment | Host screen width |
| `TFTMAC_HOST_SCREEN_HEIGHT` | `pixels` | native wrapper environment | Host screen height |
| `TFTMAC_HOST_BACKING_SCALE` | `scale` | native wrapper environment | macOS backing scale |
| `TFTMAC_NATIVE_CONTROL_WIDTH` | `points/pixels` | native wrapper environment | Control-bar width |
| `TFTMAC_NATIVE_TOPBAR_HEIGHT` | `points/pixels` | native wrapper environment | Top-bar height |
| `TFT_MACOS_GAME_MODE` | `0/1` | legacy executable launcher | macOS Game Mode request |
| `TFT_DISPLAY_SIZE` | `WxH` | legacy executable launcher | Guest/display resolution |
| `TFT_DISPLAY_DENSITY` | `DPI` | legacy executable launcher | Guest/display density |
| `TFT_UI_SCALE` | `1.0/1.25/1.5/1.75/2.0 in best-verified launcher` | legacy executable launcher | UI scale |
| `TFT_AUDIO_ENABLED` | `0/1` | legacy executable launcher | Emulator audio enable |
| `TFT_INPUT_BRIDGE_ENABLED` | `0/1` | legacy executable launcher | Host-to-guest input bridge enable |

## 14. Telemetry / measurement / benchmark input families

The raw environment map in §12 contains the exact variable names. The major tunable families are:

| Family | Mapped adjustable inputs |
| --- | --- |
| Frame pacing measurement | `TFT_MEASUREMENT_ROOT`, `TFT_MEASUREMENT_ROUNDS`, `TFT_MEASUREMENT_WINDOW_SECONDS`, `TFT_EXPECTED_STAGE`, `TFT_EXPECTED_PHASE`, `TFT_SCENE`, `TFT_VARIANT`, `TFT_PROFILE_PATH` |
| Input latency | `TFT_INPUT_LATENCY_ROOT`, `TFT_INPUT_LATENCY_ROUNDS`, `TFT_INPUT_LATENCY_WINDOW_SECONDS`, `TFT_INPUT_LATENCY_DRY_RUN`, `TFT_INPUT_LATENCY_VARIANT`, `TFT_INPUT_EVENT_DEVICE`, `TFT_INPUT_DIAGNOSTICS`, `TFT_INPUT_DIAGNOSTICS_LOG` |
| Autonomous trials | `TFT_AUTONOMOUS_TRIAL_ROOT`, `TFT_TRIAL_MAX_ATTEMPTS`, `TFT_TRIAL_MAX_CAPTURE_ATTEMPTS`, `TFT_TRIAL_MEASUREMENT_ROUNDS`, `TFT_TRIAL_MEASUREMENT_WINDOW_SECONDS`, `TFT_TRIAL_NAVIGATION_TIMEOUT`, `TFT_TRIAL_TARGET_PHASE`, `TFT_TRIAL_UNKNOWN_TIMEOUT` |
| 60 FPS campaign | `TFT_60FPS_CAMPAIGN_DIR`, `TFT_60FPS_COMBAT_HOLD_SECONDS`, `TFT_60FPS_MAX_CANDIDATES`, `TFT_60FPS_NAVIGATION_TIMEOUT` |
| PSO watcher | `TFT_PSO_CPU_LIST`, `TFT_PSO_WATCH_INTERVAL` |
| Perfetto / pipeline | `TFTMAC_ENABLE_AUTO_PERFETTO`, `TFTMAC_PIPELINE_EVENT_V1` |

## 15. Explicitly excluded from this field map

- SHA-256 values, Mach-O UUIDs, signing signatures and other integrity receipts: validation identity, not behavior settings.
- Session IDs, timestamps, PIDs, counters, FPS/jank/latency metrics and database result columns: derived telemetry, not controls.
- Riot username/password, tokens, account identifiers, cookies or any other credential material: secrets/data, not settings.
- `artifacts/tft-pbe-*` profile contents: historical/PBE-derived research is excluded as an active settings authority. Executable project control surfaces that can still carry a profile/path are mapped, but PBE profile values are not imported into the Riot 18.2 CVar catalog.
- Stale prose-only claims in `settings.md`: useful historical context but not used to manufacture active fields. The current source/config and current 18.2 boot evidence govern this inventory.
- Purely hard-coded/computed fields with no exposed adjustment surface (for example generated configuration hashes) are intentionally omitted.

## 16. Completeness receipt

- Riot 18.2 boot CVar set: **388 / 388 mapped**.
- Current DEV DeviceProfile override set: **78 / 78 mapped** within the Riot/Unreal tables.
- Advanced-diagnostics AVD `config.ini`: **145 / 145 fields mapped**.
- AVD stub `.ini`: **3 / 3 fields mapped**.
- Current native runtime profile, runtime routing, emulator launch/features, Android guest mutation surfaces, ANGLE/EGL, gfxstream/ASG, MoltenVK, UserDefaults, app environment, update/lab controls, and executable-script environment inputs are separately mapped above.

---

_Generated from the managed TFTMAC worktree and current Riot 18.2 DEV evidence on 2026-09-12. Re-run the discovery/audit before treating this map as exhaustive after a Riot client update, emulator/runtime update, or TFTMAC source/configuration change._
