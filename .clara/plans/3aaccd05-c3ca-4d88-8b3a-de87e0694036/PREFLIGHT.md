# TFTMAC DEV HighPerf + 6GB Preflight

**Request class:** IMPLEMENT  
**Managed change:** `3aaccd05-c3ca-4d88-8b3a-de87e0694036`  
**Base:** `74c74c48e75db9dc04e105d8e6f2574002fb787d`  
**Scope:** isolated `advanced_diagnostics` / TFTMAC DEV only.

## Verified current evidence

- Protected Control is `/Applications/TFTMAC.app`, mode `control`, AVD `TFT_Ultra_Tablet`, ports 5038/5582/8554. It must not be mutated or launched as part of this experiment.
- Isolated DEV is `/Applications/TFTMAC DEV.app`, mode `advanced_diagnostics`, AVD `TFTMAC_Diagnostic_StockShadow_R1`, ports 5041/5586/8556.
- The audited TFT boot selected `OthersPerfSelection=true`, `LowQualitySelection=true`, and the fragment string `Android_LowPerf_Fragment,Android_LowPerf_Frontend_Fragment,Android_6GB_Fragment,Android_GL_Base_Fragment,Android_GL_Others_Fragment`.
- The same boot applied the LowPerf values including `tft.DefaultFrameRateLimit=30`, `sg.ResolutionQuality=75`, `r.Streaming.PoolSize=300`, `r.Streaming.PoolSizeForMeshes=25`, Low audio tier, `r.OpenGL.ProgramLRUEvictTimeSeconds=20`, and `Android.OpenGL.NumRemoteProgramCompileServices=0`.
- Current native source already attempts broad `[Android_MatchedFragments]` / `[Android_LowPerf_Fragment]` CVar overrides, but writes `DeviceProfiles.ini` to `.../TFT/TFT/Saved/Config/Android`; the captured boot proves those desired overrides did not become the final effective values.
- Historical project evidence records that an ordinary copied `DeviceProfiles.ini` was not durable and the old launcher later used a verified transactional mount.
- Current guest memory authority remains approximately 5.1 GiB total with useful headroom; increasing guest RAM to 8 GiB caused host compression/swap. The 6GB memory fragment must remain selected.
- Epic documents `-DPFragments=...` as the supported command-line override for selected Device Profile fragments, and Android UE command-line files are read at launch.

## Experiment hypothesis

The Apple/ANGLE renderer identity falls through TFT's compiled mobile matching rules to the generic LowPerf tier. The smallest clean experiment is to leave the real Android guest and 6GB memory class intact while explicitly selecting TFT's own high-performance Android fragments at Unreal startup.

## Scope lock

1. DEV / `advanced_diagnostics` only.
2. No APK repack, re-sign, Riot binary modification, process injection, or Control mutation.
3. Prefer `-DPFragments` over individual CVar overrides for the first test.
4. Preserve `Android_6GB_Fragment` and the current GL base/other fragments.
5. Do not introduce rejected historical knobs (MSAA2, audio-off, half-rate skeletal animation, blind PSO prewarm, lower resolution).
6. Boot validation precedes combat validation.

## Acceptance gate

PASS only if an isolated DEV boot provides direct Unreal log evidence that:

- `Android_HighPerf_Fragment` is included;
- `Android_HighPerf_Frontend_Fragment` is included if it exists in this TFT build;
- `Android_6GB_Fragment`, `Android_GL_Base_Fragment`, and `Android_GL_Others_Fragment` remain included;
- `Android_LowPerf_Fragment` and `Android_LowPerf_Frontend_Fragment` are not the effective selected fragments;
- key final values no longer reflect the audited LowPerf policy (especially frame-rate policy, resolution quality, streaming pools, compiler-service policy, and audio tier);
- official TFT reaches its normal visible surface without correctness regression;
- protected Control executable/host identities remain unchanged.

If the exact HighPerf frontend fragment name is not recognized, change strategy rather than blindly relaunching: retain the proven HighPerf fragment and derive the valid frontend fragment from boot/package evidence.
