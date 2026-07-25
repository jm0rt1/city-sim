# PLAY-054 Claim

- **Title:** Make the command surface readable and alive
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Base commit:** First published integration authority containing this claim
- **Claimed:** July 25, 2026
- **Planned surfaces:** `Views/ContentView.swift`, `Views/TopHUDView.swift`, `Views/MetricCard.swift`, `Views/StrategyCommandCenterView.swift`, `Views/BuildToolbarView.swift`, `Views/InspectorView.swift`, existing HUD/layout/accessibility tests, HUD-specific additions to `Support/GameTheme.swift`, and `docs/production/evidence/PLAY-054/`
- **Dependencies:** accepted PLAY-033 and PLAY-039; published authority containing the integrated PLAY-054 audit; existing command/store/focus contracts remain unchanged
- **Validation/proof:** exact same-state default and 900 x 600 before/after; measured closed/open map aperture; rendered font-size inventory; complete visible Details/Journal sections; priority/metric/selection/rejection states; pointer/keyboard/command-search/Escape/FKA/AX/Reduce Motion/3x focus routes; grayscale/contrast comparison; full suite; independent quality review
- **Status:** ready after synchronization to the published authority containing this claim

Repair the observed information hierarchy without rebuilding the HUD as another
opaque control wall. The closed command surface must stay world-first, while
the open command center must become a deliberately useful reading and action
surface. Replace the current 7–9 point critical typography and 66-point compact
details viewport with responsive composition that satisfies the PLAY-054
acceptance measurements.

The lane may add narrowly named HUD-specific theme tokens. It may not change
existing shared theme semantics or any public command/store contract without a
separate integration proposal. Preserve the accepted single command route,
active map target, objective truth, selected context, focus/Escape arbitration,
and exact map hit behavior.

Do not edit SpriteKit rendering, world assets, gameplay, simulation,
persistence, package/build scripts, or task authority. Commit product,
candidate-bound evidence, and completion separately. Do not push, integrate,
self-score, self-accept, or pin the thread.
