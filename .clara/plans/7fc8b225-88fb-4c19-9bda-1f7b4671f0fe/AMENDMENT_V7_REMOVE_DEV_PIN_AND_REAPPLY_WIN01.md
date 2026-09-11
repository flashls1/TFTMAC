# Amendment V7 — remove DEV Android PIN credential and re-establish WIN-01 on Riot 18.2

## User scope change

Flash explicitly rejects an Android PIN/screen-lock requirement for TFTMAC DEV. DEV is an isolated emulator, not a physical tablet, and the splash-screen product path must never strand startup behind an invisible Android credential. Flash also requires the already-verified performance winner to remain applied after the Riot client update.

## Current evidence

- Production TFT is now Google Play-owned `com.riotgames.league.teamfighttactics` `18.2-5450971` / `8450971`; PBE is excluded.
- The DEV Android unlock Keychain item currently exists under `com.flashls1.tftmac.dev.android-unlock.v1`; protected Control has a separate `com.flashls1.tftmac.android-unlock.v2` item.
- DEV source deliberately passes no unlock secret, yet `TFTMACRuntime.swift` still requires `RUNNING_UNLOCKED` and throws `DEV Android still has a screen lock...` when the emulator has a credential. This is the direct startup defect.
- Exact source and installed `DeviceProfiles.ini` both equal WIN-01 SHA `45d6465040ef8b7298cd8da000208e4ee0be924c65a20326900267f25adf5c9c`; source/installed profile transaction are also byte-identical.
- Verified WIN-01 cache policy remains `debug.egl.blobcache.multifile=true`, ANGLE enabled `exposeNonConformant*:exposeES32ForTesting`, ANGLE disabled `preferSubmitAtFBOBoundary`, with `syncMonolithicPipelinesToBlobCache` absent.
- Verified non-winning candidate values are not integrated: PSO pool remains `4`, shader background batch remains `20`, animation budget remains `6.0`.

## Minimal implementation

1. **DEV-only one-time credential retirement.** Reuse the already-existing DEV Keychain PIN only as migration material; never prompt for a new DEV PIN and never expose the value in logs or host process arguments. If the guest is credential-locked, use the existing secure-input path to unlock user 0, then clear the Android lock credential through an ADB shell stdin channel. Verify command success and `RUNNING_UNLOCKED`.
2. Delete only the DEV Keychain item after the Android credential is cleared. Never read, modify, delete, or migrate Control's Keychain service.
3. On all later DEV launches, no PIN or Keychain item is required. DEV startup requires user 0 to become `RUNNING_UNLOCKED` naturally because no credential exists. An unexpected future credential is a repair fault, not a prompt/setup requirement.
4. Retire DEV-only setup/campaign gates that require `com.flashls1.tftmac.dev.android-unlock.v1`; preserve protected Control unlock code and Control launcher unchanged.
5. Preserve the current WIN-01 DeviceProfiles bytes and all accepted effective runtime values. Do **not** integrate rejected PSO=2 or animation-budget=5.0, and do not silently promote unresolved shader-batch=4.
6. Rebuild/install **TFTMAC DEV only**. Protected `/Applications/TFTMAC.app` and frozen LKG are immutable.
7. First migration boot may use the old DEV secret exactly once. Then cleanly stop DEV and perform a second cold boot after deleting the DEV Keychain item. Acceptance requires the second boot to reach `RUNNING_UNLOCKED`, Google-Play-owned TFT 18.2, HighPerf/WIN-01 readiness, OpenGL ES through ANGLE, and `TFT_READY_FOR_USER` with no PIN/keychain dependency.
8. Re-run current Riot post-update audit after the playable boot and preserve the pre/post client diff. This client transition is not a new performance winner by itself.

## Performance restoration acceptance

The Riot patch does not reset TFTMAC's verified winner. Runtime acceptance must prove the same WIN-01 stack is effective on 18.2:

- 1920x1080 / 320 DPI / 60 Hz;
- effective 8 vCPU / 6144 MiB;
- exact WIN-01 DeviceProfiles SHA `45d6465040ef8b7298cd8da000208e4ee0be924c65a20326900267f25adf5c9c`;
- `debug.egl.blobcache.multifile=true`;
- ANGLE enabled `exposeNonConformant*:exposeES32ForTesting`;
- ANGLE disabled `preferSubmitAtFBOBoundary`;
- no `syncMonolithicPipelinesToBlobCache`;
- `r.pso.PrecompileThreadPoolSize=4`;
- `r.ShaderPipelineCache.BackgroundBatchSize=20`;
- `a.Budget.BudgetMs=6.0`;
- selected game RHI `OPENGL_ES_ANGLE`.

If Riot 18.2 rejects or changes a profile/CVar, fail closed and record client-update drift; do not substitute an unverified optimization.

## Completion

V7 is complete only when DEV has no Android PIN credential, no DEV unlock Keychain requirement remains, a cold boot without any DEV PIN reaches playable TFT 18.2 with exact WIN-01 enhancements, Control/LKG are unchanged, update-audit evidence is preserved, source validation passes, and the selected managed change is durably checkpointed.