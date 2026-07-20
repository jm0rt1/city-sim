# PLAY-030 Completion — Build-Diagnose-Adjust Command Deck

- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Status:** ready-for-integration
- **Baseline:** `efe23eeeaf0eec6c975dfead07fd8b8394f840e3`
- **Approved contract:** `docs/production/decisions/CONTRACT-002-command-catalog.md`

## Player-visible outcome

CitySim now has one searchable command system behind the visible HUD, macOS menus, keyboard routes, and SpriteKit overlap. The command guide groups the complete declared inventory, exposes shortcuts and concise disabled reasons, searches titles/categories/outcomes, and executes available non-spatial commands through `CityGameStore.perform(_:)`. The HUD remains map-first while adding a visible Commands route, richer diagnostics, stable focus, and safe topmost-first cancellation.

The two blocking PLAY-050 defects were repaired first. The welcome now freezes the exact authored opening until dismissal, and the compact simultaneous Objectives + Command Center state now reduces Objectives to a summary while keeping Command Center details inside a labeled, focusable, visible-scroll region.

## Ordered commits

1. `d6cd7dcb098382f04424bb447da3330b143dd0a5` — `PLAY-030: Freeze the authored start during onboarding`
2. `d859910c3bd285225cbe95389a1530041fc5edc8` — `PLAY-030: Arbitrate compact command surfaces`
3. `5bd455662a43979f2cfe56bda3a3c4f9313db1b7` — `PLAY-030: Unify the CitySim command deck`
4. `e53b46a46e44cd12c516ff2d64897b6b764385dd` — `PLAY-030: Prove essential keyboard routes`

## Exact product and test files changed

- `Native/CitySimNative/Sources/CitySimNative/App/CitySimNativeApp.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/CitySceneView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Sources/CitySimNative/Support/CityCommandCatalog.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/BuildToolbarView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/CommandGuideView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/ContentView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/GameStatusOverlay.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/InspectorView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/ObjectivesView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/OverlayPickerView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/TopHUDView.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CitySimulationTests.swift`

Legacy Python, simulation rules, progression truth, save schema/service, deterministic domain-command architecture, spatial keyboard navigation, and renderer state ownership were not changed.

## Automated validation

- `env CLANG_MODULE_CACHE_PATH=/tmp/citysim-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/citysim-swift-cache swift test --package-path Native/CitySimNative`
  - 54 tests passed, 0 failures in 34.428 seconds on the final tree.
  - Includes eight dedicated catalog tests plus the expanded essential keyboard-route assertion.
  - Full-suite renderer diagnostic: 5,760 tile-root reuses, 0 updates across ten pulses, 1.773 ms average.
- `CityCommandCatalogTests`
  - Proves every `CityCommandID` appears exactly once.
  - Proves the complete non-spatial inventory, all build tools, and all overlays are covered.
  - Proves no two active commands collide on key + modifiers + focus scope.
  - Proves disabled commands explain why and cannot execute.
  - Proves direct store intent and catalog routes reach equivalent end state.
  - Proves pause resumes the last active speed and Escape closes guide → inspector → objectives → tool.
  - Proves map-focused shortcuts dispatch once, modified keys do not double invoke, `Shift+5` reaches Civic, and `H` reaches Residential.
  - Proves the guide renders at compact 620×480 and regular 760×560 bounds.
- `CitySimulationTests.testBlockingWelcomePreservesExactAuthoredStartUntilDismissed`
  - Mounted the real SwiftUI content for 0.9 seconds and proved the entire authored state, day, messages, progression, treasury, population, power, and water remained exact.
  - Mounted after dismissal and proved simulation ticks resumed.
- `CitySimulationTests.testHUDCommandDeckProducesRegularAndCompactContextFrames`
  - Proved default and exact 900×600 compact frames, including simultaneous Objectives + Utilities details.
- `git diff --check`
  - Passed with no output before each product commit.
- `bash -n script/build_and_run.sh`
  - Passed with no output.
- `env CLANG_MODULE_CACHE_PATH=/tmp/citysim-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/citysim-swift-cache ./script/build_and_run.sh --verify`
  - Built and staged `dist/CitySim.app`, launched it, and verified the `CitySimNative` process remained alive.

## Hands-on staged-app flows

### First run

