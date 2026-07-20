# PLAY-032 Direct Action and Spatial Navigation Contract Proposal

**Status:** Awaiting integration decision

**Authority base:** `36774db97e5dd017f1a4c9ecd0a4c288dd09c387`

**Owner:** UI/input owns explanation, command discovery, focus rules, and player-intent routing. Simulation owns consequence truth. SpriteKit owns map hit testing, camera, and world presentation.

## Player failure and invariant

The selected-block inspector currently shows identity, activity, operations, and a generic next action. It does not consume `CityPresentationSnapshot.spatialConsequences`, so it cannot explain local utility service, pollution, or vitality. Warnings open broad inspector sections but expose no concise direct-action menu. The accepted command catalog has camera zoom/frame commands, but no governed arrow or Return route; pointer clicks are therefore still the only way to target a map coordinate.

The invariant is: the player sees one truthful cause -> consequence -> remedy chain, and every pointer or keyboard activation reaches the same existing store intent for the same coordinate. UI copy may summarize approved truth but may not infer a new source, promise an outcome, or reproduce a simulation formula.

## Current boundaries found

- `CityPresentationSnapshot.spatialConsequences[coordinate]` already supplies independent power, water, and combined service/bands, pollution exposure/band, and vitality score/state. No snapshot addition is required.
- `CityGameStore.selectedCoordinate` is already the durable UI/input selection target and `CityScene` already draws it with a non-color outline/beam. A second keyboard-coordinate authority is unnecessary.
- Pointer primary and secondary actions already terminate at `CityGameStore.primaryAction(at:)` and `secondaryAction(at:)`.
- Every declared command flows through `CityCommandCatalog`; `CityScene.keyDown` resolves catalog metadata before dispatch. The source currently contains 52 command IDs and three renderer-spatial commands. Existing uniqueness, inventory, policy, single-dispatch, text-entry, Escape, and onboarding tests must remain binding.
- The only automatic `SKView` focus handoff is the generation-safe Welcome dismissal transition. A remedy button that closes its inspector currently leaves first responder on a vanished SwiftUI control until the player clicks the map.
- `CityMessage` has no typed presentation kind or coordinate. Changing it would affect persisted state and version-1 fingerprints, so PLAY-032 must not add fields or parse free-form detail.

## Proposed shared command addition

Add exactly ten `CityCommandID` cases and descriptors:

| Command | Binding | Route | Availability |
|---|---|---|---|
| `mapMoveNorth` | Up Arrow | store, spatial, gameplay focus | map focused and commands enabled |
| `mapMoveEast` | Right Arrow | store, spatial, gameplay focus | same |
| `mapMoveSouth` | Down Arrow | store, spatial, gameplay focus | same |
| `mapMoveWest` | Left Arrow | store, spatial, gameplay focus | same |
| `mapMoveNorthFast` | Shift-Up | store, spatial, gameplay focus | same |
| `mapMoveEastFast` | Shift-Right | store, spatial, gameplay focus | same |
| `mapMoveSouthFast` | Shift-Down | store, spatial, gameplay focus | same |
| `mapMoveWestFast` | Shift-Left | store, spatial, gameplay focus | same |
| `mapPrimaryAction` | Return | store, spatial, gameplay focus | a valid selected coordinate exists |
| `mapSecondaryAction` | Shift-Return | store, spatial, gameplay focus | a valid selected coordinate exists |

No ad hoc second shortcut table is introduced. `CityScene.keyDown` may normalize AppKit arrow/Return key codes into the catalog's canonical key strings, then must use `matchingCommand` and the existing command policy. Modified Command, Control, and Option input continues to pass to SwiftUI/AppKit. Text fields, sliders, menus, sheets, Welcome, and focused controls continue to win over bare gameplay keys.

The ten additions preserve the existing catalog shape. They do not add simulation commands, persisted replay commands, or user-remapping behavior.

## Proposed store intent and selection semantics

Extend the existing public store intent contract narrowly:

```swift
@discardableResult
func moveMapSelection(dx: Int, dy: Int, distance: Int) -> Bool

@discardableResult
func performMapAction(primary: Bool) -> Bool

@Published private(set) var mapFocusRequestGeneration: UInt

@discardableResult
func performMapFocused(_ command: CityCommandID) -> Bool
```

Semantics:

