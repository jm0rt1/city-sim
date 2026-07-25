# PLAY-067 Completion — Make the HUD Breathe with the City

- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Status:** ready-for-independent-quality-review
- **Published authority:**
  `0ed9f3a8ad28d6b29f734c97f3dd3111fd118cc6`
- **Exact staged product candidate:**
  `5b47ca6a3ca10ba51c20f94b0b38d203b3ffbaa8`
- **Evidence root:**
  `docs/production/evidence/PLAY-067/candidate-5b47ca6/`

The completion-record commit containing this file is reported in the lane
handoff because a commit cannot embed its own identity.

## Outcome

The normal command surface now presents the city's objective, treasury
trajectory, urgency, selected-target truth, and most useful existing action at
a glance while materially increasing the world aperture. The full priority
explanation remains on regular widths; compact retains the authoritative
title, status, trajectory, and action without stacking prose over the city.

Details now behaves as progressive disclosure. Its first complete card is the
existing next action; identity and diagnostics follow, and the selected target
remains in the command row. The city remains useful behind the panel:
507 visible map pixels regular/415 compact when closed and 363 regular/304
compact with Details open. Exact compact shares are 69.2% closed and 50.7%
open; Focus City remains 82.5%.

## Product and test surfaces

- `Native/CitySimNative/Sources/CitySimNative/Views/TopHUDView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/StrategyCommandCenterView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/BuildToolbarView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/InspectorView.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CitySimulationTests.swift`

The trajectory presentation consumes only existing
`CityAnalytics.projectedBalance`. Existing objective/message mappings,
commands, store intents, selected coordinate, camera, modal/text policy,
Escape ordering, and focus generation remain authoritative.

No SpriteKit, assets, persistence, gameplay, simulation, save schema, package,
build script, shared contract, or task authority changed.

## Verification

- Focused layout and command-center rendering tests: 3 tests, 0 failures.
- Complete native suite: **226 tests, 0 failures, 119.396 seconds**.
- Exact staged bundle: passed at the product commit.
- Executable SHA-256:
  `7faa948305c993bf117f35b7b40e37e40346ce5e94a89398c9c467f658fd6924`.
- Regular frames: 1278 x 768.
- Compact frames: 900 x 652, exact 900 x 600 content plus titlebar.
- `git diff --check` and repository shell syntax: passed.

Real regular and compact journeys covered pointer Details, pointer Focus
enter/exit, `Shift-Command-F`, topmost Escape, guide search and Return
activation for Tax Policy, FKA-critical traversal, AX value/action
descriptions, target/focus continuity, and compact Reduce Motion.

The rejected inherited-window attempt is preserved but excluded from all
binding measurements. Spoken VoiceOver audio was not recorded; live AX trees,
FKA traversal, and the complete automated accessibility/input suite are the
claimed evidence.

No push, integration, rebase, force, thread pinning, self-score, or
self-acceptance was performed.
