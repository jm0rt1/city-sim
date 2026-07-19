# CitySim Audit Implementation Playbook

Use this reference to form coherent batches and choose evidence. Re-evaluate against the current audit and source; do not assume these examples are still open.

## Batch selection rules

Choose the smallest batch that completes a recognizable player outcome. Prefer dependencies and shared state boundaries over severity-only ordering.

### Batch A — Clear the playfield

Typical findings:

- persistent panels crowd the map;
- objectives and inspector open by default;
- repeated event cards obstruct play;
- compact layouts do not prioritize the map.

Likely surfaces:

- `ContentView.swift`
- `EventFeedView.swift`
- `ObjectivesView.swift`
- `CityGameStore.swift`
- window sizing and inspector composition

Evidence:

- map-area comparison at default and compact sizes;
- panel open/close behavior and state restoration;
- grouped/limited notifications under repeated events;
- keyboard and accessibility labels for every disclosure/dismiss control.

### Batch B — Make interaction modes explicit

Typical findings:

- primary click changes meaning implicitly;
- placement lacks footprint and validity preview;
- bulldoze state is unsafe or unclear;
- selection disappears in a busy scene;
- instructions are pointer-only.

Likely surfaces:

- `CityGameStore.swift`
- `CitySceneView.swift`
- `CityScene.swift`
- `BuildToolbarView.swift`
- app commands/keyboard shortcuts

Evidence:

- Build, Inspect, and Bulldoze have distinct visible and accessible state;
- hover over valid, invalid, occupied, and edge cells explains the next action;
- Escape cancels safely;
- placement shows footprint, cost/upkeep, and rejection reason before click;
- undo restores the exact prior state.

### Batch C — Clarify data and controls

Typical findings:

- metric labels hide denominators;
- time controls use ambiguous media icons;
- overlays are glyph-only or dominate the scene;
- inspector does not connect diagnosis to action;
- time and cost terminology is inconsistent.

Likely surfaces:

- `TopHUDView.swift`
- `MetricCard.swift`
- `OverlayPickerView.swift`
- `OverlayLegendView.swift`
- `InspectorView.swift`
- `GameTheme.swift`
- models/analytics for accurate semantics

Evidence:

- labels match inspector calculations and units;
- normal/City overlay reset is explicit;
- every overlay remains legible and offers a relevant action;
- speed controls read Pause, 1x, 2x, 3x visually and accessibly;
- diagnosis routes to a map or build remedy without losing context.

### Batch D — Stabilize and expose accessibility

Typical findings:

- simulation ticks invalidate focus or accessibility targets;
- SpriteKit nodes are unnamed glyphs;
- keyboard users cannot traverse the grid;
- color is the only status channel.

Likely surfaces:

- observation boundaries in SwiftUI/store state;
- `CityScene.swift` accessibility elements;
- focus state and app commands;
- semantic status styling

Evidence:

- stable focus and accessibility identity for 30 seconds at maximum speed;
- keyboard grid traversal with deterministic coordinate movement;
- every actionable tile announces coordinate, type, state, and available action;
- status remains understandable without color;
- VoiceOver and Full Keyboard Access results are reported separately from automation-tree inspection.

### Batch E — Restore decision pressure

Typical findings:

- treasury scale makes costs irrelevant;
- objectives remain completed forever;
- notifications have no meaningful priority.

Treat this as gameplay and data-model work, not a cosmetic UI batch. Inspect save compatibility and simulation tests before changing balance.

Evidence:

- scenario tests across early, mid, and established cities;
- deterministic finance/objective/event tests;
- save/load compatibility;
- a hands-on session showing readable tradeoffs and progressive goals.

## Implementation contract template

```markdown
## Batch: <player outcome>

Included findings: P1-XX, P2-YY
Deferred findings: P1-ZZ (reason)

### Problem
<reproduced current behavior>

### Outcome
<observable player behavior after implementation>

### Surfaces
- <file/layer and responsibility>

### Acceptance evidence
- State/unit: <test>
- Build: <command>
- Interactive: <flow>
- Visual: <default and compact proof>
- Accessibility: <labels, focus, keyboard, assistive-tech check>

### Risks
- <save/input/layout/performance risk and mitigation>
```

## Verification matrix

| Change type | Required automated evidence | Required live evidence |
|---|---|---|
| SwiftUI composition | State/view-model tests where logic exists; full `swift test` | Default and compact screenshots; panel interaction |
| SpriteKit interaction | Coordinate, hit-test, mode, and undo tests | Hover/preview/click/pan/zoom flow in real scene |
| Accessibility | Stable identity/state tests where feasible | Accessibility tree, keyboard flow, and explicit VoiceOver limitation/result |
| Analytics/labels | Calculation and formatting tests | HUD-to-inspector semantic comparison |
| Simulation/balance | Deterministic multi-step scenario and save tests | Early/mid/established play evidence |
| Commands/input | Store transition tests | Mouse, trackpad, keyboard, Escape, and undo flow |

## Anti-patterns

- Do not “fix clutter” by merely shrinking fonts and hit targets.
- Do not introduce a second source of truth for interaction mode or selected tile.
- Do not mark accessibility fixed because labels were added to surrounding SwiftUI while the map remains opaque.
- Do not use snapshot proof from a mock scene when the real SpriteKit scene can render.
- Do not change economy constants to make one saved city look better without scenario tests.
- Do not batch unrelated P2/P3 polish with a high-risk input or save-model refactor unless they share the same dependency.
- Do not claim the audit is closed while findings remain deferred or partially addressed.
