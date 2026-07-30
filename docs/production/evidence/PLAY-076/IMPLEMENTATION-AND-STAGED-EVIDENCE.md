# PLAY-076 implementation and staged evidence

- **Claim:** `PLAY-076` — Grow the opening into a believable starter town
- **External claim authority:** `20036691842b0fdd8485ad4a924d5949c4b2e2ec`
- **Implementation baseline:** `227202371574f21f209a62153904b2f4c974dd4b`
- **Frozen product checkpoint:** `de6f477ca1a21d9dc9e825de0c7eba18055e3b7b`
- **Branch:** `codex/citysim-gameplay-loop`
- **Candidate identity:** `gameplay-loop-w8f1a46b88376`

The dirty exact-candidate worktree was intentionally not synchronized to the
external claim-authority commit. The claim and matching backlog entry were
read with `git show 2003669:<path>`, and implementation stayed on the
published corrected-topology baseline.

## Player outcome and topology

`CityGameState.newCity` now authors a visibly populated three-block starter
town without asking the renderer to invent occupied lots:

- roads: `x=4...16` on `y=9` and `y=12`; `y=9...12` on `x=4`, `x=12`,
  and `x=16`; internal divider `(8,10)` and `(8,11)`;
- occupied places: six Residential, one Commercial, one Industrial, one
  Park, one Power Plant, one Water Tower, and City Hall;
- exact Residential coordinates: `(3,10)`, `(6,10)`, `(6,11)`, `(9,10)`,
  `(10,11)`, and `(17,10)`;
- exact authored frontages: `(6,10)` north, `(6,11)` south, `(3,10)` east,
  `(17,10)` west, relocated `(9,10)` north, and retained `(10,11)` south.

Machine-checked topology:

| Property | Result |
|---|---:|
| Connected road tiles | 34 |
| Road dead ends | 0 |
| Occupied places | 12 |
| Enclosed street blocks | 3 |
| Vacant internal parcels by block | 4 / 3 / 4 |
| Occupied internal parcels by block | 2 / 3 / 2 |
| Valid empty Commercial/Industrial frontages | 40 |
| Adjacent Residential source aliases | 0 |

## Narrow two-axis simulation rule

Residential demand still uses literal housing capacity and actual population
vacancy. Industrial demand now uses only current employment and job-capacity
pressure:

```text
jobCapacityUtilization = min(1, jobs / jobCapacity)
industrialEmploymentPressure = employment * jobCapacityUtilization
industrialDemand =
    clamp(
        0.36
        + industrialEmploymentPressure * 0.35
        + max(0, 1 - employment) * 0.65
        - pollution / 140
        - max(0, taxRate - 0.10)
    )
```

The private `nearTermPopulationPotential(in:additionalJobCapacity:)` projects
only the existing 64-tick warning window toward the next 500/525 progression
milestone, bounded by actual housing capacity and employment reach. Its only
production caller is `preservesProgressionUtilityReserve`. No forecast enters
demand. Generic development utilization, `maybeUpgrade`, starting statistics,
public state, saves, fingerprints, commands, and fixtures are unchanged.

## Exact opening ledgers

Day 1 is tick 0. Day 11 is tick 40.

| Route | Tick | Treasury | Pop | Jobs / cap | Balance | R / C / I demand | Happiness | Pollution | Power / water used | Utility reserve | Strategy |
|---|---:|---:|---:|---:|---:|---|---:|---:|---|---:|---|
| No choice | 0 | $32,000.00 | 300 | 190 / 190 | -$126.20 | .720000 / .680000 / .560000 | 58.000000 | 28 | 246 / 222 | .177778 | awaiting |
| Commercial placed | 0 | $29,600.00 | 300 | 190 / 190 | -$126.20 | .720000 / .680000 / .560000 | 58.000000 | 28 | 246 / 222 | .177778 | awaiting boundary |
| Industrial placed | 0 | $28,800.00 | 300 | 190 / 190 | -$126.20 | .720000 / .680000 / .560000 | 58.000000 | 28 | 246 / 222 | .177778 | awaiting boundary |
| No choice | 40 | $30,754.50 | 310 | 190 / 190 | -$123.20 | .621645 / .707333 / .692540 | 62.736347 | 28 | 253 / 228 | .155556 | awaiting |
| Commercial | 40 | $29,873.50 | 310 | 216 / 270 | +$32.00 | .654794 / .509000 / .586429 | 64.058702 | 28 | 260 / 233 | .133333 | Commercial |
| Industrial | 40 | $29,537.50 | 310 | 216 / 300 | +$78.40 | .605530 / .599000 / .533429 | 59.891758 | 36 | 273 / 240 | .090000 | Industrial |

Both route placements leave strategy nil until tick 4, then commit exactly
once on the daily boundary. Neither strategy upgrades at tick 64. With the
existing player-funded utility decision, Industrial first develops at tick
128. Commercial remains undeveloped at tick 256 and first develops at tick
384 after its existing supporting recovery decision. The accepted PLAY-071
mature scenario still develops multiple zone levels.

## Recovery, progression, and compatibility

Focused deterministic coverage proves:

- distinct Commercial tax-relief and public-realm resolutions;
- distinct Industrial utility-expansion and green-buffer resolutions;
- the first qualifying resolution captures once and never flips;
- ignored setbacks cost more but retain a recovery path;
- all four routes earn the Town Charter at exact tick 844;
- Regional Capital is reached at tick 1024 for both Commercial routes, tick
  1036 for Industrial utility expansion, and tick 1040 for Industrial green
  buffer, all well inside tick 2,800;
