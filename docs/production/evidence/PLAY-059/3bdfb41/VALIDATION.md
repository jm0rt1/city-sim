# PLAY-059 Validation — Authoritative Spatial Diagnostic Truth

- **Authority:** `7db49768c2ce3181c29274bc75f280ed75ec6aa5`
- **Contract:** `CONTRACT-013`
- **Product/tests:** `3bdfb417e8350d97e405af55fa44790e582e0044`
- **Lane:** `codex/citysim-simulation-platform`
- **Date:** July 25, 2026

## Delivered invariant

For one exact `CityGameState`, every immutable presentation consumer now
receives the same optional, clamped, row-major values for:

- `landValueIndex` on completed non-road development;
- `localHappinessIndex` on completed non-road development; and
- `trafficPressure` on real road coordinates.

The fields are plain `Equatable`/`Sendable` values on
`CitySpatialConsequence`. They are not `Codable`, do not enter
`CityGameState`, and cannot change simulation, gameplay, commands, saves,
fingerprints, replay, or undo.

## Exact derivation

All inputs already exist in authoritative state and every result is clamped to
`0...1`.

Land Value is:

```text
20% direct road access
+ 25% combined utility service
+ 25% tile condition
+ 20% pollution safety
+ 10% active-park proximity within Manhattan radius 3
```

Local Happiness is:

```text
40% current city happiness
+ 20% combined utility service
+ 15% tile condition
+ 15% pollution safety
+ 10% active-park proximity within Manhattan radius 3
```

Traffic Pressure is potential pressure, not measured trips or congestion:

```text
25% adjacent-road topology
+ 75% nearby completed residential/commercial/industrial occupancy activity
```

Nearby activity uses Manhattan radius 3 and a decreasing distance weight.
Commercial and Industrial activity combine existing occupancy utilization with
their existing demand channel. Non-residential/job tiles contribute no
activity. The normalized activity and final value are clamped. Empty,
developed, and incomplete non-road coordinates publish `nil` Traffic Pressure.

## Deterministic fixture identities

The test-owned `spatial-diagnostics-v1` canonical diagnostic stream records
row-major coordinates and the exact optional `Double.bitPattern` for all three
channels. Frozen eight-story-state digests are:

| Story fixture | State fingerprint v1 | Diagnostic digest |
|---|---|---|
| commercial-opening-v1 | `530659316df479f38bdb9a2ba3ba20e17699ed376ac0999610f3c8cb9c4d99e6` | `aee4d9a138d5a207091879c1c71250e44a8aeae4143beaa9eff2f0aeaf572b47` |
| commercial-complication-v1 | `2a1b046eb21665206709415e3a1363aeaa0a9a4a60e83e1e1b52ae3c53b50ad4` | `73455e6d36a7bb989adad95d2e3368663dd9c907f47a5286bda54152df1275a7` |
| commercial-recovery-v1 | `2af6837e2176398673565c1ec893d77c29fe67505239d4234539baa3b053d1ff` | `a00476df33257fbb7a729c0ee60417a9e2f06be644c426defccbea1e13042406` |
| commercial-charter-victory-v1 | `58afce6edf8959ab62b9cfaf4e51157c7ba9de45280b2cff893a3b775e868e59` | `5806de89dc766fe4041c05e3e720e8af3931f088f3098717e38c21d192f36c33` |
| industrial-opening-v1 | `e603582568908a8acd9cd5e2143b2a86d32e58ae79f59b62fb4cb739e552ce05` | `afb5a8084e6400e49226a55527fc1382be2e8092ff285e3a9f25182040eaa50a` |
| industrial-complication-v1 | `a43611573cd888edba5292b9740b8a4e15f05e9cfd50edf73648427eaf775c5a` | `e89291b1d8606325e4e8e4ee3197f7c111a3865c55fbacd903f7f171dbef64e5` |
| industrial-recovery-v1 | `3ca0fc2094f85dd3dcabfab46cfe51039c927cd5cf44bad07b4f9d8c55b1accc` | `09e8d88251ae5a63e135ccd9ecb1a71630bd960311b567e44a475281e96f23a3` |
| industrial-charter-victory-v1 | `b1304ef634fc759ae1c0f0f5e56d4b51febb32c99f4f2cdbe3a1dd19885156f8` | `dd590d6fe6ffa8f949dba2988c4605917f85650532bd5838bb286f3b7d98ab9c` |

Repeated snapshots matched exactly. Tests also bind sample index
`y * width + x` to the sample coordinate and prove exact coordinate lookup.

## Applicability, clamping, and monotonicity

