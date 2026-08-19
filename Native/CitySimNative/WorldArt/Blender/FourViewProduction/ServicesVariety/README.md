# CitySim Four-View Service Variety

This source-only family adds three original sibling assets to CitySim's approved service-building style: Harborwatch Police Precinct, Lantern Gate Fire House, and Oakridge Courtyard School. The pack reproduces the immutable CitySim four-view contract: an 88x44 projected tile, orthographic 45-degree azimuth/30-degree elevation cameras, `camNE`/`camSE`/`camSW`/`camNW` order, fixed `(192,300)` top-origin pivot, transparent untrimmed 384x384 canvas, and the sole canonical `CitySimKey` light.

All geometry is procedurally modeled in Blender by `build_and_render.py`. No existing asset geometry, source pixels, Cedar Market material, per-view transform, crop, skew, offset, scale compensation, or post-render composition is reused. The assets remain source-only and are not registered with the live renderer.

Run the full production and independent validation pass:

```sh
./run_pipeline.sh
```

The validator reopens every `.blend`, verifies the fixed root, footprint, camera, light, canvas, projection, and applied mesh transforms, checks every manifest and alpha-ground-contact bound, rebuilds all 12 canonical views, three contact sheets, and both preview sizes in a temporary directory, and requires byte-identical canonical PNG output. It also structurally validates the composed preview `.blend` and exact two-unit-lattice placements.
