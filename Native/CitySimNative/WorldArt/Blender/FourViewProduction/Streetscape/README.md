# CitySim Civic Works Yard — Four-View Streetscape

This bounded source family contains one independently inspectable Blender asset for every `RoadConnectionMask` raw value from `0...15`. The bit contract is north `1`, east `2`, south `4`, and west `8`.

Each mask is constructed as original geometry at its final world coordinates. No mask or view is produced by rotating, copying, translating, scaling, skewing, cropping, or compositing another mask image. Connected asphalt geometry terminates at the corresponding midpoint of the exact `2 x 2` world-unit cell. Absent bits have neither an asphalt boundary arm nor a socket object.

The family follows the accepted CitySim Four-View contract: 88×44 projected tile, orthographic 45-degree azimuth and 30-degree elevation, four canonical cameras, 384×384 transparent output, `[192, 300]` top-origin pivot, `12.341995` ortho scale, `0.28125` shift Y, and the canonical `CitySimKey` light.

The family is source-only. It does not alter or bind `RoadRenderer`, and it does not load or reuse Cedar Market, AssetSprint, or any rejected vector source.

Run:

```sh
Native/CitySimNative/WorldArt/Blender/FourViewProduction/Streetscape/run_pipeline.sh
```

Outputs include 16 `.blend` files, 64 canonical transparent views, 16 contact sheets and manifests, a machine-readable family manifest, two connected-district proofs, and deterministic validation evidence.
