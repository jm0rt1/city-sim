# PLAY-011 Completion — Strategy-Responsive City Stories

- **Lane:** Gameplay loop
- **Branch:** `codex/citysim-gameplay-loop`
- **Status:** accepted on integration `f75ab91`
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
3. `dd49ea5f6d5d2ea13d726e4b5083b4b52bbefb2d` — `PLAY-011: Bring strategy payoff into play`

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

## Sustained-session repair and final acceptance

PLAY-050 rejected the first candidate after a coached 20:19 process lifetime ended at Day 128 / tick 509 with `$8,746`, `+$123/cycle`, 409 residents, 39% happiness, zero water spare, and Town Charter `0/12`. A gameplay-owned regression reproduced the causal failure: population-first Charter copy concealed the immediate water constraint, one ordinary commercial decision did not activate the authored strategy, a decision made after Day 21 missed the exact-tick warning, and maintaining the second power/water pair erased too much revenue from a valid growth decision.

The accepted repair in `dd49ea5` makes four bounded changes without altering a public contract:

- one additional commercial or industrial zone establishes the corresponding strategy story;
- a strategy chosen between the warning and opportunity boundaries receives its warning on the next daily check, before the Day 41 opportunity;
- existing objective and message surfaces state all Charter standards, identify exhausted water or power first, and name the costed utility remedy;
- only the second and later power/water units receive a 25% reserve-infrastructure upkeep reduction. Opening pressure and first utility costs remain unchanged.

Consequence remains binding. Utility shortage still stalls growth and depresses happiness; the city still needs 500 residents, `$10,000`, non-negative cashflow, 90% employment, complete utilities with 15% reserve, 52% happiness, every zone family, and 12 consecutive daily checks. The 315-job forecast is derived from 90% of the 350-person workforce target at 500 residents, not stored as an independent rule.

Two fixtures select the first visible valid placement rather than relying on hidden map coordinates. Commercial placemaking earns the durable Charter at tick 900; industrial utility investment earns it at tick 848. Both contain explicit warning, opportunity, setback, recovery, capacity, and award checkpoints, remain distinct in happiness, pollution, and job capacity, and retain transient reset, one-time award, undo, legacy decode, and round-trip coverage. The Day 128 regression proves the stalled route can read `add water capacity`, afford the tower, add required jobs, return policy to normal, and earn the durable award before tick 2,200.

### Validation and companion disposition

- Focused gameplay suite on product `dd49ea5`: 16 passed, 0 failed in 9.861 seconds.
- Pre-companion full suite on the gameplay branch: 88 passed and 3 frozen-fingerprint assertions failed exactly because deterministic balance outcomes changed; all other renderer, UI/input, save/recovery, schema, and repeatability checks passed.
- Correct replacement fingerprints approved by PLAY-040:
  - industrial strategy: `11adf523ca4af342d3a1126c04d3469bf3e02ddd30c8b77ea22e21c70420c5ff`;
  - commercial strategy: `65c11403d0876fc9af27782e240a4e98b2806b55b8953aa81490934bb860f68c`;
  - dense terminal fixture: `d18afceb9c8ccc09eaf54d7316abc960c6b560baa1bc7d92fa6416c9776556d8`.
- PLAY-040 accepted its companion with 14/14 platform tests and no schema, fingerprint-version, or shared-contract change.
- Exact integration `f75ab91`: 91 passed, 0 failed; exact staged verify passed.
- Independent PLAY-050 final route: accepted without coaching in 9:56 wall time with Town Charter `12/true`.

The retained causal record is `docs/production/evidence/PLAY-011-live-payoff-repair.md`. No worker push or master merge was performed from this lane.
