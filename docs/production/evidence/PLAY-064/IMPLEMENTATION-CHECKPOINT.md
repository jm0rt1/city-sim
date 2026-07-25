# PLAY-064 implementation checkpoint

- **Published authority:** `0ed9f3a8ad28d6b29f734c97f3dd3111fd118cc6`
- **Branch:** `codex/citysim-gameplay-loop`
- **Claim:** `PLAY-064`
- **Frozen product checkpoint:** `70efccfd30b6e2318998f02cb36a1cd37def9fe3`
- **Compatibility repair:** `1241bf308e8888af4cd06685347c87108ed3a014`

## Player outcome

The Town Charter is now a permanent midpoint rather than the end of the
session. Its governed daily award opens a durable Regional Capital chapter.
Commercial stewardship faces a regional retail challenge; Industrial
expansion faces a regional grid and freight mandate. Each route warns before
pressure, applies a different numerical setback, names a remedy through the
existing objective and message routes, accepts the matching durable
first-act recovery, and requires 12 consecutive qualifying daily checks
before one permanent Regional Capital recognition.

Regional recognition, not a transient population or treasury spike, enters
the existing terminal victory state. A failed qualifying day resets only the
consecutive counter. The player retains the city, permanent Charter,
strategy, recovery identity, and second-act phase.

## Authoritative behavior

- `CityProgressionState` adds only optional
  `CitySecondActProgression?`.
- The typed second-act phases are `mandate`, `warnedPressure`, `recovery`,
  `qualification`, and `completed`.
- The state stores only phase, optional next scheduled tick, consecutive
  qualifying daily checks, and the permanent one-time award bit.
- Commercial and Industrial warnings are separated from pressure by 64
  simulation ticks.
- Commercial pressure costs `$4,500`, 5 happiness, and 3 approval; its
  recovery returns `$2,000`, 4 happiness, and 3 approval.
- Industrial pressure costs `$7,000`, 8 happiness, and 5 approval; its
  recovery returns `$4,000`, 3 happiness, and 2 approval.
- Regional recognition pays Commercial `$8,000`, 6 happiness, and 5
  approval; Industrial receives `$12,000`, 3 happiness, and 4 approval.
- Commercial qualification requires 525 residents, `$12,000`, 56%
  happiness, 92% employment, non-negative cashflow, complete utilities,
  18% reserve, and three active Commercial zones.
- Industrial qualification requires 525 residents, `$15,000`, 44%
  happiness, 92% employment, non-negative cashflow, complete utilities,
  20% reserve, and three active Industrial zones.

The first-act durable recovery remains authoritative. Tax relief requires
8% or less; public-realm and green-buffer routes require the third park;
utility expansion requires the third power plant and water tower.

## Compatibility

New cities retain `secondAct == nil` until the Charter award. Legacy state
with no second-act key decodes nil and is not mutated on load. A legacy
awarded-and-playing city still normalizes to its permanent Charter terminal
victory only at the next governed daily boundary, with no second award or
message. Its analytics now says
`Town Charter secured permanently · Charter victory is complete`; only a
state with a real second act says the Regional Capital chapter is active.

All second-act phases round-trip exactly through `Codable`. Save/load,
backup recovery, deterministic replay, fingerprint identity, and exact Undo
restoration use the existing state and store architecture. No save schema,
filename, fingerprint version, package, command, public store type,
renderer, SpriteKit, SwiftUI, or legacy Python surface changed.

## Deterministic validation

Focused command:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play064-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play064-swift \
  swift test --disable-sandbox \
  --package-path Native/CitySimNative \
  --scratch-path /private/tmp/citysim-play064-build \
  --filter GameplayLoopTests
