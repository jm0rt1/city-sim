# PLAY-015 completion

- **Title:** Make the Town Charter an unmistakable session victory
- **Lane:** Gameplay loop
- **Branch:** `codex/citysim-gameplay-loop`
- **Published authority:** `ab722bd1ea7c8c132525362bc94bc12d154a78f5`
- **Authority merge:** `bb0ca473625cf95e18cc8a3ebf81039572fdb4ad`
- **Ordered task commits:**
  1. `0e3e68e5cac31d9f4b340eba18a6aa6bf8608232` — same-boundary Charter victory, legacy normalization, terminal compatibility, and focused regression coverage;
  2. `1be10212fcbc7bc1083a9af9338b660807af2bc5` — deterministic, build, staged Commercial, and staged Industrial evidence.
- **Status:** Ready for platform adoption, UI companion acceptance, and integration review

## Player-visible outcome

The Town Charter now ends the mandate immediately through the existing
victory state. The award, final objective completion, and terminal transition
share one governed daily boundary; the city cannot continue simulating behind
the victory overlay.

Existing awarded-playing legacy saves remain untouched on decode and load,
then normalize once at their next daily boundary without duplicating the
Charter award or its message.

## Files changed

- `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulation.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/GameplayLoopTests.swift`
- `docs/production/evidence/PLAY-015/IMPLEMENTATION-CHECKPOINT.md`
- `docs/production/completed/PLAY-015.gameplay-loop.md`

## Validation and proof

- Focused gameplay suite: **31/31 passed**.
- All four recovery identities enter `.won` at exact tick **844**.
- Legacy awarded-playing JSON remains playing through ticks 1-3 and
  normalizes at tick 4 with no duplicate message.
- Terminal victory remains wholly immutable through the tick-2,800 horizon.
- Loss, reset, one-time award, Undo, legacy missing-field, and recovery timing
  checks pass.
- Complete worker suite: **146 tests executed; one platform-owned frozen
  checkpoint case failed with 34 stale post-terminal assertions**. Every
  gameplay test and every other suite/test case passed.
- Build-script syntax, staged bundle verification, resource bundle presence,
  and `git diff --check`: passed.
- Commercial staged route: visible tax relief plus Undo recovery, Day-212
  victory in **7:07**, ending at `$11,343` and `+$104/cycle`.
- Industrial staged route: visible utility expansion recovery, Day-212
  victory in **3:34**, ending at `$38,498` and `+$254/cycle`.
- Full causal evidence:
  `docs/production/evidence/PLAY-015/IMPLEMENTATION-CHECKPOINT.md`.

## Compatibility and boundaries

- The four accepted recovery identities and exact tick-844 timing are
  unchanged.
- Save schema, model shape, analytics, commands, public store contracts,
  renderer behavior, platform fixtures, and build scripts are unchanged.
- Decode and load do not mutate gameplay state.
- The platform dependency must adopt the new terminal checkpoint behavior
  before the integrated full suite is green.
- The `PLAY-038` UI companion owns Charter-specific victory copy. The exact
  staged candidate correctly displayed the existing victory overlay and
  disabled further simulation, but still used the older generic metropolis
  wording.
