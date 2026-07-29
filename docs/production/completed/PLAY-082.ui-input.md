# PLAY-082 Completion — Make the Selected Target Unmistakable

- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Status:** technical-handoff-live-gate-pending
- **Corrected claim authority:**
  `d15b3b41e3abd61d9a28e9e8611593e954625388`
- **Merged published authority:**
  `775bea061ee4e9cb0af7842edbd1ec341d61aa41`
- **Product candidate:**
  `3b9242efcde6f6183c4de9649afbe66085db3478`
- **Evidence root:**
  `docs/production/evidence/PLAY-082/candidate-3b9242e/`

The evidence/completion commit containing this record is reported in the lane
handoff because a commit cannot embed its own identity.

## Outcome

The closed command rail now makes the active map target readable at a glance:
strong name, one-based block, and inspect/build/bulldoze availability state
come directly from the existing selected tile and active-target presentation.
Nil selection stays truthful.

The selected target remains `hud.selected.context`. Its existing semantic
SwiftUI button performs the existing `toggleCommandCenter` command once.
Escape follows the existing topmost cancellation route and restores map focus
without changing selection, tool, city state, or Undo.

The beacon fits the existing 64-point compact and regular situational rails.
No map aperture, scene geometry, store state, command inventory, objective,
alert, or shared theme contract changed.

## Verification

- New focused tests: **3/3 passed**
- Complete native suite, repeated without competing load: **274/274 passed**
- Four contention-affected timing methods, isolated: **4/4 passed**
- Exact staged candidate build and `--verify`: passed
- Staged executable SHA-256:
  `d30488dff241d75427f47775c3ba05d8ccc9b6290d5807c5e00e9f3d9e6ff803`
- Compact/regular focused rail renders: 884 x 64 and 1020 x 64
- Closed interactive map aperture retained: regular 554/768 points (72.1%);
  exact compact 416/600 points (69.3%)
- `git diff --check` and repository shell syntax: passed
- Exact staged candidate terminated; zero matching candidate/test process at
  handoff

## Accessibility and interaction contract

Focused tests prove exact AX label/value truth for nil, inspect, build-ready,
build-blocked, bulldoze-ready, and bulldoze-blocked states. They also prove
exactly-once Details activation, selection/state continuity, and one focus
restoration request on Escape.

The desktop was locked during the candidate-bound Computer Use attempt.
Integration explicitly directed the lane to stop retrying and retain the
blocked attempt. Consequently pointer, Return, FKA, AX press, Escape,
City/Pollution, Reduce Motion, and regular/exact-compact staged-app journeys
remain a required integration gate; they are not self-accepted here.

## Ordered commits

1. `3b9242efcde6f6183c4de9649afbe66085db3478` —
   `PLAY-082: Make selected targets unmistakable`
2. Evidence/completion commit — reported in the clean handoff.

## Scope and limitations

- Product mutation is confined to `BuildToolbarView.swift`.
- Focused tests are confined to the already claimed
  `CitySimulationTests.swift`.
- No ContentView, CityScene, store, command, objective, alert, renderer,
  gameplay, simulation, persistence, theme, package, build-script, shared
  authority, or legacy Python file changed.
- Deterministic rail renders supplement but do not replace real-app proof.
- No shared-contract blocker was introduced.