```

Result at repaired HEAD: **36 tests passed, 0 failed** in 16.187 seconds.
The suite proves both strategies, all four first-act recovery identities,
late choice after Day 25, a rejected placement before commitment, minimum
warning intervals, exact phase order, daily-only qualification, reset and
later recovery, one-time award/message behavior, terminal immutability,
legacy nil decode, every-phase round trip, save/load/backup/replay,
fingerprint identity, exact Undo, objective/message routing, and both
strategies reaching either Regional Capital recognition or explicit loss
inside the 2,800-tick 20-minute horizon.

The complete worker suite was also run in the approved host context at
repaired HEAD. It executed **231 tests** and reproduced **121 downstream
pre-adoption assertions, 13 unexpected**, while all 36 gameplay tests
passed. The failures are confined to integration-controlled consumers:

- PLAY-047 production story fixtures still require exact Charter
  `completed/won` state at tick 844;
- session, terminal, spatial, and rendering fingerprints/digests still
  freeze the Charter as terminal;
- the UI notice catalog has no action disposition for the four new Regional
  warning/pressure titles;
- existing command-center and terminal presentation consumes only the
  first-act Charter corpus.

Those fixtures, catalogs, digests, renderer expectations, and presentation
surfaces were not changed in this gameplay lane.

Build and staged verification passed:

```text
commit=1241bf308e8888af4cd06685347c87108ed3a014
candidate_id=gameplay-loop-w8f1a46b88376
bundle_identifier=com.jfmortensen.citysim.gameplay-loop.w8f1a46b88376
display_name=CitySim [Gameplay w8f1a46b88376]
staged_bundle_path=dist/CitySim-gameplay-loop-w8f1a46b88376.app
manifest=dist/manifests/gameplay-loop-w8f1a46b88376.manifest
process_id=77945
```

## Repaired-HEAD staged journey

The exact repaired app was operated through ordinary visible pointer and
keyboard controls:

1. On Day 12, the visible growth-engine action exposed Commercial and
   Industrial. Commercial was selected with the pointer.
2. Return attempted the initially focused roadless block `(11,16)` and was
   rejected without commitment. `Shift-Up`, three `Left` presses, and Return
   recovered to valid block `(8,11)` and placed Commercial.
3. Keyboard placement added Commercial capacity at `(6,11)`, a power plant
   at `(7,11)`, and a water tower at `(9,11)`.
4. Day 38 visibly warned `Protect local storefronts · DECISION · 7 DAYS`.
   Pointer-accessible tax controls lowered the rate from 10% to 8%. By Day
   96, `Tax relief locked in · STORY COMPLETE` confirmed the durable
   first-act recovery. Tax returned to 10% to restore citywide cashflow.
5. Day 208 showed `8 of 12 qualifying days complete`. Day 222 awarded the
   permanent Charter but kept the city playable and visibly changed the
   objective to `Regional mandate arrives in 6 days`.
6. Day 240 warned `Pressure lands in 4 days · protect cash and livability`.
   At Day 249 the pressure objective named the exact remedy:
   `Lower tax to 8% or less to restore local foot traffic`.
7. Tax relief was applied again. The governed daily run reached terminal
   victory on visible Day 262, far inside Day 701: 561 residents, `$24,529`
   treasury, `+$200/cycle`, 68% happiness, 392 filled jobs with 38 openings,
   and 100% utilities.

The exact staged PID `77945` was terminated after proof and verified absent.

## Downstream presentation limitation

The final gameplay state is Regional Capital recognition, but the accepted
integration-owned terminal overlay still renders `Town Charter Secured` and
the first-act Charter story. That is a truthful-product/incorrect-consumer
adoption gap. It requires fixture, notice-catalog, and terminal/UI adoption
outside this claim; it was not repaired by crossing into SwiftUI, renderer,
commands, or platform fixture ownership.

Industrial warning, recovery, qualification, terminal state, and all four
recovery identities were proved deterministically but were not separately
operated live in this lane. Final integrated both-strategy presentation and
no-coaching acceptance remains an integration and playtest gate after
consumer adoption.
