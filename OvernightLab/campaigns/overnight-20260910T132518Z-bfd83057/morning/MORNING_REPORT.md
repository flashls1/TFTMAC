# TFTMAC Overnight Report — overnight-20260910T132518Z-bfd83057

- Official package authority: `com.riotgames.league.teamfighttactics` `18.1-5423749`
- LKG integrity: PASS
- PBE evidence admitted: NO

## Runs

- `control` / `run-4dfaa589bcb147a9a0bdcd5ba6ab682d`: **HARD_REJECT**, rollback=FAIL, RHI=UNKNOWN, windows=0, meanFPS=None, meanP95ms=None
- `control` / `run-d9ea3854337e4f178372317788f10cce`: **None**, rollback=FAIL, RHI=UNKNOWN, windows=0, meanFPS=None, meanP95ms=None
- `control` / `run-e2dca4693be44de6ab04e33829a1cde4`: **HARD_REJECT**, rollback=PASS, RHI=UNKNOWN, windows=0, meanFPS=None, meanP95ms=None

## Decision boundaries

Cache existence/storage is not described as compile-time or FPS savings without a matched current-client comparison.
RHI sample percentages are not converted into removable frame milliseconds.
Any required producer whose coverage is not COMPLETE makes the dependent claim INCONCLUSIVE.
Historical/PBE evidence is not admissible for current-client promotion.
