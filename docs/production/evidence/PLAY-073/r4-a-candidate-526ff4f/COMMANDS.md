# PLAY-073 R4-A first-grid reliability commands

All commands ran from
`/Users/James/.codex/worktrees/cac1/city-sim`.

## Final five-process series

Exactly five ordered invocations used:

```sh
CITYSIM_PLAY073_R4A_COLD_MODE=scene-first-grid \
CITYSIM_PLAY073_R4A_COLD_RECEIPT_PATH=<sample-N.json> \
CITYSIM_PLAY073_R4A_PRODUCT_COMMIT=526ff4f91d72cf5dd83926df1c55636d698be38b \
CITYSIM_PLAY073_R4A_SAMPLE_INDEX=<N> \
CITYSIM_PLAY073_R4A_COMMAND_LABEL=five-fresh-processes-reliability-v4-exact-binding \
/usr/bin/time -l swift test --package-path Native/CitySimNative \
  --filter WorldRenderingTests.testR4AFreshProcessColdPathWritesGovernedReceipt
```

Before each invocation, the corresponding `preflight-N.txt` retained UTC,
HEAD/tree, `uptime`, `memory_pressure -Q`, finite `pmset -g therm`, and
`ps -axo pid,ppid,%cpu,rss,lstart,command -r`.

## Tests

```sh
/usr/bin/time -l swift test --package-path Native/CitySimNative \
  --filter WorldRenderingTests

/usr/bin/time -l swift test --package-path Native/CitySimNative
```

## Resources

```sh
/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Native/CitySimNative/WorldArt/GeneratedV4/tools/test_world_asset_pack_bindings.py

/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Native/CitySimNative/WorldArt/GeneratedV4/tools/validate_world_asset_pack.py \
  --atlas Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas \
  --staged-atlas dist/CitySim-world-rendering-w5f893ad1da1b.app/CitySimNative_CitySimNative.bundle/WorldAssets.atlas \
  --report resource/pack-validation.json

/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  Native/CitySimNative/WorldArt/GeneratedV4/tools/validate_production_geometry.py \
  --report resource/geometry-validation.json
```

The source and staged 79-file inventories were produced from relative,
lexically sorted paths and compared byte-for-byte.

## Technical staging

```sh
./script/build_and_run.sh --stage-only
./script/build_and_run.sh --verify
ps -axo pid,ppid,%cpu,rss,lstart,command
kill -TERM 43455
ps -p 43455 -o pid,ppid,%cpu,rss,lstart,command
```

This was a non-interactive technical build/resource smoke only.
