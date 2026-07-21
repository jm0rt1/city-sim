# PLAY-022 Generative World-Asset Program

## Outcome

Replace every visible legacy world-art family with a coherent, more realistic
generated-v4 system while preserving exact gameplay truth, deterministic world
identity, responsive interaction, compact readability, and renderer budgets.

The temporary `golden_district_*` plate is a style and quality proof. It must
not become the permanent renderer: it represents only one exact starting state
and cannot truthfully respond to building, growth, decline, overlays, or player
changes. The final deliverable is a semantic modular atlas.

## Production authority

- Binding visual gate: `PLAY-022_VISUAL_RECOVERY_DIRECTIVE.md`.
- Resource packaging: `decisions/CONTRACT-005-world-resource-packaging.md`.
- Pack, provenance, loader, budget, and rollback rules:
  `decisions/CONTRACT-006-generated-world-asset-pack.md`.
- Provisional style-anchor candidate at renderer commit `eac7ddf`:
  `Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png`,
  SHA-256 `b227286bfe5ffe8cfc920d3faf8abe081f5cca8a498c215bfb8a840a448e7425`.

Gate A must load in the exact staged app and pass integration plus playtest
scoring before that branch-only source is integrated or breadth generation uses
it as the frozen style anchor.

## Catalog target

The source program targets roughly 110–125 accepted high-resolution masters.
Deterministic normalization, state composition, directional assembly, and LOD
export may produce up to roughly 1,001 logical manifest entries without making
1,001 independent generations. Counts are capacity estimates, not quality
quotas.

Required built identities:

- `residential_l01...l04`, `commercial_l01...l04`, and
  `industrial_l01...l04`;
- `park_l01`, `power_plant_l01`, `water_tower_l01`, `fire_station_l01`,
  `police_station_l01`, `school_l01`, and `city_hall_l01`.

Each of the 19 identities receives three materially different maintained
variants and explicit city, neighborhood, and block LODs. A variant must change
massing, roofline, entrance rhythm, and landscaping—not merely color, mirroring,
or props.

The complete system also includes:

- eight grass sources, four each of lawn/park/plaza/yard, and macro terrain;
- one seamless road material grammar deterministically compiled into all 16
  connection masks, two wear variants, curbs, sidewalks, crossings, ends, and
  oriented frontage/driveway joins;
- deciduous, conifer, ornamental, shrub, hedge, flowerbed, dry planting, and
  city-canopy vegetation families;
- street lamps, benches, planters, hydrants, bollards, bins, bike racks,
  signals, signs, flags, playground/picnic pieces, crates, pallets,
  transformers, pipes, rooftop units, tanks, fences, and construction props;
- prepared site, foundation, frame, scaffold/finishing, weathered, distressed,
  and recovery treatments;
- bounded pedestrian, parked/moving vehicle, leaf, bird, steam, water, and dust
  art, with renderer-owned paths and Reduce Motion behavior.

Selection, placement, overlays, data patterns, and truth-bearing consequence
intensity remain deterministic/code-native and are not generated pictures.

## Eight gated batches

### Batch 0 — production lock

Land CONTRACT-005, validate manifest v4, geometry templates, anchors, naming,
prompt prefix, provenance, normalization, packer, loader fallback, source-pixel
budgets, and rollback. Gate A is the sample asset.

### Batch 1 — calibration spine

Accept one coherent grass, road-material, frontage, residential, commercial,
industrial, park, city hall, and water-tower source. Render them together at
actual app scale. Reject the entire direction if they do not look like one
world.

### Batch 2 — ground and network

Complete terrain/material sources, compile all road masks and oriented
frontages, and pass tiled 3 x 3 seam mosaics at every LOD before expanding
architecture.

### Batch 3 — all buildable-kind anchors

Add variant zero for power plant, fire station, police station, and school.
The exact staged app must show all ten buildable kinds in one coherent golden
row, with correct footprints and street-facing entrances.

### Batch 4 — zone density and variety

Complete levels 1–4 and three variants for residential, commercial, and
industrial. Prove that land use and density remain recognizable in unlabeled
grayscale crops.

### Batch 5 — civic, utility, and service breadth

Complete three maintained variants for park, city hall, power plant, water
tower, fire station, police station, and school.

### Batch 6 — environment and living city

Complete vegetation, contextual props, parked vehicles, pedestrians, and
truth-safe particles. Verify deterministic placement, bounded actions, and
equivalent static meaning under Reduce Motion.

### Batch 7 — lifecycle, consequences, and migration

