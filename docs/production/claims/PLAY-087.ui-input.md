# PLAY-087 Claim

- **Title:** Unify map diagnostics into one compact palette
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Base authority:** Future published clean Integration commit after PLAY-084
  acceptance
- **Planned surfaces:** `OverlayPickerView.swift`, `OverlayLegendView.swift`,
  `BuildToolbarView.swift`, `ContentView.swift`,
  `OverlayDiagnosticsPaletteTests.swift`, `docs/production/evidence/PLAY-087/`,
  and `docs/production/completed/PLAY-087.ui-input.md`
- **Dependencies:** PLAY-084 accepted; CONTRACT-013; existing command catalog
- **Validation/proof:** Focused layout/command/AX tests; complete native suite;
  exact staged regular/compact pointer, keyboard, FKA, VoiceOver, Escape, and
  grayscale journey; measured HUD/chrome/map aperture
- **Status:** Queued; do not mutate until PLAY-084 is accepted and Integration
  publishes an exact baseline dispatch

Use only existing overlay state, command routes, and normalized diagnostic
channels. Correct the player-facing term to `Traffic pressure` and never imply
measured vehicles, flow, or congestion. Keep City/clear direct, make
applicability and no-data explicit, and preserve the map as the dominant
surface.

Do not edit PLAY-084 files, DataOverlay, stores, commands, simulation,
snapshots, renderer, GameTheme, saves, package/build files, art, or legacy
Python. Do not push, integrate, pin, self-score, or self-accept.
