# PLAY-056 exact product evidence

## Identity

- Product commit:
  `f06047bf74363bd7dae423cc8954776d7cb15f9d`
- Branch: `codex/citysim-world-rendering`
- Candidate ID: `world-rendering-w5f893ad1da1b`
- Bundle ID:
  `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Staged bundle:
  `dist/CitySim-world-rendering-w5f893ad1da1b.app`
- Staged executable SHA-256:
  `e3ff6b2bec800b38c8f2aca2733000d5ae14a69357da21419b447f1031937dbc`
- Source and staged generated-v4 manifest SHA-256:
  `1753a314cfba5ce0034d486368dc92b23267b5a1ea8f2a30231e9a6c96f7e3fe`

`staged-candidate.manifest` binds the exact product, worktree, candidate,
bundle, executable, resource-bundle, data-root, and staging paths. The
world-pack validator independently reports `staged_matches_source: true`.

## Visible outcome

The exact staged app was operated hands-on through Computer Use. The retained
uncropped decorated-window evidence shows:

- the accepted authored park depth and street furniture;
- deterministic non-grid vacant-land identities: meadow, low organic shrub
  and flower patches, single grove, and asymmetric copse;
- no stamped perimeter grove, sharp triangular shrub, flat polygon shard, or
  visible placemat;
- truth-safe bounded pedestrians and service dressing;
- all five spatial layers at regular and exact 900 x 600 compact content:
  Land Value, Traffic Pressure, Utilities, Happiness, and Pollution;
- sparse, distinct, non-color-only world patterns that remain grounded and do
  not cover building roofs, facades, entrances, or selection geometry.

The regular and compact overlay sequences use one paused Day 53 save and the
same Frame Developed City camera. Each overlay has an accompanying full AX
tree. Integration independently inspected all twelve City/overlay frames at
original resolution and provisionally passed the visual direction.

Land Value renders ground contours only on authoritative completed developed
tiles. Traffic renders road-shoulder pressure ticks only on authoritative road
coordinates. Happiness renders ground ripples only on completed developed
tiles. Utilities and Pollution retain their accepted frontage and ground-hatch
semantics. Renderer code consumes the accepted typed spatial channels and
does not recreate simulation formulas.

## LOD, motion, and accessibility

Regular and compact Day 10 live sequences retain distinct city,
neighborhood, and block framing. The three hashes differ for actual map-scale
and detail changes, not file metadata. City preserves district structure;
neighborhood reveals road markings, street life, and park composition; block
exposes entrances, grounded props, and material detail.

`compact-reduce-motion-land-value.png` proves the same static world and
non-color overlay meaning with `CITYSIM_REDUCE_MOTION_PROOF=1`. Focused tests
report zero reduced-motion actions and static-meaning parity.

The 20-second observations retain two controls at each size:

- paused `t00` and `t20` frames are byte-identical, proving that ambient
  presentation does not drift through a paused city;
- running `t00` and `t20` frames have distinct hashes, proving bounded ambient
  activity while authoritative simulation time advances.

Every retained live screenshot has a full AX transcript. Regular and compact
trees identify the exact staged bundle, paused/running state, current data
layer, city-map target surface, command deck, and non-color legend categories.

## Automated validation

- Focused `WorldRenderingTests`: 48/48 passed.
- Full native suite: 211/211 passed in 96.508 seconds.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed from the exact product commit.
- Bundled-Python world-pack validator: passed with 132 payload checks, 132
  extrusion checks, 2,403 packed-overlap checks, 247 retained source records,
  source/staged parity, and zero failures.
- Bundled-Python production-geometry validator: passed with 2,500 reciprocal
  ground-contact checks, 100 building/road checks, 372 entrance/prop-exclusion
  neighbor checks, zero collisions, zero orphan/missing references, and zero
  failures.
- Overlay tests cover all five types at all three LODs, nil-domain
  transparency, coordinate identity, deterministic updates, construction
  exclusion, distinct static patterns, and zero actions.
- Park/public-realm tests cover deterministic assignment, no near-neighbor
  grove repetition, sidewalk-envelope furniture placement, road-core,
  frontage, socket, building, sibling-prop and collision exclusions.

The first candidate-isolation invocation was rejected by the script's usage
contract because the validator requires two live worktrees at the same branch
and commit. No substitute worktree or manifest was invented. Exact single
candidate identity is instead bound by staged verification, the retained
manifest, executable/resource digests, AX application identity, and
source/staged atlas parity.

## Budgets and diagnostics

| Measure | Result |
|---|---:|
| Representative world update | 3.699 ms |
| Representative total render | 5.273 ms |
| Decode loads / decode time | 0 / 0.000 ms |
| Golden nodes / drawables / actions | 842 / 376 / 0 |
| Five-overlay city / block nodes | 583 / 601 |
| Overlay updates | 64 |
| Generated-v4 repeated-LOD high water | 41,943,040 bytes |
| Generated-v4 fallbacks | 0 |
| Regular settled RSS, 3 LOD cycles + 2:00 | 133,360 KiB (130.23 MiB) |
| Compact Reduce Motion RSS, 3 LOD cycles + 0:59 | 189,728 KiB (185.28 MiB) |
| RSS ceiling | 333.8 MiB |

The unchanged-pulse soak ran 4,286 pulses with stable identity, bounded nodes,
and no accumulation. The full-suite renderer diagnostics reported two bounded
actions in the running soak and zero actions under Reduce Motion.

## Limits and disposition

This evidence does not ingest pending Commercial or Industrial directional
art, edit SwiftUI HUD composition, change gameplay/simulation/save/store
truth, or implement new public contracts. The existing Traffic legend copy is
SwiftUI/shared-surface owned; the renderer itself presents and names only
typed Traffic Pressure. CONTRACT-014 synchronization follows this durable
product-evidence boundary.

This is author evidence for independent PLAY-058 review. It does not self-score
or claim acceptance.