Focused tests prove:

- all three channels remain inside `0...1`, including extreme authoritative
  values;
- completed development publishes Land Value and Local Happiness but no
  Traffic Pressure;
- roads publish Traffic Pressure but no Land Value or Local Happiness;
- empty and incomplete development publish no diagnostic value;
- improving condition, utility, pollution safety, or park proximity increases
  both developed-tile indices locally;
- direct road access increases Land Value;
- city happiness increases Local Happiness without changing Land Value;
- adding connected road topology, nearby occupied housing, or job demand
  increases local Traffic Pressure;
- incomplete occupied development does not contribute traffic activity;
- deriving and retaining snapshots does not mutate the source state.

## Persistence and compatibility

Save schema remains 1 and fingerprint version remains 1. No saved model,
encoder, loader, command, store, or fixture resource changed.

Authentic input SHA-256 values remain:

- schema 0:
  `28c41c2a8c44adc0de49110ebb05ba0952f9deb4f9cb59c3f10035e7a925e908`;
- schema 1:
  `56ea7704735540d2a573aea7d96575d34d363e3583b5c90bb81ceb8b620e01b9`;
- story manifest:
  `3614c6f7cd6eeed473c499f05a29c122aa92858744a717cc2e34bdb98f72fef0`.

The dense canonical fingerprint remains
`113cce93fcbef4327d3e39665690dbf2fc6613683db6e1d362af8fa99c88b296`
and its schema-1 envelope remains 136,335 bytes. Schema-0/schema-1 load,
primary/backup recovery, corrupt-primary preservation, save/resume, replay,
undo, grouped speed, and terminal continuation all passed with exact
authoritative identity.

## Automated validation

Focused spatial suite:

```text
SpatialConsequenceTests: 13/13 passed in 2.198 seconds
```

Expanded platform compatibility matrix:

```text
BackupLoadAvailabilityTests
ProductionStoryStateFixtureTests
SessionPlatformTests
SpatialConsequenceTests
StrategyResolutionPlatformTests
TerminalVictoryPlatformTests

46/46 passed in 26.262 seconds
```

The restricted full-suite attempt exited with signal 11 when its first
AppKit-dependent `CityCommandCatalogTests` case began. The exact same command
was rerun with host access, as required for the AppKit inventory:

```text
210/210 passed in 99.862 seconds
WorldRenderingTests: 47/47 passed
```

Also passed:

- `git diff --check`;
- `git diff --cached --check`;
- `bash -n script/build_and_run.sh`;
- `bash -n script/persistence_relaunch_gate.sh`.

## Measured cost

From the complete 210-test host run across accepted start, Commercial,
Industrial, strained, recovered, and dense states:

- spatial derivation: 1.618 ms average, 2.092 ms maximum;
- complete immutable snapshot: 2.881 ms average, 3.327 ms maximum;
- transition diff: 0.132 ms;
- retained spatial samples: 73,728 bytes;
- dense session snapshot: 3.681 ms;
- dense simulation/fingerprint/save/load:
  48.469 / 1.347 / 5.980 / 3.166 ms.

The derived map stays under its existing 5 ms average / 10 ms maximum gate,
the complete snapshot stays under the PLAY-059 25 ms average / 50 ms maximum
gate, and retained samples remain below 128 KiB. The prior retained footprint
grew from 46,080 to 73,728 bytes solely because each of 576 immutable samples
now retains three optional `Double` channels.

## Exact staged runtime

`./script/build_and_run.sh --verify` built and launched exact product commit
`3bdfb417e8350d97e405af55fa44790e582e0044`:

- candidate `simulation-platform-w8bb1822a1e25`;
- bundle/preference domain
  `com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`;
- isolated data root
  `dist/test-data/simulation-platform-w8bb1822a1e25`;
- manifest
  `dist/manifests/simulation-platform-w8bb1822a1e25.manifest`;
- PID 58945, confirmed alive at the exact staged executable;
- manifest status `verified-running`.

PLAY-059 intentionally changes no visible renderer or HUD behavior.
Consequently, staged proof establishes exact build/launch and consumer
compatibility, not visual overlay acceptance. PLAY-056 may adopt these typed
values only after integration accepts this candidate.

## Rollback and stop boundary

Rollback removes the three optional fields, their derivation, and the focused
goldens. No player-data migration or fixture regeneration is required.

This candidate does not contain renderer/UI/gameplay/package/build-script
edits, measured traffic/trips, a routing model, a land-price economy, a local
happiness simulation, schema/fingerprint changes, or legacy fixture rewrites.
