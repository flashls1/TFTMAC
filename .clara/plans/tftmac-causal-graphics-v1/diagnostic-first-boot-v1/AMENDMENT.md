# Diagnostic First Boot v1 — R9 Native Forwarder and Port Authority

Status: ACTIVE APPEND-ONLY GATE

This gate follows verified Wave B v4 commit `a84aaa7` and preserves the original implementation plan and scope lock. It exists because the previously receipted Swift diagnostic host is hardcoded to the older `TFTMAC_Diagnostic_API37` AVD, ADB port `5042`, and a no-controller/no-window first-load harness. It cannot launch the accepted R9 AVD or provide TFTMAC's native controller display and therefore must not govern R9 acceptance.

## Authorized change

1. Preserve the old diagnostic host and every accepted r9 build/clone receipt.
2. Allocate diagnostic ADB `5041`, console `5586`, and controller `8556` only after listener and exclusive-bind checks pass with stock control stopped.
3. Build a new external diagnostic forwarder from the proven `RuntimeHost/main.c` launch chain with a diagnostic-only plist and ad-hoc local signature. Write a new immutable build receipt and sidecar; do not overwrite the old host or receipt.
4. Update `advanced_diagnostics` to the new forwarder/receipt and enable it with controller port `8556`. Keep `control` the default and unchanged. Keep `candidate` blocked.
5. Permit the existing main TFTMAC runtime controller to use the receipted `external_native_host` forwarder. Do not introduce another emulator spawn path.
6. Update the pinned registry identity and tests. The source verifier must build unsigned Release and pass all 49 native tests before any boot.
7. First boot must fail before TFT launch unless the loaded QEMU path/hash/UUID, command-line AVD/ports, and mapped gfxstream path/hash/UUID match the accepted R9 authority.

## Exclusions

- No modification of the stock control runtime or control AVD.
- No reuse of the stale diagnostic host as R9 authority.
- No candidate runtime, Wave C instrumentation, Riot credential handling, or APK modification.
- No final application install, distribution signing, or default-mode change.

## Exit condition

The port and forwarder receipts are sealed, `advanced_diagnostics` is selectable only with the explicit environment variable, source verification passes, and guarded first boot proves the accepted R9 loaded identities. Manual PIN/Riot/gameplay acceptance remains a user-operated continuation after the identity gate.
