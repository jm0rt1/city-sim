# PLAY-011 Completion — Strategy-Responsive City Stories

- **Lane:** Gameplay loop
- **Branch:** `codex/citysim-gameplay-loop`
- **Status:** ready-for-integration
- **Baseline:** `efe23eeeaf0eec6c975dfead07fd8b8394f840e3`
- **Claim:** `docs/production/claims/PLAY-011.gameplay-loop.md`

## Player-visible outcome

A player who establishes a two-zone lead now commits New Arcadia to one of two authored second-act stories. Both stories resolve on fixed daily boundaries without adding persisted state or using messages as domain authority:

| Beat | Tick / day | Commercial stewardship | Industrial expansion |
|---|---:|---|---|
| Advance warning | 80 / Day 21 | `Main Street Crossroads` forecasts a market weekend and the later need for tax relief or a second park. | `Freight Contract Watch` forecasts faster returns and the later need for utility reserve or a second park. |
| Opportunity | 160 / Day 41 | `Market Weekend`: +$1,800, +2 happiness, +1 approval. | `Regional Freight Contract`: +$5,000, -1 happiness, -0.5 approval. |
| Setback | 320 / Day 81 | `Storefront Slump`: -$3,000, -5 happiness, -3 approval. | `Industrial Load Surge`: -$5,500, -8 happiness, -5 approval. |
| Recovery payoff | 480 / Day 121 | Tax at 9% or less returns $1,500 and confidence; a second park returns $2,500 while preserving the tax base. | A second power plant and water tower repay $5,500; a second park returns $3,500 with the stronger livability recovery. |

Ignoring either recovery window has a bounded additional cost and leaves the city playing. Commercial expansion adds modest utility load; industrial expansion adds substantially more, so the choice also remains visible between authored beats through utilities, pollution, jobs, cashflow, and livability.

## Ordered commits

1. `0447e8aea03d6cd83aa9c5a7ff6eac8648ee7edc` — `PLAY-011: Make strategy shape the city`
2. `88c5a0d76145516d5bd969c53e5ee3e6fbcd1259` — `PLAY-011: Retain strategy arc evidence`

## Exact files changed

- `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulation.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/GameplayLoopTests.swift`
- `docs/production/evidence/PLAY-011-staged-industrial-warning.png`
- `docs/production/evidence/PLAY-011-staged-industrial-setback.png`
- `docs/production/evidence/PLAY-011-staged-industrial-payoff.png`
- `docs/production/completed/PLAY-011.gameplay-loop.md`

Legacy Python, `CityGameState`, `CityProgressionState`, `CityGameStore`, `SaveGameService`, objective routing, renderer/UI/input code, package topology, and build scripts were not changed.

## Deterministic two-strategy horizon

The two authored strategies advance to exactly tick 2,800 / Day 701, which is 19.6 minutes at the app's 0.42-second 1× pulse. Both permanently earn the Town Charter and remain in `.playing` state.

| Result at tick 2,800 | Industrial expansion | Commercial stewardship |
|---|---:|---:|
| Population | 560 | 700 |
| Treasury | $156,279.00 | $63,698.60 |
| Filled jobs | 392 | 350 |
| Happiness | 53.867 | 53.329 |
| Power use / capacity | 499 / 600 | 588 / 600 |
| Water use / capacity | 438 / 540 | 528 / 540 |
| Town Charter | permanent | permanent |
| Status | playing | playing |

Earlier established-state assertions additionally prove that industry has greater job capacity and pollution pressure, lower utility reserve, and a different treasury and happiness trajectory than commerce. The exact horizon values are locked in `testTwoStrategiesEarnTheCharterAndSurviveTheTwentyMinuteHorizon`.

## Automated validation

- `CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play011-clang SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play011-swiftpm swift test --filter GameplayLoopTests`
  - 14 tests passed, 0 failures in 8.017 seconds.
- `CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play011-clang SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play011-swiftpm swift test`
  - 49 tests passed, 0 failures in 31.574 seconds.
  - Renderer diagnostic: 10 pulses averaged 2.019 ms with 5,760 tile-root reuses and 0 updates.
