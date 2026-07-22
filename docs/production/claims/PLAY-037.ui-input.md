# PLAY-037 Claim

- **Title:** Restore compact spatial keyboard and Escape parity
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Base authority:** Wave 005 integration commit
- **Requirement IDs:** UX-003, UX-004, UX-009, UX-010, REL-005
- **Defect authority:** PLAY-051 exact candidate `23d2bf9`
- **Planned surfaces:** compact `CitySceneView` lifecycle/identity, map focus and AX semantics, surface-cancellation arbitration, focused UI/input tests, exact staged default/compact evidence
- **Dependencies:** accepted PLAY-035/036 integration; independent of PLAY-022 and blocked PLAY-034
- **Validation/proof:** exact 900 x 600 semantic City map, arrow and Shift-arrow selection, selected action reachability, Command Center then Objectives Escape order, pointer control, text/modal quarantine, Full Keyboard Access and AX evidence
- **Status:** claimed for Wave 005

Repair compact presentation without changing the active target contract, build validation, renderer art, or simulation. The same `CityMapSKView` identity and accessibility semantics must survive compact recomposition, and successive Escape presses must close only the topmost governed surface.
