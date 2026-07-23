# PLAY-014 implementation checkpoint

- **Shared local authority:** `52fc2c17643e7987f78bc360196599e3297967da`
- **Authority merge:** `fb63faa2a3ec776c7fe9869ed8aa3e5db174d81d`
- **Product and focused tests:** `2deb594948e03bf922db9cb8d026baed3b034c14`
- **Exact four-route timing pin:** `227587caca861444d55a828e1e4f0e7a67b764eb`
- **Branch:** `codex/citysim-gameplay-loop`
- **Contract:** `CONTRACT-009`

## Player outcome

Commercial and Industrial recovery choices now become durable strategic identity instead of transient city conditions. The first qualifying resolution is captured only when the scheduled daily setback or recovery review executes, then never changes. Later tax, park, or utility changes cannot flip the earned choice.

The approved four-case `Codable`, `Equatable`, `Sendable` value is stored as the optional `CityStrategyProgression.recoveryResolution`:

- Commercial tax relief;
- Commercial public-realm investment;
- Industrial utility expansion;
- Industrial green buffer.

Existing actions remain the only qualifiers: tax at 9% or less, a second active Park, or a second active Power Plant and Water Tower. No command, UI, renderer, save-schema identifier, fingerprint version, fixture, or general-event surface changed.

The stored value drives the existing distinct payoffs:

| Resolution | Treasury payoff | Happiness | Approval | Payoff message |
|---|---:|---:|---:|---|
| Commercial tax relief | +$1,500 | +7 | +5 | Tax relief stabilizes shops |
| Commercial public realm | +$2,500 | +6 | +4 | Park earns a placemaking dividend |
| Industrial utilities | +$5,500 | +2 | +2 | Reliable factories renew freight contract |
| Industrial green buffer | +$3,500 | +7 | +5 | Green buffer wins neighborhood support |

`CityAnalytics.strategyRecoveryResolution` exposes the typed authoritative value for later UI and renderer consumption.

## Deterministic validation

Focused command:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play014-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play014-swift \
  swift test --package-path Native/CitySimNative --filter GameplayLoopTests
```

Final result at `227587c`: **29 tests passed, 0 failed** in 13.565 seconds.

Coverage includes:

- nil before the governed review and capture at the scheduled daily boundary;
- first-choice monotonicity after later conditions reverse;
- all four distinct numerical and payoff-message paths;
- typed analytics for every resolution;
- missing-field legacy decode and all four model round trips;
- exact whole-state undo before and after resolution;
- unchanged late strategy choice, phase scheduling, Town Charter, and 2,800-tick horizon behavior;
- all four resolution routes earning the Town Charter at exact tick **844**, well inside the 20-minute tick-2,800 horizon.

Complete worker command:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play014-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play014-swift \
  swift test --package-path Native/CitySimNative
```

Result: **137 tests executed in 392.908 seconds; 135 test cases passed and 2 test cases failed with 5 assertions**.

- Two assertions are the CONTRACT-009/PLAY-044 active-strategy fingerprint adoption: actual `9640c2d5b481e6c257657b3f0a2b7eaf121cb9a44eaba1888b5728a7b83a53be`, frozen `825a7c39fa1d656a6ec1a273f8b9a89ca0dc7a053d71e81eb00e281553782a7c`.
- Three assertions were one Welcome-blocking test while other CitySim worktrees concurrently used the same process-global `UserDefaults` key. Its isolated rerun passed **1/1** in 26.287 seconds.
- Frozen legacy saves, nil-progression fingerprints, save/load, undo, replay, snapshots, spatial consequences, and world rendering otherwise passed. Platform fixture adoption remains assigned to PLAY-044 and was not changed here.

Other gates:

- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed with the resource bundle present.
- Renderer diagnostics: average render 1.379 ms.
- Dense session diagnostics: simulation 43.103 ms, fingerprint 1.250 ms, save 6.294 ms, load 2.921 ms, 136,367 bytes.

## Exact staged story

Staged candidate identity:

```text
commit=2deb594948e03bf922db9cb8d026baed3b034c14
candidate_id=gameplay-loop-w8f1a46b88376
bundle_identifier=com.jfmortensen.citysim.gameplay-loop.w8f1a46b88376
staged_bundle_path=dist/CitySim-gameplay-loop-w8f1a46b88376.app
resource_bundle_path=dist/CitySim-gameplay-loop-w8f1a46b88376.app/CitySimNative_CitySimNative.bundle
process_id=72983
```

The later `227587c` checkpoint changes only one focused test assertion; it does not change staged product sources.

Hands-on sequence against that exact packaged app:

1. Started a fresh authored city, paused on Day 1, selected Commercial with `C`, selected open block 15,14 with keyboard map navigation, and approved the `$2,400` / `$6`-upkeep placement with Return.
2. The route committed on Day 2. The Journal showed Market Weekend on Day 18 and Chain Store Rumor on Day 34.
3. With no early recovery, Day 50 produced `Storefront Slump`, a `$3,000` loss, and explicit instruction to lower tax or build a second Park before the Day-66 recovery review.
4. Paused on Day 51 with treasury `$26,454`, happiness 59%, and utilities fully covered. Selected Park with `P`, moved to open block 15,15, and approved the `$900` / `$18`-upkeep public-realm investment with Return.
5. At the Day-66 governed review, the Journal showed exactly one `Main Street Rebound`: “The new park restored foot traffic without sacrificing the tax base. Shops delivered a $2,500 placemaking dividend.” Treasury was `$29,090`, happiness 70%, population 365, jobs 254, and utilities 98%.
6. The in-thread staged screenshot captured the real Day-66 Journal, selected Park, and payoff metrics.
7. Invoking existing Undo restored the exact Day-51 pre-Park state: treasury `$26,454`, happiness 59%, no selected block, no Day-66 payoff, and the Day-50 setback/deadline again at the top of the Journal.

PID `72983` was terminated and verified absent after proof.

## Boundaries and handoff

- The model addition is exactly CONTRACT-009's optional four-case enum field.
- Missing legacy data decodes as `nil`; loading does not infer or mutate a resolution.
- Capture happens only inside existing scheduled daily strategy evaluation.
- First captured resolution is monotonic and payoff uses the stored value rather than current city conditions or message prose.
- PLAY-044 owns canonical fingerprint, fixture, replay-corpus, and immutable snapshot adoption after this checkpoint freezes.
- Final integrated pointer, keyboard, compact, save/relaunch/load, and all-four-route acceptance remains owned by PLAY-052.
