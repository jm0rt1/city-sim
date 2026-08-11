# PLAY-087 Current-Baseline Claim

- **Task:** PLAY-087 — Unify map diagnostics into one compact palette
- **Lane:** UI and input
- **Owner:** Agent 301 — UI/Input Lead
- **Thread:** `019fec92-42dc-7eb2-8993-c9fd8ffdf3bf`
- **Branch:** `codex/citysim-ui-diagnostics-current328b`
- **Worktree:** `/private/tmp/citysim-play087-diagnostics-current328b`
- **Product base:** `328b7d443d34e2a9308a97425c99c5438d3120ac`
- **Product tree:** `2b446d7a50dbae12a3126f4f8ba4c08e3e9580a8`
- **Status:** Active once the schema-2 outcome lease validates.

## Player outcome

The player can switch, understand, and clear City plus all five diagnostic
overlays from one compact bottom-deck palette without losing the selected
place, blocked-action feedback, or valuable map aperture. The palette names
the active layer, its normalized scale, applicability or no-data state,
source/freshness, and click-through meaning. It uses `Traffic pressure` and
never implies measured vehicles, flow, or congestion.

## Maximum mutable paths

- `Native/CitySimNative/Sources/CitySimNative/Views/OverlayPickerView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/OverlayLegendView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/BuildToolbarView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/ContentView.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/OverlayDiagnosticsPaletteTests.swift`
- `docs/production/evidence/PLAY-087/current328b/`
- `docs/production/completed/PLAY-087.ui-input.md`

Fewer changed paths are valid. Every other product, test, claim, contract,
renderer, simulation, gameplay, save, package, build, art, protected-dirt, and
accepted-QA byte is immutable.

## Frozen contracts and acceptance boundary

- Reuse the existing `DataOverlay`, command catalog, store state, normalized
  diagnostics, selected target, and feedback contracts without changing them.
- Preserve the accepted map-first regular and exact 900 x 600 composition,
  current selection, build preview, blocked-placement feedback, focus, Escape,
  Full Keyboard Access, VoiceOver, and Reduced Motion behavior.
- City/clear remains directly available; the five overlays remain reachable by
  pointer, menu, `Control-0...Control-5`, Full Keyboard Access, and VoiceOver.
- Focused proof owns executable layout/command/accessibility behavior only.
  Integration retains the full aggregate/build gate and independent real-app
  visual/usability acceptance for a later exact candidate.
- One bounded repair is permitted after the first focused failure. A second
  focused failure, shared contract need, semantic ambiguity, out-of-scope path,
  compact-height/map-aperture regression, or subjective visual judgment stops.

## Focused proof and completion

Run the claim-bound focused palette test with fresh writable caches, then
`git diff --check`; stage only actual changed allowed paths, inspect the full
index, and create one coherent commit with subject
`PLAY-087: Unify map diagnostics into one compact palette`. Do not push,
integrate, run the aggregate suite, stage the app, launch, signal the accepted
process, self-accept, or claim release.
