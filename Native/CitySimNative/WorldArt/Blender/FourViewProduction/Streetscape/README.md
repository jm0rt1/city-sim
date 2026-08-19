# CitySim Civic Works Yard — Four-View Streetscape

This bounded source family contains one independently inspectable Blender asset for every `RoadConnectionMask` raw value from `0...15`. The bit contract is north `1`, east `2`, south `4`, and west `8`.

Each mask is constructed as original geometry at its final world coordinates. No mask or view is produced by rotating, copying, translating, scaling, skewing, cropping, or compositing another mask image. Every logical socket remains at the corresponding midpoint of the exact `2 x 2` world-unit cell. Connected surface geometry extends `0.08` world unit past that socket as symmetric raster-filtering bleed, so adjacent identical materials overlap instead of exposing transparent edge pixels. Absent bits have neither an asphalt boundary arm nor a socket object.

The family follows the accepted CitySim Four-View contract: 88×44 projected tile, orthographic 45-degree azimuth and 30-degree elevation, four canonical cameras, 384×384 transparent output, `[192, 300]` top-origin pivot, `12.341995` ortho scale, `0.28125` shift Y, and the canonical `CitySimKey` light. Gameplay directions are registered explicitly to that camera: grid north maps to Blender `-X`, east to `-Y`, south to `+X`, and west to `+Y`. This is one family-level source convention, not a per-asset rotation.

The validated `camNE` family is the source of CitySim's live `FourViewRoadAssetCatalog`. It does not load or reuse Cedar Market, AssetSprint, or any rejected vector source. Transparent corridor-shaped sprites leave renderer-owned terrain visible between streets. Flush, shadow-free curbs sit at the asphalt/sidewalk interface instead of outlining each tile plate. The family uses one continuous warm-charcoal carriageway material and compact muted aggregate walks with no generated-coordinate color noise or repeated per-tile lane dash; single registered crossing bars and restrained catch-basin details distinguish major junctions without breaking the road plane.

Run:

```sh
Native/CitySimNative/WorldArt/Blender/FourViewProduction/Streetscape/run_pipeline.sh
python3 Native/CitySimNative/WorldArt/Blender/FourViewProduction/Streetscape/admit_live_catalog.py
```

Outputs include 16 `.blend` files, 64 canonical transparent views, 16 contact sheets and manifests, a machine-readable family manifest, two connected-district proofs, deterministic validation evidence, and a hash-pinned 16-mask SwiftPM resource catalog.
