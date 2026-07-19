# Native HUD command-center progress — 2026-07-19

## Implementation contract

Included findings: P1-01, P2-04, P2-05, P2-06, P2-10, P2-12, and P3-01.

Deferred findings: P1-02 and P1-03 remain separate accessibility-architecture work; P1-07 remains economy work; renderer and simulation-rule changes are outside this HUD batch.

### Problem

The contextual inspector is a 300–360-point full-height overlay even when its contents are only a few rows. It covers the right side of the map, creates a tall empty slab for short sections, makes tile context mutually exclusive with city context, and duplicates information already present in the top and bottom HUD. The command dock also leaves broad unused regions in Inspect mode and when a build category has only one tool.

### Player outcome

The player sees a stronger, denser city cockpit without losing the map:

- one integrated top status rail communicates identity, objective, economy, growth, wellbeing, employment, utilities, time, and notices;
- the bottom command dock becomes a responsive command deck;
- tile, metric, objective, and journal details replace sparse dock content instead of opening a right sidebar;
- city pulse information remains visible alongside the current action;
- short contexts fit their content and long journal content scrolls within a bounded tray;
- regular and 900 × 600 compact layouts preserve 44-point controls and clear keyboard/accessibility state.

### Code surfaces

- `Views/ContentView.swift` — remove the right overlay and route context into the bottom command deck.
- `Views/TopHUDView.swift` and `Views/MetricCard.swift` — integrated information-dense status rail.
- `Views/BuildToolbarView.swift` — command-deck shell and persistent city pulse.
- `Views/InspectorView.swift` — responsive horizontal context cards rather than a full-height sidebar.
- `Stores/CityGameStore.swift` — explicit context dismissal/preservation and mode transitions.
- `Support/CityAnalytics.swift` and `Support/GameTheme.swift` — headroom/utilization presentation values and shared HUD tokens.
- `Tests/CitySimNativeTests/CitySimulationTests.swift` — context transition, compact-layout, semantic metric, and rendered proof coverage.

### Acceptance evidence

- State/unit: one contextual destination, selection preservation, mode transitions, shared analytics/headroom values, and compact/regular layout policy.
- Build: complete `swift test --package-path Native/CitySimNative`, `git diff --check`, and staged `./script/build_and_run.sh`.
- Interactive: switch among tile, treasury, population, demand, objective, and journal context; build, bulldoze, undo, pan, zoom, speed, Escape, and context close.
- Visual: regular idle/context, compact idle/context, active build, and long journal proof from the staged app.
- Accessibility: semantic values, selected mode/context, close labels, focus stability, keyboard operation, and Reduce Motion.

### Risks

- A horizontal tray can merely move the obstruction; cap its height and reuse the command dock footprint rather than stacking a second panel.
- Compact layouts can clip commands; use a catalog menu and horizontally adaptive context cards without reducing hit targets.
- Automatically closing context on Build/Bulldoze can lose diagnostic continuity; preserve map selection and make the transition explicit.
- Frequently changing metrics can still churn accessibility identity; keep control structure and explicit IDs stable while values update.

## Progress

- Current regular/compact HUD and historical inspector proof reviewed.
- Current dirty worktree recorded; all pre-existing changes remain user-owned.
- The full-height right inspector was removed from `ContentView`.
- The top HUD was rebuilt as an integrated status spine with city identity, objective progress, five decision-ready metric cells, labeled simulation controls, and consolidated notices.
- The bottom dock was rebuilt as an adaptive command center with persistent intent controls, build catalog/category access, layer access, current costs/upkeep/access rules, city headroom signals, demand, and contextual undo.
- Tile and citywide context now share one bounded four-card bottom tray. A selected block remains selected while the player browses finances, population, happiness, employment, demand, utilities, or the journal.
- Short detail sets fit a single row. Journals with more than four grouped notices use a bounded vertical scroll region and retain access to every notice.
- Selection details now report type-appropriate capacity/activity, actual road connection, upkeep, and the simulation's real demolition cost rather than generic or inferred fields.
- Compact width uses labeled menus for catalog, city data, and overlays while preserving the 44-point control minimum.
- Final review hardening aligned category selection with its visible active tool, routed the keyboard Command Center shortcut through the same store transition as pointer controls, replaced City Hall's demolition offer with protected-landmark messaging, and made repeated grouped notices retrigger their transient presentation.

## Audit finding dispositions

