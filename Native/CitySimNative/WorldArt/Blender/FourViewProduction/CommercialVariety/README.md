# CitySim Commercial Variety Source Family

This bounded source-only pack adds two original commercial candidates as natural siblings of the approved live-quality `market_arcade_midrise` and `aurora_exchange_tower`. It does not modify or bind live resources.

## Candidates

| Asset | Family | Distinct identity |
|---|---|---|
| `sunbrick_market_lofts` | Medium commercial | Golden-brick stepped lofts, recessed market passage, striped shop awnings, iron fire escapes, roof conservatory |
| `copperglass_exchange_annex` | High commercial | Asymmetric stepped office tower, horizontal copperglass bands, external frame, planted sky terraces, offset lantern crown |

Both use the approved density-family helpers and material character. The existing siblings are loaded read-only into the composed preview; their geometry and pixels are not copied into either candidate source.

## Locked contract

- Blender `4.5.12`, Eevee Next
- orthographic 2:1 dimetric projection
- 88×44 projected tile from a 2×2-world-unit tile
- 45-degree base azimuth, 30-degree elevation
- `camNE`, `camSE`, `camSW`, `camNW`
- transparent, untrimmed 384×384 RGBA canvas
- top-origin footprint pivot `[192,300]`
- identity `AssetRoot` and `FootprintPivot` at the world ground origin
- sole canonical `CitySimKey` area light
- no per-view or per-asset rotation, skew, scale, crop, offset, or post-render compensation

## Build and validate

```sh
Native/CitySimNative/WorldArt/Blender/FourViewProduction/CommercialVariety/run_pipeline.sh
```

The validator reopens each `.blend`, verifies the locked rig and source transforms, checks exact 2×2-tile ground contact, validates byte and decoded-pixel hashes, and performs clean deterministic rerenders of all eight canonical views, both contact sheets, and both composed previews.

The terminal success marker is:

```text
COMMERCIAL_VARIETY_VALIDATION_PASS
```

## Direct visual evidence

- `sunbrick_market_lofts/sunbrick_market_lofts_contact-sheet.png`
- `copperglass_exchange_annex/copperglass_exchange_annex_contact-sheet.png`
- `preview/copper-row-commercial-block-1280x800.png`
- `preview/copper-row-commercial-block-900x600.png`
- `validation/validator-output.txt`

The preview places the two candidates beside their approved medium- and high-commercial siblings on one fixed world-X/world-Y street grid at identity scale. Every placement center and lot edge lands on the same two-world-unit grid.

## Shipping status

Everything in this directory is `source-only-not-live`. No runtime catalog, native renderer, test target, canonical pipeline, or approved asset source is changed here. Live admission belongs to the Goal Driver after visual acceptance.
