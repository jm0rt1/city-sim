# CitySim Environment Four-View Production

Original procedural Blender source for one exact-tile civic road/sidewalk treatment and one exact-tile pocket grove park. This directory is source-only review evidence and performs no live asset registration.

The local `pipeline.json` repeats the locked canonical values from `../../FourViewPipeline/`: 2-unit tile projecting to 88×44, 384×384 transparent untrimmed output, shared `(192,300)` pivot, 45-degree azimuth / 30-degree elevation cameras, and `CitySimKey` lighting. Geometry is axis-aligned in shared world XY space; there is no post-render compensation.

Run `./run_pipeline.sh`. Outputs include one `.blend`, four camera renders, a visibly labeled contact sheet, and a manifest per asset, plus the composed source-only streetscape preview and its manifest.
