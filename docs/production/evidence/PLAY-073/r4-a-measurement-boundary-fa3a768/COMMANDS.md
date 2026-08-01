# Reproduction commands

The retained build used:

```sh
swift test \
  --package-path Native/CitySimNative \
  --scratch-path /private/tmp/play073-r4a-fa3a768.j5rFTV/scratch \
  --filter WorldRenderingTests.testR4ACoarseDistrictMassDefinitionBindsFrozenBaselineAndRejectsTerrainOnlyPass
```

The coarse ledger replay used the same command with `--skip-build` and
`CITYSIM_PLAY073_R4A_COARSE_COMPARISON_PATH` pointed to
`COARSE-COMPARISON-B.json`.

Each of the five direct and five first-grid samples used a separate invocation:

```sh
env \
  CITYSIM_PLAY073_R4A_COLD_MODE=<make-backdrop-or-scene-first-grid> \
  CITYSIM_PLAY073_R4A_COLD_RECEIPT_PATH=<sample-json> \
  CITYSIM_PLAY073_R4A_PRODUCT_COMMIT=fa3a7687 \
  CITYSIM_PLAY073_R4A_SAMPLE_INDEX=<1-through-5> \
  CITYSIM_PLAY073_R4A_COMMAND_LABEL=swift-test-skip-build-fresh-process \
  swift test \
    --package-path Native/CitySimNative \
    --scratch-path /private/tmp/play073-r4a-fa3a768.j5rFTV/scratch \
    --skip-build \
    --filter WorldRenderingTests.testR4AFreshProcessColdPathWritesGovernedReceipt
```

Every invocation has its own retained transcript and distinct PID. No sample was
replaced.
