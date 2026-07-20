# PLAY-050 Wave 002 Automated Validation — 6e87d243

## Static and identity gates

- `git diff --check`: passed with no output.
- `bash -n script/build_and_run.sh`: passed with no output.
- `./script/build_and_run.sh --print-identity`: passed and printed the lane-specific identity retained in `manifest.md`.
- `git status --short --branch`: clean at the start of validation.

The first sandboxed SwiftPM attempt failed before candidate compilation because macOS nested sandbox setup returned `sandbox-exec: sandbox_apply: Operation not permitted`. The identical command was rerun outside that nested restriction with the same isolated caches; this environment failure is not attributed to the candidate.

## Independent full suite

Command:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play050-wave2-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play050-wave2-swift \
  swift test --package-path Native/CitySimNative --skip-build
```

Result at 2026-07-19 22:03–22:04 local time:

- 78 tests executed, 0 failures in 42.670 seconds.
- Command catalog: 8/8 passed.
- City simulation/UI harness: 36/36 passed.
- Gameplay loop: 14/14 passed.
- Session platform: 14/14 passed.
- World rendering: 6/6 passed.
- Renderer: 5,760 tile roots reused, zero updated, 2.315 ms unchanged-pulse average.
- Dense session: 47.300 ms / 400 ticks; fingerprint 1.599 ms; save 7.812 ms; load 3.382 ms; 135,456 bytes.
- Dense digest: `7b6454ecbe83aeb3bdc88de4fb1d6cb23ef67ce81849123e907d3147c6c52a77`.
- Lifecycle Reduce Motion diagnostic: three active actions normally, zero with Reduce Motion.

The green suite does not freeze or assert the dense fixture digest; the performance test only asserts round-trip equality and timing limits before printing the digest. It therefore did not catch the mismatch against the accepted completion record.

## Deterministic repeat

Command:

```text
env CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play050-wave2-clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play050-wave2-swift \
  swift test --package-path Native/CitySimNative --skip-build \
  --filter SessionPlatformTests/testDenseSessionSimulationAndPersistencePerformance
```

Result at 2026-07-19 22:04 local time:

- 1 test executed, 0 failures.
- Dense session: 53.464 ms / 400 ticks; fingerprint 2.221 ms; save 9.153 ms; load 4.072 ms; 135,456 bytes.
- Repeated digest: `7b6454ecbe83aeb3bdc88de4fb1d6cb23ef67ce81849123e907d3147c6c52a77`.

The full-suite and focused-run digests are identical and differ from the pre-published accepted value `fe710ac93dcb3d4bc4438157f777a2e2e8557397573b0d39f1d8ac3e5ab86cd5`.

## Classification

Automated behavior is broadly green, but the frozen fingerprint contract fails. Because this is an immediate rejection condition, staged-app and player-session validation were not started. Tests alone do not upgrade the candidate to playable or close D001/D002.
