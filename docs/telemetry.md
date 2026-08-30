# TFTMAC Telemetry and Diagnostics

TFTMAC diagnostics are local-first and evidence-driven.

## Native capture

Each native app start creates a private `0700` session directory under:

```text
~/Library/Application Support/TFTMAC/Captures/<session-id>/
```

`TFTMAC_NATIVE_RUNTIME.sqlite` is the queryable session authority. `native-events.jsonl`, emulator stdout/stderr and session-scoped `logcat.raw.txt` are local sidecars. Raw logcat is sensitive, never copied into SQLite, and must not be published.

Useful evidence may include:

- host monotonic timestamps;
- emulator/runtime state;
- one-second native frame-ingress interval windows and visual checkpoints;
- raw-gRPC source-window and Metal output-presentation rates, labeled separately and never called Unreal FPS;
- aggregate logcat fault counts with raw lines kept outside SQL;
- SurfaceFlinger render-rate and cumulative missed/HWC/GPU counters sampled at boundaries and every 30 seconds during gameplay;
- AudioFlinger active output, sample rate, stereo state, tracks and underruns;
- host CPU/RSS/memory-pressure samples;
- guest `/proc/meminfo` and host/guest monotonic clock calibration;
- renderer/graphics state;
- package version, installer, and signer evidence;
- explicit user stutter markers.

The Telemetry menu records `MATCH_ENTRY`, `COMBAT_START`, `VISIBLE_STUTTER` and `MATCH_END` on the host monotonic timeline. Use cumulative SurfaceFlinger counter deltas only inside those marked windows. `gfxinfo` is not Unreal/Vulkan frame authority. Perfetto remains a bounded on-demand diagnostic rather than an always-on observer.

## Retention

Keep only evidence that protects a current product decision:

- latest successful playable baseline;
- latest native-app acceptance capture;
- current package-authority evidence;
- current promoted A/B evidence;
- current unresolved crash/failure capture.

Superseded runs should be compacted to their session ID, configuration hash, verdict, key metrics, and relevant source hashes before raw bulk is removed.

## Privacy

Diagnostics must not intentionally capture or publish Google/Riot credentials, tokens, cookies, account identifiers, private Android userdata, or unrelated application data. Sanitize any excerpt before sharing it.

No remote telemetry service is required for the current TFTMAC runtime or acceptance path.
