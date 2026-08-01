# PLAY-073 R4-A returned-candidate repair command ledger

Every command ran from
`/Users/James/.codex/worktrees/cac1/city-sim`.

## Sync and ownership

```sh
git fetch origin
git merge 5d86e804be679c765c2465c60ceaee72f3702c48
git show 5d86e804be679c765c2465c60ceaee72f3702c48:Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift
```

The UI-owned test file was restored as the exact master blob before the product
commit. Renderer source/tests were staged explicitly and inspected with
`git diff --cached --check`.

## Focused repair gates

```sh
swift test --package-path Native/CitySimNative \
  --filter WorldRenderingTests.testR4ASourceContextRepetition

swift test --package-path Native/CitySimNative \
  --filter WorldRenderingTests.testLotContextIsDeterministicTruthBoundedAndProtectsFrontage

swift test --package-path Native/CitySimNative \
  --filter WorldRenderingTests.testCompletedBuildingKindReplacementInvalidatesDevelopedGroundExactlyOnce

swift test --package-path Native/CitySimNative \
  --filter WorldRenderingTests.testCompletedIndustrialReplacementInvalidatesServiceCampusGround

swift test --package-path Native/CitySimNative \
  --filter WorldRenderingTests.testStartingCameraFramesTheDevelopedCoreAtDefaultAndCompactLODs
```

Ledger export:

```sh
env \
  CITYSIM_PLAY073_R4A_REPETITION_LEDGER_PATH=<repetition-ledger.json> \
  CITYSIM_PLAY073_R4A_PRODUCT_COMMIT=298167c74a7d28042857d7f87c1f7b9130f779ed \
  swift test --package-path Native/CitySimNative \
    --filter WorldRenderingTests.testR4ASourceContextRepetitionLedgerPassesStarterAndMatureFixtures
```

## Semantic evidence

```sh
env CITYSIM_PLAY073_R4A_MEASUREMENT_ROOT=<measurement> \
  CITYSIM_PLAY073_R4A_MEASUREMENT_PHASE=exact-product-candidate \
  CITYSIM_PLAY073_R4A_PRODUCT_COMMIT=298167c74a7d28042857d7f87c1f7b9130f779ed \
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

Existing lifecycle, construction, and spatial-consequence exporters wrote only
to this candidate root. Grayscale companions were derived with the bundled
Pillow 12.2.0 interpreter.

## Five fresh processes

Each sample used a new process and a retained preflight:

```sh
env \
  CITYSIM_PLAY073_R4A_COLD_MODE=scene-first-grid \
  CITYSIM_PLAY073_R4A_COLD_RECEIPT_PATH=<sample-N.json> \
  CITYSIM_PLAY073_R4A_PRODUCT_COMMIT=298167c74a7d28042857d7f87c1f7b9130f779ed \
  CITYSIM_PLAY073_R4A_SAMPLE_INDEX=<N> \
  CITYSIM_PLAY073_R4A_COMMAND_LABEL=five-fresh-processes-v3 \
  swift test --package-path Native/CitySimNative \
    --filter WorldRenderingTests.testR4AFreshProcessColdPathWritesGovernedReceipt
```

The first preflight attempt used streaming `pmset -g thermlog` and stalled
before any XCTest sample. Its partial output is preserved under
`rejected/performance-preflight-thermlog-stall/`; the corrected preflight used
the finite `pmset -g therm`.

## Resources

Two complete copies of the canonical atlas were rebuilt concurrently in the
separate roots recorded by `resource/TEMP-ROOTS.txt`:

```sh
/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Native/CitySimNative/WorldArt/GeneratedV4/tools/build_world_asset_pack.py \
  --output-atlas <temporary-complete-atlas>
```

Validation:

```sh
/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Native/CitySimNative/WorldArt/GeneratedV4/tools/test_world_asset_pack_bindings.py

/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Native/CitySimNative/WorldArt/GeneratedV4/tools/validate_world_asset_pack.py \
  --atlas <build-a> --staged-atlas <build-b> \
  --report <pack-validation.json>

/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Native/CitySimNative/WorldArt/GeneratedV4/tools/validate_production_geometry.py \
  --report <geometry-validation.json>
```

The initial incomplete-atlas invocations are preserved under `rejected/` and
are not evidence of a pass.

## Final suites and staged resource verification

```sh
/usr/bin/time -l swift test --package-path Native/CitySimNative \
  --filter WorldRenderingTests

/usr/bin/time -l swift test --package-path Native/CitySimNative

./script/build_and_run.sh --verify
ps -axo pid,lstart,command
kill -TERM 87185
ps -axo pid,command
```

The complete suite failure is preserved verbatim. The staged run performed no
player interaction and was used only to bind exact product, executable, bundle,
manifest, source/staged resource parity, and exact-PID termination.

## Independent-return accounting repair

The preserved candidate was synchronized normally without rewriting:

```sh
git fetch origin
git merge a8b30be4a4a12515d934b035b63946af82247b1f
```

This produced merge commit
`ed46ecb0d775c1a99ad82c12dd5de6b953d49b6e`. Exact ancestry, changed-path,
claim, product-delta, and UI-owned blob checks are retained in
`validation/CURRENT-MASTER-EXACT-CHECKS.json`.

The current-master focused renderer recheck ran these exact filters:

```sh
swift test --package-path Native/CitySimNative \
  --filter WorldRenderingTests.testR4ASourceContextRepetition
swift test --package-path Native/CitySimNative \
  --filter WorldRenderingTests.testLotContextIsDeterministicTruthBoundedAndProtectsFrontage
swift test --package-path Native/CitySimNative \
  --filter WorldRenderingTests.testCompletedBuildingKindReplacementInvalidatesDevelopedGroundExactlyOnce
swift test --package-path Native/CitySimNative \
  --filter WorldRenderingTests.testCompletedIndustrialReplacementInvalidatesServiceCampusGround
swift test --package-path Native/CitySimNative \
  --filter WorldRenderingTests.testStartingCameraFramesTheDevelopedCoreAtDefaultAndCompactLODs
```

The five commands executed six tests with zero failures. No full-suite,
performance, pack, staged-app, or player-facing receipt was replaced by this
merge-only evidence repair.
