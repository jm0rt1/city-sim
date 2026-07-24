# PLAY-033 Claim

- **Title:** Make the HUD a compact city command center
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Base commit:** Accepted beauty baseline `9f38efec4877ab7c3f0d77bf3bd4e36b56e3c034`
- **Claimed:** July 21, 2026
- **Planned surfaces:** SwiftUI HUD/panel composition, existing store/catalog/focus routing, command metadata/search, placement-rejection presentation, accessibility, UI/input tests, and exact staged proof
- **Dependencies:** accepted PLAY-013 authoritative analytics, PLAY-047 story states, and PLAY-034 active-target truth; no new public command/store/focus contract required
- **Validation/proof:** retained under `docs/production/evidence/PLAY-033/61d5376-hud-command-center/`; default and exact 900 x 600 pointer/keyboard journeys, 41% compact map occupancy, both strategy story matrices, warning-to-action routes, persistent rejection recovery, command search, focus traces, AX tree, Full Keyboard Access-critical and VoiceOver-critical semantics, full suite, and exact staged manifest
- **Status:** ready-for-integration at product checkpoint `61d5376c86b2c88399b4b24884818dc680cf2c08`

Make the HUD feel like a decisive command center: one visible urgent decision, one short route to action, durable recovery from invalid placement, and no compact panel combination that relegates the map to a strip. Preserve one catalog/store intent path and measured HUD-safe map insets.

Do not infer strategy timing, duplicate simulation truth, change gameplay balance, claim renderer placement truth, add ad hoc shortcuts, or redesign persistence.
