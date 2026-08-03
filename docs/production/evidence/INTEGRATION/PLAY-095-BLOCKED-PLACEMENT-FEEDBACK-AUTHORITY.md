# PLAY-095 Blocked Placement Feedback Authority

## Exact defect

Independent PLAY-075 evidence at
`docs/production/evidence/PLAY-075/r4-f-fc996a28-final-v1/RESULT.json`
records `PLAY075-R4F-003`: in Road build mode, pointer-select occupied block
`6,8`. The build decision says `BLOCKED`, the map primary action says
`Unavailable`, and Escape cancellation works, but the action update announces
`Road construction approved`.

## Integrated diagnostic boundary

The integrated PLAY-095 store diagnostic proves the exact successful Road then
occupied Road sequence through `CityGameStore.primaryAction(at:)` publishes the
correct caution text/tone, leaves simulation and undo unchanged, and preserves
the selected tool. The contradiction therefore does not belong to the store or
simulation contract.

## Frozen pointer/view repair

Own only:

- `Native/CitySimNative/Sources/CitySimNative/Rendering/CitySceneView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`
- `docs/production/evidence/PLAY-095/pointer-feedback-coherence-v2/`

Reproduce the actual scene/coordinator path where a pointer candidate is
accepted, its blocked presentation is applied, and the primary attempt is
dispatched. The visible/AX map target and action feedback must never expose a
new blocked target beside an earlier approval, including intermediate
publication inside the same main-actor event. Preserve the already-correct
store result, successful mutation/undo/selection/sound, and pointer/keyboard
command parity.

Add focused regressions for:

1. a successful Road placement followed by a blocked occupied placement;
2. a blocked occupied placement from a fresh store;
3. repeated blocked placement without state mutation or undo growth;
4. successful placement after a blocked attempt; and
5. feedback tone/text matching the latest simulation result and the map
   primary-action availability.

Do not modify `CityGameStore`, `CitySimulation`, validation rules, commands,
world composition, camera, HUD hierarchy, resources, persistence, or shared
authority. If the defect cannot be reproduced through the exact
`CityScene`/`CitySceneView.Coordinator` pointer boundary within the named files,
stop with a second diagnostic packet; do not widen paths.
Integration owns the full Swift suite and staged build. A new independent
real-app journey must verify the exact pointer action and AX announcement.
