# PLAY-022 Round 1D governed cold series

- Frozen product: `8433621760ba169995aa1a5dc81cac27c380d746`
- Rejected predecessor product: `2cf18b0f0d9a0aee9f3708e72593eb6e7cd99ae0`
- Accepted rejection authority: `7ccf0c15b31fb2b6f4fff2aea3e32612d05a9360`
- Sample count: exactly five, retained in execution order with no replacements
- Process policy: fresh `swift test --skip-build` invocation and fresh XCTest process per sample
- Unrelated-process policy: observe and retain; do not terminate or manipulate
- Metric policy: report world update, asset decode/load, and total render separately

## Build and cache policy

The renderer class is built once in a new Round 1D scratch root:

    env SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play022-round1d-five/module-cache \
      CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play022-round1d-five/module-cache \
      swift test --package-path Native/CitySimNative \
      --scratch-path /private/tmp/citysim-play022-round1d-five/scratch \
      --filter CitySimNativeTests.WorldRenderingTests

Every governed sample then uses the same built test bundle:

    env SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play022-round1d-five/module-cache \
      CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play022-round1d-five/module-cache \
      swift test --package-path Native/CitySimNative \
      --scratch-path /private/tmp/citysim-play022-round1d-five/scratch \
      --skip-build --filter CitySimNativeTests.WorldRenderingTests

Before each sample, retain commit/status, staged identity and hashes, thermal
state, memory pressure, VM statistics, relevant processes, and the complete
process table. No sample may be replaced.

## Gate

The `PLAY022_ROUND1C_COLD_PROFILE total_render_ms` value remains governed:

1. median total render time must be at most 4.8 ms;
2. all five totals must be at most 6.03 ms; and
3. thresholds must not be widened or relabeled.

Renderer functionality, staged verification, geometry, input, isolation,
resource identity, and regular/compact memory gates remain independently
required. This packet is author evidence only and cannot self-accept the
visual candidate.
