# CONTRACT-013: Authoritative spatial diagnostic channels

**Status:** Approved for ordered implementation

**Date:** July 25, 2026

**Owner:** Integration

## Player outcome

Land Value, Traffic, and Happiness change the visible world in ways that are
localized, deterministic, truthful, and actionable instead of remaining
legend-only modes or renderer-authored guesses.

## Current blocker

`CitySpatialConsequence` currently carries coordinate-level Utilities,
Pollution, and vitality truth. `WorldOverlayRenderer` explicitly rejects Land
Value, Traffic, and Happiness because no approved coordinate-level values
exist for those modes. PLAY-056 may not infer them in SpriteKit.

## Approved contract

1. `CitySpatialConsequence` may add three presentation-only optional channels:
   - `landValueIndex` on completed developed tiles;
   - `localHappinessIndex` on completed developed tiles; and
   - `trafficPressure` on road tiles.
2. Every value is clamped to `0...1`, derived deterministically from existing
   authoritative state, and `nil` where the channel is not applicable.
3. Land Value may combine existing road access, utility service, condition,
   pollution exposure, and park proximity. It is a diagnostic index, not a
   currency value and not a new economy rule.
4. Local Happiness may combine the existing city happiness value with local
   utility, condition, pollution, and park proximity. It does not replace or
   feed the simulation's authoritative city happiness.
5. Traffic Pressure may combine existing nearby occupancy/job demand and road
   topology for each real road coordinate. It describes deterministic
   potential pressure, not measured vehicles, trips, congestion, or routing.
6. The fields live only in the immutable presentation/spatial snapshot. They
   are not encoded, fingerprinted, replayed, persisted, simulated, or used to
   change gameplay outcomes.
7. PLAY-056 may consume only these typed values. It must render Land Value and
   Local Happiness on applicable developed lots and Traffic Pressure on real
   road tiles, with distinct non-color patterns and selection-safe geometry.
8. Player-facing accessibility and legend copy must say `Traffic pressure`
   and must not imply measured vehicle counts.

## Compatibility and proof

- No save schema, package, command, store, gameplay, or renderer-input shape
  outside the existing presentation snapshot changes.
- Existing Utilities, Pollution, vitality, fingerprints, save bytes, story
  fixtures, undo, replay, and deterministic continuation remain exact.
- Tests must prove nil/applicability boundaries, repeat identity,
  row-major/coordinate identity, monotonic local changes, no state mutation,
  and bounded snapshot construction cost.
- Renderer adoption occurs only after the simulation-platform candidate is
  accepted into `master`.

## Rejected expansion

This contract does not authorize a traffic simulator, route finder, land-price
economy, neighborhood happiness gameplay system, save migration, HUD redesign,
or renderer-local inference.
