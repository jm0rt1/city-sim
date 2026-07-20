# PLAY-041 Spatial Consequence Contract Proposal

**Status:** Proposed; no shared public contract implementation is authorized

**Authority base:** `3e8ffe405b00783121c08a06fadc7e0335d7d7aa`

**Owner:** Simulation platform derives immutable truth; gameplay owns authoritative inputs; renderer and UI consume values without recomputing them.

## Problem and invariant

The accepted renderer currently computes utility reach, pollution, and local amenity/economic proxies directly from `CityGameState`. These formulas live in `WorldOverlayRenderer`, so SpriteKit—not simulation/presentation—decides what is true. `LotConsequencePresentation` correctly refuses to infer utility or environmental state that is absent from the model, leaving authored world consequences unable to represent those states honestly.

The invariant is: for one exact authoritative state, every UI, renderer, accessibility, audio, diagnostic, save/replay, and test consumer receives the same immutable per-coordinate consequence values and the same deterministic transition identities. Consumers choose presentation, not truth.

## Smallest additive public shape

Add a value-owned spatial map to `CityPresentationSnapshot`:

```swift
struct CityPresentationSnapshot: Equatable, Sendable {
    let state: CityGameState
    let fingerprint: CityStateFingerprint
    let spatialConsequences: CitySpatialConsequenceMap

    func consequenceEvents(
        since previous: CityPresentationSnapshot?
    ) -> [CitySpatialConsequenceEvent]
}

struct CitySpatialConsequenceMap: Equatable, Sendable {
    let width: Int
    let height: Int
    let samples: [CitySpatialConsequence] // authoritative row-major order

    subscript(_ coordinate: GridCoordinate) -> CitySpatialConsequence? { get }
}

struct CitySpatialConsequence: Identifiable, Equatable, Sendable {
    var id: GridCoordinate { coordinate }
    let coordinate: GridCoordinate
    let utility: CityLocationUtilityService
    let pollutionExposure: Double // closed 0...1, 0 is clean
    let vitalityScore: Double     // closed 0...1
    let vitality: CityLocationVitality
}

struct CityLocationUtilityService: Equatable, Sendable {
    let power: Double    // closed 0...1
    let water: Double    // closed 0...1
    let combined: Double // min(power, water)
    let band: CityConsequenceBand
}

enum CityLocationVitality: Int, Equatable, Sendable {
    case notApplicable
    case strained
    case stable
    case prosperous
}

enum CityConsequenceBand: Int, Equatable, Sendable {
    case severe
    case strained
    case healthy
}

struct CitySpatialConsequenceEvent: Identifiable, Equatable, Sendable {
    let id: String
    let authoritativeTick: Int
    let coordinate: GridCoordinate
    let dimension: CitySpatialConsequenceDimension
    let direction: CitySpatialConsequenceDirection
    let fromBand: CityConsequenceBand
    let toBand: CityConsequenceBand
}

enum CitySpatialConsequenceDimension: String, Equatable, Sendable {
    case utility
    case pollution
    case vitality
}

enum CitySpatialConsequenceDirection: String, Equatable, Sendable {
    case worsening
    case recovery
}
```

No mutable cache, SpriteKit/AppKit/SwiftUI value, closure, consumer state, or second simulation authority enters the snapshot.

## Exact derivation

All calculations use active tiles only (`constructionProgress >= 1`), clamp to `0...1`, and iterate samples in authoritative row-major tile order.

### Utility service

For each coordinate and each utility independently:

1. Source reach is `max(0, 1 - ManhattanDistance / 12)` from the nearest active source; an active source coordinate has reach `1`.
2. Capacity factor is `min(1, capacity / max(1, used))` for that utility.
3. Service is `min(sourceReach, capacityFactor)`; no source means `0`.
4. Combined service is `min(power, water)`.
5. Band thresholds are `severe < 0.50`, `strained < 0.85`, and `healthy >= 0.85`.

This replaces the renderer's current binary shared capacity factor and makes power and water independently inspectable without creating a network graph that the vertical slice does not possess.

### Pollution exposure

Preserve the accepted overlay's deterministic local source model, but publish exposure rather than a renderer-specific cleanliness color:

- nearest industrial influence within radius 6, weight `0.62`;
- nearest power-plant influence within radius 8, weight `0.82`;
- nearest park relief within radius 3, weight `0.16`;
- exposure is `clamp(industrial + power - parkRelief)`.

Pollution bands for transition comparison are `healthy < 0.25`, `strained < 0.55`, and `severe >= 0.55`. Because high exposure is bad, its comparison order is inverted when producing direction.

### Prosperity and strain

`notApplicable` covers empty, road, and incomplete tiles. Active locations use only existing authoritative inputs:

- 30% tile condition;
- 25% utilization (`occupancy / capacity`) for residential/commercial/industrial, otherwise 1;
- 20% combined utility service;
- 15% pollution safety (`1 - exposure`);
- 10% city happiness (`happiness / 100`).

