# TFTMAC Changelog — Current 18.3 Ledger

## 2026-10-02 — 1080p playability promotion

- Three matched 1920×1080 full-Trial captures at 8 vCPU/6144 MiB measured a
  median 59.03 workload FPS, versus approximately 47.4 at 2560×1440.
- The DEV launcher now defaults to 1920×1080 at density 416; an explicit
  `TFTMAC_DEV_DISPLAY=2560x1440` override preserves rollback/control.
- The strict continuous-60-FPS contract and present-lineage ownership remain
  unresolved. vCPU10, RAM, renderer, and graphics-CVar changes remain gated.

## 2026-09-27 — Current-authority refresh

- Reconciled active TFTDEV authority to the verified 18.3 route: TFT `18.3-5530794` / code `8530794`, Google Play installer, StockShadow DEV route, promoted 1920×1080 output at density 416, 8 vCPU, 6144 MiB, host GPU/CoreAudio. Physical displays remain 2560×1440.
- Confirmed the receipt records launch/playability, input, presentation, audio, and logger evidence. It does not claim a complete-match benchmark or a performance win.
- Removed lower-version identities and stale current-state language from active authority views. Preserved prior source documents and imported settings in explicitly labeled `pre-18.3` archives.
- No application, launcher, emulator profile, graphics setting, or gameplay behavior was changed by this documentation refresh.

## Current decision

The next experiment is blocked until one real 18.3 game is captured with the comprehensive logger. Use that matched capture as the baseline for any single reversible setting change.

## Historical ledger

The detailed pre-18.3 test ledger is preserved at `authority/archive/pre-18.3/ssot-CHANGELOG.md` and `authority/archive/pre-18.3/source-worktree/CHANGELOG.md`. Those records are historical provenance only and cannot override the current 18.3 authority.
