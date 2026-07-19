# CitySim Native UI/UX Remediation

**Date:** July 18, 2026
**Batch:** Clear the playfield
**Source audit:** `docs/NATIVE_UI_UX_AUDIT_2026-07-18.md`

## Implementation contract

Included findings: P1-01, P1-06, P2-01, P2-05, P2-12.
Deferred: interaction modes and placement feedback (Batch B), data/controls (Batch C), accessibility grid and focus stability (Batch D), and economy/objective progression (Batch E).

### Problem

The default workspace opened with the full mandate and inspector visible, displayed as many as three repetitive event cards, and enforced a 1100×720 minimum without a compact composition. These surfaces reduced the playable map on every edge.

### Player outcome

- The city now opens map-first with objectives and inspector collapsed.
- Objectives remain visible as one compact progress control and expand on request.
- Only one grouped notification covers the map; repeated events show a count and the remaining history routes to City Journal.
- A 900×600 compact composition keeps essential metrics and build access while replacing the eleven-item build strip with a labeled menu.
- The compact inspector uses an in-canvas panel instead of removing a permanent map column.

## Dispositions

### P1-01 — Partially addressed

Default objectives and inspector no longer consume the map, and the event stack is reduced to one card. Live proof shows a substantially clearer playfield. The top HUD, build dock, overlay picker, objective summary, and one event still intentionally occupy map edges; the later interaction-mode and data-control batches should continue reducing chrome by context.

### P1-06 — Verified fixed

`CityGameStore.messageSummaries` groups repeated title/severity pairs while preserving newest-first order. `EventFeedView` renders only the newest group, displays `×N`, reports other groups in City Journal, and dismisses the whole visible group with a contextual accessible label.

Live verification observed nine “Neighborhood Upgraded” messages as one `Neighborhood Upgraded ×9` card, and later two storms as one `Severe Storm ×2` card. No second or third card covered the map.

### P2-01 — Partially addressed

The full mandate is closed by default and replaced by a progress summary showing the next incomplete objective and completion count. The control expands and collapses correctly and exposes a contextual accessibility label/value. Completed goals still remain in the expanded list and objective rotation is deferred to Batch E.

### P2-05 — Verified fixed

The inspector is closed by default and now uses the same in-canvas overlay panel at regular and compact widths. The system `.inspector` and its inaccessible divider were removed. Live accessibility inspection confirmed no splitter is present; the panel exposes its title, contents, and an explicit `Close inspector` button. Opening and closing it does not resize the map or lose context.

### P2-12 — Verified fixed

The minimum content size is now 900×600. `ContentView.isCompactLayout` switches below 1100 points wide or 700 points high. At 900×600, the HUD keeps Treasury and Population, the build strip becomes a menu, and the inspector becomes an overlay panel.

A debug-only `ProofWindowConfigurator` provides deterministic 900×600 and regular-size launch modes without affecting release builds or ordinary launch behavior. The actual staged app was launched at 900×600 and verified with its real SpriteKit scene, compact HUD, build menu, grouped event, objectives summary, and overlay inspector. The prior off-window black-map proof is superseded by the live compact artifacts below.

## Implementation surfaces

- `Models/CityModels.swift`: grouped notification summary value.
- `Stores/CityGameStore.swift`: map-first defaults, objective summary state, notification grouping and grouped dismissal.
- `Views/ContentView.swift`: responsive regular/compact composition and compact inspector.
- `Support/ProofWindowConfigurator.swift`: debug-only deterministic real-window proof sizing.
- `Views/TopHUDView.swift`: compact essential-metric mode.
- `Views/BuildToolbarView.swift`: compact labeled build menu.
- `Views/EventFeedView.swift`: single grouped notification.
- `Views/ObjectivesView.swift`: compact mandate summary and contextual accessibility labels.
- `Tests/CitySimulationTests.swift`: default-state, responsive threshold, grouping, objective priority, and compact rendering coverage.

## Evidence

### Automated

- `swift test --package-path Native/CitySimNative` with writable module caches: **16 tests passed, 0 failures**.
- `bash -n script/build_and_run.sh`: passed.
- `git diff --check`: passed before final documentation.
- Focused tests added:
  - `testMapFirstChromeDefaultsClosed`
  - `testMessageSummariesGroupRepeatedEventsAndDismissTogether`
  - `testObjectiveSummaryPrioritizesIncompleteMandate`
  - `testCompactInterfaceProducesInspectableFrame`

### Live app

- Rebuilt and launched `dist/CitySim.app` through `script/build_and_run.sh`.
- Verified map-first default in the actual SpriteKit-backed window.
- Verified single grouped event at repeat counts of nine and two.
- Verified objective summary expansion and contextual “Hide objectives” label.
- Verified overlay inspector opens and closes on demand at regular and compact widths.
- Verified the accessibility tree contains no system inspector splitter and exposes `Close inspector`.
- Launched the actual app at 900×600 with the real SpriteKit scene, then restored regular window size.
- Restored inspector and objectives to collapsed state, normal simulation speed, City overlay, and approximately restored camera position.

### Visual proof

- `docs/visuals/citysim-native-map-first-live.jpg`: actual running app with the real SpriteKit scene.
- `docs/visuals/citysim-native-compact-live.jpg`: actual staged app at 900×600 with the real SpriteKit scene.
- `docs/visuals/citysim-native-compact-inspector-live.jpg`: actual 900×600 overlay inspector and compact build controls.
- `docs/visuals/citysim-native-compact-map-first.png`: retained off-window harness artifact, superseded by the live compact proofs.

## Remaining risk and next batch

The next coherent batch should implement explicit Build / Inspect / Bulldoze modes, placement validity preview, Escape cancellation, and stronger map selection. That batch will reduce the need for persistent instruction text and further simplify the bottom dock without conflating input-state work with this composition change.
