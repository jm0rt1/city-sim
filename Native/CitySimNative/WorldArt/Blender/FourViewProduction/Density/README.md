# CitySim Uptown Foundry Density Family

This directory contains a source-only, original Blender density-progression family for CitySim. It extends the accepted Four-View family without changing native Swift, live resources, or `LotRenderer`.

## New source assets

| Asset | Zone | Level | Player-visible identity |
|---|---|---:|---|
| `foundry_crown_apartments` | Residential | 3 | Stepped warm-brick apartment tower, stacked balconies, copper crown, roof garden |
| `market_arcade_midrise` | Commercial | 2 | Stone retail arcade, three office floors, awnings, corner clock, roof pergola |
| `aurora_exchange_tower` | Commercial | 3 | Limestone podium, vertically articulated teal-glass tower, stepped copper crown |
| `canalworks_factory` | Industrial | 2 | Expanded sawtooth production hall, administration wing, tanks, loading docks, pipe gantry |
| `foundry_peak_plant` | Industrial | 3 | Furnace tower, twin stacks, silos, conveyor, heavy loading frontage, dense pipe rack |

The progression avenue also loads the accepted sources only for comparison:

- Residential L1 Copper Finch, L2 Brickline, L3 Foundry Crown
- Commercial L1 Harbor, L2 Market Arcade, L3 Aurora Exchange
- Industrial L1 Ironleaf, L2 Canalworks, L3 Foundry Peak

Those accepted `.blend` files are read-only inputs to the preview. No source pixels or geometry are copied into the five new asset sources.

## Fixed production contract

- Blender `4.5.12`, Eevee Next
- orthographic 2:1 dimetric projection
- 88×44 projected tile from a 2×2-world-unit tile
- 45-degree base azimuth and 30-degree elevation
- `camNE`, `camSE`, `camSW`, `camNW`
- 384×384 transparent RGBA PNGs
- fixed top-origin pivot `[192,300]`
- camera ortho scale `12.341995`, shift Y `0.28125`
- fixed `CitySimKey` area light
- identity `AssetRoot` and ground-origin `FootprintPivot`
- no per-view or per-asset rotation, skew, scale, translation, crop, compositing, or post-render compensation

The composed avenue uses one orthographic 45/30 preview camera. Every lot center and edge lies on the same two-unit world grid; all roads are parallel to world X or Y.

## Build and validate

```sh
Native/CitySimNative/WorldArt/Blender/FourViewProduction/Density/run_pipeline.sh
```

Equivalent explicit commands:

```sh
/Applications/Blender-4.5.12-arm64.app/Contents/MacOS/Blender \
  --background --factory-startup --python-exit-code 1 \
  --python Native/CitySimNative/WorldArt/Blender/FourViewProduction/Density/build_and_render.py

/Applications/Blender-4.5.12-arm64.app/Contents/MacOS/Blender \
  --background --factory-startup --python-exit-code 1 \
  --python Native/CitySimNative/WorldArt/Blender/FourViewProduction/Density/validate.py \
  -- --report Native/CitySimNative/WorldArt/Blender/FourViewProduction/Density/validation/validator-output.txt
```

The validator opens every source `.blend`, confirms the exact rig and transforms, projects the world axes and pivot, checks dimensions/alpha/contact/canvas bounds, verifies source and artifact hashes, measures the accepted low/medium/high source heights, inspects the preview grid and placement transforms, and clean-rerenders all 20 asset PNGs plus both composed avenue PNGs for byte identity.

## Provenance and shipping status

All five assets are original procedural Blender geometry authored by `build_and_render.py`. Cedar Market and the rejected vector-like family are neither loaded nor reused. The outputs are `source-only-not-live`; nothing here is bound to the runtime renderer.
