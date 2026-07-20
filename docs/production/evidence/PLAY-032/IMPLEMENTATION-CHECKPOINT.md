# PLAY-032 Direct Action Implementation Checkpoint

- **Lane:** UI/input
- **Branch:** `codex/citysim-ui-input`
- **Authority baseline:** synchronized through local `master` `b092261f77ad72b1401d4cd7a5d598f3f9fcdd46`
- **Status:** independent HIGH-finding repairs focused-test green; staged app and live acceptance remain pending

## Implemented player outcome

- Arrow and Shift-Arrow navigate one or five blocks through ten catalog-governed map commands; Return and Shift-Return use the exact existing primary and secondary store actions.
- The new routes dispatch only from an actual first-responder `SKView` while command policy permits them. The store remains the only owner of selection and action intent.
- Direct diagnosis consumes the selected coordinate's accepted `CityPresentationSnapshot.spatialConsequences` sample and presents cause, current consequence, and bounded remedies without reproducing platform formulas or promising recovery.
- Stable authored notice titles expose an `Act` menu with explicit tradeoffs or supporting evidence. No message detail parsing or schema change is used.
- Approved direct remedies request one generation-safe map focus handoff. Keyboard movement now consumes actual SwiftUI top-HUD and bottom-command-deck frames, plus compact/regular first-frame fallbacks, to keep the selected block inside an asymmetric unobscured viewport; pointer selection does not invoke that reveal path.
- The map publishes a stable VoiceOver label/value plus contextual custom actions. Inspect/build/bulldoze actions identify the target and availability; valid demolition announces its cost and undo before activation, while open land and protected City Hall expose no destructive custom action and Return is disabled.
- Selected-location diagnosis remains an additional consequence card. It no longer replaces the persistent next-action card containing demolition cost, destructive label, and undo hint.
- The notice test reads the integrated simulation's authored warning/critical titles and compares them to a frozen PLAY-012 inventory before requiring a catalog disposition, so a gameplay addition or rename cannot pass by iterating the UI catalog over itself.

## Exact changed surfaces

- `Native/CitySimNative/Sources/CitySimNative/Support/CityCommandCatalog.swift`
- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/CitySceneView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Support/CityDirectActionPresentation.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/InspectorView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/EventFeedView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/ContentView.swift`
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

That result predates the independent HIGH-finding repairs. The repair adds an integrated scene plus measured-HUD occlusion assertion at regular and exact 900 x 600 sizes, contextual accessibility/destructive-action/undo assertions, and the authoritative warning/critical source inventory comparison.

Post-repair command:

```bash
swift test --package-path Native/CitySimNative \
  --scratch-path /private/tmp/citysim-play032-audit-repair-c8e2-07699da-v2 \
  --filter CityCommandCatalogTests
```

Result: clean build completed in 12.53 seconds; 18 tests passed, 0 failed, 0 unexpected in 22.270 seconds (22.272 seconds selected-suite wall timing). The first isolated compile identified that the preference key's immutable empty default needed `static let` for Swift 6 concurrency safety; that single declaration was corrected before the successful fresh-scratch run.

## PLAY-022 synchronization gate

The normal merge of `b092261` produced one conflict in `CitySceneView.Coordinator`. The resolution retained both PLAY-032's map-focus request generation and PLAY-022's `CityPresentationSnapshot` cache; the scene continues to render the cached authoritative snapshot while consuming PLAY-032 viewport insets and command/accessibility routes.

The isolated post-merge selection ran all 18 `CityCommandCatalogTests` plus the three renderer integrity/performance tests used for PLAY-022's telemetry repair. Clean build completed in 12.60 seconds. All 21 tests passed with 0 failures in 89.781 seconds: UI 18/18 in 25.156 seconds; ten-pulse renderer integrity 1/1 in 12.359 seconds with 1.327 ms average render time; reduced-motion event expiry/exact telemetry 1/1 in 35.642 seconds; and 4,286-pulse soak 1/1 in 16.624 seconds with 1.1127 ms average render time. Both renderer averages remain below the 2.1 ms ceiling.

`git diff --check` passed with no output.

## Deliberately pending gates

Integration released the serialized focused runner after the renderer lane completed. This UI worker ran only `CityCommandCatalogTests`; it did not run the full suite, stage or launch the app, or claim pointer, keyboard, Full Keyboard Access, VoiceOver, default/900 x 600 live-window, save/load, or live consequence-latency proof. The focused store assertion does prove exact demolition undo restoration. The remaining live gates are mandatory before readiness. No screenshot or live observation is claimed by this repair checkpoint.
