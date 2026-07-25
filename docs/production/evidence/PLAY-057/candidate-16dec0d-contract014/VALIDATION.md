# PLAY-057 CONTRACT-014 Validation

## Outcome

The exact staged candidate closes the disappearing-chrome pointer boundary
without restoring state after a map mutation. A pointer-originated Focus City
enter or exit starts one UI/input-owned transition gate before chrome changes.
The existing `CitySceneView` adapter rejects only pointer target candidates
and pointer primary/secondary map actions until same-window movement exceeds
the fixed four-point threshold or a safe lifecycle cancellation occurs.

The SwiftUI buttons remain the sole semantic, Full Keyboard Access, focus-ring,
and accessibility controls. The local monitor observes the originating
down/drag/up sequence but returns every event unchanged. Shortcut, menu,
command-guide, keyboard-map, FKA, and accessibility routes remain immediate.

No store state restoration, `CityScene` rendering change, gameplay rule,
simulation rule, save schema, asset, camera contract, command inventory, or
build-script change is part of the product commit.

## Automated validation

At exact product commit `16dec0d7172557dc57518eea828c89d321544ffc`:

- Focus pointer-transition subset: **4 tests, 0 failures**.
- `CityCommandCatalogTests`: **43 tests, 0 failures**.
- Complete native suite:
  `swift test --package-path Native/CitySimNative`:
  **218 tests, 0 failures, 101.676 seconds**.
- `git diff --cached --check`: passed before the product commit.
- The staged bundle built successfully with
  `./script/build_and_run.sh --stage-only`.

Focused coverage proves:

- originating-window identity and unrelated-event pass-through;
- the monitor view is hit-test transparent and does not replace the semantic
  SwiftUI button;
- cancelled, removed, and completed control lifecycles;
- zero-delta and exact-threshold events keep the gate active;
- same-window movement beyond four points clears it;
- window close safely cancels it;
- inspect, build, and bulldoze pointer candidate/primary/secondary bridges are
  blocked during the transition;
- keyboard/accessibility map actions remain outside the gate;
- typed Focus City dispatch occurs exactly once on enter and exit;
- state fingerprint, treasury, undo depth, coordinate, selected target/action,
  tool/mode, panel state, camera position/scale, and focus generation remain
  exact except for the single intended focus-mode toggle.

## Exact staged state

Both layouts used the same loaded quicksave and authoritative state:

- New Arcadia, Day 33, paused;
- treasury `$34,037`, net `+$93 / cycle`;
- 12 notices, highest severity warning;
- priority `Prepare for the load surge`, `DECISION · 16 DAYS`;
- selected City Hall at block `12, 12`;
- Undo disabled before and after each attempted transition.

The binding accessibility trees retain that identity:

- inspect: `Inspect City Hall at block 12, 12`, available;
- build: `Build Road at block 12, 12`, unavailable because the existing
  structure must be demolished first;
- bulldoze: `Demolish City Hall at block 12, 12`, unavailable because City Hall
  is a protected landmark.

The full state digest and private undo depth are asserted in focused tests.
The live trees independently retain the player-visible coordinate, target,
action/reason, treasury, selected mode/tool, and disabled Undo.

## Real pointer journeys

Computer Use drove the visible control center derived from the live
accessibility surface, not a stale hard-coded coordinate.

### Regular

For inspect, Road build, and bulldoze:

1. capture the closed state;
2. click Enter Focus City with a real pointer;
3. capture the focused state while the pointer remains stationary;
4. click Exit Focus City with a real pointer;
5. capture the restored command surface.

Every route retained block `12, 12`, the selected target/action and accepted
availability reason, `$34,037`, disabled Undo, and the same camera geometry.
No map candidate, primary action, or secondary action leaked through either
transition.

### Exact compact

The same inspect, Road build, and bulldoze routes passed at exact 900 x 600
content with Reduce Motion proof enabled. The compact Details continuity route
also passed:

1. open City Hall Details while bulldoze remains selected;
2. enter Focus City by pointer;
3. exit Focus City by pointer;
4. verify Details reappears with the same block, target/action, reason, camera,
   treasury, and disabled Undo.

## Aperture and camera identity

Manual measurement on the retained original pixels:

| Layout | Closed world | Focus world | Open Details |
|---|---:|---:|---:|
| Regular 1,278 x 768 | 447 px | 634 px | separately retained continuity route |
| Compact 900 x 600 content | 361 px (60.2%) | 494 px (82.3%) | 271 px (45.2%) |

The selected City Hall and surrounding road/building geometry remain
pixel-aligned between each uninterrupted closed-to-Focus pair. Focus increases
only the chrome aperture; it does not reset, scale, or translate the camera.

## Immediate non-pointer routes

- `Shift-Command-F` toggled Focus City while the pointer gate remained active
  and preserved the bulldoze target.
- City Data > Toggle Focus City used the existing typed command route.
- Command-/ opened the searchable guide; `focus city` exposed the available
  Toggle Focus City result and activation used that catalog/store route.
- Escape exited Focus City topmost and restored the prior command surface
  without cancelling the bulldoze target.
- Full Keyboard Access traversal reached `hud.focus-city.exit`; Space
  activated it and restored map focus.
- Live AX trees expose one semantic enter/exit button with the approved label,
  help, shortcut value, and stable ID. No monitor overlay appears as a second
  action. Focused tests exercise the same exactly-once typed route used by the
  accessibility default action.
- Reduce Motion keeps the compact composition, input quarantine, focus route,
  and AX semantics intact.

Spoken VoiceOver audio was not recorded and is not claimed. The retained live
AX hierarchy plus FKA activation and focused accessibility dispatch tests are
the candidate evidence.

## Evidence index

Binding screenshots and AX trees are under:

- `live/regular/regular-inspect-*`
- `live/regular/regular-build-*`
- `live/regular/regular-bulldoze-*`
- `live/compact/compact-inspect-*`
- `live/compact/compact-build-*`
- `live/compact/compact-bulldoze-*`

Non-pointer and panel-continuity records:

- `live/regular/regular-shortcut-immediate-focus.ax.txt`
- `live/regular/regular-menu-focus.ax.txt`
- `live/regular/regular-command-guide-focus.ax.txt`
- `live/regular/regular-escape-restores-bulldoze.ax.txt`
- `live/regular/regular-fka-exit-focused.ax.txt`
- `live/regular/regular-fka-space-exit.ax.txt`
- `live/compact/compact-details-before-focus.ax.txt`
- `live/compact/compact-details-to-focus.ax.txt`
- `live/compact/compact-focus-exit-restores-details.ax.txt`

## Known limitations

- The state fingerprint, undo depth, camera values, and exactly-once dispatch
  are deterministic test assertions; the live accessibility layer does not
  expose every internal value.
- Aperture is a manual original-pixel measurement corroborated by the retained
  same-state frames and existing layout tests.
- The candidate does not attempt to suppress all map input globally. It
  intentionally gates only the approved pointer candidate and primary/
  secondary bridges during the narrow transition lifetime.
- Acceptance and independent quality review remain integration-owned.
