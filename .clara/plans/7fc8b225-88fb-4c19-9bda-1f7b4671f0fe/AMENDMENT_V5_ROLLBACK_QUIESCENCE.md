# Amendment V5 — bounded rollback transport-quiescence verification

## Trigger

V4 shader retest campaign `incremental-20260911T210746Z-64c4f370` failed closed after an AUTH_BLOCKED candidate because cleanup reported `fallback_emulator_stop=true`, `emulator_stopped=false`, and `rollback.verified=false`. Immediate post-failure evidence proved QEMU=NONE, DEV=NONE, ADB transport absent, installed DEV integrity PASS, frozen LKG integrity PASS, and codesign PASS. The false rollback failure is therefore a bounded observation race: `wait_cleanup()` checks ADB `get-state` immediately after the fallback emulator stop, while ADB may retain the just-dead emulator transport briefly after QEMU exits.

## Minimal repair

After fallback/native emulator shutdown and AVD recovery, wait for at most 10 seconds for **both** conditions to be true at the same observation:

1. `owned_emulator_pids()` is empty; and
2. `adb get-state` does not return success/device.

Then compute `emulator_stopped` from that final observation exactly as before.

## Fail-closed rules

- Do not relaunch or mutate the emulator during this verification wait.
- Do not infer success merely from time passage.
- If QEMU is present or ADB still reports the DEV serial as live at the deadline, rollback remains unverified and the campaign must stop.
- Existing profile restore, AVD restore, DEV stop, installed-app integrity, frozen-LKG integrity, and codesign/static gates remain mandatory and unchanged.
- No Control/LKG mutation is authorized.

## Resume rule

The failed shader retest remains `INCONCLUSIVE / AUTH_BLOCKED`; it is not performance evidence. After this repair passes source/live validation and a cleanup canary, a fresh one-candidate shader retest may be run from unchanged `DEV-B8-WIN-01`. Do not rewrite the failed run's recorded rollback bit.
