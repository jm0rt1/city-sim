# CitySim Four-View Neighborhood Services

This source-only family contains three original Blender service buildings: Emberline Fire Station, Bluecrest Police Station, and Maplewood Neighborhood School. They use the accepted CitySim Four-View contract: one 88x44 projected tile, orthographic 45-degree azimuth/30-degree elevation cameras, fixed `[192,300]` top-origin pivot, 384x384 transparent canvas, and the canonical `CitySimKey` light.

The assets are generated from original procedural mesh geometry in `build_and_render.py`. No Cedar Market file, rejected vector asset, source pixel, generated image, per-view transform, crop, skew, translation, scale compensation, or post-render compositing is loaded or used. The output is explicitly source-only and is not integrated into `LotRenderer`.

Run the complete deterministic production and validation pass:

```sh
./run_pipeline.sh
```

The validator opens every `.blend`, verifies the fixed root/camera/light/grid contract, checks alpha bounds and pivot contact, proves projected world-axis consistency in all four views, verifies manifest hashes, performs a clean factory-startup rerender, and requires byte-identical canonical PNGs. The representative block places all three source assets on one exact two-unit lattice with one orthographic 45/30 preview camera at 1280x800 and 900x600.
