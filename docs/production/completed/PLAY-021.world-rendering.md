# PLAY-021 Completion — Golden Neighborhood

- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Status:** ready-for-integration
- **Integration authority:** `43be4f40f92827c081663ed41fcc93090ce506fc`
- **Product candidate:** `7ba6f982f7c26b3296a75c00f20bc248de3b31a3`
- **Live evidence:** `86a956ba51e67fd32be934bc3a0fb9e67f0a7c2d`

## Player-visible outcome

The shipping start is now a composed authored crossroads instead of procedural
icons lost in a flat field. Connected asphalt, curbs, sidewalks, crosswalks,
frontages, shadows, props, terrain edge, stable grass variants, and sparse
vacant-land groves give the city place quality while retaining honest expansion
space. Residential, commercial, industrial, park, utility, and civic forms are
distinct by silhouette. Construction, growth, decline, and recovery remain
architectural, non-color-only readings rather than floating-label truth.

The final focused correction tightened the default and compact block-detail
lenses to 0.35 and 0.46 and added deterministic static groves to empty tiles
only. Groves claim no occupancy, service, traffic, prosperity, pollution, or
utility state. Camera input can still zoom to neighborhood and city LOD, pan,
and frame developed bounds.

## Ordered branch history for PLAY-021

1. `7e52d3c92a5c2f895685234787b18395474fe5b6` — preserve rejected baseline
2. `a2d7b2e79088e4b9d67c753f2902e769a599b538` — establish authored world atlas
3. `57a4d5209b1f3e122a33ecc7ef6fbbc5a4ffe182` — author streets and frontages
4. `ba91fd5f8447ebcd563f708575ee54e9c1f3ba5f` — replace icon lots with places
5. `35baf027f30f424169bb6a537a05685a0d194649` — frame authored neighborhood
6. `c51855e7a2ba981137921cb8769b0fff2339d429` — integrate outcomes and ambient life
7. `06496584b2d8eb7b69e9d1c04995bd1dace5348a` — preserve renderer diagnostics
8. `f08821ff0b62e0ee894bf9b9d52f68bfb2596fcf` — record blocked live gate
9. `854d4eae2d221bca6523c0c2e2109861d9f54577` — merge authority `43be4f4`
10. `7ba6f982f7c26b3296a75c00f20bc248de3b31a3` — compose shipping neighborhood
11. `86a956ba51e67fd32be934bc3a0fb9e67f0a7c2d` — retain exact live evidence

The completion-record commit follows these commits and is reported separately.
No PLAY-020/021 history was rewritten, squashed, reset, pushed, or integrated.

## Product, asset, and proof surfaces

- `Rendering/`: `AmbientLifeRenderer`, `CityScene`, `CitySceneView`,
  `LotLifecycleRenderer`, `LotRenderer`, `RoadRenderer`, `TerrainRenderer`, and
  `WorldAssetCatalog`.
- `Resources/WorldAssets.atlas/`: 46 original PNGs plus `manifest.json` for
  terrain, all 16 road masks, five frontages, and fifteen place variants.
- `WorldArt/generate_world_assets.py` and `WorldArt/README.md`: deterministic
  generator and provenance. All shipping pixels are original repository-owned
  output; the Imagegen art reference is non-shipping and supplied no sampled
  pixels.
- `Package.swift`: only the recovery brief's narrowly pre-approved resource
  registration.
- `WorldRenderingTests.swift`: topology, seed, LOD, lifecycle, reuse, soak,
  camera, and vacant-grove coverage.
- `docs/production/evidence/PLAY-021/`: immutable BEFORE, renderer fixtures,
  rejected synchronized start, exact live AFTER set, accessibility tree, and
  hash manifest.

Legacy Python, simulation rules, store intent, HUD/view composition, save
schema, and build scripts were not changed by PLAY-021 product work.

## Validation and performance

- Focused `WorldRenderingTests`: 13/13 passed in 62.682 seconds.
- Full native suite: 85/85 passed in 220.668 seconds.
- Exact staged `./script/build_and_run.sh --verify`: passed for candidate
  `world-rendering-w5f893ad1da1b`, isolated bundle identifier, executable,
  data root, and manifest.
- Full 24 x 24 world: 576 tiles, 9,004 nodes, 5,760 unchanged reuses, 0 updates,
  18.494 ms over ten pulses / 1.849 ms average.
- Thirty-minute equivalent soak: 4,286 pulses, stable identity, 9,004 nodes,
  2,424 drawables, 3 bounded actions, 3,762.075 ms total / 0.8778 ms average.
- Golden block: 1,393 nodes / 508 drawables / 0 actions, 5.025 ms.
- Reduce Motion: 0 lifecycle/ambient actions while static architecture, props,
  and state meaning remain visible.
- Drawable regular candidate settled at 171,792 KiB RSS versus the immutable
  PLAY-020 baseline observation of 139,344 KiB (+32,448 KiB / 23.3%). The live
  Reduce Motion instance settled to 117,456 KiB. Compact and Reduce Motion
  launches showed transient allocation peaks before settling; no node/action
  growth or retained pulse growth appeared in the soak.

## Real-app acceptance

The exact candidate passed default launch, real 900 x 600 compact content,
camera scale 0.72 before/after, block/neighborhood/city LOD, developed-city
framing, pointer pan and scroll zoom, normal city and pollution overlay,
City Hall selection/hit testing, valid and occupied-tile road previews, road
commit, exact undo restoration, and Reduce Motion. The accessibility tree
exposes city identity, authoritative metrics, speeds, notices, command modes,
data layers, selected City Hall at block 12,12, placement outcome text, and
Undo. `AFTER.md` records exact candidate paths and SHA-256 values.

The synchronized start was explicitly rejected before correction because the
developed cluster remained too small in repetitive empty terrain. Its retained
frame demonstrates that tests did not self-accept the art. The final default
and compact shipping frames are the accepted visual result.

## Truthful limitations and contract disposition

Accepted state still has no approved per-coordinate utility service,
prosperity, or pollution analytics. PLAY-021 therefore does not decorate lots
with invented localized claims. The accepted aggregate pollution overlay is
exercised, but localized utility trouble, prosperity, and pollution cues remain
blocked on a future integration-approved immutable spatial presentation input.
No shared-contract proposal is required for this candidate.

The live journey proves construction and ordinary simulated growth. Decline and
recovery remain proven through deterministic renderer fixtures that consume
real `CityTile.condition` values because the accepted short staged journey does
not author those transitions on demand. SpriteKit contains no debug mutation or
renderer-owned simulation rule to fake them.
