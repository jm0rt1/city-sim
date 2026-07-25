# CONTRACT-016: Authoritative local activity presentation

**Status:** Approved for ordered PLAY-065 then PLAY-066 adoption

**Date:** July 25, 2026

**Owner:** Integration

## Player outcome

The city visibly feels busier around real successful places and quieter around
empty, failing, or disconnected places without pretending CitySim simulates
individual trips or citizens.

## Approved contract

1. `CitySpatialConsequence` may add two optional presentation-only channels:
   - `streetActivityIndex` on real road tiles; and
   - `placeActivityIndex` on completed developed, civic, service, utility, and
     park tiles where local activity is meaningful.
2. Values are clamped to `0...1`, deterministic, row-major stable, and `nil`
   where not applicable.
3. Street activity may combine existing adjacent occupancy/job capacity,
   authoritative traffic pressure, connectivity, and nearby place vitality.
4. Place activity may combine existing building kind, occupancy/capacity,
   condition, utility service, local happiness, pollution exposure, and
   authoritative park/civic presence.
5. These are qualitative presentation indices, not person counts, vehicles,
   trips, routes, schedules, measured congestion, or new simulation rules.
6. The channels live only in the immutable spatial/presentation snapshot.
   They are not encoded, fingerprinted, persisted, replayed, or permitted to
   affect gameplay outcomes.
7. After PLAY-065 acceptance, PLAY-066 may use the indices to choose bounded,
   deterministic ambient presence and animation. Zero or `nil` must visibly
   suppress that activity. Reduce Motion must preserve meaning without motion.
8. Renderer accessibility and evidence must describe `local activity` or
   `activity pressure`; it must not expose invented counts or routes.

## Required proof

- applicability and nil boundaries for every tile family;
- repeat-identical samples and unchanged source state;
- monotonic fixtures for occupancy, connection, condition, service, and
  recovery;
- exact save bytes, fingerprints, undo, replay, and continuation;
- bounded snapshot construction cost and memory; and
- renderer adoption proving deterministic placement, no collision or
  occlusion, zero activity at nil/zero, LOD behavior, and bounded residency.

## Rejected expansion

This contract does not authorize a traffic simulator, route finder, agent
population, individual schedules, economic rebalance, persisted activity,
renderer inference outside the typed values, or HUD-reported counts.
