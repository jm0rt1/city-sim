# PLAY-074 Claim

- **Title:** Make building and recovery obvious on the map
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Base authority:** Published Wave 008 product candidate `87e1e682566b68d20deb1a9e2028e2b885e0423a`
- **Planned surfaces:** existing store presentation and typed commands, map-first construction/diagnosis/recovery composition, preview and decision-support UI, menus/guide wiring, focused UI/accessibility tests, staged proof, and `docs/production/evidence/PLAY-074/`
- **Dependencies:** accepted PLAY-067/070 product; existing typed command/store contracts; no new public command without integration approval
- **Validation/proof:** target/footprint/cost/availability/consequence/cancel before commit; invalid reason durability; selected-place recovery action; regular/compact map aperture; pointer/keyboard/menu/guide/Escape/FKA/AX/VoiceOver/Reduce Motion; undo/save/load; full suite; PLAY-075
- **Status:** accepted into integration through final Focus City merge
  `b259187`; exact integrated build `fbbff0c` passed 257/257, staged
  verification, and integration's direct Return/Undo keyboard replay

Make the core build-diagnose-recover loop direct and map-first. The player
must understand what will happen before commitment and what to do after a
setback without searching through stacked panels.

Keep every action in the typed command catalog and preserve the active
coordinate through every surface. Do not add UI rules that disagree with
gameplay, edit SpriteKit/assets/persistence, create pointer-only actions, cover
the city with new panels, or invent a second truth source. Do not push,
integrate, self-score, self-accept, or pin.
