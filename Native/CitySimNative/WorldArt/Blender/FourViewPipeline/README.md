# CitySim Blender Four-View Sprite Pipeline

This directory is the non-shipping source pipeline for CitySim four-view building sprites. It creates an original reference house, a reusable `.blend` source, four transparent untrimmed PNGs, a contact sheet, and a machine-readable manifest. It does not modify or admit live game assets.

## Locked production contract

- One world tile is a 2-unit square and projects to CitySim's 88×44 pixel ground diamond.
- Every asset uses the same orthographic rig: 45° base azimuth, 30° elevation, and cameras `camNE`, `camSE`, `camSW`, `camNW` at 90° intervals.
- `AssetRoot` and `FootprintPivot` stay at world origin. The pivot projects to pixel `(192, 300)` on every 384×384 canvas.
- The canvas is transparent, constant, and untrimmed. Output names follow `<assetId>_<camera>.png`.
- `CitySimKey` is the only light object. Camera, root, lighting, output size, and post-render transforms are pipeline settings, never artist settings.
- Asset geometry may be modeled from reusable parts, but all mesh rotation and scale transforms must be applied. Do not rotate, skew, scale, crop, trim, or offset individual rendered views.

`pipeline.json` is the executable specification. `build_and_render.py` constructs the scene from an empty Blender file and is the template for future assets. `validate_pipeline.py` checks the saved source and rendered outputs rather than trusting the builder.

## Run

From this directory:

```sh
./run_pipeline.sh
```

The script requires Blender 4.5.12. Override its executable location only when needed:

```sh
CITYSIM_BLENDER_BIN=/path/to/blender ./run_pipeline.sh
```

Expected proof ends with `FOUR_VIEW_PIPELINE_PASS`. Render PNGs are normalized to a metadata-free canonical RGBA8 encoding so repeated renders can be compared byte-for-byte; the manifest also records decoded-RGBA hashes. Generated example files live under `example/` and remain source evidence only.

## Asset-worker handoff

1. Duplicate `build_reference_house()` under a new asset-specific name; keep `configure_scene()`, `create_camera_rig()`, `create_lighting()`, and every value in `pipeline.json` unchanged.
2. Build geometry under `AssetRoot` around `FootprintPivot=(0,0,0)`. Reuse `add_box()`, `add_gable_prism()`, `add_window()`, and material helpers. Apply mesh rotation/scale transforms before rendering.
3. Change only `output.assetId` and the asset builder selection in a versioned pipeline copy. Never compensate one view after rendering.
4. Run the pipeline, inspect the four-view contact sheet, and retain the `.blend`, PNGs, and manifest together.
5. Hand the candidate to the separately authorized asset admission/integration lane. This directory grants no gameplay, renderer, source-selection, or shipping change.

The supplied research image is recorded by filename and SHA-256 in `pipeline.json`. It informed silhouette/readability and contact-sheet presentation only; the Copper Finch House is original procedural geometry and does not reuse its pixels or a Cedar Market source asset.
