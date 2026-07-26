# PLAY-065 Completion — Authoritative Local Activity

- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Status:** ready for integration
- **Authority:** `0ed9f3a8ad28d6b29f734c97f3dd3111fd118cc6`
- **Contract:** `CONTRACT-016`
- **Product/tests:** `aadbc3e4b0192d1c8aec1a753817c57ca5ff0f01`
- **Evidence:** `docs/production/evidence/PLAY-065/aadbc3e/VALIDATION.md`
- **Evidence/completion commit:** reported in the simulation-platform handoff

## Player outcome

Street and place activity now have one deterministic, coordinate-level
presentation truth. After integration acceptance, the renderer can make real
connected streets and successful places feel busier while suppressing activity
at empty, incomplete, failed, or disconnected locations—without inventing
people, vehicles, trips, or routes.

## Exact changed surfaces

Product and tests:

- `Native/CitySimNative/Sources/CitySimNative/Models/CitySpatialConsequences.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/SpatialConsequenceTests.swift`

Evidence and disposition:

- `docs/production/evidence/PLAY-065/aadbc3e/VALIDATION.md`
- `docs/production/claims/PLAY-065.simulation-platform.md`
- `docs/production/completed/PLAY-065.simulation-platform.md`

No renderer, SwiftUI, gameplay, store, command, package, build script, save
service, schema, fingerprint algorithm/version, authentic fixture, or legacy
Python file changed.

## Typed renderer adoption contract

- `CitySpatialConsequence.streetActivityIndex: Double?`
  - non-`nil` only for `.road`;
  - `0` means an applicable road with no current local activity pressure;
  - combines connection, existing Traffic Pressure, and nearby completed-place
    vitality;
  - never denotes a count, trip, route, schedule, or measured congestion.
- `CitySpatialConsequence.placeActivityIndex: Double?`
  - non-`nil` only for completed developed, Park, Utility, Service, and Civic
    places;
  - combines road access, occupancy/capacity or authoritative place presence,
    condition, utility service, Local Happiness, and pollution safety;
  - empty land, roads, and incomplete places publish `nil`.
- Both values are clamped to `0...1`, immutable, transient, row-major stable,
  coordinate-identical, and repeat-deterministic.
- Existing initializer call sites default both values to `nil`, so renderer
  fixtures do not fabricate activity.
- Renderer adoption must visibly suppress activity at `nil` or zero, stay
  bounded/deterministic, preserve Reduce Motion meaning, and use the language
  `local activity` or `activity pressure`.

## Compatibility and proof

- Focused spatial suite: 15/15 passed twice.
- Expanded platform matrix: 48/48 passed.
- Complete native suite: 228/228 passed in 121.138 seconds.
- `WorldRenderingTests`: 55/55 passed without renderer adoption.
- All eight `local-activity-v1` story digests repeated exactly while the
  pre-existing diagnostic digests and version-1 state fingerprints stayed
  frozen.
- Authentic schema-0/schema-1 bytes and story resources remain unchanged.
- Save schema remains 1; fingerprint version remains 1.
- Dense fingerprint/save remain
  `113cce93fcbef4327d3e39665690dbf2fc6613683db6e1d362af8fa99c88b296`
  and 136,335 bytes.
- Save/load, backup recovery, corrupt-primary preservation, replay, undo,
  grouped speed, immutable snapshots, and terminal behavior remain exact.
- Derivation measured at most 4.270 ms; complete snapshot at most 5.143 ms;
  retained samples are 92,160 bytes.
- Shell syntax, diff checks, and exact staged `--verify` passed.

The restricted full suite hit the known AppKit signal-11 environment boundary;
the exact host-access rerun passed all 228 cases. No visible activity was
implemented or self-scored.

## Integration order and rollback

Integration should accept PLAY-065 before PLAY-066 renderer adoption. The
renderer may consume only these typed values and must not duplicate formulas or
infer people, trips, routes, schedules, or measured congestion.

Rollback removes the additive snapshot product commit and its tests. No schema
migration, save repair, fixture regeneration, or player-data action is needed.