| Finding | Disposition | Evidence |
| --- | --- | --- |
| P1-01 | Completed for HUD scope | Persistent chrome is confined to integrated top and bottom edges; no full-height right overlay remains. |
| P2-04 | Completed | `hudContextScope` decouples selected-block context from citywide data and exposes an explicit return-to-selection action. |
| P2-05 | Completed | Context is a content-fit horizontal deck; only a long journal scrolls, inside a 168–180-point cap. |
| P2-06 | Completed | HUD/detail terminology now distinguishes residents/housing headroom, jobs/openings, happiness/approval, utilities/spare capacity, and notices. |
| P2-10 | Completed for changed surfaces | Duplicate pointer-only help was replaced by one current-action prompt and contextual feedback. |
| P2-12 | Automated evidence complete; staged visual pass pending | Deterministic 1,278 × 768 and 900 × 600 renders retain all primary controls without horizontal clipping. |
| P3-01 | Completed | Undo is available in the city pulse or destructive-mode context; Save remains a global toolbar action. |
| P1-02 / P1-03 | Deferred | Whole-store observation and a complete keyboard/VoiceOver grid architecture remain separate work. |

## Implementation paths

- `Native/CitySimNative/Sources/CitySimNative/Views/ContentView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/TopHUDView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/MetricCard.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/BuildToolbarView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/InspectorView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Sources/CitySimNative/Support/CityAnalytics.swift`
- `Native/CitySimNative/Sources/CitySimNative/Support/GameTheme.swift`
- `Native/CitySimNative/Sources/CitySimNative/Models/CityModels.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CitySimulationTests.swift`

## Automated evidence

- Final `swift test --package-path Native/CitySimNative`: 35 tests passed, 0 failures in 20.095 seconds.
- Focused final HUD render test: 1 test passed, 0 failures in 15.577 seconds and exported regular finance, compact selection, compact long-journal, and compact active-build frames.
- Final `swift build --package-path Native/CitySimNative`: passed in 1.96 seconds.
- Final `git diff --check`: passed with no whitespace errors.
- Final `./script/build_and_run.sh`: passed; the final staged bundle built and launched successfully.
- Renderer diagnostic from the final complete suite: 10,309 recursive nodes; 5,760/5,760 tile roots reused over ten unchanged pulses; 0 tile updates; 15.035 ms total and 1.504 ms average. The HUD work did not alter SpriteKit world ownership or tile invalidation.

## Proof index

### Deterministic full-SwiftUI HUD harness

- `docs/visuals/citysim-hud-command-center-regular-context-renderer.png` — 1,278 × 768 finance command center.
- `docs/visuals/citysim-hud-command-center-compact-context-renderer.png` — 900 × 600 selected residential block.
- `docs/visuals/citysim-hud-command-center-compact-journal-renderer.png` — 900 × 600 seven-notice bounded journal.
- `docs/visuals/citysim-hud-command-center-compact-build-renderer.png` — 900 × 600 active Commercial build state with cost, upkeep, road rule, cashflow, capacity, and demand access.

These images prove SwiftUI composition but the `NSHostingView` bitmap path does not capture SpriteKit's Metal-backed map, so its map region is black. Real staged-app screenshots remain the required visual proof for combined world/HUD composition.

## Hands-on status

The final staged-app audit is pending because the macOS session remains locked and the UI/accessibility controller cannot inspect or operate CitySim. The final app bundle built and launched successfully. Default/compact screenshots, direct input checks, focus stability, and live FPS/node evidence must not be claimed until the Mac is unlocked and the pass is completed.

## Deferred work and remaining risks

- P1-02 remains open: the SwiftUI shell still observes the whole store while live metrics update, so a 30-second 3x focus-identity soak is still required.
- P1-03 and a complete keyboard-accessible SpriteKit grid remain deferred as authorized.
- The command tray no longer obscures the right side, but an open detail tray intentionally uses additional bottom height; selection/camera behavior near the lower map edge must be sampled in the staged app.
- The retained renderer still holds all detail layers in memory. The prior live instrumented baseline was approximately 56.8–57.1 FPS with about 9,297 nodes and 7,743 draws; the HUD batch has not yet produced a new live comparison.
- Full authored assets, weather, night cycle, route-informed traffic, economy rebalance, and unrelated Python work remain outside this HUD batch.
- Existing user-owned changes in the dirty worktree remain preserved. Nothing was staged, committed, pushed, or submitted as a pull request.

## Integration disposition — 2026-07-19

Integration completed the previously pending staged-app inspection, confirmed the command-center surfaces were present and operable, reran the complete native suite (35 tests, 0 failures), passed `git diff --check` and build-script syntax validation, and built and launched the staged app with `./script/build_and_run.sh --verify`. The product implementation was accepted as `PLAY-001` in commit `cb30157`. A live keyboard sequence was interrupted when the staged bundle changed externally, so keyboard-route acceptance continues to rely on the automated command tests and the earlier retained hands-on evidence; a fresh uninterrupted keyboard/accessibility soak remains assigned to `PLAY-050`.
