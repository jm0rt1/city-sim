# PLAY-073 R4-C Adjacent Residential Repetition Authority

**Owner:** Integration

**Status:** active frontier visual authority

**Execution boundary:** `LUNA_IMPLEMENTATION / gpt-5.6-luna / high`

**Acceptance boundary:** independent `FRONTIER_AUTHORITY / gpt-5.6-sol / high`

## Exact return and preserved gains

Independent PLAY-075 returned exact candidate
`e4f038f942f8c011a0b38b71353e40b4ac5054d4`. The broad undifferentiated
green-quadrant defect is resolved. Terrain variation, registration, contact,
materials, overlap/clipping, resource integrity, pointer placement, keyboard
map focus, command-guide Escape, and compact Focus City all passed and must
remain byte- or behavior-equivalent except for this bounded repair.

The remaining automatic return is the northwest starter block's adjacent
residential pair at `GridCoordinate(x: 6, y: 10)` and
`GridCoordinate(x: 6, y: 11)`. Their accepted North and South source identities
are truthful and distinct, but the runtime lot compositions still read as the
same orange, black-roofed building at city, neighborhood, and block scales.
The current context variants are `0` and `1`; their subtle parity-based ground
treatment is not a player-visible solution.

## Frozen visual solution

Preserve every accepted residential source pixel, logical ID, authored
direction, frontage, pivot, scale, tint, and registration. Do not mirror,
rotate, recolor, relabel, replace, or selectively hide either building.

Make residential context variants materially distinct through truthful,
frontage-bound lot composition:

- Variant `0` is a **garden-grove lot**. At city and neighborhood visibility it
  has one unmistakable asymmetrical planted silhouette: a large deciduous
  street-tree canopy plus a smaller companion canopy, with grounded trunks,
  contact shadow, and a continuous low planting/hedge bed.
- Variant `1` is a **terraced-court lot**. It retains an open building
  silhouette and uses a visibly different warm-stone garden court, linear low
  hedge, and narrow planted strip. It must not add a second tree silhouette
  that recreates the grove read.
- Variants `2` and `3` must retain deterministic non-aliasing. They may reuse
  the same two composition families only with materially different side,
  geometry, count, and palette role; the exact `0`/`1` starter pair is the
  binding player-facing target.

All composition derives only from tile kind, coordinate-selected variant, and
the normalized authoritative road-frontage socket. It conveys landscaping and
parcel treatment only—never occupancy, wealth, service, traffic, policy, or
another gameplay fact. Every ground-contact point stays within the 72-by-36
lot diamond, leaves the accepted entrance-to-road path unobstructed, adds no
labels/actions/hit targets, and repeats exactly. Canopies may create vertical
silhouette above their own grounded lot but may not overlap an adjacent
building sprite or road envelope.

## Exact mutable surfaces

- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotContextRenderer.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
- `docs/production/evidence/PLAY-073/r4-c-adjacent-repetition-v1/`

Everything else is read-only. In particular, do not edit `LotRenderer.swift`,
`TerrainRenderer.swift`, `CityScene.swift`, `GoldenDistrictRenderer.swift`, any
asset/atlas/manifest, World Art source, package/build file, gameplay,
simulation, UI/store/save surface, claim, backlog, shared authority, or prior
evidence.

## Focused implementation proof

The worker must prove:

1. exact starter tiles `(6,10)` and `(6,11)` retain their accepted North/South
   logical IDs and source presentation while receiving variants `0` and `1`;
2. their city- and neighborhood-visible context signatures differ in
   silhouette geometry, composition role, placement, and material role—not
   node name alone;
3. all four residential variants and four frontages repeat exactly and retain
   in-lot contact points, clear entrance paths, no labels/actions/interaction
   nodes, and no adjacent context collision;
4. commercial, industrial/service, civic, park, terrain, and existing R4-B
   context bytes/behavior are unchanged;
5. focused `WorldRenderingTests`, deterministic technical color/grayscale
   comparison exports, exact input/output hashes, and `git diff --check` pass.

The worker commits one coherent product commit and one evidence/handoff commit.
It does not run the full Swift suite, build or operate the staged app, score the
visual result, push, merge, integrate, or self-accept. Integration owns the one
aggregate full suite and staged build. A fresh independent PLAY-075 recheck
owns regular/compact city, neighborhood, and block acceptance plus the same
interaction sanity checks.

## Automatic return and stop conditions

Return immediately if the pair still reads as twins at any governed LOD; the
repair needs source-art mutation, sprite tint/scale/transform, another renderer
file, semantic state, or shared contract; any context crosses its lot/road or
obstructs frontage; terrain or prior accepted composition changes; focused
tests fail outside scope; or two implementation attempts fail.
