# PLAY-072 Baseline Audit — Visible-City State Truth

- **Authority:** `e38059e721dae05c8df421754e3cb63ddf3fa153`
- **Accepted PLAY-069 ancestor:** `addc01c6b55ee4e93ba2aa1a789ca26cc97eda40`
- **Lane:** `codex/citysim-simulation-platform`
- **Date:** July 25, 2026

## Existing authoritative seam

The complete visible-city matrix can remain test-owned evidence built from
existing production truth:

- `CityGameState` owns tile kind, level, occupancy, condition, construction
  progress, strategy progression, second-act progression, and terminal status.
- `CityPresentationSnapshot` immutably copies the state, version-1
  fingerprint, analytics, and row-major `CitySpatialConsequenceMap`.
- `CitySpatialConsequenceMap` already publishes utility, pollution, vitality,
  developed-tile Land Value and Local Happiness, road Traffic Pressure, and
  transient street/place activity.
- `SaveGameService` already owns schema-1 envelopes, bare schema-0
  compatibility, exact digests, atomic primary/backup behavior, and recovery.

No persisted presentation field, district model, renderer enum, command,
package resource rule, schema change, or fingerprint-version change is
required.

## Honest lifecycle mapping

Each strategy can produce one sequential seven-state fixture route:

1. **vacant:** the committed-strategy opening state plus one valid empty,
   road-connected focus coordinate;
2. **construction:** the strategy's job-producing building accepted at that
   coordinate with authoritative zero construction progress;
3. **active:** four deterministic ticks complete that same building and
   rebalance occupancy;
4. **pressured:** replay reaches the accepted first-act complication;
5. **recovering:** replay reaches the accepted default recovery resolution;
6. **upgraded:** replay reaches the active Town Charter midpoint with the same
   focus place grown through normal upgrade rules; and
7. **terminal:** replay reaches the corresponding default-route Regional
   Capital terminal.

Commercial uses tax relief and Industrial uses utility expansion because those
are the already-frozen default recovery routes. PLAY-069 continues to own
four-route terminal coverage.

Pressure and recovery currently do not mutate `CityTile.condition`; production
simulation only initializes condition. Their honest visible truth is the
strategy phase plus existing spatial diagnostics and local-activity channels.
PLAY-072 must freeze that current behavior rather than fabricate a condition
scar or anticipate gameplay tuning.

## Compatibility and stop boundary

The new corpus will be additive under test `Fixtures/VisibleCityStates` and
will retain one focus coordinate in its test manifest. The coordinate selects
existing state; it is not production or persisted presentation state.

Validation must freeze:

- schema-1 state bytes, version-1 state fingerprint, complete spatial digest,
  diagnostic-channel digest, local-activity digest, and focus-tile identity;
- exact lifecycle replay between all seven states;
- primary load, corrupt-primary backup recovery, paused load, cleared undo,
  immutable snapshots, terminal rejection, and existing budgets;
- two independent corpus builds; and
- authentic schema-0/schema-1 and PLAY-047/069 corpus hashes.

Stop rather than implement if any state requires a new production contract,
gameplay outcome, renderer/UI change, package-topology edit, legacy fixture
rewrite, or unexplained drift.
