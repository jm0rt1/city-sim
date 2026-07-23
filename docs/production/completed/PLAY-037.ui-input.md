# PLAY-037 Completion — Restore Compact Spatial Keyboard and Escape Parity

- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Status:** ready-for-integration
- **Base authority:** `52fc2c17643e7987f78bc360196599e3297967da`
- **Product commits:**
  - `50167403531aa90084e95281b463c513acaf415c` — `PLAY-037: Preserve compact map focus and identity`
  - `ae85efeedede7e0b2ccee3f8d2ae98bb8e1ae47c` — `PLAY-037: Restore map Full Keyboard Access traversal`

## Outcome

`CitySceneView` now declares the semantic `CityMapSKView` as its exact representable view type, so compact recomposition cannot silently degrade the map to a generic `SKView` contract. The view continuously publishes `City map` identity, selected-block value, actionable help, and truthful custom actions. Arrow and Shift-Arrow input still routes through the existing catalog/store map intent and reveals the resulting selection.

Topmost surface cancellation remains store-owned. Closing Command Center or Objectives now advances the existing map-focus generation, so each Escape closes one governed surface, preserves the tool and selection, and returns focus to the map. Only a later Escape with no governed surface open reaches the existing tool-cancellation path.

The focused map also hands unmodified Tab and Shift-Tab to AppKit's key-view loop. Full Keyboard Access can therefore leave the SpriteKit surface and reach selected Command Center actions; renderer commands, target choice, and scene validation are unchanged.

## Files changed

- `Native/CitySimNative/Sources/CitySimNative/Rendering/CitySceneView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`

No renderer art, hover or target semantics, build validation, simulation rule, save/session schema, CONTRACT-008, or PLAY-034 surface changed.

## Automated validation

- `CityCommandCatalogTests`: 26 tests passed, 0 failures in 44.456 seconds on the final product commits.
- `testExactCompactRetainsSemanticMapIdentityKeyboardSelectionAndEscapeFocus` hosts the real `ContentView` at 900 x 600, proves semantic map identity and actions, Right/Shift-Right movement, two-step Escape order, selection/tool/state preservation, and map focus handoff.
- `testSemanticMapHandsTabAndShiftTabToFullKeyboardAccessLoop` proves native forward and reverse key-view traversal from `CityMapSKView`.
- Existing measured-HUD coverage continues to require at least 40% interactive map height with selected coordinates inside default and exact compact safe viewports.
- Full native suite: 135 tests passed, 0 failures in 370.336 seconds.
- Unchanged renderer diagnostics: 5,759 reused tiles, 1 updated tile, 1.282 ms average render time; 4,286-pulse soak averaged 1.1022 ms.
- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- Exact staged `./script/build_and_run.sh --verify`: passed for the final committed candidate.

## Staged proof

Default and exact compact pointer, keyboard, Full Keyboard Access, and AX journeys are retained in `docs/production/evidence/PLAY-037/5016740/README.md`.

- Fresh default measured 1,229 x 768 and exposed only the blocking Welcome surface until explicit Return dismissal.
- Default and compact pointer selection plus Right/Shift-Right retained a semantic, focused, revealed map selection with truthful selected actions.
- Exact compact measured a 900 x 652 frame / 900 x 600 content. Simultaneous Objectives and Command Center retained map dominance, a collapsed objective summary, and scrollable selected-block controls.
- At both sizes, Escape closed Command Center first and Objectives second while preserving tool, selection, paused state, and focus handoff.
- With Full Keyboard Access enabled, Tab left the map and reached the compact selected-block action; Shift-Tab traversed back.
- Command-guide text input quarantined Left/Shift-Right from map navigation and Escape returned focus to the unchanged selection.

AX inspection and Full Keyboard Access were exercised separately from spoken VoiceOver; spoken VoiceOver is not claimed.

## Contract and compatibility notes

- **One intent path:** map arrows, primary/secondary actions, cancellation, and catalog commands continue through the existing catalog/store routes.
- **Focus only:** the added store generation changes first-responder handoff after governed panel dismissal; it does not own or duplicate modal state.
- **Renderer boundary:** the semantic AppKit view is made explicit, but SpriteKit art, camera behavior, hover target choice, renderer validation, and CONTRACT-008 remain untouched.
- **Simulation/save:** the full deterministic, gameplay progression, undo, save/replay, fingerprint, spatial, and soak suites passed unchanged.

No shared-contract proposal is required. No push or integration was performed.