The clamped weighted result is `vitalityScore`. Vitality is `strained < 0.45`, `stable < 0.72`, and `prosperous >= 0.72`. This is presentation truth only: it never feeds revenue, demand, happiness, progression, construction, or terminal state. Gameplay remains the sole owner of those rules and of future changes to authoritative condition/occupancy inputs.

## Recovery and stable event identity

Recovery is a transition, not another persisted meter. `consequenceEvents(since:)` compares two immutable snapshots in row-major order and dimension order (`utility`, `pollution`, `vitality`):

- movement toward a healthier band emits `.recovery`;
- movement toward a worse band emits `.worsening`;
- unchanged bands emit nothing;
- `previous == nil`, equal fingerprints, different grid dimensions, or `previous.authoritativeTick >= current.authoritativeTick` emits nothing, preventing cold-load and undo animation replay.

An event ID is reconstructed exactly as:

```text
spatial-v1:<current fingerprint digest>:<x>:<y>:<dimension>:<from raw>:<to raw>
```

It is stable across deterministic replay of the same transition, unique across coordinates/dimensions/exact current states, and independent of renderer node identity. Consumers may deduplicate effects by this ID. The event is transient and is intentionally not replayed after a cold load; the durable loaded sample still exposes the current strain or health truth.

## Persistence, compatibility, and fingerprint consequences

- `CityGameState`, `CityTile`, `CityMessage`, save schema 1, and fingerprint version 1 do not change.
- Spatial samples and transition events are derived presentation data and are not Codable or persisted.
- Existing and legacy saves decode exactly as today; a snapshot derived after load contains the same spatial values as one derived before saving the same authoritative state.
- Save byte count and canonical state fingerprint are byte-for-byte unchanged.
- Undo restores the previous authoritative state/fingerprint; snapshot derivation restores its exact spatial map. No transient recovery event is emitted across non-forward tick movement.
- Rollback removes the additive snapshot field/types and returns consumers to the old raw-state boundary without any save migration.

If PLAY-012 later needs a recovery phase that must survive independently of current condition/occupancy/service state, that is a separate additive persisted gameplay proposal. It is not smuggled into this presentation contract.

## Performance and bounds

For the fixed 24 x 24 vertical-slice city:

- exactly 576 samples, indexed in O(1) by `y * width + x`;
- source lists are collected once; derivation is bounded by tiles multiplied by active source count, never renderer node count;
- complete spatial derivation target: <= 5 ms average and <= 10 ms hard gate in the dense 24 x 24 fixture;
- transition diff target: <= 2 ms average and <= 5 ms hard gate;
- at most 3 transition events per coordinate per compared snapshot (1,728 hard structural maximum);
- retained map storage target: <= 128 KiB excluding the already-owned `CityGameState`;
- no save-size or fingerprint-time change because presentation data is not serialized or hashed.

Measurements must cover the accepted start, commercial, industrial, utility-strained, recovered, and dense fixtures—not an empty map alone.

## Affected lanes and adoption order

1. **Integration** approves or adjusts this shared snapshot contract and field semantics.
2. **PLAY-041 platform** implements deterministic derivation, snapshot/event tests, save/fingerprint compatibility, and performance evidence.
3. **PLAY-012 gameplay** may change existing authoritative inputs but consumes the contract; it does not define renderer truth.
4. **PLAY-022 renderer** replaces utility/pollution inference in `WorldOverlayRenderer` and passes samples to lot/effect presentation. It owns colors, materials, animation, LOD, and accessibility-safe visual treatments only.
5. **PLAY-032 UI/input** uses the same selected-coordinate sample for cause/remedy text and accessible values; it does not recalculate formulas.
6. **PLAY-051 quality** verifies UI/world agreement, deterministic replay, save/load, undo, recovery event deduplication, and consequence latency.

Land value, traffic, general happiness overlays, audio design, gameplay balance, network simulation, and persisted incident lifecycles remain out of scope.

## Required tests

- map count, row-major ordering, coordinate lookup, bounds, and immutability;
- independent power/water capacity pressure and active-source-only reach;
- pollution source, distance, and park-mitigation monotonicity;
- vitality bounds, applicability, and representative prosperous/strained fixtures;
- deterministic repeated maps and transition IDs;
- stable event sort order, recovery/worsening direction, nil/equal/undo suppression;
- identical spatial map before save and after schema-1 load, plus legacy schema-0 load;
- exact state fingerprint and save bytes unchanged by snapshot derivation;
- whole-state undo restores exact map and emits no false forward recovery;
- snapshot consumers cannot mutate authoritative state;
- accepted-start, two strategy, strained/recovered, and dense performance budgets;
- consumer examples proving renderer and UI receive identical selected-coordinate values.
