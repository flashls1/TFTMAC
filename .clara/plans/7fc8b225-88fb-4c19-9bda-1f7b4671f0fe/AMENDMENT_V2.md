# Amendment V2 — make one-CVar overlay visible to the measured TFT process

## Blocking dependency
Fresh matched controls are valid and reach stage 1-5 on `DEV-B8-WIN-01`, but all three candidate runs fail `CVAR_NOT_EFFECTIVE`: the candidate profile hash is installed in the ADB/root namespace, while Unreal's fresh engine log still does not prove the requested candidate value. The candidate is therefore not admissible and no performance conclusion may be taken.

The existing candidate path unmounts the native LKG profile target and creates a new bind mount after zygote already owns the verified LKG bind mount. That remount is not proven in zygote's mount namespace, so a new TFT process can continue to inherit the original LKG profile even though ADB sees the candidate target hash.

## Smallest correct repair
Do not redesign the app/runtime and do not mutate protected Control/LKG. Keep the already-verified native LKG bind mount topology intact. While TFT is force-stopped and ADB is root:

1. Verify the canonical native HighPerf stage file and target both equal the current winner profile hash and record the stage inode/metadata/context.
2. Push the candidate and a baseline copy to a run-scoped `/data/local/tmp/tftmac-incremental-*` staging directory.
3. Overwrite the canonical native HighPerf stage file **in place** (truncate/write the same inode; never rename, unlink, unmount, or create another bind mount).
4. Prove the stage inode, metadata, and context are unchanged; prove stage + target hash equal the candidate; prove every numeric `zygote64` mount namespace sees the candidate target hash.
5. Return ADB to shell and launch the official `GameActivity`. Require the fresh Unreal engine log to prove the exact candidate CVar before any measurement.
6. Before DEV quit/cleanup, force-stop TFT, root ADB, overwrite the same stage inode back to the run-scoped baseline bytes, and prove stage + target + every zygote namespace equal the current winner hash. Then unroot and allow normal native rollback/quit.
7. Any failure after candidate bytes are written invokes the same baseline restoration path. If baseline restoration cannot be proven, stop the queue immediately.

## Acceptance
- Candidate mechanism is valid only when engine log proves the exact changed CVar and native 1-5 windows exist.
- Matched control/candidate testing then resumes in the existing order.
- A setting is retained only after the existing confirmation pair also reports PROMISING/HOME_RUN.
- Neutral/regression/inconclusive restores the current winner immediately.
- `DEV-B8-WIN-01` remains the current winner unless repeatable evidence promotes a successor.

## ZenGate V2
PASS subject to ZenMC V2. This is narrower than a per-zygote mount redesign: it reuses the canonical native stage inode already bound into zygote, changes only its bytes while TFT is stopped, and preserves all existing rollback/integrity boundaries. New candidate families, app/runtime copies, AVD changes, and Control/LKG mutation remain out of scope.
