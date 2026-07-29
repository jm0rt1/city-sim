# PLAY-082 Completion — Make the Selected Target Unmistakable

- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Status:** technical-handoff-live-gate-pending
- **Corrected claim authority:**
  `d15b3b41e3abd61d9a28e9e8611593e954625388`
- **Merged published authority:**
  `775bea061ee4e9cb0af7842edbd1ec341d61aa41`
- **Initial product candidate:**
  `3b9242efcde6f6183c4de9649afbe66085db3478`
- **Regular-width product candidate:**
  `816f8f321ec506979f8258e34ea05eed366a6bd1`
- **Action-truth product candidate:**
  `d12d1df1948605153e7fa91c7ea05621391a71fb`
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
- Compact/authentic-regular focused rail renders: 884 x 64 and 1120 x 64
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
2. `80c527a18c66288f2316556b4169e00644844493` —
   `PLAY-082: Bind selected target evidence`
3. `816f8f321ec506979f8258e34ea05eed366a6bd1` —
   `PLAY-082: Bind the authentic regular command rail`
4. `c76c75279237c6d50b3fe41e02b7c929ae91f828` —
   `PLAY-082: Correct regular rail evidence`
5. `d12d1df1948605153e7fa91c7ea05621391a71fb` —
   `PLAY-082: Make beacon actions truthful to accessibility`
6. Return evidence/completion commit — reported in the clean handoff.

## Integration-return correction

The prior 1020-point forced-noncompact unit render is retained but rejected:
it is below ContentView's real regular breakpoint and visibly wrapped several
labels. The corrected test now enters through a 1278 x 768 regular window and
binds the real 1120 x 64 command-rail maximum.

At that authentic width, the first render isolated one remaining defect:
`Commands` wrapped. A two-modifier BuildToolbarView repair keeps that existing
label single-line at its natural width. The corrected regular proof shows
Inspect, Bulldoze, Commands, Details, the `City Hall` beacon title, and
`INSPECT` status single-line and unclipped. Compact remains clean and the
viewport-settlement test remains green.

Focused return results:

- selected-target beacon suite: **3/3 passed**;
- affected viewport-settlement test: **1/1 passed**;
- rail heights: unchanged at 64 points;
- command/store/focus/AX behavior: unchanged;
- locked-desktop staged interaction limitation: retained without retry or
  self-acceptance.

## Independent-return accessibility correction

Build and bulldoze beacons no longer announce an action they do not perform.
Every actionable beacon now says `Open details for <target/tool> at block …`.
Its AX value continues to expose the existing build/demolish readiness,
blocked reason, cost/consequence, and protection disclosure.

Exact focused assertions cover inspect, build-ready, build-blocked,
bulldoze-ready, bulldoze-blocked, and all nil controls. The 3/3 beacon suite
and 1/1 viewport test pass. Exactly-once command routing, Escape/focus/state
continuity, the 64-point rail, authentic 1120 proof, and the locked-desktop
limitation are unchanged.

## Scope and limitations

- Product mutation is confined to `BuildToolbarView.swift`.
- Focused tests are confined to the already claimed
  `CitySimulationTests.swift`.
- No ContentView, CityScene, store, command, objective, alert, renderer,
  gameplay, simulation, persistence, theme, package, build-script, shared
  authority, or legacy Python file changed.
- Deterministic rail renders supplement but do not replace real-app proof.
- No shared-contract blocker was introduced.