The staged app was launched with only `hasSeenCitySimWelcome` reset. The live accessibility tree and screenshot reported Day 1, `$26,000`, 300 residents, 58% happiness, 190 jobs, 54 power spare, 48 water spare, one notice, and the original objective. After another 1.8 seconds behind the blocking welcome, every value remained exact. Pointer dismissal removed the welcome; the simulation then advanced to Day 5 with updated treasury, population, utilities, demand, and notices. The welcome preference was restored by the normal Start Building action.

### Pointer and command palette

- The HUD Commands button opened the guide.
- Search autofocus landed in the labeled search field.
- Searching `utilities` reduced the inventory to build category, overlay, and Command Center routes.
- Searching `pollution` and activating the result changed the authoritative HUD layer control to Pollution while leaving the guide available for continued work.
- Disabled Undo displayed `There is no reversible construction action` and was not executable.

### Keyboard and focus

- With the map focused, `3` selected 3× exactly once; Space paused; `B` entered Bulldoze; Escape returned to Inspect; `H` selected Residential.
- `⌘/` opened the guide, `⌥⌘I` opened Command Center, and `⌃3` selected the Utilities overlay.
- Escape in the search field closed the guide. With compact Objectives and Command Center both open, successive Escape presses closed Command Center first, then Objectives.
- Tab from guide search reached the executable New Region row; the guide retained an Escape exit and no focus trap.

### Compact arbitration

The live app was tiled to a half-screen compact width. The HUD switched to compact metrics and Catalog controls. Opening Objectives plus Command Center produced the compact objective summary with the explicit hint `Close command-center details to expand all objectives`; it did not retain the full objectives body. Command Center exposed the `Scrollable command-center details` region, visible scrollbar, section menu, close control, and diagnostic remedies. Pointer navigation reached Utilities, Build power, Build water, and Utility map. Scrolling moved the accessibility scrollbar value from 0 to 1. The map remained the dominant surface and no command-center body escaped the window.

## Proof artifacts

- `docs/production/evidence/PLAY-030/live-first-run-frozen.jpeg` — live staged compact welcome, 768×924 capture.
- `docs/production/evidence/PLAY-030/live-command-guide.jpeg` — live staged searchable guide, 620×560 capture.
- `docs/production/evidence/PLAY-030/live-compact-arbitrated.jpeg` — live staged compact Objectives + Command Center, 768×924 capture.
- `docs/production/evidence/PLAY-030/command-guide-compact.png` — deterministic 620×480 point guide render at 2×.
- `docs/production/evidence/PLAY-030/command-deck-default.png` — deterministic default deck render at 2×.
- `docs/production/evidence/PLAY-030/command-deck-compact-arbitrated.png` — deterministic exact 900×600 point arbitration render at 2×.

## Compatibility and quality consequences

- **Command/store contract:** `CityCommandID`, descriptor metadata, focus scope, route ownership, shortcut discovery, and `perform/canPerform/disabledReason` are UI-owned. The router calls existing store intents and retains no city-state copy.
- **Renderer ownership:** SpriteKit still owns camera `+`, `-`, and `0`. Overlapping game keys publish one catalog ID through one callback and then call the same store intent.
- **Progression:** accepted objectives `stabilize`, `capacity`, and `town-charter` remain read-only presentation inputs. No progression field or simulation rule was duplicated.
- **Save/undo:** no persistence type, schema, service, or save payload changed. Existing whole-state undo remains authoritative; availability is surfaced through the catalog.
- **Accessibility:** visible controls and guide rows expose names, values, shortcut descriptions, disabled reasons, hints, stable identifiers, and a focusable scroll region. Full Keyboard Access reached the search and executable rows.
- **Compact layout:** exact 900×600 deterministic proof and live half-screen proof both retain command access, objective summary, scrolling, diagnostic remedies, and map dominance.
- **Performance:** the catalog is immutable metadata; search filters presentation only. No simulation loop, renderer invalidation, or observation boundary changed.

## Shared-contract and merge notes

CONTRACT-002 is implemented without changing CONTRACT-001 progression truth. Integration should apply the four ordered commits above, then the completion/evidence commit that contains this record. No renderer, persistence, or simulation contract is requested.

## Deliberately deferred by contract

- Spatial coordinate selection and keyboard grid navigation.
- Remappable bindings, macros, replay commands, and simulation-domain command logging.
- Persistence architecture or save migration.
