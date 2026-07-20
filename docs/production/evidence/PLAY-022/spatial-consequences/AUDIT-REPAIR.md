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

## Telemetry performance repair

Integration's combined run exposed that the first audit repair recursively
recounted roughly 10,000 nodes on every render, increasing the unchanged soak
to 9.9693 ms average. The follow-up repair retains exact prior tree totals on
unchanged renders. It now applies exact subtree-metric deltas for backdrop,
tile, overlay, event insertion, and event expiry changes; scans only direct
consequence-layer children for the current displayed-cue count; and performs a
full recursive recount only on the initial render, after selection or Reduce
Motion changes, or when it detects an unexplained asynchronous cue removal.

Authorized focused validation used scratch path
`/private/tmp/citysim-play022-telemetry-focused-20260720-1612` and module cache
`/private/tmp/citysim-play022-telemetry-clang-20260720-1612`:

- expiry/telemetry plus 4,286-pulse soak: 2/2 passed in 53.134 seconds;
- soak: 4,894.623 ms total / 1.1420 ms average, 10,289 nodes, 2,505
  drawables, 5 bounded actions, and unchanged identity;
- exact ten-pulse invalidation: 1/1 passed in 12.033 seconds, with 5,759 tile
  reuses and one authoritative spatial update.

The exact subtree-delta focused group used scratch path
`/private/tmp/citysim-play022-delta-focused-20260720-1625` and module cache
`/private/tmp/citysim-play022-delta-clang-20260720-1625`. The expiry test proved
that incremental diagnostics exactly match a test-only recursive recount after
both insertion and event-only expiry. The unchanged 4,286-pulse soak passed at
4,929.119 ms total / 1.1501 ms average with 10,289 nodes, 2,505 drawables, and
5 bounded actions.

An initial ten-pulse measurement of 3.753 ms included platform-owned snapshot
derivation and was therefore rejected as a renderer metric. Integration
confirmed that the shipping `CitySceneView` derives and caches presentation
snapshots before calling the scene renderer. The corrected shipping-boundary
test measures only `scene.render(snapshot:)`, enforces the established 2.1 ms
renderer budget, and passed 1/1 in 12.035 seconds: 13.411 ms total / 1.341 ms
average, 5,759 tile reuses, and one authoritative spatial update. Neither the
earlier platform-inclusive timings nor their failures are presented as
renderer performance.
