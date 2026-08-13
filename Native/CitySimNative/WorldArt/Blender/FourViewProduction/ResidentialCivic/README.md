# Residential + Civic Four-View Production

Source-only CitySim art evidence containing two original procedural Blender assets:

- `marigold_court_house`: a compact L-plan residence with warm stucco, split tiled hip roofs, a sheltered entrance court, planters, and restrained domestic detail.
- `hearthside_council_hall`: a small public hall with a broad centered stair, columned entrance, clock tower, open bell arch, flag, and symmetrical civic facade.

Both assets use the canonical FourViewPipeline contract verbatim: Blender 4.5.12 Eevee, one 2-unit world tile projecting to 88×44 pixels, 45-degree azimuth / 30-degree elevation orthographic cameras, 384×384 transparent untrimmed outputs, shared `(192,300)` ground pivot, unit root transform, and the sole `CitySimKey` light.

Run `./run_pipeline.sh`. A successful run ends with `RESIDENTIAL_CIVIC_VALIDATION_PASS`. The validator performs a second clean render into a temporary directory and requires byte-identical canonical PNG hashes. Nothing here is registered with the live game.
