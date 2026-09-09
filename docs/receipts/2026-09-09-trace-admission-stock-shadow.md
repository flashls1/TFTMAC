# Trace admission receipt: current stock-shadow runtime

**Observed:** 2026-09-09 (local Mac, America/Chicago)

## Decision-critical test

The changed mechanism is opt-in propagation of `TFTMAC_PIPELINE_EVENT_V1=1`
into the emulator-host child, with a private per-capture event directory. The
test launched the rebuilt DEV app in `advanced_diagnostics` with silent mode and
the recorder enabled, then stopped the owned emulator and inspected the sealed
capture.

## Evidence

- Build: `/bin/zsh scripts/build-dev-launcher.command` passed.
- Capture: `2026-09-09T03-04-55.694Z-ef5d84df-4698-41e4-a5e1-b8a8435875f7`
- Event: `CAUSAL_PIPELINE_RECORDER_ENABLED` recorded the private directory and
  schema 1.
- Runtime identity: stock-shadow `libgfxstream_backend.dylib` SHA-256
  `3772fef215058831ea419c9281fd203d010003d5defdc195dd120bc7748e4093`.
- Native capture sealed enough to inspect and reached first native frame.
- `pipeline-events/` existed with mode `0700` but contained zero segment files.
- SQLite `pipeline_events` count was `0`.
- No `TFTPIPE1` or causal recorder signature appeared in the stock-shadow
  emulator output.

## Result

`INCONCLUSIVE_FOR_TFT_CAUSALITY`: the app-to-host plumbing is exercised, but the
current stock-shadow driver does not emit the source-instrumented event stream.
This does not identify a TFT late-frame owner and cannot support an optimization
claim. The existing instrumented external runtime remains a separate diagnostic
artifact; selecting it requires its own isolated runtime identity and parity
gate. No Control files or credentials were changed.
