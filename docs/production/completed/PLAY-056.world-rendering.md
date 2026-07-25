# PLAY-056 Living Public Realm Completion

- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Status:** ready for independent PLAY-058 review; not self-accepted
- **Published wave authority:** `22f6d7c`
- **Authoritative spatial diagnostics:** `f7c898823c2c2ef1521c590d3bba7e8b6d13827d`
- **Exact product:** `f06047bf74363bd7dae423cc8954776d7cb15f9d`
- **Exact evidence:** `1b96f3d5f0c0b8f400d6a8c389f45d7f93cb35f2`
- **CONTRACT-014 authority:** `82b5a1d7ae64174fccb9e3c7f6fc86517e120251`
- **Post-authority merge:** `818d51b26e0147df3333751e38ff2ce9541959dd`
- **Candidate ID:** `world-rendering-w5f893ad1da1b`
- **Bundle ID:** `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- **Evidence packet:**
  `docs/production/evidence/PLAY-056/candidate-f06047b/`

## Ordered task commits

1. `e47190e22cb3b2caf19ef35b14851cbeb8740010` — freeze the corrected
   same-state living-city baseline and preserve the rejected first capture.
2. `f9451ff3f818dba2f5e23b8eecae5e17f15a49d6` — reveal authored park
   depth, deterministic street furniture, ambient context, and initial
   vacant-land composition.
3. `1bd5ae1359d31884ea39fa9a88886dcee00660dc` — replace the perceptually
   repeated grove border and flat shrub shards with neighbor-aware organic
   meadow, shrub, grove, and copse identities.
4. `09b3641bf0cea694765f31ffe0f70faefb5de53b` — normally merge the
   accepted PLAY-059 typed spatial diagnostics.
5. `f06047bf74363bd7dae423cc8954776d7cb15f9d` — adopt authoritative Land
   Value, Traffic Pressure, and Local Happiness alongside Utilities and
   Pollution in the world renderer.
6. `1b96f3d5f0c0b8f400d6a8c389f45d7f93cb35f2` — retain exact staged
   regular/compact overlays, LODs, Reduce Motion, ambient observations, AX,
   validator, identity, RSS, and hash evidence.
7. `818d51b26e0147df3333751e38ff2ce9541959dd` — normally merge published
   CONTRACT-014 after the evidence boundary; it changes only UI/input
   authority documents.
8. This completion commit updates only the PLAY-056 claim and completion
   record.

## Player-visible outcome

The public realm now matches the accepted generated-v4 buildings instead of
reading as a flat board around them:

- parks use authored fountain, path, planting, border, shadow, and entrance
  composition above a grounded foundation;
- vacant land deterministically selects among three meadow identities, three
  low organic shrub/flower identities, one single grove, and one asymmetric
  copse;
- neighbor-aware assignment materially reduces repeated groves and prevents
  a stamped perimeter or vegetation grid;
- low vegetation uses overlapping soft lobes, restrained tonal depth, contact
  shadow, and sparse seed/flower dots instead of triangles, shards, perfect
  circles, or outlined placemats;
- benches, planters, and racks remain inside the curb/sidewalk envelope and
  outside the drivable core, frontage/socket exclusions, buildings, and
  sibling props;
- bounded pedestrians and service dressing make real connected streets feel
  inhabited without claiming traffic agents, population, trips, or other
  simulation facts.

The five world-visible data layers now use distinct sparse non-color patterns:

- Land Value: ground contours on authoritative completed developed tiles;
- Traffic Pressure: road-shoulder ticks on authoritative road coordinates;
- Utilities: the existing power/water frontage treatment;
- Happiness: ground ripples on authoritative completed developed tiles;
- Pollution: the existing sparse ground hatch.

No overlay washes an entire tile, covers a roof or entrance, publishes a
floating label, or relies on the legend for its primary map meaning.

## Truth and ownership

Land Value consumes only
`CitySpatialConsequence.landValueIndex`; Traffic consumes only
`.trafficPressure`; Happiness consumes only `.localHappinessIndex`. Utilities
and Pollution retain their accepted typed inputs. Nil domains are transparent,
construction is excluded where the typed contract is not applicable, and no
renderer formula recreates or influences simulation truth.

No gameplay, simulation, save, state fingerprint, public store, command,
SwiftUI HUD, `Package.swift`, build script, Commercial/Industrial directional
catalog, or legacy Python surface changed. CONTRACT-014 remains wholly owned
by UI/input; its post-evidence merge produces zero
`Native/CitySimNative` delta from the exact product.

## Exact product surfaces

- `Native/CitySimNative/Sources/CitySimNative/Rendering/AmbientLifeRenderer.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotRenderer.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/WorldOverlayRenderer.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CitySimulationTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`

No new generated source art or atlas payload was required for this slice.

## Exact staged proof

The staged app was operated through Computer Use at regular and exact 900 x
600 compact content. The retained packet includes:

- uncropped City, Land Value, Traffic Pressure, Utilities, Happiness, and
  Pollution frames at both sizes, all on one paused Day 53 state and Frame
  Developed City camera;
- full AX trees for every frame;
- visibly and hash-distinct city, neighborhood, and block framing at both
  sizes;
- compact Reduce Motion with equivalent static Land Value, park, vegetation,
  and ambient meaning;
- 20-second regular and compact running observations with changed frame hashes;
- 20-second regular and compact paused controls with byte-identical frame
  hashes; and
- rejected first LOD-control attempts explicitly separated and labeled rather
  than silently reused.

Integration inspected the twelve regular/compact City and overlay frames at
original resolution. It provisionally passed the public-realm direction,
organic vegetation, and sparse/distinct overlays; final acceptance still
belongs to independent PLAY-058.

## Validation

Exact product validation before synchronization:

- focused `WorldRenderingTests`: 48/48 passed;
- full native suite: 211/211 passed in 96.508 seconds;
- `bash -n script/build_and_run.sh`: passed;
- `./script/build_and_run.sh --verify`: passed from exact product `f06047b`;
- bundled-Python world-pack validation: passed 132 payload, 132 extrusion,
  2,403 packed-overlap, staged/source digest, and residency checks with zero
  failures;
- bundled-Python production geometry: passed 2,500 reciprocal contact, 100
  building/road, and 372 entrance/prop-exclusion neighbor checks with zero
  collisions or failures.

After normal merge of exact `origin/master` `82b5a1d`:

- focused `WorldRenderingTests`: 48/48 passed in 21.789 seconds;
- full native suite: 211/211 passed in 97.206 seconds;
- `git diff --quiet f06047b..818d51b -- Native/CitySimNative` passes.

## Budgets

- Post-sync representative render: 3.670 ms world update, zero decode loads,
  5.281 ms total.
- Golden frame: 842 nodes / 376 drawables / zero actions.
- Five-overlay city/block: 583 / 601 nodes, 64 overlay updates.
- Repeated LOD residency: 41,943,040 bytes high water, 648 hits, 12 misses,
  nine evictions, zero fallbacks.
- Regular staged RSS after three LOD cycles and two minutes: 133,360 KiB
  (130.23 MiB).
- Compact Reduce Motion RSS after three LOD cycles and 59 seconds: 189,728 KiB
  (185.28 MiB).
- Both RSS samples remain below the 333.8 MiB ceiling.
- Thirty-minute-equivalent unchanged-pulse soak: 4,286 pulses, stable node
  identity, two bounded running actions, and no accumulation.

## Limitations and handoff

The existing player-facing Traffic legend wording is a SwiftUI/shared
presentation surface. PLAY-056 changes no HUD copy; its renderer presents only
typed Traffic Pressure. Any copy refinement belongs to integration/UI-input
under the approved shared contracts.

This task intentionally does not ingest pending Commercial or Industrial
directional art or broaden into further asset-family production. Hand the
exact clean candidate to independent PLAY-058. This lane does not self-score,
push, integrate, or claim acceptance.
