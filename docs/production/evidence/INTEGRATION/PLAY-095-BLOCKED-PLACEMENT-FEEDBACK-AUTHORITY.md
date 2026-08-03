# PLAY-095 Blocked Placement Feedback Authority

## Exact defect

Independent PLAY-075 evidence at
`docs/production/evidence/PLAY-075/r4-f-fc996a28-final-v1/RESULT.json`
records `PLAY075-R4F-003`: in Road build mode, pointer-select occupied block
`6,8`. The build decision says `BLOCKED`, the map primary action says
`Unavailable`, and Escape cancellation works, but the action update announces
`Road construction approved`.

## Frozen repair

Own only:

- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`
- `docs/production/evidence/PLAY-095/blocked-placement-feedback-v1/`

Reproduce the occupied-road pointer path through the public store command
surface. A failed build must atomically publish the rejection message with
caution tone and must not retain or re-expose an earlier positive approval.
A successful build must still mutate once, record undo once, select the new
coordinate, publish positive approval, and play its existing success sound.
Pointer and keyboard dispatch of the same command must resolve identically.

Add focused regressions for:

1. a successful Road placement followed by a blocked occupied placement;
2. a blocked occupied placement from a fresh store;
3. repeated blocked placement without state mutation or undo growth;
4. successful placement after a blocked attempt; and
5. feedback tone/text matching the latest simulation result and the map
   primary-action availability.

Do not modify `CitySimulation`, validation rules, commands, renderer, views,
HUD hierarchy, resources, persistence, or shared authority. If the defect
cannot be reproduced through `CityGameStore.primaryAction(at:)` within the two
named source/test files, stop with a diagnostic packet; do not widen paths.
Integration owns the full Swift suite and staged build. A new independent
real-app journey must verify the exact pointer action and AX announcement.