1. Movement initializes an absent selection from the first active tile nearest the developed-core center, falling back to region center. It then clamps to `0..<gridWidth` and `0..<gridHeight`.
2. Arrow movement uses distance 1; Shift-Arrow uses distance 5. It changes only `selectedCoordinate`. It never builds, demolishes, changes mode, opens a panel, or advances the simulation.
3. Primary execution calls the existing `primaryAction(at:)` with the selected coordinate. Secondary execution calls the existing `secondaryAction(at:)`. Pointer and keyboard therefore share the exact validation, undo, feedback, sound, and state mutation path.
4. `performMapFocused(_:)` accepts only existing non-destructive map-entry commands used by direct remedies, such as build-tool selection and explicit overlay selection. It first calls `perform(_:)`; only a successful command increments `mapFocusRequestGeneration`.
5. Destructive demolition is not added to this slice. Bulldoze plus Return uses the existing reversible path. No hidden selection can be acted on while Welcome or another blocking policy is active.
6. New/load/undo/cancel clear selection exactly as today. Save/load schemas and canonical fingerprints do not include selection or focus generation.

The selection remains explicit player-intent state, not simulation state. There is no separate keyboard cursor, duplicate world state, or renderer-owned actionable coordinate.

## Focus and visibility bridge

`CitySceneView.Coordinator` consumes `mapFocusRequestGeneration` with the same lifecycle protections as Welcome focus restoration:

- enqueue at most one next-main-loop handoff for a new generation;
- weakly retain the actual `SKView` and recheck window attachment and `.enabled` command policy;
- cancel when Welcome reblocks, the view detaches, or a newer generation supersedes it;
- never steal focus during text editing without an explicit player activation of a map-focused remedy;
- never move VoiceOver focus merely because simulation state changed.

`CityScene` continues to render the existing selection outline/beam. On a keyboard selection change it pans only enough to keep that coordinate inside a HUD-safe viewport margin; it does not recenter every arrow press. Reduced Motion makes the reveal immediate. Pointer selection already begins onscreen and must not trigger camera churn.

This is the only requested rendering-boundary adjustment. PLAY-022 may restyle selection but must preserve its non-color cue, priority above overlays, and keyboard visibility.

## UI-local selected-location diagnosis

Add a UI-local immutable presentation value built once from the current `CityPresentationSnapshot`, selected tile, and coordinate. It is not stored, Codable, public simulation state, or a second analytics authority.

It presents exact facts and bounded language:

- **Cause:** the limiting approved input, e.g. `Power service is severe at 42%; water is healthy at 91%`, or `Pollution exposure is severe at 68%`.
- **Consequence:** the current authoritative combined-service, pollution, and vitality state, e.g. `This block is strained at 39% vitality`. It may say an input contributes to vitality, but may not repeat weights or promise a future score.
- **Remedy:** one or more existing `CityCommandID` routes whose mechanics are already legitimate. Low power offers Build Power Plant and Utilities Overlay; low water offers Build Water Tower and Utilities Overlay; elevated pollution offers Build Park and Pollution Overlay. The copy says `place nearby` or `add capacity`, never `this will fix the block`.
- **No false remedy:** if vitality is strained while utility and pollution bands are healthy, the card reports condition/activity/citywide factors and offers City Data as diagnosis, not as a claimed fix.
- **Not applicable:** open land, roads, and incomplete construction do not receive a vitality diagnosis. Existing build or construction status remains primary.

At regular size, the selected inspector keeps four cards by replacing the generic `Next action` card with one concise `Cause / consequence / response` card. At 900 x 600, the same card uses one primary remedy plus a labeled `More responses` menu. It must not add a fifth card, widen the command-center overlay, shrink 44-point targets, or obscure more map.

The card exposes one stable accessibility element containing block identity, cause, consequence, and status. Remedy controls retain separate names, availability, costs where known, and hints that focus will return to the map for placement. Color is supplementary to text, icon, and band name.

## UI-local warning action catalog

Do not change `CityMessage`. Extend the existing UI-owned title routing into a tested `CityNoticeActionCatalog` that maps only authored stable titles to existing commands. The message's authored title/detail remain the cause and consequence; the catalog supplies action labels and command routes without parsing prose.

Minimum governed mappings:

- `Choose a Growth Engine`: Build Commercial and Build Industrial with explicit cleaner-versus-faster tradeoff language.
- `Chain Store Rumor`: open Tax Policy and/or Build Park.
- `Freight Load Forecast`: open Utilities, Build Power Plant, Build Water Tower, and/or Build Park.
- `Industrial Load Absorbed`: no urgent remedy; open Utilities as supporting evidence only.
- `Main Street Crossroads`, `Storefront Slump`, and `Main Street Recovery Delayed`: open Tax Policy and/or Build Park.
- `Freight Contract Watch`, `Industrial Load Surge`, and `Freight Recovery Delayed`: Build Power Plant, Build Water Tower, and/or Build Park.
- `Budget Gap`: open Finances; commercial/industrial build routes may be offered only with copy that says they add taxable activity, not that they guarantee balance.
- `Utility Reserve Tight` and `Utility Shortfall`: Utilities Overlay plus Build Power Plant and Build Water Tower.
- `Hiring Bottleneck`: Build Commercial and Build Industrial with their existing clean-versus-fast tradeoff language.
- `Severe Storm`: open Utilities; it is diagnosis, not a promise to undo the already-applied event cost.

