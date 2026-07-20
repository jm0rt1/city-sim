# PLAY-032 Claim

- **Title:** Turn diagnosis into direct action
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Base commit:** Accepted Wave 002 publication `74b694d`; authority commit containing this claim
- **Claimed:** July 20, 2026
- **Planned surfaces:** `App/`, `Views/`, approved command/focus/store routing, UI/input tests, accessibility, and staged journey evidence
- **Dependencies:** accepted PLAY-031; approved PLAY-041 truth; integration approval for any new shared command, store, focus, or snapshot contract
- **Validation/proof:** cause/consequence/remedy inventory, pointer-keyboard intent parity, spatial-navigation/focus tests, default/compact/Full Keyboard Access/VoiceOver live journeys, full suite, and staged build
- **Status:** focused repair checkpoint validated; staged-app and independent live acceptance remain pending

Make critical warnings actionable and design governed keyboard spatial navigation without creating a second command system. Journey mapping, remedy design, interaction prototypes, and contract proposals may start immediately.

Do not duplicate simulation truth, add ad hoc shortcuts, or mutate shared public surfaces before integration approval.

## Independent audit repair scope

- Replace the symmetric camera reveal heuristic with measured, asymmetric top/bottom HUD occlusion bounds at regular and exact 900 x 600 layouts.
- Make the map's primary accessibility action identify its current inspect/build/bulldoze intent, target, availability, and destructive cost before activation.
- Keep invalid and protected primary actions unavailable while preserving the existing one-press valid action and undo route.
- Keep the demolition disclosure/control present alongside selected-location diagnosis rather than allowing diagnosis to replace it.
- Compare the UI action catalog to the warning/critical titles authored in the integrated PLAY-012 simulation source so additions and renames fail loudly.
