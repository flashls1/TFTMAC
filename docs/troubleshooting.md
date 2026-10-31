# TFTMAC Troubleshooting

Use TFTMAC's verified runtime controls and diagnostics before changing protected AVD/runtime state manually.

## Native build fails

Run:

```sh
/bin/zsh scripts/verify-tftmac.command
```

Repair only the reported source, dependency, protocol, or test failure. Do not recreate the retired source-built emulator laboratory as a generic repair step.

## Stock emulator does not start

Verify that `/Volumes/MAC MINI M4/TFTMAC/Runtime` is mounted and that its SDK and AVD are intact. Do not silently create a replacement runtime on the internal disk.

## Google Play or TFT requires authentication

Complete sign-in, MFA, consent, or CAPTCHA through the official Android/Google/Riot UI. Do not automate around those gates.

## TFT package is missing or stale

Use the official Google Play path. Confirm the package is `com.riotgames.league.teamfighttactics` and the installer is `com.android.vending`. Do not use third-party APK mirrors, repackaging, re-signing, or binary patching.

## Performance is poor

Use the existing raw-first capture tooling. Compare one variable at a time against the promoted 18.3 baseline (`1920×1080` guest / 416 dpi / 60 Hz / 8 vCPU / 6144 MiB / host GPU / OpenGL ES through ANGLE) and cold-confirm any improvement before keeping it. The in-game quality preset, FPS cap, and Performance Mode remain `NOT_RECORDED_POST_CLEANUP`; do not treat older M4 or pre-18.3 observations as current. The strict 60-FPS/severe-stall contract remains unresolved.

## Safe diagnostics

Prefer bounded process/runtime state, SurfaceFlinger metrics, filtered logs, package metadata, and purpose-built captures. Never share complete game logs, AVD images, credentials, tokens, Keychain output, cookies, or unfiltered crash memory.
