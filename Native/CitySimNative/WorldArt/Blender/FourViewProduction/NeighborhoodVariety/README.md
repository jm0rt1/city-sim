# CitySim Neighborhood Variety

This source-only family expands the approved live four-view building style with two residential and two industrial siblings. It reuses the established Density helpers, locked projection, warm material character, and `CitySimKey` lighting. It does not replace existing assets or use the rejected Cedar Market/vector family.

Locked output contract: 88×44 projected tile, 384×384 transparent untrimmed canvas, pivot `(192,300)`, `camNE/camSE/camSW/camNW`, orthographic 45° base azimuth and 30° elevation, identity `AssetRoot`, and no per-view compensation.

Run:

```sh
./run_pipeline.sh
```

Successful validation ends with `NEIGHBORHOOD_VARIETY_VALIDATION_PASS`. Each asset directory contains its `.blend`, four canonical PNG views, contact sheet, and manifest. Live admission is deliberately separate and requires composed in-game proof.
