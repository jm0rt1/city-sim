# CitySim Civic and Utility Variety

This source-only family adds one city-hall sibling and two utility siblings to the approved live four-view style. It reuses the established Density helpers, warm modeled material character, and fixed `CitySimKey` rig. Existing live assets remain the baseline and are not replaced.

Locked output contract: 88x44 projected tile, 384x384 transparent untrimmed canvas, pivot `(192,300)`, `camNE/camSE/camSW/camNW`, orthographic 45-degree base azimuth and 30-degree elevation, identity `AssetRoot`, and no per-view compensation.

Run:

```sh
./run_pipeline.sh
```

Successful validation ends with `CIVIC_UTILITY_VARIETY_VALIDATION_PASS`. Each asset directory contains its `.blend`, four canonical PNG views, contact sheet, and manifest. Live admission is separate and requires composed in-game proof.
