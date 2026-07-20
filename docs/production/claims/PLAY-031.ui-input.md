# PLAY-031 Claim

- **Title:** Quarantine onboarding input and restore the intended window
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Base commit:** Integration authority commit containing this claim, with `c70321b` as the product candidate ancestor
- **Claimed:** July 20, 2026
- **Planned surfaces:** `App/`, `Views/`, UI/input portions of `Stores/CityGameStore.swift`, command availability/routing tests, proof-window behavior, and candidate-specific evidence
- **Dependencies:** PLAY-050 D005 reproduction and accepted CONTRACT-002 command catalog
- **Validation/proof:** Focused routing/modal/window tests, full suite, staged default/compact pointer and keyboard onboarding, accessibility/focus evidence, and exact D005 regression sequence
- **Status:** accepted and closed; D006 passed default/compact keyboard and pointer routes without an extra map click

The repair must establish one typed blocking-modal policy consumed by every command route. It may not fix individual leaked shortcuts independently or weaken the frozen PLAY-050 gate.
