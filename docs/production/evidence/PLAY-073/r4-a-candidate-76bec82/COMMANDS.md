# PLAY-073 R4-A command ledger

The working directory for every command was
`/Users/James/.codex/worktrees/cac1/city-sim`.

## Performance

Each sample `1...5` used one new `swift test` process:

```sh
env \
  CITYSIM_PLAY073_R4A_COLD_MODE=scene-first-grid \
  CITYSIM_PLAY073_R4A_COLD_RECEIPT_PATH=<sample-N.json> \
  CITYSIM_PLAY073_R4A_PRODUCT_COMMIT=76bec82739c8487d170c8725af45fe6f1025aacb \
  CITYSIM_PLAY073_R4A_SAMPLE_INDEX=<N> \
  CITYSIM_PLAY073_R4A_COMMAND_LABEL=five-fresh-processes-v2 \
  swift test --package-path Native/CitySimNative \
    --filter WorldRenderingTests.testR4AFreshProcessColdPathWritesGovernedReceipt
```

The ordered preflight beside each sample records UTC, exact Git HEAD/product
ancestry, tracked status, command, host load, memory pressure, and thermal
state. No sample was retried or replaced.

## Semantic evidence

```sh
env CITYSIM_PLAY073_R4A_MEASUREMENT_ROOT=<measurement> \
  CITYSIM_PLAY073_R4A_MEASUREMENT_PHASE=exact-product-candidate \
  CITYSIM_PLAY073_R4A_PRODUCT_COMMIT=76bec82739c8487d170c8725af45fe6f1025aacb \
  swift test --package-path Native/CitySimNative \
    --filter WorldRenderingTests.testR4ARenderedPixelMeasurementBaselineIsDeterministic

env CITYSIM_PLAY073_R4A_FINAL_COARSE_COMPARISON_PATH=<comparison.json> \
  swift test --package-path Native/CitySimNative \
    --filter WorldRenderingTests.testR4AFinalCoarseDistrictMassImprovesFrozenBaselineWithoutColorCredit

env CITYSIM_PLAY073_R4A_LOD_ROOT=<lod-matrix> \
  swift test --package-path Native/CitySimNative \
    --filter WorldRenderingTests.testR4ALODMatrixUsesOneCenterAndDistinctSemanticThresholds

env CITYSIM_PLAY022_ROAD_SEAM_MOSAIC=<16-mask-three-lod.png> \
  swift test --package-path Native/CitySimNative \
    --filter WorldRenderingTests.testProductionCorridorExportsAllTopologySeamMosaicAcrossSemanticLODs
```

The lifecycle, construction, and spatial consequence exporters used their
existing task-owned environment paths. Grayscale companions were derived with
the bundled Pillow 12.2.0 runtime, without changing source pixels.

## Resources

The canonical `WorldAssets.atlas` was copied to two temporary roots. Each root
was rebuilt independently with:

```sh
/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Native/CitySimNative/WorldArt/GeneratedV4/tools/build_world_asset_pack.py \
  --output-atlas <temporary-complete-atlas>
```

Sorted SHA-256 inventories were identical. Validation used:

```sh
/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Native/CitySimNative/WorldArt/GeneratedV4/tools/validate_world_asset_pack.py \
  --atlas <build-a> --staged-atlas <build-b> --report <pack-validation.json>

/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Native/CitySimNative/WorldArt/GeneratedV4/tools/validate_production_geometry.py \
  --report <geometry-validation.json>
```

The first incomplete-atlas validation attempt is retained under
`rejected/incomplete-atlas-validator/`.

## Final suites

```sh
/usr/bin/time -l swift test --package-path Native/CitySimNative \
  --filter WorldRenderingTests

/usr/bin/time -l swift test --package-path Native/CitySimNative
```

SpriteKit test processes ran outside the managed filesystem sandbox because
macOS graphics and SwiftPM module caches require system locations. No app was
launched.
