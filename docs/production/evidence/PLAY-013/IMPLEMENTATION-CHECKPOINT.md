# PLAY-013 implementation checkpoint

- **Authority baseline:** `c3c0f4ad109791fe5a90dd120b98a9812ff685e2`
- **Gameplay product commit:** `6d5df6b37cecfb35604f205cc12bf94b8e69f564`
- **Branch:** `codex/citysim-gameplay-loop`
- **Contract:** `CONTRACT-007`

## Player outcome

The strategy story no longer depends on absolute ticks. A successful Commercial or Industrial placement commits once at the next daily boundary, then opportunity, complication warning, setback, and recovery advance once in order from persisted phase-relative scheduling. A late legacy choice schedules forward without replay or cascade, later tile-count reversal cannot switch the route, and the obsolete `Choose a Growth Engine` prompt retires during the commitment evaluation.

## Deterministic validation

Focused command:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play013-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play013-swift \
  swift test --package-path Native/CitySimNative --filter GameplayLoopTests
```

Result: **25 tests passed, 0 failed** in 11.28 seconds.

The focused suite covers:

- the retained Day-25 miss, an occupied placement rejection, and successful Day-52 late choice;
- next-daily-boundary commitment, 16-day phase intervals, `>=` overdue handling, exact-once advancement, and no cascade;
- Commercial and Industrial opportunities, warnings, setbacks, both recovery responses, ignored recovery, and route non-flip;
- derived awaiting-choice, committed strategy, phase, and days-until-consequence analytics;
- save/load at every phase, missing legacy strategy, and undo before and after commitment;
- unchanged Town Charter boundary, consecutive reset, one-time award, and objective/message routing;
- Town Charter at tick 844 for both deterministic reference routes and the exact tick-2,800 / Day-701 horizon.

At tick 2,800 the Industrial reference remains playable with population 560, treasury `$214,957`, jobs 392, and happiness 53.867. The Commercial reference remains playable with population 700, treasury `$109,207.55`, jobs 350, and happiness 53.329. Both have permanently earned the Town Charter.

Full worker-lane command:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play013-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play013-swift \
  swift test --package-path Native/CitySimNative
```

Result: **125 tests executed in 376.06 seconds; 123 test cases passed and 2 PLAY-042 fixture-adoption tests failed with 10 assertions**. The exact failures were four stale strategy-message expectations, four active-strategy digest expectations, the dense fixture's expected nil strategy, and its digest. Schema-0, schema-1, frozen nil-strategy fingerprints, grouped speed, save/load, backup recovery, undo, immutable snapshot, spatial consequences, UI/input, and world-rendering tests passed. No platform test file was modified in this lane.

Integration subsequently reported that PLAY-042 adopted this checkpoint on local master `224def8` with **127/127** tests and staged verification. That downstream result is an integration handoff, not a worker-local rerun.

Other gates:

- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed and launched the exact committed staged candidate.
- Dense diagnostics during the full worker run: 400 step attempts in 41.587 ms, fingerprint 1.235 ms, save 6.016 ms, load 2.888 ms, save size 136,367 bytes.
- Renderer diagnostics during the full worker run: average render 1.395 ms.

## Exact staged causal journey

Staged candidate identity:

```text
commit=6d5df6b37cecfb35604f205cc12bf94b8e69f564
candidate_id=gameplay-loop-w8f1a46b88376
bundle_identifier=com.jfmortensen.citysim.gameplay-loop.w8f1a46b88376
staged_bundle_path=dist/CitySim-gameplay-loop-w8f1a46b88376.app
resource_bundle_path=dist/CitySim-gameplay-loop-w8f1a46b88376.app/CitySimNative_CitySimNative.bundle
```

Hands-on sequence against that packaged app:

1. Dismissed Welcome, selected 3x, and deliberately allowed the fresh city to cross the old deadline to Day 70.
2. Paused and selected Commercial through the real keyboard command.
3. Selected occupied Road block 14,13. Accessibility truth reported the Commercial placement unavailable with the occupied remedy; Return did not create a build or undo state.
4. Moved to open-land block 15,14. Accessibility truth reported the placement available with `$2,400` cost and `$6` upkeep; Return approved construction and exposed Undo.
5. Resumed at 1x and paused after the next daily boundary. On Day 71, the new Commercial site had changed the city to `$17,977`, `+$115/cycle`, population 370, jobs 259, and 97% utilities.
6. Opened the live Journal. Its top entry was `MAIN STREET CROSSROADS`, dated Day 71, with the dynamic promise that Market Weekend would arrive by Day 87. `Choose a Growth Engine` was absent while current `UTILITY SHORTFALL` remained visible.
7. Advanced to Day 88. The live Journal contained exactly one `MARKET WEEKEND`, dated Day 87, above the Day-71 commitment and current utility pressure. No expired absolute Day-25 copy returned.

The staged visual was captured in-thread from the real app but the Computer Use service's temporary screenshot file expired when the exact candidate process was terminated. PID `91602` was terminated and verified absent. The retained proof in this file is the exact accessibility/value transcript and candidate identity; combined uncoached pointer, keyboard, compact, and persistence acceptance remains assigned to PLAY-051 after PLAY-033 lands.

## Boundaries and integration notes

- No SwiftUI, SpriteKit, command, store-public-contract, save-schema identifier, fingerprint version, build script, or general event architecture changed.
- `CityPresentationSnapshot` remains unchanged and derives analytics from its authoritative state.
- Active-strategy fixture and digest adoption belongs to PLAY-042 and was intentionally not mixed into the gameplay commit.
- UI urgency presentation consumes the new analytics only after PLAY-033 integration.
