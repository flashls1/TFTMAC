# Shutdown finalization test receipt

Date: 2026-09-08
Status: **LIFECYCLE_PASS; UI-LATENCY IMPROVEMENT NOT YET QUANTIFIED**

The cleanup path was changed so `ANGLEViewEvidence.normalize` runs in a
utility detached task instead of synchronously on `TFTMACRuntimeService`. The
candidate was then launched with the same ANGLE manifest and automatic capture,
reached `TFT_READY_FOR_USER`, and was quit cleanly.

- Capture: `2026-09-08T17-41-36.882Z-de838fff-4efc-4fb8-9f58-073af65da4ab`
- SQLite SHA-256: `5b843deb13c6a64784d48bfbfcb4a36f8187d3f3994ab3fcc0e53c2f609e9fba`.
- ANGLE evidence SHA-256: `12609b7568e9d7d829b3bb3b4499aea180d8e63e2cca6192bf3253d55df6fe84`.
- Session: `STOPPED`, `2026-09-08T17:41:36Z` to `2026-09-08T17:42:52Z`.
- `ANGLE_DRIVER_LOADED_VERIFIED` and `TFT_READY_FOR_USER` were recorded.
- The clean quit command returned in 17.36 seconds and the session sealed in
  17.39 seconds. Trace capture/drain consumed approximately 16 seconds of
  that interval; the short run did not contain the 299,000-event workload that
  exposed the previous 23-second normalization gap.
- `EMULATOR_EXIT_CONFIRMED`, `AVD_CONFIG_RESTORED`, and
  `ANGLE_EVIDENCE_FINALIZED` all completed at 17:42:52Z. No raw artifact was
  lost and the session remained `STOPPED`.

This proves the detached finalization change compiles and preserves the
shutdown lifecycle. It does not yet prove a lower user-visible quit latency,
because the trace-drain wait remains in the same stop sequence. A separate
responsiveness test must isolate or defer that drain before claiming the
freeze is eliminated.
