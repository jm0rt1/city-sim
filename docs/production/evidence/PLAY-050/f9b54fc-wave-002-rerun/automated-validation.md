# PLAY-050 Wave 002 Rerun Automated Validation — f9b54fc

## Static and build gates

- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --print-identity`: passed with the repaired merge HEAD and lane-specific paths.
- `./script/build_and_run.sh --verify`: built and launched the exact staged quality bundle; exact PID `32451` remained alive.
- Staged executable and `Info.plist` hashes are retained in `manifest.md`.

## Full native suite

Command used isolated writable Swift module caches and `swift test --package-path Native/CitySimNative`.

Result at 2026-07-19 22:20–22:21 local time:

- 78 tests passed, 0 failures in 40.558 seconds.
- Command catalog: 8/8.
- City simulation/UI harness: 36/36.
- Gameplay loop: 14/14.
- Session platform: 14/14.
- World rendering: 6/6.
- Renderer: 5,760 roots reused, zero updates, 2.019 ms unchanged-pulse average.
- Lifecycle motion: three active actions normally and zero with Reduce Motion.
- Corrected dense fixture: `dense-24x24-terminal-wave2-v2`; 400 step attempts; final tick 44; status `.lost`; simulation 47.315 ms; fingerprint 1.518 ms; save 7.474 ms; load 4.385 ms; 135,456 bytes; digest `7b6454ecbe83aeb3bdc88de4fb1d6cb23ef67ce81849123e907d3147c6c52a77`.

## Two focused dense repeats

`SessionPlatformTests/testDenseSessionSimulationAndPersistencePerformance` was executed twice with `--skip-build`:

| Run | Simulation | Fingerprint | Save | Load | Final state | Digest |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | 50.683 ms | 2.197 ms | 7.947 ms | 3.677 ms | tick 44 / `.lost` | `7b6454ecbe83aeb3bdc88de4fb1d6cb23ef67ce81849123e907d3147c6c52a77` |
| 2 | 46.823 ms | 2.002 ms | 7.812 ms | 3.867 ms | tick 44 / `.lost` | `7b6454ecbe83aeb3bdc88de4fb1d6cb23ef67ce81849123e907d3147c6c52a77` |

The original D003 dense-fixture rejection is resolved for this repaired candidate: name, terminal tick/status, exact v1 digest, schema-1 equality, and performance independently pass.

## Boundary of this result

Automated and staged-build gates pass. They do not override the separate CONTRACT-004 live identity failure in `defects/PLAY-050-D004-duplicate-quality-preference-domain.md`. The frozen gate stopped before live D001/D002, command, persistence, accessibility, and 20-minute interaction.
