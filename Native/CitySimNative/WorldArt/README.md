# CitySim World Art Pipeline

CitySim ships one production-selected semantic pack, `generated-v4-calibration`,
through SwiftPM's copied `WorldAssets.atlas` resource. The accepted ImageGen
masters provide appearance only. Repository descriptors and tools own the 2:1
projection, footprints, pivots, anchors, road topology, LODs, page layout, and
all mapping from gameplay truth.

The older deterministic Pillow artwork remains the explicit `legacy-v2`
rollback source. It is not loaded by the production selection.

## Generated-v4 authority

- Raw accepted masters, prompts, references, normalization records, and
  provenance are retained under `GeneratedV4/ImageGen/`.
- Canonical RGBA LOD sources live under `GeneratedV4/normalized/`.
- Deterministic road topology lives under
  `GeneratedV4/compiled/calibration-network/`.
- Exact 1x1, 2x1, and 2x2 geometry templates and hashes live under
  `GeneratedV4/templates/`.
- The production manifest and four packed pages live in
  `Sources/CitySimNative/Resources/WorldAssets.atlas/`.

The production pack uses northwest light and southeast shadows, four pixels of
gutter, two pixels of edge extrusion, unrotated stable shelf packing, and
explicit city, neighborhood, and block payloads. Atlas construction never
calls ImageGen and never changes the retained masters.

## Deterministic build and validation

Use the Codex bundled Python runtime so Pillow is available:

```bash
PYTHON=/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3.12

"$PYTHON" \
  Native/CitySimNative/WorldArt/GeneratedV4/tools/build_world_asset_pack.py \
  --output-atlas \
  Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas

"$PYTHON" \
  Native/CitySimNative/WorldArt/GeneratedV4/tools/validate_world_asset_pack.py \
  --atlas \
  Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas
```

`build_calibration_pack.py` remains a compatibility entry point and delegates
to the same production builder. `compile_calibration_network.py` writes only
the retained deterministic source payloads; it cannot mutate shipping
resources or the manifest.

Two clean output directories must produce byte-identical manifests and pages.
Validation rejects digest drift, absolute development paths, non-RGBA or
non-power-of-two pages, inadequate padding or extrusion, overlapping packed
rectangles, anchor drift over 0.5 world point, missing LODs or road masks,
orphan pages, excessive residency, missing rollback resources, and staged
resource differences.

## Runtime and rollback

`WorldAssetCatalog` loads the manifest and pages from `Bundle.module`, validates
each page SHA-256 before decoding, creates descriptor-bound subtextures,
preloads one adjacent camera LOD, and evicts other page LODs. Diagnostics expose
pack ID, manifest digest, pages, hits, misses, evictions, decoded bytes, load
time, and bounded explicit fallback reasons. Production proof requires zero
fallbacks.

Debug builds may set:

```bash
CITYSIM_WORLD_ASSET_PACK=legacy-v2
```

That switch changes only renderer resource selection. It does not change saves,
simulation state, logical visual identities, Package.swift, or shared
contracts. Unknown pack IDs fail explicitly instead of silently selecting a
different pack.
