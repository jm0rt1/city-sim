# PLAY-050-D006 — Gameplay shortcuts are inert after Welcome dismissal

- Severity: critical Wave 002 acceptance blocker.
- Candidate: product `1084ba6ef624f9928d80f30829fe9f651ed68166`; playtest merge `d947b7d660d5778dcf34c165e750db293e060236`.
- Owner return: UI and Input.
- Requirements: D001 post-dismissal agency; keyboard-only route; command focus/surface precedence; decision by 02:00.
- Reproducibility: reproduced independently after both keyboard and pointer dismissal.

## Keyboard-dismissal reproduction

1. Launch the fresh, uniquely identified staged candidate at default size.
2. Leave Welcome open for at least 60 seconds and confirm the authored city remains Day 1.
3. Press Return to activate `welcome.start-building`.
4. Without clicking the map, press `Space`, `2`, `B`, and `Command-/`.
5. Close the command guide with Escape and inspect HUD/accessibility state.

Expected: Welcome transfers control into gameplay; Space pauses, 2 selects 2x, B selects Bulldoze, Command-/ opens the guide, and Escape closes the guide before cancelling the tool.

Actual: the global Command-/ and Escape routes operate, but Space, 2, and B do not. The city remains at 1x and advances to Day 10 while the newly disclosed pause shortcut is inert. Inspect remains selected.

## Pointer-dismissal reproduction

1. Reset only the candidate's isolated `hasSeenCitySimWelcome` preference and relaunch with `CITYSIM_COMPACT_WINDOW=1`.
2. Verify the same 60-second containment invariants.
3. Activate `welcome.start-building` by pointer.
4. Without clicking the SpriteKit map, press Space. Repeat after opening Objectives and Command Center using their global shortcuts.

Expected: Space pauses immediately after player agency begins.

Actual: Space remains inert. The city advances from Day 1 to Day 19 across repeated attempts while the Pause control remains `Not selected` and 1x remains `Selected`.

## Controlled comparison

With the same compact process and surfaces unchanged, click the accessibility element `SKView` once and press Space again. Pause immediately becomes `Selected`, 1x becomes `Not selected`, and the city stops at Day 19. The command implementation works; the post-Welcome focus transfer does not.

## Player impact

Welcome itself is safely quarantined, but the first instruction handed to a new player—“Space pauses”—fails at the moment control is returned. Modified global shortcuts continue to work, making the failure inconsistent and difficult to diagnose. The player can unknowingly lose days while believing pause or speed/tool commands were accepted. This violates the frozen focus and keyboard gate and invalidates decision timing.

Evidence: `../d006-post-dismissal-shortcuts-inert.jpeg`, `../d006-map-focused-space-works.jpeg`, and `focus-reproduction.txt`.

No product repair was made by PLAY-050.
