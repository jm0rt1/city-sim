# PLAY-041 Completion — Authoritative Spatial Consequence Truth

- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Status:** ready-for-integration
- **Authority base:** `3e8ffe405b00783121c08a06fadc7e0335d7d7aa`
- **Approved contract:** additive derived-only spatial presentation map and deterministic transition events

## Player outcome

CitySim now has one deterministic answer for the service, pollution, and vitality at every map coordinate. The renderer, HUD, accessibility descriptions, diagnostics, and effects can consume the same immutable sample instead of independently guessing consequence truth. Recovery and worsening transitions also have stable replay-safe identities.

This platform slice intentionally changes no visible graphics or HUD. Its outcome is the authoritative boundary required for PLAY-022 and PLAY-032 to make spatial consequences compelling without creating competing simulation rules.

## Ordered commits

1. `4e04486267a514dd76786cc090ce619e2c23f482` — `PLAY-041: Propose spatial consequence truth`
2. `a6de23d3fb2c8b6d19aebb4d8e02fbc53565ebed` — `PLAY-041: Publish spatial consequence truth`
3. completion/evidence commit containing this record

## Exact implementation scope

- `Native/CitySimNative/Sources/CitySimNative/Models/CityPresentationSnapshot.swift`
- `Native/CitySimNative/Sources/CitySimNative/Models/CitySpatialConsequences.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/SpatialConsequenceTests.swift`
- `docs/production/evidence/PLAY-041/SPATIAL-CONSEQUENCE-CONTRACT-PROPOSAL.md`
- `docs/production/evidence/PLAY-041/IMPLEMENTATION-VALIDATION.md`
- `docs/production/claims/PLAY-041.simulation-platform.md`
- `docs/production/completed/PLAY-041.simulation-platform.md`

No persisted model, save service/schema, fingerprint version, gameplay balance, renderer, SwiftUI view, command, build script, package topology, or legacy Python file changed.

## Delivered semantics

- Immutable width/height/row-major map with 576 samples and O(1) coordinate lookup on the 24 x 24 vertical slice.
- Independent power, water, and combined utility values and authoritative bands.
- Pollution exposure/band and applicable-location vitality score/state.
- Active-source and active-location derivation only.
- Stable `spatial-v1` transition identity tied to the exact current canonical fingerprint.
- Deterministic row-major/dimension event order.
- Suppression on cold load, equal state, grid mismatch, non-forward tick, and vitality transitions involving `notApplicable`.
- Derived-only transient events; no persisted recovery meter or cold-load effect replay.

## Compatibility and deterministic evidence

- `SpatialConsequenceTests`: 9/9 passed.
- `SessionPlatformTests`: 14/14 passed in 2.312 seconds.
- Complete native suite: 100/100 passed in 227.620 seconds.
- Dense fingerprint remained `d18afceb9c8ccc09eaf54d7316abc960c6b560baa1bc7d92fa6416c9776556d8`.
- Schema-1 and legacy bare saves derive the same maps as their pre-save authoritative state.
- Save bytes and canonical state fingerprints are unchanged by snapshot derivation.
- Whole-state undo/replay restores exact maps and cannot emit a false non-forward recovery.

## Performance

Full-suite PLAY-041 diagnostic:

- spatial derivation average 1.238 ms, maximum 1.263 ms;
- transition diff 0.160 ms;
- representative event count 68;
- retained sample storage 46,080 bytes.

These results clear the approved 5 ms average / 10 ms maximum derivation, 2 ms average / 5 ms maximum diff, 1,728-event, and 128 KiB gates. Full details, including the corrected benchmark boundary, are retained in `docs/production/evidence/PLAY-041/IMPLEMENTATION-VALIDATION.md`.

## Exact staged candidate

`./script/build_and_run.sh --verify` built and launched product commit `a6de23d3fb2c8b6d19aebb4d8e02fbc53565ebed` with candidate identity `simulation-platform-w8bb1822a1e25`, isolated bundle/preference domain `com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`, and isolated data root `dist/test-data/simulation-platform-w8bb1822a1e25`. PID 24535 was confirmed alive at the exact staged executable. `bash -n` and `git diff --check` passed.

## Adoption order, limitations, and rollback

Integration should take PLAY-041 before PLAY-012, PLAY-022, and PLAY-032 adoption work. Gameplay may evolve the existing authoritative inputs but must not duplicate spatial formulas. Renderer and UI own presentation and cause/remedy language, not consequence truth. Quality independently owns agreement, accessibility, latency, save/load, undo, and event-deduplication acceptance.

The vertical slice does not model utility networks, land value, traffic, persisted incidents, or a durable recovery phase. Utility reach is the approved Manhattan-radius model and vitality is presentation truth, not a new economic rule. These are explicit scope boundaries, not hidden renderer inference.

Rollback removes the additive snapshot field/types/tests. No save migration or player-data repair is required. The worker has not pushed, merged, or changed `master`.