- warning boundaries, pressure, recovery scars, upgrade diversity, and
  terminal freeze remain deterministic;
- legacy nil decode, schema-one save/load, backup recovery, whole-state
  replay, Codable round trip, version-one fingerprint repeatability, and exact
  Undo restoration remain intact.

## Validation

Focused command:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play076-focused-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play076-focused-swiftpm \
  swift test --package-path Native/CitySimNative \
  --filter 'StarterDistrictTests|GameplayLoopTests'
```

Result: **47/47 passed**.

Bounded non-adoption command:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play076-full-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play076-full-swiftpm \
  swift test --package-path Native/CitySimNative \
  --skip 'CitySimulationTests|ProductionStoryStateFixtureTests|VisibleCityStateFixtureTests|SessionPlatformTests|WorldRenderingTests|SpatialConsequenceTests|StrategyResolutionPlatformTests|TerminalVictoryPlatformTests'
```

Result: **109/109 passed** in 82.810 seconds.

The complete worker command executed **264 tests** in 205.908 seconds and
reported **353 assertion failures and 6 unexpected failures**. These are not
claimed as a pass. They are confined to integration-owned fixed-coordinate,
frozen story/visible/platform fingerprints and renderer references that still
describe the accepted eight-place opening, plus renderer average update time
`2.739 ms` against the `2.1 ms` budget. The lane did not rewrite those
fixtures or cross into renderer ownership. Exact adoption observations are in
`ADDITIVE-FIXTURE-ADOPTION.md`.

Also passed:

- `bash -n script/build_and_run.sh`;
- exact candidate-bound staged build verification;
- resource packaging and launch;
- `git diff --check`.

## Real staged journeys

The exact product checkpoint was staged as:

```text
candidate_id=gameplay-loop-w8f1a46b88376
commit=de6f477ca1a21d9dc9e825de0c7eba18055e3b7b
bundle_identifier=com.jfmortensen.citysim.gameplay-loop.w8f1a46b88376
staged_bundle_path=dist/CitySim-gameplay-loop-w8f1a46b88376.app
data_root=dist/test-data/gameplay-loop-w8f1a46b88376
```

### Regular Commercial

The regular `1229 × 768` staged window visibly showed the 12 occupied places
across the three-block network. Pointer interaction opened the visible growth
choice and selected Commercial. The first visually chosen target was blocked
with the truthful direct-road-access remedy. Keyboard map navigation moved to
Block 8, 11; Return built the zone; and the next daily boundary committed
`Commercial stewardship`. At paused Day 5 the HUD showed `$29,249`,
`+$26/cycle`, 304 residents, 212 filled jobs / 58 openings, 44 power and 41
water spare, and `OPPORTUNITY · 16 DAYS`.

### Compact Industrial

The same exact candidate was relaunched explicitly with
`CITYSIM_COMPACT_WINDOW=1`; its retained frame is `900 × 652`. Pointer
interaction opened the growth action and selected Industrial. Its initial
Block 11, 4 placement was blocked. Keyboard `Shift-Down`, arrows, and Return
moved to valid Block 8, 11 and built the zone. The next boundary committed
`Industrial expansion`. At paused Day 5 the compact HUD showed `$28,298`,
`+$73/cycle`, 304 residents, 212 filled jobs / 88 openings, 31 power and 34
water spare, and `OPPORTUNITY · 16 DAYS`.

### Save/relaunch/load

The regular Commercial city was saved through the app. The candidate-bound
persistence gate then:

1. recorded the manifest, executable hash, exact PID, data root, and save
   inventory;
2. terminated only manifest PID `86282`;
3. relaunched the same bundle in explicit compact mode as PID `87270`;
4. loaded the quicksave through the app, restoring paused Day 5 Commercial
   state exactly in the visible HUD;
5. saved the compact Industrial route, recorded the post-save inventory, and
   terminated only PID `87270`.

The before quicksave digest
`fbde9a41ccaf5eafa1852e45070ba9c3a29f3d37f72a2652a42b2bc4b841c129`
became the backup after the later save. The new quicksave digest is
`4a9cf0fffd78a7490b28f3a8e7da14ad690309e3bb62b547b3794af7a7312665`.
Raw gate records are retained under `persistence/`.

| Retained image | Dimensions | SHA-256 |
|---|---:|---|
| `commercial-regular-day5.jpeg` | 1229 × 768 | `a373157b8aa0c4068b68201f3976aa32d5acdbb3e2d6828cdc55c02c9c8dda0b` |
| `commercial-compact-reloaded-day5.jpeg` | 900 × 652 | `8ef1a4762d219e35f81cecadd8184b1935ad588e3c729451236b51162ac3361c` |
| `industrial-compact-day5.jpeg` | 900 × 652 | `62cc039d45fcf7f0394ebbc1ac9e80078096d6fef2840a4e02307a00cddd0d5c` |

## Boundaries and disposition

No renderer, SwiftUI, command, package/build script, shared contract, public
store, save shape, schema ID, fingerprint version, fixture history, shipping
resource, art selection, or legacy Python changed. Integration/simulation owns
additive fixture adoption, fixed-coordinate consumer updates, and the
renderer-budget disposition. Final integrated no-coaching acceptance remains
an independent integration/quality decision; this lane does not self-accept.
