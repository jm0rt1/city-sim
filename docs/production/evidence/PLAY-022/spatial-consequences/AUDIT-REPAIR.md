# PLAY-022 Spatial Consequence Audit Repair

## Candidate state

- Baseline candidate: `d08f73b735b06677d7be6fc30f96b500410aac82`
- Post-audit repair: working tree pending a focused commit
- Claim status: blocked checkpoint, not ready for integration

The exact isolated baseline suite passed 108/108 tests in 304.249 seconds
(304.257 seconds wall) using scratch path
`/private/tmp/citysim-play022-d08f73b-full-20260720-1545` and module cache
`/private/tmp/citysim-play022-d08f73b-clang-20260720-1545`.

Static integration review then rejected four gaps. The repair:

1. expires Reduce Motion transition marks at `event.authoritativeTick + 4` on
   a later authoritative render, with zero SpriteKit actions and at most one
   retained transition root per coordinate;
2. reconciles nodes, drawables, actions, raw consumed events, and actually
   displayed grouped cues after expiry/insertion and interaction presentation;
3. retains one shape-coded aggregate consequence mark per developed place at
   city LOD: cross for severe, triangle for strained, upward chevron for
   prosperous, with dimension-specific detail at closer LODs;
4. separates consumed contract IDs from grouped displayed-cue diagnostics.

## Focused repair validation

The authorized isolated focused run used scratch path
`/private/tmp/citysim-play022-repair-focused-20260720-1602` and module cache
`/private/tmp/citysim-play022-repair-clang-20260720-1602`.

Result: 2/2 tests passed in 35.735 seconds (35.736 seconds wall):

- `testCityLODUsesOnePersistentNonColorAggregatePerDevelopedPlace`
- `testReducedMotionEventsExpireBoundedlyAndSuppressSaveLoadUndoReplayDuplicates`

Coverage includes equal-state renders, four-tick progression, JSON save/load,
undo, deterministic forward replay, bounded nodes/drawables, zero Reduce Motion
actions, and consumed-vs-displayed diagnostics.

## Evidence limitation

The retained PNGs are disclosed deterministic shipping-renderer harness frames,
not staged-window captures. Their hashes predate this audit repair and must not
be presented as pixel-exact proof of the repaired city-LOD layer.

The exact `d08f73b` staged manifest and process were verified, but Computer Use
`get_app_state` failed to return and was externally aborted after 443.7 seconds.
No screenshot, accessibility tree, pointer journey, compact resize, or live
interaction proof resulted. Integration prohibited further Computer Use
retries. The real drawable-window gate remains blocked.

Post-repair full-suite, regenerated harness, and exact staged-app verification
remain pending serial authorization from integration.
