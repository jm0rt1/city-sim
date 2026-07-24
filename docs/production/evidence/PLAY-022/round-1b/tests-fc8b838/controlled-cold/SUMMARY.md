# PLAY-022 Round 1B controlled cold timing

- Candidate: `fc8b838d6d33ee8091ce6c54c125ea0cee279f5b`
- Tree: `1277422dabd28c67469b11516ba06692f978bc1a`
- Gate: `PLAY022_ROUND1B_COLD_RENDER total_render_ms <= 6.03`
- Result: **failed as an all-samples gate**; 2/3 original governed samples
  passed, and the one explicitly additional sample passed (3/4 retained
  governed samples overall).

## Documented method

The exact test bundle was built once in the isolated scratch directory
`/private/tmp/citysim-play022-fc8b838-controlled-cold`. Each governed sample
then started a fresh XCTest process with the same documented focused class:

```text
env SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play022-fc8b838-controlled-cold/module-cache \
  CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play022-fc8b838-controlled-cold/module-cache \
  swift test --package-path Native/CitySimNative \
  --scratch-path /private/tmp/citysim-play022-fc8b838-controlled-cold/scratch \
  --skip-build --filter CitySimNativeTests.WorldRenderingTests
```

This whole-class order is material. The golden export performs and reports the
explicit generated-v4 decode/load phase first. The later
`testRendererDiagnosticsSeparateWorldUpdateTotalRenderAndAssetDecode` test
then emits the governed `PLAY022_ROUND1B_COLD_RENDER` marker without hiding
decode cost. Each governed invocation had at least a 30-second idle window and
ran sequentially. No staged CitySim app or concurrent lane-agent workload was
active; unrelated host processes were observed but not manipulated.

## Governed samples

| Sample | Golden update | Golden decode | Golden total | Cold update | Cold decode | Cold total | Gate |
|---|---:|---:|---:|---:|---:|---:|---|
| Original 1 | 4.860 ms | 8 / 23.178 ms | 29.237 ms | 4.360 ms | 0 / 0.000 ms | **5.544 ms** | pass |
| Original 2 | 4.390 ms | 8 / 22.065 ms | 27.636 ms | 4.283 ms | 0 / 0.000 ms | **5.392 ms** | pass |
| Original 3 | 5.335 ms | 8 / 26.003 ms | 32.762 ms | 7.409 ms | 0 / 0.000 ms | **8.781 ms** | **fail** |
| Explicit additional 4 | 5.587 ms | 8 / 23.334 ms | 30.121 ms | 4.130 ms | 0 / 0.000 ms | **5.277 ms** | pass |

All four whole-class commands passed 35/35 functional tests. That does not
erase the separate cold-total budget miss in original sample 3. Its captured
pre-run environment had load average `6.91` and an unrelated dental Playwright
Chrome renderer at `93.8%` CPU, alongside WindowServer and OS service load.
The miss is retained, not suppressed or relabelled. The additional sample ran
only after that browser workload had fallen to `0.4%`; its pre-run load average
was `4.91` and it passed at `5.277 ms`.

The other retained environment logs disclose non-zero host background work:
original sample 1 observed Steam at `100%` CPU, while original sample 2
observed Ecosystem, analytics, trust, and WindowServer activity. Both still
passed. No unrelated process was terminated or changed.

## Distinct non-governed evidence

The earlier exploratory failure remains unchanged in
`../world-rendering-tests.log`: it ran the documented whole class amid
concurrent agent activity and reported a `16.573 ms` golden update plus a
`6.280 ms` cold total. It is historical exploratory evidence, not one of this
controlled series.

Before confirming the required class ordering, one retained standalone
method-discovery invocation ran only the diagnostics test. It skipped the
explicit golden load phase, so the cold marker absorbed 8 decodes / `83.233
ms` and reported `105.687 ms` total. `sample-1.log` preserves that result. It
is non-comparable to the documented same-method samples and is not counted in
the 2/3 or 3/4 governed results.

## Disposition

The exact candidate demonstrates three under-ceiling measurements, including
the additional low-contention sample, but it does **not** satisfy an
all-original-samples `<= 6.03 ms` gate. Independent integration must retain
the 2/3 original and 3/4 expanded outcomes; this packet does not mark the cold
timing gate wholly green.
