# TFTMAC Telemetry and Diagnostics

TFTMAC diagnostics are local-first and evidence-driven.

## Raw-first capture

High-rate frame/runtime evidence is written append-only during capture. Normalization into SQLite or other derived analysis happens after capture so database writes do not perturb the measured workload.

Useful evidence may include:

- host monotonic timestamps;
- emulator/runtime state;
- filtered logcat/emulator output;
- SurfaceFlinger frame timing;
- host CPU/RSS/memory-pressure samples;
- renderer/graphics state;
- package version, installer, and signer evidence;
- explicit user stutter markers.

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
