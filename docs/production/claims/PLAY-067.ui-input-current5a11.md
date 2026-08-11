# PLAY-067 Current-Baseline Claim — Make the HUD Breathe with the City

- **Task:** PLAY-067 — Make the HUD breathe with the city
- **Lane:** UI and input
- **Owner:** Agent 301, thread `019fec92-42dc-7eb2-8993-c9fd8ffdf3bf`
- **Branch:** `codex/citysim-ui-play067-current5a11`
- **Worktree:** `/private/tmp/citysim-play067-hud-current5a11`
- **Authority:** `5a1169498fe5ca7b2f240d0a05bb18e7336a3546`
- **Product baseline:** `24e899623471d4f74165ded9672a1f4e6a21ea29`
- **Status:** Active current-baseline outcome lease.

## Player outcome

At regular and exact 900 x 600 layouts, the city trajectory, current priority,
selected-target truth, and next useful action remain immediately legible while
the map stays dominant. Opening Details progressively discloses one complete,
actionable section without losing the active target, focus, or usable map
aperture.

## Mutable maximum

- `Native/CitySimNative/Sources/CitySimNative/Views/TopHUDView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/StrategyCommandCenterView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/BuildToolbarView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/InspectorView.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CitySimulationTests.swift`
- `docs/production/evidence/PLAY-067/current5a11/`
- `docs/production/completed/PLAY-067.ui-input-current5a11.md`

The allowlist is a maximum, not a required touched-file count. Change only
meaningful paths needed for the bounded outcome.

## Frozen contracts

Consume only existing objective, trajectory, priority, selected-target, and
typed-command truth. Do not add commands or a parallel truth source; change
gameplay, simulation, saves, renderer, assets, camera, active map coordinates,
default target identity, theme contracts, packages, or build scripts; shrink
hit targets; introduce pointer-only behavior; or disturb the accepted PLAY-066
process PID 76765.

## Execution and proof

Agent 301 owns one outcome-fast-path task: inspect the current regular and exact
900 x 600 HUD/Details behavior, implement the smallest contract-preserving UI
correction if a concrete deficiency remains, run one focused Swift proof for
trajectory/priority/target/action truth and pointer/keyboard/FKA/AX/Escape
parity, capture current regular and exact-compact evidence through an existing
test-owned surface where available, stage explicit meaningful paths, and create
one coherent `PLAY-067:` commit. One bounded local repair is allowed after a
first focused failure; a second failure stops.

Return `NO_REAL_GAP` without manufacturing an edit if the current baseline
already satisfies the player outcome. Stop on any shared-contract need,
truth ambiguity, unexpected path, target/focus drift, unusable aperture, or
scope expansion. No aggregate, stage-only build, real-app QA, integration,
push, release, or self-acceptance.
