# PLAY-022 Gate A — Golden Block Style and Scale

**Status:** binding authoring sheet for Gate A; July 20, 2026

**Reference:** `docs/production/evidence/PLAY-021/art-direction-reference.png`

**Scope:** one exceptional developed block in the shipping `CityScene`; breadth waits for review

## Composition and projection

- Use one 2:1 isometric grid. One simulation tile remains 72 x 36 world points;
  vertical architecture rises on screen without changing the ground footprint.
- The golden district is a continuous 6 x 6-tile composition centered on the
  accepted crossroads. Roads, parcels, sidewalks, driveways, and shadows share
  the same grid and may not end at visible tile seams inside the composition.
- Developed land must occupy 55–70% of the available world viewport at the
  default launch. Target camera scales are 0.48 regular and 0.60 compact; final
  values may move only to meet the retained uncropped live frames.
- City LOD reads district massing and connected streets; neighborhood LOD adds
  facade rhythm, trees, parked objects, and large props; block LOD adds entries,
  paving joints, planters, lamps, benches, loading detail, and bounded motion.

## Physical scale and source-pixel budget

SpriteKit camera scale `s` displays one world point as `1/s` logical pixels or
`2/s` physical pixels on the target 2x display. A 72 x 36 tile therefore needs:

| View | Scale | Physical tile demand | Minimum source | Policy |
|---|---:|---:|---:|---|
| Closest supported block | 0.30 | 480 x 240 px | 512 x 256 px | block export |
| Gate A default | 0.48 | 300 x 150 px | 384 x 192 px | block export |
| Gate A compact | 0.60 | 240 x 120 px | 256 x 128 px | neighborhood export |
| Neighborhood | 0.82 | 176 x 88 px | 192 x 96 px | neighborhood export |
| City | 1.45 | 99 x 50 px | 128 x 64 px | city export or mip |

The rejected 144 x 72 tile source is enlarged 3.33x at the closest camera and
2.08x at the Gate A default. It is not an acceptable block-detail source.
Golden-block art is authored as resolution-independent SVG and exported to a
3072 x 2048 master plus explicit 2048 x 1365 and 1024 x 683 LOD rasters. Raw
authoring sheets never ship; only cleaned, transparent, hashed exports do.

## Physical grammar

- Parcel modules are 1 x 1 or 2 x 1 tiles. Buildings occupy 55–78% of their
  parcel and meet the street with a visible entry, walk, stoop, apron, or dock.
- Residential height: 0.7–1.6 tile widths. Commercial: 0.8–2.2. Industrial:
  0.6–1.6 with wider roofs. Civic: 1.5–2.6 and serves as the focal silhouette.
- Roads use one asphalt value, continuous curbs, 6–9 px logical sidewalks at
  default, coherent intersection paving, aligned lane marks, crosswalks only at
  the central junction, and driveways that bridge curb to parcel.
- Every major object has a contact shadow. Northwest key light creates bright
  upper-left planes; roofs and lit walls sit above mid-value ground; southeast
  walls are darker; cast shadows travel southeast at roughly 2:1.

## Material and value hierarchy

1. **Focal architecture:** warm limestone/copper civic, brick commercial,
   stucco/wood residential, soot-muted brick/steel industrial.
2. **Movement network:** charcoal asphalt, warm-gray curb, pale aggregate walk,
   restrained ochre lane marks, off-white crosswalks.
3. **Ground:** olive and moss macro patches, dry soil edges, planted parcel
   greens; texture contrast stays below architecture and interaction states.
4. **Life and props:** deep-value tree trunks/canopies, warm lamps, muted parked
   vehicles, benches, bins, planters, hydrants, pallets, and loading equipment.
5. **Backdrop:** darkest and least saturated. Normal play has no cyan rings,
   bolts, floating lifecycle labels, or repeated consequence graffiti.

Grayscale targets: backdrop 10–18%, asphalt 20–28%, foliage 24–48%, ground
38–58%, walls 45–78%, roofs 32–68%, highlights 76–92%. Selection and placement
remain the only high-contrast outline systems.

## State language and motion

- Healthy: maintained frontage, complete roofline, planted edge, warm windows.
- Strained: authoritative condition only; reduced maintenance, dry planting,
  boarded/open bays, patched material. No generic warning symbol.
- Recovered: authoritative condition only; restored facade and planting,
  removed damage, modest work/celebration prop. No prosperity inference.
- Gate A ambient life is truth-safe: one looping pedestrian pair, one parked
  service object with no implied route, subtle tree movement, and fountain or
  vent motion. Every action is keyed, bounded, and removed by Reduce Motion
  while the static object remains meaningful.

## Gate A budgets and rejection checks

- Golden composition: at most 1 district plate per active LOD, 40 supplemental
  SpriteKit nodes, 12 drawables, and 4 bounded actions beyond the accepted
  renderer baseline. Unchanged pulses reuse the plate and all existing roots.
- Target renderer regression: <=20% for unchanged-pulse average; zero node or
  action accumulation; selection, hit testing, placement, overlay, and Reduce
  Motion remain above or legible against the art.
- Reject before review if the staged default is mostly empty grass, any central
  road seam/end is visible, buildings float or disagree on light/scale, debug
  motifs dominate, source pixels are magnified beyond this table, or the best
  proof is cropped/harness-only.
