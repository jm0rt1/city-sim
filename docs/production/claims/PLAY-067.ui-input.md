# PLAY-067 Claim

- **Title:** Make the HUD breathe with the city
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Base authority:** Published `1b883ca684b07ba38c5c755b616723bde0cd2230`
- **Planned surfaces:** existing store presentation state and typed commands, `ContentView`, top HUD/priority/command/details composition, theme tokens, menus/guide wiring where needed, focused UI/accessibility tests, staged proof, and `docs/production/evidence/PLAY-067/`
- **Dependencies:** accepted PLAY-030/034/039/054/057, exact published baseline; PLAY-064 state may be consumed only through accepted existing objective/message mappings
- **Validation/proof:** same-state baseline/candidate normal/Focus City/open-Details frames at regular and exact 900 x 600; measured aperture; objective/urgency/trajectory/selected-target/action truth; pointer/keyboard/guide/menu parity; target/camera continuity; modal/text quarantine; Escape/focus restoration; FKA/AX/Reduce Motion; full suite; PLAY-068 independent review
- **Status:** authorized on the exact published baseline

Create a polished situational command layer that makes the current objective,
trajectory, urgency, selected target, and next useful action legible without
stacking heavy panels over the city. Details must progressively disclose
information while preserving a useful map aperture and the active target.

Every action remains routed through the typed command catalog. Do not add UI
rules that disagree with simulation/gameplay, move the active map target,
edit SpriteKit/assets/persistence/gameplay rules, create pointer-only actions,
push, integrate, self-score, self-accept, or pin the thread.
