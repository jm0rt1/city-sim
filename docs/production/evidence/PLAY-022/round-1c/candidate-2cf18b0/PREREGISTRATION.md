# PLAY-022 Round 1C governed cold series

- Frozen product: 2cf18b0f0d9a0aee9f3708e72593eb6e7cd99ae0
- Rejected predecessor product: fc8b838d6d33ee8091ce6c54c125ea0cee279f5b
- Rejected predecessor evidence: 701bb0aa7de3ee2f80932065bf7167aada7fbe3f
- Sample count: exactly five, retained in execution order with no replacements
- Process policy: fresh swift test --skip-build invocation and fresh XCTest process per sample
- Unrelated-process policy: observe and retain; do not terminate or manipulate
- Metric policy: report world update, asset decode/load, and total render separately

## Build and cache policy

The renderer class is built once in a new Round 1C scratch root:

    env SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play022-round1c-five/module-cache \
      CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play022-round1c-five/module-cache \
      swift test --package-path Native/CitySimNative \
      --scratch-path /private/tmp/citysim-play022-round1c-five/scratch \
      --filter CitySimNativeTests.WorldRenderingTests

Every governed sample then uses the same built test bundle:

    env SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play022-round1c-five/module-cache \
      CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play022-round1c-five/module-cache \
      swift test --package-path Native/CitySimNative \
      --scratch-path /private/tmp/citysim-play022-round1c-five/scratch \
      --skip-build --filter CitySimNativeTests.WorldRenderingTests

Before each sample, retain commit/status, staged identity and hashes, thermal
state, memory pressure, VM statistics, relevant processes, and the complete
process table. No sample may be replaced.

## Gate

The PLAY022_ROUND1C_COLD_PROFILE total_render_ms value is governed:

1. median total render time must be at most 4.8 ms;
2. all five totals must be at most 6.03 ms; and
3. thresholds must not be widened or relabeled.

Renderer functionality, staged verification, geometry, input, isolation,
resource identity, and regular/compact memory gates remain independently
required. This packet does not self-score the visuals or authorize Round 2,
PLAY-023, CONTRACT-008, push, or integration.
