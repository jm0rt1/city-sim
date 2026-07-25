# PLAY-059 Completion — Authoritative Spatial Diagnostic Truth

- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Status:** ready for integration
- **Authority:** `7db49768c2ce3181c29274bc75f280ed75ec6aa5`
- **Contract:** `CONTRACT-013`
- **Product/tests:** `3bdfb417e8350d97e405af55fa44790e582e0044`
- **Evidence:** `docs/production/evidence/PLAY-059/3bdfb41/VALIDATION.md`
- **Completion commit:** reported in the simulation-platform handoff

## Player outcome

Land Value, Local Happiness, and Traffic Pressure now have one deterministic,
coordinate-level presentation truth. Renderer and UI adoption can consume
typed values instead of guessing from raw city state or showing legend-only
modes.

This platform result is intentionally not yet visible. Integration must accept
it before PLAY-056 adopts the fields in SpriteKit, and quality retains visual,
non-color, accessibility, and player-comprehension acceptance.

## Exact changed surfaces

Product and tests:

- `Native/CitySimNative/Sources/CitySimNative/Models/CitySpatialConsequences.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/SpatialConsequenceTests.swift`

Evidence and disposition:

- `docs/production/evidence/PLAY-059/3bdfb41/VALIDATION.md`
- `docs/production/claims/PLAY-059.simulation-platform.md`
- `docs/production/completed/PLAY-059.simulation-platform.md`

No renderer, SwiftUI, gameplay, store, command, package, build script, save
service, schema, fingerprint algorithm/version, authentic fixture, or legacy
Python file changed.

## Delivered contract

- Optional `landValueIndex` and `localHappinessIndex` exist only on completed
  developed tiles.
- Optional `trafficPressure` exists only on road tiles and explicitly denotes
  deterministic potential pressure rather than measured trips or congestion.
- All values are clamped, immutable, row-major, coordinate-stable, and derived
  from existing authoritative state.
- Land Value responds locally to road access, utility service, condition,
  pollution safety, and active-park proximity.
- Local Happiness combines city happiness with local utility, condition,
  pollution safety, and active-park proximity without feeding gameplay
  happiness.
- Traffic Pressure combines road topology with nearby completed occupancy and
  existing Commercial/Industrial demand.
- Empty/incomplete/non-applicable coordinates publish `nil`.
- Eight story states have frozen diagnostic-channel digests while retaining
  their exact version-1 state fingerprints.

## Compatibility and proof

- Focused spatial suite: 13/13 passed.
- Expanded platform matrix: 46/46 passed in 26.262 seconds.
- Complete host native suite: 210/210 passed in 99.862 seconds.
- `WorldRenderingTests`: 47/47 passed without renderer adoption.
- Authentic schema-0/schema-1 bytes and all eight schema-1 story resources
  remain unchanged.
- Save schema remains 1; fingerprint version remains 1.
- Dense fingerprint remains
  `113cce93fcbef4327d3e39665690dbf2fc6613683db6e1d362af8fa99c88b296`.
- Save/load, backup recovery, corrupt-primary preservation, replay, undo,
  grouped speed, immutable snapshots, and terminal behavior remain exact.
- Derivation measured 1.618 ms average / 2.092 ms maximum; complete snapshot
  2.881 / 3.327 ms; retained samples 73,728 bytes.
- Shell syntax, diff checks, and exact staged `--verify` passed.

The restricted full-suite attempt crashed at the first AppKit-dependent test;
the required host-access rerun passed all 210 cases. This environment boundary
is recorded in the retained evidence rather than hidden.

## Staged runtime and limitations

Exact staged product `3bdfb417e8350d97e405af55fa44790e582e0044`
ran as isolated candidate `simulation-platform-w8bb1822a1e25`, bundle and
preference domain
`com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`, with isolated
data root `dist/test-data/simulation-platform-w8bb1822a1e25`. PID 58945 was
confirmed alive and its manifest reported `verified-running`.

No visible overlay was implemented or self-scored. Traffic is not measured
vehicle truth, Land Value is not a currency/economy rule, and Local Happiness
does not replace city happiness.

## Integration order and rollback

Integration should accept PLAY-059 before PLAY-056 overlay adoption.
Renderer/UI consumers may read the typed optionals but must not duplicate the
formulas or imply measured traffic.

Rollback removes this additive snapshot-only product commit and its tests.
No schema migration, save repair, fixture regeneration, or player-data action
is required.