Complete construction and condition treatments, replace debug-like status
graffiti with environmental storytelling, exercise healthy/strained/recovered
truth, migrate every semantic renderer path, remove the monolithic Gate A plate
from production, and stop loading legacy art.

Each batch ends with a focused commit, generated-source/provenance review,
contact sheet, actual-scale render fixture, exact staged default/compact proof,
performance delta, and independent disposition. A failed batch is repaired or
rejected before later batches continue.

## Reference and prompt graph

Every asset generation references:

1. the immutable Gate A global style anchor;
2. an exact deterministic 2:1 footprint/connection/anchor template;
3. the approved variant-zero family anchor after it exists.

Variant two never references variant one; all siblings return to variant zero
to prevent cumulative drift. Rejected art is never used as a reference.

Shared built-in ImageGen prompt prefix:

```text
Use case: stylized-concept
Asset type: CitySim modular 2:1 isometric atlas source for <ASSET_ID>
Input images:
- Image 1: immutable Gate A style anchor; match projection, material depth,
  value hierarchy, detail scale, and northwest-key/southeast-shadow language;
  do not copy district layout.
- Image 2: authoritative geometry/registration template; preserve footprint,
  connections, canvas position, and ground pivot exactly.
- Image 3: approved family variant-zero anchor when available; match family
  scale and material vocabulary without duplicating massing.
Primary request: create exactly one <SUBJECT>.
Style/medium: richly detailed realistic hand-painted city-builder sprite;
orthographic 2:1 isometric; parallel edges; no perspective convergence.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key field.
Lighting: warm northwest key; coherent southeast contact/cast shadow.
Constraints: one centered asset with generous padding; no text, UI, rings,
logos, watermark, extra roads, or extra objects; do not use #ff00ff in subject.
Avoid: concept-art scenery, toy plastic, voxel/pixel art, floating geometry,
mixed camera angles, impossible architecture, and exaggerated outlines.
```

Road endpoints, parcel bounds, and pivots are hard constraints. Buildings
occupy 55–78 percent of their declared parcel and face the named street edge.
Props contain no ground plane or cast shadow; the renderer supplies their
shared shadow. Two consecutive drift failures freeze the family and trigger an
anchor/prompt review rather than accumulating adjectives.

## Repository layout and ingestion

```text
Native/CitySimNative/WorldArt/
  catalog/world-assets.json
  ImageGen/
    prompts/batch-N/<asset>.md
    raw/batch-N/<asset>-source-vNN.png
    provenance/batch-N/<asset>.json
    rejections.jsonl
  tools/
    normalize_world_asset.py
    build_world_asset_pack.py
    pack_world_atlas.py
    validate_world_asset_pack.py

Sources/CitySimNative/Resources/WorldAssets.atlas/
  manifest.json
  pages/city/page-NN.png
  pages/neighborhood/page-NN.png
  pages/block/page-NN.png
```

Image-generation cells write only unique batch inboxes. They do not edit the
manifest, shipping pages, renderer, or shared catalog. The renderer lead is the
single ingestion authority: it reviews sources, runs deterministic cleanup and
packing, stages exact paths, validates, and commits coherent batches. Rejected
binaries may be discarded; their prompt IDs and reasons remain in the ledger.

## Automatic asset rejection

Reject before ingestion for perspective convergence; template or endpoint drift
over one normalized pixel; family scale drift over five percent; inconsistent
light/shadow; floating, fused, malformed, clipped, or padded-poor geometry;
magenta spill or halo; invented roads/objects; text, UI, watermark, cyan debug
marks; recolor-only variants; or insufficient camera source density.

Road/terrain batches additionally fail on any visible seam, curb discontinuity,
atlas bleed, or pivot movement over 0.5 world point. Production fails on missing
LOD, orphan files, digest mismatch, manifest fallback, unbounded memory/actions,
or any staged resource that differs from the built pack.

## Orchestration roles

- **Integration:** owns contracts, task order, shared staging, batch acceptance,
  rollback, final merge, and master publication.
- **Renderer lead:** owns ImageGen direction, semantic asset ingestion, atlas
  compiler/loader, renderer mapping, focused commits, and exact candidate proof.
- **Generation cells:** produce one distinct asset per built-in call into unique
  batch directories, retain accepted masters/prompts/provenance, and never
  integrate or self-accept.
- **Playtest quality:** independently reviews contact sheets, seams, grayscale
  recognition, LOD motion, default/compact staged frames, interactions, and the
  dense city without implementation coaching.

No worker pushes. No generated batch reaches `master` before the exact staged
app passes its player-visible gate.
