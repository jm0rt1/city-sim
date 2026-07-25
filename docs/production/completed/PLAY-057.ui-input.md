# PLAY-057 Completion — Focus the City Safely

- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Status:** ready-for-integration
- **Published CONTRACT-014 authority:**
  `82b5a1d7ae64174fccb9e3c7f6fc86517e120251`
- **Focus City product:** `5165615f63775f6f67bfba0f1643d8f2679e4374`
- **Pointer transition product:**
  `16dec0d7172557dc57518eea828c89d321544ffc`
- **Candidate-bound evidence:**
  `ba79a0b8b36859b67292a6794c81170b7a9a4e0d`
- **Evidence root:**
  `docs/production/evidence/PLAY-057/candidate-16dec0d-contract014/`

The completion-record commit containing this file is reported in the lane
handoff because a commit cannot embed its own identity.

## Player-visible outcome

Focus City now gives the world materially more room while retaining city/day,
paused/running speed, treasury direction, the highest authoritative urgency,
notice count/severity, selected target/action truth, and an obvious exit.
The existing typed command is available from the HUD, command guide, macOS
menu, and `Shift-Command-F`, with topmost Escape and deterministic focus
restoration.

The disappearing-chrome pointer defect is closed without restoring state after
an underlying map mutation. Pointer enter and exit now start one transient
UI/input gate before chrome changes. The gate rejects only SpriteKit pointer
target candidates and pointer primary/secondary actions while the originating
pointer remains stationary. Same-window movement beyond four points or a safe
lifecycle cancellation clears it. Keyboard, menu, command-guide, FKA, and
accessibility routes remain immediate.

## Ordered candidate checkpoints

1. `86a3711` — `PLAY-057: Freeze Focus City baseline`
2. `5165615` — `PLAY-057: Focus the city without hiding urgent truth`
3. `55b7af2` — `PLAY-057: Retain rejected pointer-boundary evidence`
4. `2642ec5` — `PLAY-057: Instrument Focus pointer monitor geometry`
5. `346f60f` — `PLAY-057: Retain shared input-boundary trace`
6. `9b0b982` — non-rewriting merge of published CONTRACT-014 authority
7. `16dec0d` — `PLAY-057: Quarantine map input during Focus transitions`
8. `ba79a0b` — `PLAY-057: Bind pointer transition proof`

The intervening pointer-shield and state-restoration commits remain preserved
ancestors and are explicitly rejected evidence, not candidate behavior.

## Product and test surfaces

The Focus City feature uses the existing command/store path and UI/input-owned
composition:

- `Native/CitySimNative/Sources/CitySimNative/App/CitySimNativeApp.swift`
- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Sources/CitySimNative/Support/CityCommandCatalog.swift`
- `Native/CitySimNative/Sources/CitySimNative/Support/CityMapPointerTransitionGate.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/CitySceneView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/ContentView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/TopHUDView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/BuildToolbarView.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CitySimulationTests.swift`

The CONTRACT-014 repair does not modify `CityScene`, renderer art or geometry,
simulation/gameplay rules, persistence, save schema, assets, package/build
scripts, or the command inventory. It does not create a second target or
restore selected state after a mutation.

## Automated result

- Focus pointer-transition subset: **4 tests, 0 failures**.
- `CityCommandCatalogTests`: **43 tests, 0 failures**.
- Complete native suite: **218 tests, 0 failures, 101.676 seconds**.
- `git diff --cached --check`: passed for product and evidence checkpoints.
- Exact staged bundle: built successfully with
  `./script/build_and_run.sh --stage-only`.

Tests cover fixed-threshold movement, zero-delta/synthetic hover, originating
window identity, lifecycle cancellation, unrelated-event pass-through,
transparent monitor hit testing, exactly-once typed dispatch, and all three
approved pointer bridges. Inspect, build, and bulldoze assertions bind the
state fingerprint, treasury, exact undo depth, coordinate, target/action,
tool/mode, panels, focus generation, and camera position/scale.

## Exact staged proof

- Candidate: `ui-input-wdbeadac6e0bd`
- Bundle identifier:
  `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Executable SHA-256:
  `06a5a49c0cdd711b220a8799ec6b8c935931f89683891e04bd0fc3e986036140`
- Loaded quicksave SHA-256:
  `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`
- Regular proof frame: 1,278 x 768
- Compact proof frame: 900 x 652, exact 900 x 600 content plus title bar

Real-pointer enter and exit passed for inspect, Road build, and bulldoze in
both regular and compact layouts. Every route retained City Hall block 12,12,
the exact action/availability reason, `$34,037`, disabled Undo, selected
mode/tool, and pixel-aligned camera geometry. The separate compact
Details-open → Focus → exit route restored Details and the same target/action.

Measured visible world aperture:

- regular: 447 → 634 pixels;
- compact: 361/600 (60.2%) → 494/600 (82.3%);
- compact open Details: 271/600 (45.2%).

Shortcut, menu, command-guide search, topmost Escape, FKA traversal/Space,
semantic AX identity/default-action routing, and Reduce Motion passed. The
live AX tree exposes one Focus enter/exit action and no monitor overlay
duplicate.

## Accessibility and focus

The SwiftUI button remains the sole semantic, focus-ring, FKA, and AX route.
The AppKit observer consumes no event. FKA reached the exact exit button and
Space restored map focus. AX labels, help, stable IDs, shortcut values,
highest notice severity/count, selected action, and availability reasons
remain present in regular and compact trees.

Spoken VoiceOver audio was not recorded and is not claimed. Live AX hierarchy,
FKA activation, and focused exactly-once accessibility dispatch tests are
retained separately and reported accurately.

## Save, performance, and known limitations

- The gate is transient presentation input state; it is not saved,
  fingerprinted, replayed, simulated, or copied into immutable city snapshots.
- The observer does not consume unrelated events and removes itself on safe
  lifecycle cancellation.
- No save/session behavior changed, and pointer Focus transitions perform no
  city-state mutation.
- Aperture is measured manually from original candidate pixels and
  corroborated by layout tests.
- Independent PLAY-058 and integration own acceptance. This lane does not
  self-score or self-accept.

No push, integration, rebase, force, state restoration, or thread pinning was
performed.
