# CitySim Civic Works Yard — Four-View Streetscape

This bounded source family contains one independently inspectable Blender asset for every `RoadConnectionMask` raw value from `0...15`. The bit contract is north `1`, east `2`, south `4`, and west `8`.

Each mask is constructed as original geometry at its final world coordinates. No mask or view is produced by rotating, copying, translating, scaling, skewing, cropping, or compositing another mask image. Connected asphalt geometry terminates at the corresponding midpoint of the exact `2 x 2` world-unit cell. Absent bits have neither an asphalt boundary arm nor a socket object.

The family follows the accepted CitySim Four-View contract: 88×44 projected tile, orthographic 45-degree azimuth and 30-degree elevation, four canonical cameras, 384×384 transparent output, `[192, 300]` top-origin pivot, `12.341995` ortho scale, `0.28125` shift Y, and the canonical `CitySimKey` light.

The validated `camNE` family is the source of CitySim's live `FourViewRoadAssetCatalog`. It does not load or reuse Cedar Market, AssetSprint, or any rejected vector source. Transparent corridor-shaped sprites leave renderer-owned terrain visible between streets; only the connected asphalt, shoulder, and curb geometry occupies each road tile.

Run:

```sh
Native/CitySimNative/WorldArt/Blender/FourViewProduction/Streetscape/run_pipeline.sh
python3 Native/CitySimNative/WorldArt/Blender/FourViewProduction/Streetscape/admit_live_catalog.py
```

Outputs include 16 `.blend` files, 64 canonical transparent views, 16 contact sheets and manifests, a machine-readable family manifest, two connected-district proofs, deterministic validation evidence, and a hash-pinned 16-mask SwiftPM resource catalog.
