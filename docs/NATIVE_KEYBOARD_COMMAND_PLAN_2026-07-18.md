# CitySim Native Keyboard Command Plan

**Date:** July 18, 2026
**Product:** `Native/CitySimNative`
**Status:** implementation specification
**Outcome:** every game command has a documented keyboard route, and high-frequency play can move between modes, tools, data, panels, and the map without touching the pointer.

## Command philosophy

CitySim uses two shortcut layers:

- **Gameplay keys** are fast, mostly unmodified keys that work while the city/map owns focus. They cover time, interaction modes, construction tools, map navigation, and confirmation.
- **Application commands** use macOS-standard modifiers and remain discoverable in menus. They cover files, undo, panels, overlays, and inspector destinations.

Gameplay keys must never fire while a `TextField`, `TextEditor`, slider keyboard adjustment, menu, sheet, or other text/input control owns focus. Command-modified macOS menu shortcuts may continue to work where platform conventions allow. Escape first cancels the active edit/menu, then cancels the current game interaction on the next press.

The shortcut shown in a menu, tooltip, build tool, HUD button, accessibility help string, and settings reference must come from one command registry. Do not independently hard-code the same shortcut in SwiftUI and `CityScene.keyDown`.

## Canonical shortcut map

### Files and history

| Action | Shortcut | Behavior |
|---|---:|---|
| New region | ⌘N | Starts the existing new-region flow. Destructive confirmation should be added when unsaved-state tracking exists. |
| Save city | ⌘S | Saves without changing focus or simulation speed. |
| Load city | ⌘O | Loads the quicksave and preserves the existing load behavior. |
| Undo last construction/demolition | ⌘Z | Restores the exact previous state; disabled when unavailable. |

### Simulation time

| Action | Shortcut | Behavior |
|---|---:|---|
| Toggle pause | Space | Pauses; when pressed again, restores the last non-paused speed rather than always selecting 1x. |
| Pause explicitly | 0 | Selects paused speed. |
| Normal speed | 1 | Selects 1x. |
| Fast speed | 2 | Selects 2x. |
| Fastest speed | 3 | Selects 3x. |

### Interaction modes

| Action | Shortcut | Behavior |
|---|---:|---|
| Inspect mode | V | Cancels build/bulldoze intent and activates map inspection. |
| Return to selected build tool | T | Activates build mode using the last selected building tool. |
| Bulldoze mode | B | Activates bulldoze; pressing B again returns to Inspect. |
| Cancel current interaction | Esc | Returns safely to Inspect and clears transient placement/selection state. |
| Execute action at keyboard cursor | Return | Inspects, builds, or bulldozes according to the visible interaction mode. |
| Secondary/cancel-to-inspect action | ⇧Return | Matches right-click semantics at the keyboard cursor. |
| Undo | ⌘Z | Available in every interaction mode. |

### Direct build tools

These keys select the tool, select its category in the command dock, and enter Build mode in one action.

| Tool | Shortcut | Mnemonic |
|---|---:|---|
| Road | R | Road |
| Residential | H | Home |
| Commercial | C | Commercial |
| Industrial | I | Industry |
| Park | P | Park |
| Power plant | E | Energy |
| Water tower | W | Water |
| Fire station | F | Fire |
| Police station | L | Law |
| School | S | School |
| City Hall | G | Government |

Tool shortcuts work only when the game/map context owns focus. This permits `I`, `S`, and other letters to remain ordinary input inside the city-name field.

### Build catalog categories

Category commands reveal the category and select its most recently used tool. If no tool has been used in that category, use its first tool.

| Category | Shortcut |
|---|---:|
| Roads | ⇧1 |
| Zones | ⇧2 |
| Utilities | ⇧3 |
| Services | ⇧4 |
| Civic | ⇧5 |

Direct tool letters remain the fastest route; category shortcuts exist because category buttons are player actions and must also be keyboard-addressable.

### Data overlays

Overlay commands use Control plus a number so they do not compete with simulation speeds.

