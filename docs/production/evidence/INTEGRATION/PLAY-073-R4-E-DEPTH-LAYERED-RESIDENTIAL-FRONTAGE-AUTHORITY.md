# PLAY-073 R4-E depth-layered residential frontage authority

**Owner:** Integration frontier visual authority

**Status:** active successor to rejected R4-D V2

**Execution boundary:** `LUNA_IMPLEMENTATION / gpt-5.6-luna / high`

**Acceptance boundary:** independent `FRONTIER_AUTHORITY / gpt-5.6-sol / high`

## Exact return and preserved gains

R4-D V2 is preserved cleanly at rejected evidence checkpoint
`cb1ddba6eeb0c8715e1e6bdec415c42809d6e213`, with product ancestor
`78feeb0090f727b34ce02b378066562c1a0344a5`. Its 72 focused renderer tests,
exact pair placement, four-frontage/four-variant geometry coverage, corrected
2560 x 1600 compositor, multi-lobed grove, and byte-repeat color/grayscale
exports pass. Those are implementation gains, not visual acceptance.

The exact color sheet
`docs/production/evidence/PLAY-073/r4-d-vertical-residential-silhouette-v1/TECHNICAL-COLOR-CONTACT-SHEET.png`
has SHA-256
`ef9434dcbd316bb15a2ad82c0c26a96a77551f2e75a674a1a5f7cf7fe3ab725e`.
It truthfully shows the remaining automatic return: after the court substrate
is depth-grounded behind the accepted building sprite, its paving and terrace
language is no longer decision-usefully visible at native gameplay scale.

## Frontier diagnosis

R4-D asks one residential context subtree to behave as both ground substrate
and visible foreground detail. Moving that subtree forward makes the court
read as a facade-mounted slab; moving it behind the accepted sprite grounds it
but hides the court. Repeated coordinate, alpha, and local `zPosition` tuning
cannot resolve this contradictory compositing role. The renderer needs an
explicit depth-layer contract around the accepted building sprite.

This is an architecture correction, not a third R4-D micro-repair.

## Frozen R4-E architecture

### Explicit context phases

`LotContextRenderer` must return or add deterministic context in two explicit
phases for each governed LOD:

1. **Ground underlay** is attached before the accepted building sprite. It
   owns lot substrate, contact shadow, court paving, planting soil, and other
   geometry that must be occluded naturally by the building.
2. **Foreground accent** is attached after the accepted building sprite. It
   owns only genuinely vertical or depth-near details such as a low terrace
   edge, step face, hedge face, planter lip, trunks, and canopy. It may not
   contain a broad filled ground polygon.

`LotRenderer` owns the ordering boundary: underlay, accepted source sprite,
then foreground accent. Existing non-residential context remains visually and
behaviorally equivalent and is assigned to the underlay unless it already has
a proven vertical role. No source pixel, sprite identity, scale, tint,
frontage, pivot, interaction node, semantic state, or shared contract changes.

### Garden-grove lot

Preserve the accepted R4-D multi-lobed, northwest-lit crown and exact visible
scale. Move its contact shadow and planting substrate to the underlay; place
trunks, hedge face, lobes, outline, highlights, and crown shadow in foreground.
Its anchors and all R4-D ground, vertical, road, neighbor, entrance, and pair
envelopes remain binding.

### Terraced frontage court

Replace the hidden side-slab treatment with a road-facing entrance apron
derived only from the normalized authoritative frontage socket:

- the warm-stone underlay sits between the building entrance and road socket,
  within the 72 x 36 lot diamond and outside the 16 x 8 road envelope;
- its accumulated logical bounds remain at least 24 x 9 render points;
- use an opaque, district-coherent warm-stone value with a darker perimeter
  and three or more isometric paving/step divisions;
- a shallow road-facing step face, one low linear hedge face, and one narrow
  planter lip occupy only the depth-near edge and render in foreground;
- no tree canopy, broad foreground fill, facade overlay, detached platform,
  invented occupancy, or interaction surface is allowed.

The court must remain visibly separate from the building and connected to the
entrance/frontage. It is not acceptable merely because named nodes exist.

## Candidate-bound pixel proof

The technical exporter must render each context role to deterministic isolated
masks and then render the actual composed pair. For regular 1280 x 800 city,
neighborhood, and block frames plus exact compact 900 x 600 neighborhood:

1. the court has at least 200 visible composed pixels in every regular frame
   and at least 90 in compact;
2. at least 55% of isolated court-role pixels remain visible after composition;
3. foreground court pixels have zero overlap with accepted building opaque
   pixels, while underlay overlap is correctly occluded by the sprite;
4. median court-versus-adjacent-ground Rec.709 luma separation is at least 18
   on the 0...255 scale in color-derived measurements and at least 12 in the
   retained grayscale frame;
5. the exact starter pair remains visually non-aliased at all governed LODs,
   and the grove/court roles are recognizable without labels or zoom crops;
6. the color and integer Rec.709 grayscale sheets reproduce byte-identically
   across two fresh exports.

Retain a compact machine-readable role/pixel ledger beside the sheets. Tests
must compute these values from actual raster bytes, not inferred geometry.

## Exact mutable surfaces

- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotContextRenderer.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotRenderer.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
- `docs/production/evidence/PLAY-073/r4-e-depth-layered-residential-frontage-v1/`

Everything else is read-only. Preserve all R4-C/R4-D commits and evidence. Do
not edit `CityScene.swift`, `TerrainRenderer.swift`, `GoldenDistrictRenderer`,
assets, atlases, manifests, package/build files, World Art, gameplay,
simulation, UI/store/save, claims, backlog, prior evidence, or shared
authority.

## Focused execution and stop

Start from exact clean renderer checkpoint
`cb1ddba6eeb0c8715e1e6bdec415c42809d6e213`. Commit one coherent product/test
change and one evidence/handoff result. Run the focused R4-E exporter twice,
all `WorldRenderingTests`, JSON/hash validation, and exact descendant
`git diff --check` only.

Stop on path expansion, source-art or shared-contract need, failure of any
pixel/envelope gate, non-residential drift, interaction/resource regression,
unresolved visual judgment, or any mandatory escalation trigger. If this
architecture cannot pass in one bounded implementation, preserve the result
and return it for a separate source-art or broader renderer decision; do not
continue local visual tuning. Integration owns the aggregate build and staged
review. Fresh PLAY-075 owns final candidate-bound acceptance. The worker does
not score, accept, merge, push, integrate, or pin.
