# Amendment 001 — post-close evidence recovery route

Date: 2026-09-11 America/Chicago
Change: `b42fb30e-2f22-45f0-9d27-00d9e67a58bf`
Supersedes only the PRE/PLAN assumption that ignored OvernightLab generated evidence still exists in the closed `ff2f318b...` worktree and can be copied from there. All other scope, safety, and results-first constraints remain in force.

## New direct evidence

1. PR #9 merge closed change `ff2f318b-245d-418a-b86f-e07d55b19826`; its worktree is now absent.
2. Bounded searches found no old `overnight-20260910T160337Z-501dd433` directory, `TFTMAC_OVERNIGHT.sqlite`, or `active-campaign.txt` in remaining TFTMAC worktrees, `/Volumes/MAC MINI M4/TFTMAC`, user Trash, Clara durable areas searched, Spotlight results, or local Time Machine snapshots.
3. `tmutil listlocalsnapshots` reports no local snapshots for `/Volumes/MAC MINI M4` or `/`.
4. The authoritative DEV native capture root is `~/Library/Application Support/TFTMAC/Modes/advanced_diagnostics/Captures`, not the generic historical `~/Library/Application Support/TFTMAC/Captures` path used by an earlier bounded check.
5. Twelve Sept. 10 advanced-diagnostics capture directories remain in that native capture root for the relevant campaign window, each with `TFTMAC_NATIVE_RUNTIME.sqlite`. The final saved-run launch maps to capture `2026-09-10T22-43-10.664Z-a5718134-6211-4bcb-8bd6-c17b134e8a6f`, whose native DB remains present at 7,368,704 bytes. A later retained capture `2026-09-10T19-45-09.532Z-9d9d31f1-4359-4b57-bd0b-4ed818d72db8` remains present with a 20,217,856-byte native DB.

## Classification

This is a **BLOCKING DEPENDENCY for the original copy-from-closed-worktree preservation step**, not a reason to stop the project and not a reason to rerun resolved performance candidates. The derived OvernightLab campaign DB/screenshots/reports that lived only as ignored worktree files cannot be truthfully claimed recovered from current local storage. However, the authoritative native session telemetry survives externally, and merged source plus current record books preserve the verified decisions/winner.

## Revised execution contract

1. Keep the minimal wrapper/source repair already defined.
2. Install the small merged OvernightLab source/config/classifier helper into `/Volumes/MAC MINI M4/TFTMAC/OvernightLab` without touching Control/LKG/DEV runtime binaries.
3. Do **not** create a fake replacement for the lost old `TFTMAC_OVERNIGHT.sqlite`, campaign screenshots, or result files. Record their absence explicitly.
4. Inventory and seal the surviving relevant native capture directories/SQLite identities needed for continuity. These remain the primary raw performance evidence.
5. Initialize a fresh OvernightLab database only through normal current controller startup/self-test behavior; historical verified decisions remain sourced from `CHANGELOG.md`/`project.md` and surviving native captures, not synthesized rows.
6. Update `project.md` and `CHANGELOG.md` with the continuity fact: PR #9 merged; derived ignored worktree layer was removed with closed-worktree cleanup and has no local snapshot recovery route; authoritative native captures remain available and are the recovery evidence source.
7. Run installed `verify-static`, `self-test`, and `fault-test`. No gameplay/performance candidate is run in this continuity repair.
8. Preserve the current automatic queue as `control` only. Do not automatically resume the stale historical campaign identity, because its campaign DB/checkpoint no longer exists at the live layer.
9. Source validation/review/CI/merge and local live-install verification remain required.

## Acceptance adjustment

The old requirement "stale old campaign is reconciled in its original OvernightLab DB" is superseded because that DB is no longer locally recoverable. Replacement acceptance is: the loss is truthfully documented; surviving native captures are proven present; the new live OvernightLab starts from current authority without inventing historical rows; and no resolved candidate is replayed merely to reconstruct deleted derived telemetry.