| Overlay | Shortcut |
|---|---:|
| City view / clear overlay | ⌃0 |
| Land value | ⌃1 |
| Traffic | ⌃2 |
| Utilities | ⌃3 |
| Happiness | ⌃4 |
| Pollution | ⌃5 |
| Cycle forward | ⌃] |
| Cycle backward | ⌃[ |

Selecting an overlay updates the visible overlay control and legend. Pressing the active overlay’s shortcut again may leave it active; clearing is always the explicit ⌃0 command.

### Inspector destinations

Inspector commands use Option plus a number. They open the inspector if needed, clear tile-only presentation when appropriate, and navigate directly to the requested section.

| Inspector destination | Shortcut |
|---|---:|
| City overview | ⌥1 |
| Finances | ⌥2 |
| Population | ⌥3 |
| Happiness | ⌥4 |
| Employment | ⌥5 |
| Development demand | ⌥6 |
| Utilities | ⌥7 |
| City journal | ⌥8 |
| Toggle/close inspector | ⌥0 |

### Panels, alerts, and objectives

| Action | Shortcut | Behavior |
|---|---:|---|
| Toggle objectives | ⌘J | Opens or collapses the objective surface. |
| Open alert center/journal | ⌘⇧A | Opens the consolidated alert center and City Journal. |
| Toggle inspector | ⌘⌥I | Retained as a mnemonic alias for ⌥0. |
| Dismiss transient feedback | ⌘. | Clears only the current transient message; it must not dismiss durable alerts. |
| Close active panel | Esc | Closes the topmost transient panel before cancelling the interaction beneath it. |

### Map and camera

| Action | Shortcut | Behavior |
|---|---:|---|
| Move keyboard cursor | Arrow keys | Moves one grid coordinate and keeps it visible. |
| Move keyboard cursor quickly | ⇧Arrow keys | Moves five cells, clamped to the map. |
| Pan camera | ⌥Arrow keys | Pans without moving the selected/keyboard tile. |
| Zoom in | `=` or `+` | Zooms around the keyboard cursor or viewport center. |
| Zoom out | `-` | Zooms around the keyboard cursor or viewport center. |
| Frame developed city | Home | Uses the current developed-core framing behavior. |
| Frame entire region | ⇧Home | Fits the full buildable map. |
| Center selected tile | C | When a tile is selected and no build/inspect letter command is being resolved, centers it. Because C is also Commercial, the implementation should use **⌘L** for “Locate Selection” to avoid ambiguity. |
| Locate current selection | ⌘L | Canonical, conflict-free center-selection command. |
| Cycle selectable tile forward | Tab | Advances through developed/interesting tiles in stable coordinate order. |
| Cycle selectable tile backward | ⇧Tab | Reverses the same traversal. |

`C` is reserved for Commercial. Only ⌘L should ship for locating the selection.

### Contextual actions

| Action | Shortcut | Availability |
|---|---:|---|
| Activate focused/default control | Return | Standard SwiftUI behavior outside the map; executes at keyboard cursor inside the map. |
| Demolish selected structure | ⌘⌫ | Enabled only when a demolishable tile is selected; requires the same confirmation/safety rules as the visible button. |
| Open selected tile inspector | ⌘I | Opens details for the keyboard cursor or selected tile. |
| Open related data for selected alert | ⌘Return | Only when an alert row owns focus. |
| Dismiss selected alert | ⌘⌫ | Only when an alert row owns focus; must not conflict with demolish because focus context is explicit. |
| Increase tax rate | ⌥↑ | Only while the Finance inspector is active; one configured step. |
| Decrease tax rate | ⌥↓ | Only while the Finance inspector is active; one configured step. |

## Actions that remain standard focus navigation

Every action needs a keyboard route, but not every action needs a global hotkey. The following use standard macOS keyboard operation and must expose correct focus, names, and default/cancel behavior:

- choosing an item in a menu or picker: Tab/Shift-Tab, arrows, Space/Return;
- editing the city name: focus the field, type, Return to commit, Escape to cancel;
- adjusting sliders: focus, then arrows/Page Up/Page Down as supported;
- activating visible inspector remedies: focus and Space/Return;
- closing an individual panel with its Close button: focus and Space/Return, plus the global panel Escape behavior;
- selecting a specific journal entry: focus traversal plus arrows; commands then act on the focused entry.

These controls still belong in the command inventory and automated accessibility checks. “Standard focus route” is an explicit shortcut assignment, not an exemption.

## Architecture

### Single command registry

Add a central command definition, tentatively:

```swift
enum CityGameCommand: Hashable {
    case newRegion, save, load, undo
    case togglePause, setSpeed(SimulationSpeed)
    case inspectMode, resumeBuildMode, bulldozeMode, cancelInteraction
    case selectBuildCategory(BuildCategory)
    case selectTool(BuildingKind)
    case selectOverlay(DataOverlay), cycleOverlay(Int)
    case openInspector(InspectorSection), toggleInspector
    case toggleObjectives, openAlerts, dismissFeedback
    case moveCursor(dx: Int, dy: Int), panCamera(dx: Int, dy: Int)
    case zoomIn, zoomOut, frameDevelopedCity, frameRegion, locateSelection
    case executePrimary, executeSecondary, demolishSelection
}
```

Pair it with `CityCommandDescriptor` containing title, menu group, key equivalent, modifiers, focus policy, enabled predicate, accessibility help, and optional HUD hint. The registry is the source for:

- SwiftUI `Commands` menus;
- SpriteKit/map event routing;
- button tooltips and shortcut badges;
- accessibility help;
- the in-game shortcut reference;
- conflict and coverage tests.

### Dispatch ownership

- `CityGameStore` executes player intent, state changes, modes, selection, panels, overlays, and undo.
- `CityScene` executes camera movement and tracks the keyboard grid cursor, reporting actionable coordinates through callbacks.
- `CitySceneView.Coordinator` bridges typed commands between the registry, store, and scene.
- SwiftUI `Commands` exposes every global/menu command and uses normal enabled/disabled state.
- A narrow AppKit key monitor may route unmodified gameplay keys only when the map/game context is active. It must not swallow events from text or accessibility controls.

Do not maintain separate switch statements in `CityGameCommands` and `CityScene.keyDown`. If AppKit conversion is necessary, convert `NSEvent` to a `CityGameCommand` once, then dispatch the typed command.

## Focus and conflict policy

1. Text entry always wins over unmodified gameplay keys.
2. A presented menu, sheet, confirmation, or system dialog always wins over game commands.
3. Escape closes the topmost transient UI, then cancels interaction, then clears selection on successive presses.
4. Map contextual commands require an active keyboard cursor; if absent, initialize it from selection, hovered tile, developed core, or map center in that order.
5. Destructive commands must be enabled only for valid targets and must never act on a stale hidden selection.
6. System-reserved macOS shortcuts are not reassigned.
7. Shortcuts use physical key equivalents consistently across keyboard layouts where SwiftUI/AppKit permits; localized display strings come from the system.
8. When two commands share a key in different focus scopes, the focused scope and the menu’s enabled state must make the winner unambiguous.

## Discoverability requirements

- All commands appear in logical macOS menus: File, Edit, Simulation, Build, View, Data, Window/Inspector, and Help.
- HUD/build controls show the shortcut in `.help` and accessibility help.
- Build tools show their direct key in the regular and compact catalog.
- The active mode banner always names its escape route, for example “Commercial · C · Esc to cancel.”
- Add a searchable **Keyboard Shortcuts** sheet opened with ⌘/ and linked from Help.
- The sheet groups commands exactly as this document does and indicates contextual/unavailable actions.
- The first-run experience mentions Space, V, one build key, B, arrows, Return, and Escape—no more than the minimum play loop.
- User remapping is a later enhancement; the first release must keep the registry data-shaped so remapping can be added without replacing command execution.

## Implementation batches

### Batch 1 — Registry and parity

- Inventory every current `Button`, menu command, SpriteKit key handler, and store intent.
- Introduce `CityGameCommand`, descriptors, dispatcher, focus policies, and conflict validation.
- Move existing ⌘N/⌘S/⌘O/⌘Z, Space, 1–3, V, B, Escape, ⌘J, and ⌘⌥I into the registry without behavioral regression.
- Add unit tests proving every registered key combination is unique within its focus scope.

### Batch 2 — Modes, tools, categories, and time

- Implement 0–3, pause restore, V/T/B/Escape, direct tool letters, and Shift-number categories.
- Render shortcut hints in both regular and compact build interfaces.
- Verify mode/tool/category state stays synchronized across keyboard, HUD, and menus.

### Batch 3 — Overlays, inspector, alerts, and objectives

- Implement Control-number overlays, Option-number inspector destinations, alert/objective commands, and panel Escape priority.
- Add every command to menus and accessibility help.
- Verify that simulation pulses do not invalidate focused commands.

### Batch 4 — Keyboard map operation

- Add stable keyboard cursor identity, arrow traversal, Return/Shift-Return actions, Tab traversal, camera pan/zoom/frame/locate commands, and contextual deletion.
- Keep cursor and selection visible above world art and overlays with a non-color cue.
- Auto-scroll/center only when the cursor would leave the usable viewport; do not make every arrow press animate the camera unnecessarily.

### Batch 5 — Reference UI and completeness gate

- Add the ⌘/ shortcut sheet, menu organization, dynamic enabled states, and shortcut badges.
- Add a command coverage test that fails when a new player-facing action is introduced without a command descriptor or declared standard focus route.
- Complete keyboard-only and Full Keyboard Access playthroughs at default and compact layouts.

## Acceptance evidence

### Automated

- Every `CityGameCommand` has exactly one descriptor.
- No duplicate key/modifier combination exists within the same focus policy.
- All `BuildingKind.buildPalette`, `BuildCategory`, `DataOverlay`, `InspectorSection`, and `SimulationSpeed` cases have commands.
- Store transition tests cover modes, tools, categories, overlays, panels, time, cancellation, and undo.
- Keyboard cursor tests cover bounds, fast movement, traversal order, and target validity.
- Focus-policy tests prove unmodified gameplay letters do not execute during text entry.
- The complete Swift package test suite passes.

### Hands-on

Starting with the pointer untouched, a player can:

1. pause and resume the simulation;
2. select Road, build a road at the keyboard cursor, and undo it;
3. select Residential, place it, cancel, and return to Inspect;
4. enter and leave Bulldoze without an accidental demolition;
5. inspect a tile and navigate all inspector sections;
6. activate and clear every data overlay;
7. open objectives and alerts, follow an alert to related data, and close the panel;
8. pan, zoom, frame the region, and locate the selected tile;
9. save and load;
10. edit the city name without triggering gameplay commands.

Repeat the playthrough at the default and compact window layouts. Run a separate Full Keyboard Access pass and a VoiceOver pass; do not treat one as proof of the other.

## Completion definition

Keyboard coverage is complete only when every player-facing action is either:

1. represented by a `CityGameCommand` with a documented binding, enabled state, focus policy, menu/discovery surface, and test; or
2. explicitly registered as a standard focused-control action with verified macOS keyboard operation.

A source-code inventory, automated coverage report, and hands-on pointer-free playthrough must agree. Merely adding `.keyboardShortcut` to visible buttons is insufficient.
