# PLAY-065 Validation — Authoritative Local Activity

- **Authority:** `0ed9f3a8ad28d6b29f734c97f3dd3111fd118cc6`
- **Contract:** `CONTRACT-016`
- **Product/tests:** `aadbc3e4b0192d1c8aec1a753817c57ca5ff0f01`
- **Lane:** `codex/citysim-simulation-platform`
- **Date:** July 25, 2026

## Delivered invariant

For one exact `CityGameState`, every immutable presentation consumer receives
the same row-major, coordinate-stable, clamped optional values:

```swift
let streetActivityIndex: Double?
let placeActivityIndex: Double?
```

`streetActivityIndex` is non-`nil` only when `tile.kind == .road`.
`placeActivityIndex` is non-`nil` only for completed Residential, Commercial,
Industrial, Park, Power Plant, Water Tower, Fire Station, Police Station,
School, and City Hall tiles. Empty land and incomplete places publish `nil`.
A real but inactive isolated road publishes `0`, making absence of applicable
activity distinct from non-applicability.

The values are plain `Equatable`/`Sendable` snapshot data. They are not
`Codable`, do not enter `CityGameState`, and cannot change commands, gameplay,
saves, fingerprints, replay, or undo.

## Exact derivation

All inputs already exist in authoritative state. Every term and final value is
clamped to `0...1`.

Street Activity is:

```text
25% adjacent-road connection count / 4
+ 45% existing authoritative trafficPressure
+ 30% nearby completed-place vitality
```

Nearby vitality uses the existing `vitalityScore` within Manhattan radius 3,
with weight `1 - distance / 4`, normalized by 4. It denotes qualitative local
activity pressure, not people, vehicles, trips, routes, schedules, or measured
congestion.

Place Activity is:

```text
15% direct road access
+ 25% occupancy/capacity for Residential, Commercial, and Industrial,
     or 1 for authoritative Park, Utility, Service, and Civic presence
+ 20% tile condition
+ 15% combined utility service
+ 15% existing localHappinessIndex
+ 10% pollution safety
```

## Applicability, monotonicity, and identity

Focused tests cover every `BuildingKind`, incomplete places, zero-versus-`nil`
meaning, and extreme clamping. Isolated fixtures prove:

- connection increases Place Activity;
- occupancy increases both Place and adjacent Street Activity;
- condition increases both indices;
- restored power/water service increases both indices;
- a combined happiness/service/condition/occupancy recovery increases both;
- repeated snapshots are exactly equal and preserve the source state; and
- sample index `y * width + x` remains bound to its coordinate.

The pre-existing `spatial-diagnostics-v1` digests did not change. PLAY-065
freezes a separate `local-activity-v1` canonical stream of row-major
coordinates and exact optional `Double.bitPattern` values:

| Story fixture | State fingerprint v1 | Local activity digest |
|---|---|---|
| commercial-opening-v1 | `530659316df479f38bdb9a2ba3ba20e17699ed376ac0999610f3c8cb9c4d99e6` | `21e4927edde685eae5c23378d0290e88386300c1675f548f21ed8e438b08f5c2` |
| commercial-complication-v1 | `2a1b046eb21665206709415e3a1363aeaa0a9a4a60e83e1e1b52ae3c53b50ad4` | `07296cfe78941dcf2a0597171623d90eded97c514e091665c13549a290e163c5` |
| commercial-recovery-v1 | `2af6837e2176398673565c1ec893d77c29fe67505239d4234539baa3b053d1ff` | `9b032f071496b9f45ef4787291d0dcc00b1b121007d3ac0a5441750aca7e0d4e` |
| commercial-charter-victory-v1 | `58afce6edf8959ab62b9cfaf4e51157c7ba9de45280b2cff893a3b775e868e59` | `a57786ae493774b289dfe51d9fbbf65b632ef24bad8dc4c193dff35653e15319` |
| industrial-opening-v1 | `e603582568908a8acd9cd5e2143b2a86d32e58ae79f59b62fb4cb739e552ce05` | `7039a2d2b77e202772726611f1e98854c1537d289bd38383c17ddeb70cfcda75` |
| industrial-complication-v1 | `a43611573cd888edba5292b9740b8a4e15f05e9cfd50edf73648427eaf775c5a` | `b7b84220d43c4fc4e785d9287a04d78239e29f123327885922969c72f16c1bac` |
| industrial-recovery-v1 | `3ca0fc2094f85dd3dcabfab46cfe51039c927cd5cf44bad07b4f9d8c55b1accc` | `80d2971381a37e39851529e80614e1f395f14d27445487aa60d292f49e8c4d99` |
| industrial-charter-victory-v1 | `b1304ef634fc759ae1c0f0f5e56d4b51febb32c99f4f2cdbe3a1dd19885156f8` | `7a9373a5ef1506c1d3ba85e3fe05222ca89ab2d09a5a44ab5a42d9c9f13aae52` |

