# TFTMAC GPU Runtime v2.0 — Phase 0 Preflight Report

Generated: 2026-08-27T11:41:28.060Z

Status: **BLOCKED**

## Blockers

- Host preflight is not green (frozen Xcode 26.6 / 17F113 required).
- Canonical authority documents are missing or hash-mismatched.
- Android API 37 package freeze is incomplete.
- Vulkan SDK 1.4.357.0 validation is incomplete.
- Resolved emu-master-dev manifest is not frozen.
- Locked-source GuestAngle authority proof is not green.
- Exact Vulkan CTS required-case list is not frozen.
- STACK.lock.yaml has 21 unresolved critical field(s): frozen_at, host.xcode_version, host.xcode_build, host.macos_sdk_path, android_command_line_tools.installed_revision, android.play_image_revision, android.platform_tools_revision, android.emulator_revision, android.platform_revision, android.build_tools_revision, aemu.resolved_manifest_sha256, aemu.qemu_commit, aemu.aemu_commit, aemu.gfxstream_commit, aemu.integrated_angle_commit, aemu.integrated_moltenvk_commit, aemu.guestangle_authority, vulkan_sdk.vulkaninfo_version, moltenvk.reference_commit, generality.gles_cts_commit, generality.vulkan_required_cases_sha256

## Artifact inventory

| Artifact | State | SHA-256 |
|---|---|---|
| `ssot/AUTHORITY_INPUTS.sha256` | PRESENT | 0aaaaad5d75ce0582daf3d11ffa8cc3e5713abc7e9396b9f5676b7d55635589b |
| `ssot/STACK.lock.yaml` | PRESENT | 90b1f1dbeb6d4b4efbe9151710eec3e73a3512d3439858575a0142fd1ede5fd2 |
| `ssot/host-preflight.json` | PRESENT | 39ae5c8421252daba5a7494b97c01aec4909d65a4283238022f6a36a4da82344 |
| `ssot/xcode-discovery.json` | PRESENT | a49f7bc7421aed40f62ed14d22d6ff235a67e12a7bf3aee21024bf943bd4b931 |
| `ssot/android-license-status.json` | PRESENT | 3a80c4cee1b7f11d8428622ec98805fff7fa54805eb8843fdc595af48a0a90a9 |
| `ssot/android-sdk-packages.txt` | MISSING | — |
| `ssot/vulkaninfo-summary.txt` | MISSING | — |
| `ssot/upstreams-aemu.lock.xml` | MISSING | — |
| `ssot/phase0-source.json` | MISSING | — |
| `ssot/source-hashes.txt` | MISSING | — |
| `ssot/guestangle-authority.json` | MISSING | — |
| `ssot/vulkan-required-cases.spec.json` | PRESENT | ee085639d3f479fd3d1fe11c29762ef45807120645a37e55818c412c68d7942d |
| `ssot/vulkan-required-cases.txt` | MISSING | — |
| `ssot/phase0-policy.json` | PRESENT | 946edceae70e6298f6b62cfd93d9ac8074783adbbb9e78cc1f1db9626c5e862b |

Phase 0 may be declared complete only when this report is PASS and `STACK.lock.yaml` contains no unresolved critical-path null.