The single toast gains at most one compact `Act` menu; the Journal may show the full response set. Dismiss remains distinct. Good/informational messages without an immediate decision keep the current open-detail route. A catalog coverage test freezes every authored warning/critical title from the exact integrated PLAY-012 baseline and rejects a missing explanation/action disposition. Gameplay must review the mapping whenever authored message titles or recovery mechanics change.

## Pointer, keyboard, Full Keyboard Access, and VoiceOver routes

- **Pointer:** click selects/acts through `primaryAction(at:)`; right-click uses `secondaryAction(at:)`; diagnosis remedies use ordinary buttons/menus and focus the map only after explicit activation.
- **Map keyboard:** arrows select, Shift-arrows jump, Return executes primary, Shift-Return executes secondary. Existing Escape priority and build/bulldoze modes remain unchanged.
- **Full Keyboard Access:** Tab reaches the diagnosis card remedies and warning `Act` menu; Space/Return activates them; focus then lands on the visible map target for placement. Toolbar, city-name field, slider, menu, and sheet focus suppress map keys.
- **VoiceOver:** selected-block summary speaks coordinate, type, cause, consequence, and vitality; remedies are separately actionable and announce that placement continues on the map. The map selection exposes a stable coordinate/type/value description and primary/secondary custom actions. VoiceOver and Full Keyboard Access are tested separately.
- **Onboarding:** every new route is rejected by `.blocked(.welcome)` and absent from the blocked accessibility tree. Dismissal still queues exactly one map-focus handoff.

## Compatibility, affected lanes, and order

- **Snapshot/platform:** no field, derivation, event, fingerprint, schema, or performance contract change.
- **Gameplay:** no rule or message payload change. Gameplay reviews the static warning-to-action dispositions for truthfulness.
- **Renderer:** preserves selection visibility above overlays and adds bounded edge reveal only; no consequence formula.
- **UI/input:** owns command additions, store intent/focus generation, diagnosis copy, responsive card/menu, accessibility, and catalog tests.
- **Quality:** independently verifies pointer/keyboard equivalence, focus containment, selected truth versus world overlay, remedy honesty, VoiceOver, Full Keyboard Access, default/900 x 600, save/load/undo, and consequence latency.

Integration should approve this after PLAY-041 and before PLAY-032 implementation. It can integrate alongside PLAY-022 only if selection-node edits are reconciled explicitly; PLAY-022's authored world consequence presentation should otherwise land first.

## Required tests and live proof

Automated:

- every old and new command appears exactly once and has no collision within focus scope;
- arrow/Shift-arrow bounds, initialization, stable movement, and no mutation beyond selection;
- Return/Shift-Return reach the exact pointer primary/secondary end state once;
- Welcome, text entry, sliders, menus, sheets, Command/Control/Option input, and Escape precedence suppress the new bare keys;
- focus generation is one-shot, stale-safe, detached-safe, and policy-safe;
- selected UI facts exactly equal the approved snapshot sample and never recalculate bands;
- each remedy resolves to an existing command and is shown only for its approved condition;
- every authored warning/critical title has an explicit action or no-action disposition;
- default and exact 900 x 600 rendered bounds retain map dominance and minimum targets;
- full native suite, `git diff --check`, build-script syntax, and exact staged launch pass.

Hands-on on the exact staged candidate:

1. Pointer-select a utility-strained and pollution-strained block; verify exact cause, consequence, and honest responses.
2. Activate each direct remedy by pointer, map keyboard, Full Keyboard Access, and VoiceOver; verify focus lands on the visible target without an extra click.
3. With the pointer untouched, navigate bounds and five-cell jumps, build, inspect, bulldoze, cancel, and undo.
4. Repeat at default and exact 900 x 600 with Objectives and Command Center arbitration.
5. Keep focus stable for 30 seconds at 3x, then save/load and undo without stale or hidden selection action.
6. Confirm Welcome blocks every new route before both Return and pointer dismissal journeys.

## Decision requested

Reply **APPROVED**, **ADJUST**, or **DEFER** for:

1. the ten additive catalog commands;
2. store-owned selection movement/action plus one generation-safe map-focus request;
3. no snapshot or persisted-message change;
4. the UI-local diagnosis and stable-title warning action catalogs;
5. bounded SpriteKit selection reveal coordinated with PLAY-022.
