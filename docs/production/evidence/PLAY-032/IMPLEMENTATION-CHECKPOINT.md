# PLAY-032 Direct Action Implementation Checkpoint

- **Lane:** UI/input
- **Branch:** `codex/citysim-ui-input`
- **Authority baseline:** `33323098142482537092f52d15ef9679979d5e32`
- **Status:** coherent implementation checkpoint; full-suite, staged-app, and live acceptance remain pending

## Implemented player outcome

- Arrow and Shift-Arrow navigate one or five blocks through ten catalog-governed map commands; Return and Shift-Return use the exact existing primary and secondary store actions.
- The new routes dispatch only from an actual first-responder `SKView` while command policy permits them. The store remains the only owner of selection and action intent.
- Direct diagnosis consumes the selected coordinate's accepted `CityPresentationSnapshot.spatialConsequences` sample and presents cause, current consequence, and bounded remedies without reproducing platform formulas or promising recovery.
- Stable authored notice titles expose an `Act` menu with explicit tradeoffs or supporting evidence. No message detail parsing or schema change is used.
- Approved direct remedies request one generation-safe map focus handoff. Keyboard movement keeps the selected block within a bounded map-safe viewport; pointer selection does not invoke that reveal path.
- The map publishes a stable VoiceOver label/value plus primary and secondary custom actions. Diagnosis controls provide separate labels and honest hints; compact presentation keeps one primary response plus `More responses`.

## Exact changed surfaces

- `Native/CitySimNative/Sources/CitySimNative/Support/CityCommandCatalog.swift`
- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/CitySceneView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Support/CityDirectActionPresentation.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/InspectorView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/EventFeedView.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`

No model, snapshot field, consequence derivation, save/message schema, gameplay rule, package, build script, or legacy Python file changed.

## Focused validation

Command:

```bash
swift test --package-path Native/CitySimNative \
  --scratch-path /private/tmp/citysim-play032-ui-c8e2-3332309 \
  --filter CityCommandCatalogTests
```

Result: 16 tests passed, 0 failed in 1.040 seconds after a clean scratch compile. Coverage includes catalog uniqueness/collision, map-first-responder enforcement, one-time dispatch, bounded selection, pointer/keyboard end-state equivalence, Welcome suppression, modified-input precedence, lifecycle-safe focus generation, exact snapshot-derived diagnosis, governed notice actions, map accessibility value/custom actions, and default/compact rendering bounds.

`git diff --check` passed with no output.

## Deliberately pending gates

Integration assigned this lane a focused compile/test gate while other lanes owned the serial full-suite runner. The worker therefore did not run the full native suite, stage or launch the app, or claim pointer, keyboard, Full Keyboard Access, VoiceOver, default/900 × 600, save/load/undo, or live consequence-latency proof. Those gates remain mandatory before readiness. No screenshot or live observation is claimed by this checkpoint.
