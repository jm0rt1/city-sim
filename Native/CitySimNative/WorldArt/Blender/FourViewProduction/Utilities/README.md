# CitySim Four-View Utilities

Original Blender source family for two utility lots:

- `municipal_water_tower`: riveted elevated tank, braced legs, pump/service house, exposed pipework, and fenced service apron.
- `brick_grid_substation`: brick control building, transformers, ceramic insulators, bus bars, switchgear, and safety fencing.

Both assets use the locked CitySim Four-View contract: an 88x44 projected tile, orthographic 45-degree azimuth and 30-degree elevation, `camNE`/`camSE`/`camSW`/`camNW`, 384x384 transparent renders, top-origin pivot `[192,300]`, root origin `[0,0,0]`, and the canonical warm `CitySimKey`. There is no per-view or post-render transform compensation.

Run the complete bounded pipeline:

```sh
bash run_pipeline.sh
```

The build writes Blender sources, four canonical PNGs per asset, contact sheets, manifests, and the 1280x800 and 900x600 neighborhood-edge proofs. Validation re-builds and re-renders each asset in a temporary directory and requires byte-identical canonical PNG hashes.

The composed proof appends accepted Four-View source geometry for Marigold Court House, Harbor Corner Storefront, Ironleaf Service Workshop, and the standard/dressed civic-road tiles. It does not load or reuse Cedar Market assets.
