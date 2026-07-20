# PLAY-041 Implementation Validation

**Authority base:** `3e8ffe405b00783121c08a06fadc7e0335d7d7aa`

**Product commit:** `a6de23d3fb2c8b6d19aebb4d8e02fbc53565ebed`

**Date:** July 20, 2026

## Contract delivered

`CityPresentationSnapshot` now publishes one immutable `CitySpatialConsequenceMap`. Its 24 x 24 fixture maps contain 576 row-major samples with constant-time coordinate lookup. Every sample supplies independent power, water, and combined utility values and bands, pollution exposure and band, and applicable-location vitality score and state.

The implementation derives these values from active authoritative tiles and current utility totals only. Deterministic multi-source distance fields preserve the approved Manhattan-distance formulas without making cost depend on renderer nodes. No calculation feeds back into simulation, gameplay balance, progression, revenue, demand, happiness, construction, or terminal state.

Forward snapshot comparison emits sorted utility, pollution, and vitality transition events. IDs have the approved form `spatial-v1:<fingerprint-version>:<current-digest>:<x>:<y>:<dimension>:<from>:<to>`. Cold load, equal fingerprints, dimension mismatch, non-forward ticks, and vitality transitions involving `notApplicable` emit no event.

## Focused behavioral proof

`SpatialConsequenceTests` passed 9/9. The suite binds:

- 576-sample row-major shape, coordinate lookup, and out-of-bounds behavior;
- independent power and water pressure plus active-source-only reach;
- industrial and power pollution with monotonic park mitigation;
- vitality applicability, bounds, and representative health states;
- deterministic maps, stable IDs, row-major/dimension event ordering, and recovery/worsening direction;
- nil, equal-fingerprint, dimension-mismatch, undo/non-forward, and `notApplicable` suppression;
- schema-1 and legacy bare-state load equivalence;
- byte-identical save output and unchanged canonical state fingerprints before versus after derivation;
- exact undo/replay maps and immutable snapshot value ownership;
- one selected-coordinate value shared by renderer-style and UI-style consumers without duplicated formulas.

`SessionPlatformTests` passed 14/14 in 2.312 seconds. The accepted dense persisted fixture remained `dense-24x24-terminal-wave2-v3` at tick 44 / `.lost`, digest `d18afceb9c8ccc09eaf54d7316abc960c6b560baa1bc7d92fa6416c9776556d8`.

The complete native suite passed 100/100 in 227.620 seconds. The AppKit window tests require host execution; the accepted full run used writable scratch/module-cache paths outside the filesystem sandbox.

## Performance and bounds

The final full-suite diagnostic across accepted-start, commercial, industrial, utility-strained, recovered, and dense 24 x 24 fixtures reported:

- complete spatial derivation average: 1.238 ms, against the 5 ms target;
- complete spatial derivation maximum: 1.263 ms, against the 10 ms hard gate;
- transition diff: 0.160 ms, against the 2 ms target and 5 ms hard gate;
- representative transition count: 68, below the structural maximum of 1,728;
- retained sample storage: 46,080 bytes, below the 128 KiB target.

An initial diagnostic incorrectly timed fingerprint creation and cold fixture setup together with derivation, producing 5.51 ms average and 21.1 ms maximum. The benchmark boundary was corrected to measure the approved spatial derivation after one warm derivation per fixture; no product formula or acceptance threshold was relaxed. A subsequent focused run measured 1.183 ms average, 1.288 ms maximum, and 0.139 ms transition diff, consistent with the full-suite result.

Existing dense platform diagnostics remained healthy in the full run: simulation 44.415 ms, fingerprint 1.362 ms, schema-1 save 6.364 ms, validated load 2.990 ms, and 135,864-byte envelope. Snapshot derivation is neither serialized nor hashed.

## Exact staged-app proof

`bash -n script/build_and_run.sh` and `git diff --check` passed. `./script/build_and_run.sh --verify` built and launched the exact product commit `a6de23d3fb2c8b6d19aebb4d8e02fbc53565ebed` as:

- candidate: `simulation-platform-w8bb1822a1e25`;
- bundle/preference domain: `com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`;
- staged app: `dist/CitySim-simulation-platform-w8bb1822a1e25.app`;
- isolated data root: `dist/test-data/simulation-platform-w8bb1822a1e25`;
- exact executable: `dist/CitySim-simulation-platform-w8bb1822a1e25.app/Contents/MacOS/CitySimNative-w8bb1822a1e25`;
- PID 24535, confirmed alive against that exact executable after launch.

This platform slice deliberately introduces no visible renderer or HUD change. PLAY-022 and PLAY-032 can now present the same authoritative spatial truth; their live visual, accessibility, and player-comprehension proof remains an adoption gate rather than a claim of this commit.

## Compatibility and rollback

`CityGameState`, `CityTile`, `CityMessage`, save schema 1, fingerprint version 1, package topology, renderer, SwiftUI, and legacy Python are unchanged. Existing saves require no migration. Removing the additive snapshot field and spatial types fully rolls back this candidate without touching player data.