- `git diff --check`
  - Passed with no output before the gameplay commit.
- `bash -n script/build_and_run.sh`
  - Passed with no output.
- `CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play011-clang SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play011-swiftpm script/build_and_run.sh --verify`
  - Built `dist/CitySim.app`, launched it, and verified the `CitySimNative` process remained alive.

Coverage proves authored beats occur on the intended daily boundaries; both strategies visibly diverge at the opportunity; both commercial recoveries; both industrial recoveries; bounded ignored-setback outcomes; exact two-strategy horizons; and every accepted PLAY-010 compatibility, reset, one-time, undo, and routing behavior.

## Hands-on staged-app causal flow

1. Launched the repository-built `dist/CitySim.app`, started a fresh region, paused it, selected Industrial, and placed two valid road-served industrial zones. Treasury moved from $26,000 to $19,600 with visible construction feedback.
2. Ran at 3× and opened the real Journal. `Freight Contract Watch` appeared on Day 21 with both recovery choices before impact. By Day 38, the HUD showed the strategy's positive $346/cycle cashflow alongside 95% utility coverage.
3. On Day 41, `Regional Freight Contract` added its $5,000 opportunity. The live HUD moved from $31,352 shortly before the boundary to $37,395 after it.
4. Built a second power plant and water tower through the live build palette. After construction, coverage returned to 100% with substantial reserve.
5. On Day 81, `Industrial Load Surge` removed $5,500 and eight happiness points. The staged HUD showed $14,578, 48% happiness, and the warning beside the earlier opportunity and advance warning.
6. On Day 121, `Freight Network Secured` recognized the utility response and repaid the $5,500 disruption cost. The retained Day 133 frame shows the complete causal chain together with $26,222, +$144/cycle, 432 residents, 302 jobs, 55% happiness, and 100% utilities with 206 power / 197 water spare.

The live accessibility tree exposed the exact titles, days, consequence copy, response choices, and related-data actions shown in the retained frames.

## Proof artifacts

- `docs/production/evidence/PLAY-011-staged-industrial-warning.png`
- `docs/production/evidence/PLAY-011-staged-industrial-setback.png`
- `docs/production/evidence/PLAY-011-staged-industrial-payoff.png`
- Commercial and industrial deterministic arcs: `GameplayLoopTests.testStrategyStoriesWarnOnDailyBoundaryAndCreateDifferentOpportunities`
- Commercial recoveries: `GameplayLoopTests.testCommercialSetbackSupportsTaxReliefAndParkRecovery`
- Industrial recoveries: `GameplayLoopTests.testIndustrialSetbackSupportsUtilityAndGreenBufferRecovery`
- Bounded ignored outcomes: `GameplayLoopTests.testIgnoringEitherSetbackCostsMoreButLeavesARecoveryPath`
- Exact horizon: `GameplayLoopTests.testTwoStrategiesEarnTheCharterAndSurviveTheTwentyMinuteHorizon`

## Compatibility and contract consequences

- **Town Charter:** evaluation remains in the existing daily block after authoritative daily population and treasury calculations. Twelve consecutive qualifying checks, failed-day reset, permanent one-time award, legacy nil normalization at the next daily boundary, exact undo, and routing tests all pass.
- **Save/undo:** no persisted field, schema, migration, public store type, or command was added. Strategy identity is derived from placed zones; the recovery decision is derived from ordinary tax/building state.
- **Messages:** the implementation emits existing `CityMessage` values for presentation. Tick and city state are authoritative; message presence is never used to drive progression.
- **Events:** no general event framework was introduced. Existing seeded background events begin after the authored Day 121 payoff so they cannot obscure the warned sequence.
- **UI/render/input:** no contract or implementation changed. Existing Journal and HUD surfaces rendered every consequence and recovery result.
- **Accessibility/performance:** no new control or renderer observation boundary was introduced. The staged accessibility tree and full-suite renderer diagnostic remained healthy.

## Integration notes

The change stays within the active PLAY-011 claim and requires no shared-contract proposal. Integration can merge this branch or cherry-pick the gameplay commit followed by the evidence commit and this completion-record commit. No push or integration was performed from the worker lane.
