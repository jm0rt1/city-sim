# PLAY-022 Round 1B exact-candidate validation

- Candidate: `fc8b838d6d33ee8091ce6c54c125ea0cee279f5b`
- Tree: `1277422dabd28c67469b11516ba06692f978bc1a`
- Branch: `codex/citysim-world-rendering`
- Validation date: 2026-07-22
- Scope: automated validation only; no product, contract, claim, staging,
  commit, GUI, or existing-process mutation
- Build isolation: task-scoped SwiftPM scratch and module-cache paths under
  `/private/tmp/citysim-play022-tests-fc8b838-*`

## Result

The full native suite and the focused resolver suite pass. The first isolated
focused renderer run does **not** pass: the exact historical golden-fixture
update measured `16.573 ms`, above the mandatory `6.03 ms` ceiling, and failed
`testGoldenNeighborhoodShippingRendererExportsThreeLODsAndCompact`. The
identical warm repeat and the renderer block in the isolated full suite pass.
The retained evidence therefore contains two passing timing samples and one
failing sample; the cold performance gate is not consistently satisfied and
must not be reported as wholly green.

| Check | Exact result |
|---|---|
| Focused `CitySimNativeTests.WorldRenderingTests`, isolated build | **Failed:** 35 executed, 1 failure, 27.447 s test time; 44.20 s command wall time |
| Focused renderer, identical warm repeat | 35/35 passed, 0 failures, 23.889 s test time; 24.43 s command wall time |
| Focused `CitySimNativeTests.IsometricGridCoordinateResolverTests` | 3/3 passed, 0 failures, 0.003 s test time; 13.92 s command wall time including isolated build |
| Full `Native/CitySimNative` Swift suite | 135/135 passed, 0 failures, 69.467 s test time; 83.22 s command wall time |
| Renderer block inside full suite | 35/35 passed, 0 failures, 24.578 s |
| Resolver block inside full suite | 3/3 passed, 0 failures, 0.003 s |
| `bash -n script/build_and_run.sh` | passed |
| `bash -n script/verify_candidate_isolation.sh` | passed |
| `git diff --check` | passed |

The focused command was:

```text
env SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play022-tests-fc8b838-focused/module-cache \
  CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play022-tests-fc8b838-focused/module-cache \
  swift test --package-path Native/CitySimNative \
  --scratch-path /private/tmp/citysim-play022-tests-fc8b838-focused/scratch \
  --filter CitySimNativeTests.WorldRenderingTests
```

The warm repeat used the identical command and already-built isolated scratch.
The resolver command replaced `focused` with `resolver` in the task-scoped
paths and filtered
`CitySimNativeTests.IsometricGridCoordinateResolverTests`. The full suite used
`...-full` paths and omitted the filter.

## Cold timing and decode disclosure

| Sample | Golden-fixture update | Golden decode | Golden total | Separate cold render | `<= 6.03 ms` |
|---|---:|---:|---:|---:|---|
| Focused isolated build | **16.573 ms** | 8 loads / 37.173 ms | 55.662 ms | 6.280 ms total | **No; test failed** |
| Focused warm repeat | 4.355 ms | 8 loads / 22.891 ms | 28.406 ms | 5.336 ms total | Yes |
| Full isolated suite | 4.546 ms | 8 loads / 22.416 ms | 28.113 ms | 5.204 ms total | Yes |

The test assertion applies the `6.03 ms` ceiling to the historical golden
fixture's `world_update_ms`; the first sample failed at `16.573 ms`. Its
separate `PLAY022_ROUND1B_COLD_RENDER` marker also exceeded the ceiling at
`6.280 ms` total. Both overages are retained and disclosed. The later two
samples pass both measurements, but they do not erase the first failure.

## Residency, reuse, and fallback diagnostics

All three renderer executions reported the same bounded generated-v4
residency:

- 28 resident textures;
- 13,521,048 resident and high-water decoded bytes;
- 56 hits, 364 misses, 336 evictions; and
- **0 fallbacks**.

The full run reported 1,932 initial nodes and 1,935 final nodes across ten
pulses, with 5,759 tile reuses, 1 update, and 1.582 ms average changed-pulse
render time. The 30-minute-equivalent unchanged-pulse soak retained 1,932
nodes, 758 drawables, 1 bounded action, and 0.0025 ms average pulse time.
Reduce Motion reported 0 actions; the city/neighborhood/block diagnostics
retained 871 nodes without LOD-specific duplication.

Default occupied-mass coverage remained `0.624132 x 0.850377`; exact compact
coverage remained `0.540000 x 1.220904`. Both runs separately reported the
larger network context and did not count it as occupied mass.

## Resolver and CONTRACT-008 boundary

The focused and full runs exercised all three resolver tests:

- every authoritative 24 x 24 cell center resolves to its exact coordinate;
- interior points remain inside the intended isometric diamond; and
- out-of-map points and invalid geometry are rejected.

`fc8b838` changes only `Rendering/CitySceneView.swift`,
`Rendering/TerrainRenderer.swift`, and the renderer-focused test file relative
to parent `860b9e9`. Inspection across authority `5df04fa..fc8b838` finds no
changes to `CityGameStore`, models, services, App, Views, packages, build
scripts, or
`docs/production/decisions/CONTRACT-008-active-map-action-target.md`. The
CONTRACT-008 blob is identically
`bc519df6974c80ff9b1f2cc9e516882dd62dc407` at both endpoints. This validation
does not broaden the candidate into active player-intent targeting.

## Retained files

- `world-rendering-tests.log` — isolated focused renderer run with the retained
  performance failure
- `world-rendering-tests-warm-repeat.log` — successful identical warm repeat
- `resolver-tests.log` — successful focused resolver run
- `full-native-tests.log` — successful complete native suite
- `world-rendering-tests.sandbox-attempt.log` and
  `resolver-tests.sandbox-attempt.log` — pre-discovery outer-sandbox failures
- `diagnostics.log` — exact renderer markers from all renderer executions
- `timings-and-counts.log` — exact suite counts and command wall times
- `candidate-identity.log` — commit, tree, source, manifest, and contract hashes
- `static-checks.log` — syntax, diff, and CONTRACT-008 boundary checks

The initial focused and resolver invocations were blocked before test discovery
because SwiftPM's nested `sandbox-exec` could not run inside the outer workspace
sandbox. The identical isolated commands then ran under approved execution;
those pre-discovery failures are environmental and are not counted as product
test failures.

`SHA256SUMS` records the exact digest for every retained file except itself.
