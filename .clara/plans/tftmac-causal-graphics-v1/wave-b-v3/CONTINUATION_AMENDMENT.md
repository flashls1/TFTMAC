# Wave B v3 — Runtime-Mode Integration Continuation Amendment

Status: ACTIVE APPEND-ONLY AMENDMENT

This amendment supplements, and does not replace, the original TFTMAC Causal Graphics Optimization plan v1.1. The original plan remains at `.clara/plans/tftmac-causal-graphics-v1/IMPLEMENTATION_PLAN.md` with SHA-256 `78785b29815dba26a8da1d2ed56e0e9c256d3e7d9cfb4c4857b3c954846e8d2b`. The execution-scope lock remains unchanged at SHA-256 `dc77b6913d14409adc883dd27a67c42e982c40ab9149a68771b61dc99fae297e`.

## Current accepted authority

- Active managed change: `215ec5a3-6554-4ca3-95db-1525433bb20f`.
- Exact base/head before this amendment: `d96a1caf68b807bbae1a03246666da7eea4df620`.
- Accepted r9 diagnostic build manifest: `9556ffe5c9d083d3ba90006628b8fc5a94a6989f56fa21d40bb9a30f2f99ef8d`.
- Accepted stopped-clone receipt: `09e4b2d21290de582320cb0aee3148af25f5e2e59199e225e604afbb6cb19648`.
- Accepted native diagnostic host receipt: `a72d10106acb83444a38027ed3978b6ef3bc60e7ec0ae0ba9439f67eb57f6067`.
- Stock Build 8 remains the protected and default control runtime.

## New finding and adjudication

An unaccepted local draft marked `advanced_diagnostics` launch-ready on controller port 8556 without a durable controller-port allocation receipt. That draft is rejected, preserved under `.clara/plans/tftmac-causal-graphics-v1/protected-local-work/unaccepted-waveb-draft-before-v3`, and must not become launch authority. The accepted registry is restored before product-source work.

Five stale Clara watchers were observing operation IDs that never existed. They are observation noise only: they authorize no replay and do not prove any emulator, TFT, clone, build, or validation effect.

## Effective Wave B implementation scope

1. Preserve the rejected draft and restore the accepted fail-closed registry.
2. Add a typed three-mode registry contract for exactly `control`, `advanced_diagnostics`, and `candidate`.
3. Keep `control` as the only launch-ready default and preserve its existing Build 8 runtime, AVD, ports, serial, package path, state behavior, and /usr/bin/open app-host chain.
4. Give each mode an explicit runtime root, AVD identity, ADB/console/controller identity, state namespace, and lease identity. A single global exclusivity lease remains the collision guard and records the exact selected mode identity.
5. Keep `advanced_diagnostics` blocked until a separately receipted controller port is written through a later append-only gate. Its sealed build, stopped-clone, and native-host receipts must be structurally and cryptographically validated before it can become launch-ready.
6. Keep `candidate` blocked until an accepted ROOT_NAMED-derived, stock-compatible candidate exists.
7. Remove control-only hard-coded ADB, AVD, serial, console, and controller identities from shared runtime operations; resolve those values from the selected definition.
8. Verify selected binary hashes before launch and verify loaded emulator/gfxstream image identity before TFT starts.
9. This source-only wave performs no emulator launch, TFT launch, AVD mutation, runtime replacement, application install, or control shutdown.
10. Run one decisive changed-head production verifier after implementation. Do not rerun the already-accepted unchanged 43-test baseline separately.

## Wave B v3 acceptance

PASS requires: exact three-mode decoding; default control behavior; diagnostics and candidate fail-closed behavior; registry and external-receipt tamper rejection; mode-aware lease persistence; mode-derived runtime commands; unsigned Release build; all native tests; unchanged visible Git state after validation; and a review proving no runtime process was launched.

After PASS, the next causal stage is a separate controller-port allocation receipt and guarded diagnostic first-boot gate. No later graphics instrumentation, candidate promotion, or production cutover is authorized by this amendment.
