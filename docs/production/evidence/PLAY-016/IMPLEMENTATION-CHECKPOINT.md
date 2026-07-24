# PLAY-016 implementation checkpoint

- **Published authority:** `e3ba50cd478f185265c9ddaad1e319ddb9475942`
- **Authority merge:** `f09fdd911ae893df532fa7f485e63b145a311009`
- **Frozen product checkpoint:** `a0ce861f7b7b5f5acbed5db63f44c18981c7f140`
- **Branch:** `codex/citysim-gameplay-loop`
- **Claim:** `PLAY-016`

## Player outcome

New Arcadia now opens as an authoritative two-block starter district instead
of a single crossroads. Its 32 road cells form one connected network with no
dead ends. Eight occupied lots span both blocks, and every occupied lot has
road access. The same opening exposes 46 valid road-adjacent Commercial or
Industrial growth frontages across multiple rows and both sides of the
district.

The richer network remains a pressured game state:

- treasury: `$32,000`;
- projected balance: `-$90.20/cycle`;
- population/jobs: `300 / 190`;
- power/water headroom: `54 / 48`;
- strategy commitment: the next eligible daily boundary after the first
  successful Commercial or Industrial placement;
- recovery and victory: all four accepted recovery identities still earn the
  Town Charter at exact tick `844`.

The additional `$6,000` opening reserve is the smallest tested balance repair
that keeps the accepted ignored-growth recovery viable under the eight extra
road cells' upkeep. It does not remove the operating deficit, utility
pressure, route difference, or recovery requirement.

## Authoritative topology

`CityGameState.newCity` authors:

- parallel east-west roads at `y=9` and `y=12`, from `x=4...16`;
- north-south connections at `x=4`, `x=12`, and `x=16`, from `y=9...12`;
- the accepted City Hall, two Residential lots, one Commercial lot, one
  Industrial lot, Park, Power Plant, and Water Tower;
- the Water Tower at `(15,13)`, making all eight occupied lots road-adjacent.

No persisted field, command, schema identifier, fingerprint version, fixture,
renderer, SpriteKit, SwiftUI, or legacy-save behavior changed.

## Deterministic validation

Focused gameplay and starter-district command:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play016-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play016-swift \
  swift test --package-path Native/CitySimNative \
  --filter 'StarterDistrictTests|GameplayLoopTests'
```

Result at the frozen checkpoint: **36 tests passed, 0 failed** in 13.720
seconds.

The focused coverage proves:

- exact 32-road connectivity and absence of road dead ends;
- exact eight-lot kind inventory, multi-block occupancy, and road access;
- exact 46-choice Commercial/Industrial frontage inventory;
- either first growth choice commits at tick 4 and does not mutate earlier;
- seed repeatability, JSON round trip, and repeatable version-one
  fingerprinting without a version change;
- distinct Commercial/Industrial numerical consequences;
- the retained Day-25 late-choice and rejected-placement behavior;
- all four recovery identities, ignored-recovery paths, exact Undo, and
  Town Charter victory at tick 844.

Ordinary simulation and spatial consumer command:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play016-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play016-swift \
  swift test --package-path Native/CitySimNative \
  --filter 'CitySimulationTests|SpatialConsequenceTests'
```

Result: **45 tests passed, 0 failed** in 28.616 seconds. Renderer update
diagnostics averaged `0.811 ms`; the spatial fixture derivation averaged
`1.160 ms`.

Complete worker command:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play016-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play016-swift \
  swift test --package-path Native/CitySimNative
```

Result: **199 tests executed in 94.899 seconds; 103 assertions failed, 0
unexpected failures**. Every gameplay, ordinary simulation, spatial,
Codable, legacy-save, and Undo check passed. The failures are confined to the
explicitly deferred consumers of changed authoritative starting state:

- PLAY-047 production story corpus bytes, manifests, state/spatial digests;
- platform frozen fingerprints, checkpoints, dense fixture, resolution, and
  terminal digests assigned to PLAY-048;
- renderer reference, developed-bounds, camera-framing, and spatial proof
  expectations assigned to PLAY-024.

Those integration-controlled fixtures and renderer expectations were not
changed in this lane. `bash -n script/build_and_run.sh`, `git diff --check`,
staged bundle verification, and resource-bundle presence passed.

## Exact staged fresh-start evidence

```text
commit=a0ce861f7b7b5f5acbed5db63f44c18981c7f140
candidate_id=gameplay-loop-w8f1a46b88376
bundle_identifier=com.jfmortensen.citysim.gameplay-loop.w8f1a46b88376
display_name=CitySim [Gameplay w8f1a46b88376]
staged_bundle_path=dist/CitySim-gameplay-loop-w8f1a46b88376.app
resource_bundle=present
manifest=dist/manifests/gameplay-loop-w8f1a46b88376.manifest
process_id=53468
```

The exact packaged app was operated through visible controls, keyboard map
navigation, and accessibility descriptions only:

1. The fresh staged city visibly presented the connected two-block street
   network and occupied lots on both blocks. At the first retained frame it
   was Day 6, running at 1x, with the visible growth-engine decision ready.
2. `Act on Choose a growth engine` exposed the visible Commercial and
   Industrial routes. Commercial was selected.
3. Keyboard map navigation moved from the occupied City Hall to open block
   `12,11`. The app announced: `Available. Costs $2,400 and $6 upkeep per
   cycle.`
4. Return approved that placement. The same run then displayed
   `Commercial stewardship`, `OPPORTUNITY · 16 DAYS`, and
   `Commercial construction approved` on Day 34.

The retained frames span `08:33:15` to `08:34:04`, so the visible diagnosis,
route selection, valid-frontage navigation, placement, and authoritative
commitment took **49 seconds**, inside the two-minute opening gate even after
allowing the simulation to run throughout.

Retained files:

| File | Purpose | SHA-256 |
|---|---|---|
| `fresh-start-two-block-district.jpeg` | Fresh authoritative district and visible fork | `c9b39fec889183c619b3a5225c25fd301cd161c48e084e029347e718fd7673d9` |
| `commercial-valid-frontage.jpeg` | Keyboard-selected valid road frontage | `d96952c440a3dd5fcd6d4a9c4e18fa26a7c747c2eee9d2ef040e080eeb5be33e` |
| `commercial-committed.jpeg` | Constructing lot, committed strategy, and warning interval | `19aa137388e4ca82c09a25220c2e0eeb37e6ccf91467a82d773dd57784e29a6b` |

PID `53468` exited after the proof and was verified absent.

## Limitations and handoff

- One real staged Commercial opening was operated. The Industrial opening,
  all four complete recovery journeys, save/relaunch, and Charter victory
  were not re-operated live in this lane; their exact deterministic
  compatibility is covered by the green gameplay suite.
- PLAY-048 must adopt this frozen checkpoint into platform fixtures,
  fingerprints, replay snapshots, and production story corpus.
- PLAY-024 must consume the authoritative topology and update renderer
  framing/reference expectations without inventing decorative city state.
- Final integrated no-coaching, both-strategy, all-recovery, save/relaunch,
  and 20-minute Charter acceptance remains an integration/quality gate.
