# PLAY-022 Round 1B final five-sample cold window

- Authority: `52fc2c17643e7987f78bc360196599e3297967da`
- Frozen product: `fc8b838d6d33ee8091ce6c54c125ea0cee279f5b`
- Starting evidence HEAD: `881dba4fbae06610cd08b10af268d4a4e407633c`
- Sample count: exactly five, retained in execution order with no replacements
- Idle policy: 30 seconds immediately before each environment capture
- Process policy: fresh `swift test --skip-build` invocation and fresh XCTest process per sample
- Unrelated-process policy: observe and retain; do not terminate or manipulate

## Cache and build policy

The test bundle is built once before the governed window in a new scratch root:

```text
env SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play022-fc8b838-wave005-five/module-cache \
  CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play022-fc8b838-wave005-five/module-cache \
  swift test --package-path Native/CitySimNative \
  --scratch-path /private/tmp/citysim-play022-fc8b838-wave005-five/scratch \
  --filter CitySimNativeTests.WorldRenderingTests
```

Every governed sample uses exactly:

```text
env SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play022-fc8b838-wave005-five/module-cache \
  CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play022-fc8b838-wave005-five/module-cache \
  swift test --package-path Native/CitySimNative \
  --scratch-path /private/tmp/citysim-play022-fc8b838-wave005-five/scratch \
  --skip-build --filter CitySimNativeTests.WorldRenderingTests
```

The prebuild is retained but is not one of the five governed samples.

## Before-sample capture

`capture_environment.sh` records immediately before each invocation:

- UTC time, branch, evidence HEAD, frozen candidate/tree, and clean status;
- absence of product/resource differences from `fc8b838`;
- exact staged executable, candidate-manifest, packaged generated-v4 manifest,
  source generated-v4 manifest, and resource-inventory hashes;
- uptime/load, `pmset -g therm` output and exit, free-memory percentage,
  `vm_stat`, and physical memory;
- a focused CitySim/XCTest/Swift-build process subset and the complete process
  table.

## Gate

The governed metric is the `PLAY022_ROUND1B_COLD_RENDER` cold total, while
world-update, asset-decode, and total-render timings remain separately
reported. The window passes only when:

1. median cold total is at most `6.03 ms`;
2. at least four of five cold totals are at most `6.03 ms`; and
3. no uncontaminated sample exceeds `9.045 ms`.

Externally contaminated samples remain in the ordered series and are identified
only from their prerecord. No extra sample is authorized.
