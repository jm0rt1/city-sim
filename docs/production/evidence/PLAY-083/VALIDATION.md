# PLAY-083 Validation

## Disposition

`industrial-active-district-v3` is a truthful candidate for the explicit
`early -> active` mapping, and `industrial-recovering-district-v3` is a
truthful candidate for the explicit `recovered -> recovering` mapping. This
worker evidence does not publish either mapping. Integration must review and
publish one binding receipt before QA may leave `BLOCKED`.

No fixture, manifest, product, public contract, schema, fingerprint, renderer,
UI, gameplay, art, package, build-script, or legacy-Python byte changed.

## Exact authority

- Published authority:
  `c00f8295973d527c597c333769b7c4ef7d3acca5`
- Non-rewriting synchronization merge:
  `f41e66aa47fcfb953f3f7fd549f46793c04df090`
- Proof-code checkpoint:
  `7169c09bfd276be43a7180fdf61f5a519300c6c6`
- Accepted request SHA-256:
  `73842570ee5d10e83ef3ec59b301dd9998959bd07e9d3d64e4d9d49c678bf51b`
- VisibleCityStates v3 manifest SHA-256:
  `9eed6405adc84b8bdf025bb2ac1365b327c8659bdbf0384bc6f172d6c9a2aace`
- Candidate packet SHA-256:
  `aca3974c2dc6a8386c1ef4f274d5154ae537d2415e50a2558c7417f8f044cb2e`

## Semantic results

### `early -> active`

- Exact file SHA-256:
  `48a45a4f3901eee09fca2bcf10315381e421dbc605ffa050e13fbee5dc17fdc3`
- Git blob: `af685a8ac6479f97ab12e342a75a726250e58497`
- Tick 68, playing, Industrial Expansion, opportunity phase.
- No second act, no recovery resolution, no Town Charter.
- Industrial focus `(5,8)` is complete and occupied.
- The exact construction predecessor plus four deterministic simulation steps
  equals the admitted state.
- State/spatial/diagnostic/activity digests reproduce exactly.

### `recovered -> recovering`

- Exact file SHA-256:
  `5a278e43873f364c986545a856eec6a8ba4315b712b843028dcc5d8e602720f4`
- Git blob: `9b408b2d01763b5a986287e968f4732e67c2a420`
- Tick 992, playing, Industrial Expansion completed, qualification phase.
- Town Charter awarded; Regional Capital not awarded.
- Recovery resolution is `industrialUtilityExpansion`.
- Industrial focus `(4,8)` is level 3 at condition 0.64.
- No Industrial tile is below 0.4; exactly one remains in `[0.4, 0.75)`.
- Exact pressured replay reaches this state; exact terminal successor replay
  remains unchanged.
- State/spatial/diagnostic/activity digests reproduce exactly.

## Commands and exact results

Focused simulation and frozen-corpus matrix:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play083-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play083-swiftpm-cache \
  swift test --package-path Native/CitySimNative \
  --filter 'PLAY083LifecycleBindingTests|VisibleCityStateFixtureTests'
```

Result: 10 tests executed, 10 passed, 0 failures in 8.812 seconds.
PLAY-083 alone: 3/3 in 0.183 seconds.

Two independent materializations:

```text
CITYSIM_PLAY083_OUTPUT_ROOT=/private/tmp/citysim-play083-run-e.J418hb \
CITYSIM_PLAY083_CANDIDATE_COMMIT=7169c09bfd276be43a7180fdf61f5a519300c6c6 \
swift test --package-path Native/CitySimNative \
  --filter PLAY083LifecycleBindingTests.testWriteBindingCandidateOnlyWhenExplicitlyRequested

CITYSIM_PLAY083_OUTPUT_ROOT=/private/tmp/citysim-play083-run-f.XZGsv9 \
CITYSIM_PLAY083_CANDIDATE_COMMIT=7169c09bfd276be43a7180fdf61f5a519300c6c6 \
swift test --package-path Native/CitySimNative \
  --filter PLAY083LifecycleBindingTests.testWriteBindingCandidateOnlyWhenExplicitlyRequested

diff -qr /private/tmp/citysim-play083-run-e.J418hb \
  /private/tmp/citysim-play083-run-f.XZGsv9
```

Result: 1/1 passed in each run; recursive diff emitted no output. Both packets
were 5,089 bytes with SHA-256 `aca3974c2dc6a8386c1ef4f274d5154ae537d2415e50a2558c7417f8f044cb2e`.

Positive and 22-negative validator:

```text
env PYTHONDONTWRITEBYTECODE=1 python3 \
  docs/production/evidence/PLAY-083/validate_lifecycle_binding.py \
  --repo . \
  --packet docs/production/evidence/PLAY-083/binding-candidate.json \
  --self-test-negatives
```

Result: `PASS_CANDIDATE_FOR_INTEGRATION_REVIEW`, both mappings validated,
`PASS_22_OF_22`, QA `BLOCKED`.

Complete native suite:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play083-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play083-swiftpm-cache \
  swift test --package-path Native/CitySimNative
```

Result: 298 tests executed, 2 caller-input tests skipped, 1 failure. The sole
failure is renderer-owned
`CitySimulationTests.testRendererInitialRenderAndPulsesInvalidateOnlyChangedSpatialTruth`:
4.330 ms exceeds the unchanged 2.1 ms renderer threshold. All PLAY-083,
VisibleCityStates, persistence, replay, recovery, fingerprint, snapshot, and
negative gates passed. The threshold was not changed or suppressed.

## Performance and compatibility

- Visible corpus generation: 2,079.537 ms and 2,099.054 ms.
- Active: fingerprint 1.127 ms, snapshot 3.142 ms, save 8.475 ms,
  load 2.737 ms, 131,315 bytes.
- Recovering: fingerprint 1.145 ms, snapshot 3.215 ms, save 8.672 ms,
  load 2.755 ms, 134,184 bytes.
- Retained spatial samples: 92,160 bytes.
- Schema remains 1; fingerprint version remains 1.
- Exact primary load, paused store load with cleared Undo, byte-exact
  save round-trip, corrupt-primary backup recovery, immutable snapshot, and
  Undo restoration passed for both states.

## Integration handoff

Integration may independently validate
[`binding-candidate.json`](binding-candidate.json) and, if satisfied, publish a
separate binding authority that binds the request, proof candidate, exact
paths, blobs, hashes, and digests. Until then, the PLAY-075 blocker remains
preserved and QA rehearsal remains blocked.
