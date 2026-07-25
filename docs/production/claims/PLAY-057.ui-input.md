# PLAY-057 Claim

- **Title:** Let the player focus the city
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Base authority:** First published integration authority containing this claim
- **Claimed:** July 25, 2026
- **Planned surfaces:** existing command catalog/store presentation state, `ContentView`, top HUD and command deck composition, macOS command/menu wiring, focused UI/input/accessibility tests, and `docs/production/evidence/PLAY-057/`
- **Dependencies:** accepted PLAY-030/034/039/054/055; approved CONTRACT-012 and CONTRACT-014; exact published claim baseline
- **Validation/proof:** same-state regular and exact 900 x 600 closed/Focus City/open-Details frames; measured aperture; pointer/shortcut/command-guide/menu parity; mode/target/camera/panel continuity; modal/text quarantine; Escape/focus restoration; FKA/AX/Reduce Motion; 3x state updates; full suite; independent PLAY-058 review
- **Status:** dispatched; acceptance belongs to integration after PLAY-058

Implement the narrow transient Focus City mode authorized by CONTRACT-012.
When active, the city must dominate the window while a compact status rail
retains city identity, pause/speed, treasury direction, highest urgency,
selected-target/action truth, and an obvious exit. The full command surface
must return without losing camera, target, tool, panel choice, or focus.

Use the existing typed command route for the visible action, command guide,
macOS menu, and one conflict-free shortcut. Preserve modal quarantine,
topmost-Escape ownership, active-map-target identity, compact operation, Full
Keyboard Access, and accessibility semantics.

The exact staged pointer trace proved that disappearing SwiftUI chrome can
allow SpriteKit pointer targeting after the originating control consumed its
down/up sequence. CONTRACT-014 therefore adds the narrow UI/input-owned
`CityMapPointerTransitionGate` and permits `CitySceneView` to consult it at
the existing pointer candidate and primary/secondary bridges. Do not restore
state after an underlying map mutation.

Do not edit SpriteKit rendering/assets, gameplay, simulation, persistence, or
package/build scripts. Do not broaden CONTRACT-012 without an integration
proposal. Commit product, evidence, and completion outcomes separately. Do not
push, integrate, self-score, self-accept, or pin the thread.