Two consecutive focused runs reproduced all eight digests exactly.

## Persistence and compatibility

Save schema remains 1 and fingerprint version remains 1. No saved model,
encoder, loader, command, store, package, or fixture resource changed.

Authentic input SHA-256 values remain:

- schema 0:
  `28c41c2a8c44adc0de49110ebb05ba0952f9deb4f9cb59c3f10035e7a925e908`;
- schema 1:
  `56ea7704735540d2a573aea7d96575d34d363e3583b5c90bb81ceb8b620e01b9`;
- story manifest:
  `3614c6f7cd6eeed473c499f05a29c122aa92858744a717cc2e34bdb98f72fef0`.

The dense canonical fingerprint remains
`113cce93fcbef4327d3e39665690dbf2fc6613683db6e1d362af8fa99c88b296`
and its schema-1 envelope remains 136,335 bytes. Exact save/load, schema-0
load, primary/backup recovery, corrupt-primary preservation, replay, undo,
grouped speed, immutable snapshot, and terminal continuation passed.

## Automated validation

Focused spatial suite, twice:

```text
15/15 passed in 2.295 seconds
15/15 passed in 2.252 seconds
```

Expanded platform compatibility matrix:

```text
BackupLoadAvailabilityTests
ProductionStoryStateFixtureTests
SessionPlatformTests
SpatialConsequenceTests
StrategyResolutionPlatformTests
TerminalVictoryPlatformTests

48/48 passed in 30.739 seconds
```

The restricted full-suite attempt passed 4 cases, then exited with signal 11
when its first AppKit-dependent `CityCommandCatalogTests` case began. The exact
same command reran with host access:

```text
228/228 passed in 121.138 seconds
WorldRenderingTests: 55/55 passed
```

Also passed:

- `git diff --check`;
- `git diff --cached --check`;
- `bash -n script/build_and_run.sh`;
- `bash -n script/persistence_relaunch_gate.sh`.

## Measured cost

Across the two repeated focused runs:

- spatial derivation: 2.392 / 2.316 ms average and 3.436 / 3.247 ms maximum;
- complete snapshot: 3.500 / 3.640 ms average and 4.346 / 4.495 ms maximum;
- retained 24 x 24 samples: 92,160 bytes.

The complete host run measured 2.727 ms average / 4.270 ms maximum spatial
derivation and 3.952 / 5.143 ms complete snapshot construction. Dense session
simulation/fingerprint/snapshot/save/load measured
47.048 / 1.449 / 4.915 / 7.310 / 3.847 ms.

All values remain below the existing 5 ms average / 10 ms maximum derivation,
25 / 50 ms snapshot, and 128 KiB retained-sample gates. The retained footprint
increased from 73,728 to 92,160 bytes solely because 576 immutable samples now
retain two additional optional `Double` values.

## Exact staged runtime

`./script/build_and_run.sh --verify` built and launched product commit
`aadbc3e4b0192d1c8aec1a753817c57ca5ff0f01`:

- candidate `simulation-platform-w8bb1822a1e25`;
- bundle/preference domain
  `com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`;
- display name `CitySim [Simulation w8bb1822a1e25]`;
- isolated data root
  `dist/test-data/simulation-platform-w8bb1822a1e25`;
- manifest
  `dist/manifests/simulation-platform-w8bb1822a1e25.manifest`;
- PID 44367, confirmed alive at the exact staged executable;
- manifest status `verified-running`.

PLAY-065 intentionally changes no visible renderer or HUD behavior. Staged
proof establishes exact build/launch and consumer compatibility, not visual
activity acceptance. PLAY-066 may adopt the typed values only after integration
accepts this platform candidate.

## Rollback and stop boundary

Rollback removes the two optional snapshot fields, derivation, and focused
activity goldens. No player-data migration or fixture regeneration is needed.

This candidate contains no renderer/UI/gameplay/package/build-script edits,
agent/trip/route/schedule simulation, measured traffic, economic rebalance,
persisted activity, schema/fingerprint change, or authentic fixture rewrite.
