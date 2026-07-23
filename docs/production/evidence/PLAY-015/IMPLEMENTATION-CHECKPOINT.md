# PLAY-015 implementation checkpoint

- **Published authority:** `ab722bd1ea7c8c132525362bc94bc12d154a78f5`
- **Authority merge:** `bb0ca473625cf95e18cc8a3ebf81039572fdb4ad`
- **Product and focused tests:** `0e3e68e5cac31d9f4b340eba18a6aa6bf8608232`
- **Branch:** `codex/citysim-gameplay-loop`
- **Claim:** `PLAY-015`

## Player outcome

Earning the Town Charter now ends the mandate through the existing `.won`
state on the same governed daily boundary that awards the Charter. The
simulation becomes terminal immediately: later step attempts cannot change
the tick, treasury, population, progression, messages, or any other state.

An older save that already contains an awarded Charter but remains `.playing`
is not changed by decoding or loading. It normalizes to `.won` only at its
next daily boundary, without issuing a second award or a second
`Town Charter Awarded` message.

## Implementation boundary

The rule remains inside `CitySimulation`:

- the existing daily progression evaluation sets `.won` when it newly awards
  the Charter;
- an already-awarded `.playing` state normalizes when that same daily
  evaluation next runs;
- end-state loss evaluation only runs while the city remains `.playing`, so
  the new same-boundary victory cannot be overwritten;
- no model shape, analytics contract, store command, SwiftUI, renderer,
  persistence identifier, fixture, or task-authority surface changed.

The four accepted recovery identities, their numerical payoffs, and their
exact tick-844 timing remain unchanged.

## Deterministic validation

Focused command:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play015-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play015-swift \
  swift test --package-path Native/CitySimNative --filter GameplayLoopTests
```

Result at `0e3e68e`: **31 tests passed, 0 failed** in 10.795 seconds.

Focused coverage proves:

- all four recovery routes enter `.won` at exact tick **844**;
- the first eleven qualifying days remain `.playing` and the twelfth wins;
- the award and existing title-routed message occur exactly once;
- a failed qualification boundary resets the run and can later win;
- terminal victory is wholly immutable through the tick-2,800 horizon;
- a legacy awarded-playing JSON round trip remains `.playing`;
- legacy ticks 1-3 do not normalize and tick 4 does;
- exact Undo restoration, legacy missing progression, and terminal loss
  compatibility remain intact.

Complete worker command:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play015-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play015-swift \
  swift test --package-path Native/CitySimNative
```

Result: **146 tests executed in 403.479 seconds; one platform test case failed
with 34 assertions, 0 unexpected failures**.

The only failing case is
`SessionPlatformTests.testAcceptedStrategyCommandsProduceFrozenCheckpoints`.
Its accepted platform fixture still attempts daily-advance commands after
tick-844 victory. Those commands now correctly reject with
`simulationNotPlaying`, and its pre-victory checkpoint values and digests are
therefore stale. GameplayLoopTests, CityCommandCatalogTests,
CitySimulationTests, SpatialConsequenceTests,
StrategyResolutionPlatformTests, WorldRenderingTests, and every other
SessionPlatformTests case passed. PLAY-015 did not alter the platform-owned
fixture; its adoption remains assigned to the simulation-platform dependency.

Other gates:

- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed with the resource bundle
  present.
- Renderer diagnostics: average render 1.444 ms.

## Exact staged candidate

```text
commit=0e3e68e5cac31d9f4b340eba18a6aa6bf8608232
candidate_id=gameplay-loop-w8f1a46b88376
bundle_identifier=com.jfmortensen.citysim-gameplay-loop.w8f1a46b88376
display_name=CitySim [Gameplay w8f1a46b88376]
staged_bundle_path=dist/CitySim-gameplay-loop-w8f1a46b88376.app
resource_bundle=present
manifest=dist/manifests/gameplay-loop-w8f1a46b88376.manifest
process_id=22395
```

Both routes below were operated against that exact packaged app through
visible controls and accessibility descriptions only. No fixture command,
source-derived placement coordinate, direct model mutation, or hidden state
was used.

### Commercial, no-coaching

1. Started a fresh region and paused on Day 5 while diagnosing the visible
   cashflow objective.
2. Used the visible Build, Zones, and Commercial controls, keyboard map
   navigation, the announced valid placement at block 15,14, and Return.
3. The route closed its opening deficit and created job openings, then
   exposed utility pressure. A Power Plant and Water Tower created a
   recoverable low-cash setback.
4. When the premature Water Tower timing drove treasury to `$278`, visible
   Undo restored the exact pre-Water-Tower Day-37 state. The command guide
   then led to Tax Policy; lowering tax to 9% captured the tax-relief
   resolution at the next daily boundary.
5. Rebuilding the Water Tower and adding a second Commercial zone reduced
   cashflow from `-$152/cycle` to `-$22/cycle`. Organic growth crossed to
   `+$1/cycle` on Day 90.
6. On Day 212 the objective summary changed to `All objectives achieved` and
   the existing victory overlay appeared. Final visible values were treasury
   `$11,343`, cashflow `+$104/cycle`, 511 residents, 61% happiness, 350 filled
   jobs with 0 openings, and 168 power / 153 water spare.

Observed wall-clock time from the paused fresh-city checkpoint to victory:
**7 minutes 7 seconds**.

### Industrial, no-coaching

1. Used `Start a New Region`, paused the fresh city, and selected Industrial
   through the visible Build and Zones controls. Keyboard navigation found
   the announced valid block 15,14 placement.
2. The first Industrial zone reached `+$129/cycle` with 79 job openings but
   quickly exposed utility pressure.
3. A Power Plant and Water Tower captured the utility-expansion recovery
   route at its governed review. Their upkeep created a `-$81/cycle`
   recoverable setback.
4. A second Industrial zone restored cashflow to `+$101/cycle` with 160 job
   openings by Day 59. Happiness was 55%, visibly lower than the Commercial
   route, while pollution remained severe on selected industrial blocks.
5. Day 202 showed `2 of 12 qualifying days complete`. Day 212 changed to
   `All objectives achieved` and displayed the victory overlay.
6. Final visible values were treasury `$38,498`, cashflow `+$254/cycle`, 511
   residents, 55% happiness, 357 filled jobs with 53 openings, and 142 power
   / 139 water spare.

Observed wall-clock time from the paused fresh-city checkpoint to victory:
**3 minutes 34 seconds**.

The thread retained exact staged screenshots for both Day-212 overlays. The
Industrial proof visibly includes the Day-212 HUD values above.

## Causal comparison

| Route | Recovery | Setback | Recovery response | Day-212 treasury | Cashflow | Happiness | Jobs open |
|---|---|---|---|---:|---:|---:|---:|
| Commercial | Tax relief | Utility expansion and near-insolvency | Undo, 9% tax, second Commercial | $11,343 | +$104 | 61% | 0 |
| Industrial | Utility expansion | Utility upkeep and lower happiness | Second Industrial | $38,498 | +$254 | 55% | 53 |

Both live routes finished well inside 20:00 and matched the deterministic
tick-844 terminal boundary. The current overlay still uses its existing
generic metropolis copy; the claimed Charter-specific presentation remains
the accepted `PLAY-038` UI dependency and was not changed by this lane.

## Handoff

- The gameplay candidate is frozen at `0e3e68e`.
- Platform adoption must update only the accepted post-terminal command
  expectations and frozen checkpoint values/digests.
- Integrated UI acceptance must confirm the `PLAY-038` Charter-specific
  victory presentation against this terminal rule.
