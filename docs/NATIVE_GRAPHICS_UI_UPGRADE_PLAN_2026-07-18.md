# CitySim Native Graphics and UI Upgrade Plan

**Date:** July 18, 2026
**Product:** `Native/CitySimNative`
**Rendering stack:** SpriteKit world, SwiftUI interface
**Primary outcome:** make the city itself the dominant, compelling game surface and turn the HUD into a concise command-and-consequence layer.

## Product direction

CitySim should look like a living miniature city rather than colored geometry beneath floating utility panels. The world remains a deterministic top-down/isometric 2D simulation, but gains authored visual families, richer terrain and networks, visible activity, lighting, effects, and strong interaction feedback. The UI becomes map-first: essential status stays visible, detail appears contextually, and every persistent element earns its screen area.

This is an upgrade of the existing native architecture, not a renderer rewrite. SpriteKit continues to own the world and pointer interaction; SwiftUI continues to own commands, HUD, inspector, notifications, and responsive composition. Simulation truth remains in the model/store.

## Design pillars

1. **Readable at a glance.** District use, road connectivity, utility state, construction, selection, and trouble must survive every camera distance.
2. **Alive, not noisy.** Traffic, lights, trees, smoke, construction, weather, and service activity communicate simulation state without becoming decorative clutter.
3. **Map first.** The city receives the full canvas. The HUD summarizes decisions and consequences; it does not become a dashboard wall.
4. **Confident construction.** The cursor shows the selected asset, footprint, validity, cost, upkeep, and rejection reason before commitment.
5. **Deterministic art.** Lot variation and ambient decoration are derived from stable seeds so saves and visual tests remain reproducible.
6. **Scalable and accessible.** Detail adapts by zoom and performance tier. Color is reinforced by shape, pattern, icon, and text.

## Target screen composition

- **Top-left city capsule:** city name, day, current objective, and one city-health state.
- **Top-center metric ribbon:** treasury trend, population, happiness, and employment; compact by default and expandable for denominators and history.
- **Top-right time and alerts:** labeled Pause / 1x / 2x / 3x controls plus one severity-aware alert button.
- **Bottom command dock:** categorized build tools, current-mode banner, cost/upkeep, and demand; expands on demand rather than spanning the window permanently.
- **Context rail:** a single right-side panel for selected tile, city analytics, or event detail. Closed until requested and resizable.
- **In-world feedback:** placement ghost, selection ring, service/hazard markers, construction progress, and short anchored consequences.

## Phase 0 — Visual foundation and performance contract

**Goal:** create the system that later art can use without growing `CityScene.swift` into a monolith.

### Work

- Split `CityScene` into focused renderer components: terrain, roads, lots/buildings, ambient activity, overlays, effects, and interaction layers.
- Introduce `WorldVisualStyle`, `RenderQuality`, `CameraDetailLevel`, and shared world color/material tokens.
- Add a stable coordinate-based visual seed and asset identifiers; never store incidental SpriteKit node state in the save.
- Add a small texture-atlas pipeline under `Native/CitySimNative/Resources` with nearest/bilinear filtering documented per asset family.
- Cache reusable textures and geometry; update changed tiles instead of rebuilding every node on every simulation pulse.
- Add debug toggles for FPS, node count, draw count, tile identities, and camera detail level.

### Exit gate

- Current city renders equivalently through the componentized pipeline.
- Simulation updates do not rebuild unchanged tiles.
- Default and compact proof scenes hold 60 fps on the development Mac with a recorded node/draw baseline.
- Full Swift test suite passes and the staged app launches through the Codex Run action.

## Phase 1 — World art vertical slice

**Goal:** prove a compelling final visual language across one representative neighborhood before producing every asset.

### Work

- Replace flat green diamonds with a terrain atlas: grass variants, soil/lot edges, subtle grid breakup, park ground, and contextual edge treatment.
- Create connected road sprites for straights, corners, T-junctions, crossings, ends, sidewalks, curbs, lane marks, and crosswalks.
- Create one complete visual family each for residential, commercial, industrial, park, and civic lots.
- Give buildings authored silhouettes, roof equipment, frontage, lot props, trees, shadows, and three stable seeded variants.
- Establish three camera detail levels:
  - **City:** silhouettes, district rhythm, major roads, alerts.
  - **Neighborhood:** facades, lots, trees, vehicles, service state.
  - **Block:** frontage, construction detail, pedestrians/props where truthful.
- Add a restrained environmental backdrop and vignette so the map edge feels intentional.

### Exit gate

- A golden 8×8 neighborhood looks intentional at all three camera distances.
- Building families remain distinguishable without their glyph badges.
- Road topology is visually correct for every connection mask.
- Seeded variants reproduce exactly after relaunch and save/load.
- Proof captures cover default, compact, normal overlay, and one diagnostic overlay.

## Phase 2 — Living-city motion, lighting, and effects

**Goal:** make simulation consequences visible in the world.

### Work

- Replace looping tile-local cars with route-informed traffic whose density reflects road demand.
- Add stable ambient life: swaying vegetation, lit windows, streetlights, service beacons, park activity, and industrial motion.
- Add construction stages rather than a generic frame: cleared lot, foundation, structure, finishing, completion burst.
- Add state effects for power/water failure, fire/police response, pollution, severe weather, upgrades, and demolition.
- Add a visual day/evening/night cycle decoupled from simulation speed, with high-contrast placement and selection treatment at every time.
- Respect Reduce Motion and add low/medium/high effects settings.

### Exit gate

- Visible activity agrees with model state and never implies nonexistent capacity or service.
- Important effects have a non-motion and non-color equivalent.
- Thirty-minute playtest shows no accumulating nodes/actions and no material frame degradation.

## Phase 3 — Construction and map interaction

**Goal:** make building on the map feel direct, safe, and satisfying.

**Audit scope:** P1-04, P1-05, P2-09; supports P1-03.

### Work

- Introduce explicit `inspect`, `build(kind)`, and `bulldoze` interaction modes owned by `CityGameStore`.
- Render a cursor-attached building ghost and exact footprint in SpriteKit.
- Show validity using outline, hatch/icon, and text—not color alone.
- Anchor a compact tooltip to the hovered tile with name, cost, upkeep, projected balance, and rejection reason.
- Add drag-to-build for roads with path preview and aggregate cost.
- Make Escape cancel, right-click return to inspect, and Command-Z restore the exact previous state.
- Strengthen selection with a persistent animated-but-reduced-motion-safe ring and selected-lot elevation treatment.

### Exit gate

- Valid, unaffordable, occupied, disconnected, edge, and bulldoze-protected cases are covered by state tests and live interaction.
- Mouse, trackpad, keyboard, Escape, and undo paths are verified.
- Default and compact screenshots prove that previews never hide the target tile.

## Phase 4 — Rich map-first HUD

**Goal:** replace the collection of floating panels with one coherent command interface.

**Audit scope:** P1-01, P1-06, P2-01, P2-02, P2-04, P2-05, P2-06, P2-07, P2-08, P3-02, P3-03.

### Work

- Replace the full-width glass slab with three grouped HUD regions using shared chrome, spacing, typography, and state tokens.
- Turn metrics into compact trend-bearing chips: current value, delta, semantic denominator, and warning state.
- Replace transport glyph ambiguity with visible Pause, 1x, 2x, and 3x labels.
- Consolidate events into one alert center with a single transient toast, repeat grouping, time/day, severity, and map focus action.
- Collapse objectives to a next-goal capsule with direct delta; expand into a progress panel only on request.
- Convert the build toolbar into categorized commands with a clear current-mode strip and expandable catalog.
- Replace glyph-only overlays with a labeled data-layer menu, explicit **City** reset, opacity control, actionable legend, and “show remedy” route.
- Make the inspector one contextual rail with selection/city/event destinations, stable navigation, resizable width, and compact bottom-sheet behavior.
- Add restrained transitions that explain origin and destination; honor Reduce Motion.

### Exit gate

- At least 75% of the default window remains readable map area with no panel open.
- Every persistent control has a visible purpose, keyboard route, accessibility name/value, and compact behavior.
- HUD values and inspector denominators agree in focused tests and hands-on comparison.
- Live proof covers idle, build mode, selected tile, active warning, inspector, overlay, and compact layout.

## Phase 5 — Data-overlay and accessibility rendering

**Goal:** make analysis powerful without erasing the city, and make the map operable beyond pointer-and-color interaction.

**Audit scope:** P1-02, P1-03, P2-03, P3-01.

### Work

- Render overlays as translucent, adjustable layers with roads, buildings, selection, and hazards protected above them.
- Add texture/pattern and boundary cues for traffic, utilities, happiness, pollution, and land value.
- Add cause/remedy explanations and click-through paths from legend to affected tiles and relevant build tools.
- Give every tile a stable accessibility identity, coordinate, type, condition, key metric, selection state, and available action.
- Add keyboard grid navigation, inspect/build/demolish actions, camera centering, and focus retention at maximum speed.
- Isolate frequently changing metric observations so the whole control hierarchy does not churn every 0.42 seconds.

### Exit gate

- Overlay opacity and palette remain readable in standard, increased-contrast, and color-deficiency checks.
- Keyboard traversal and stable tile identity are demonstrated for 30 seconds at 3x speed.
- VoiceOver and Full Keyboard Access are tested separately and limitations are recorded honestly.

## Phase 6 — Asset breadth, polish, and shipping proof

**Goal:** extend the approved vertical slice across the whole build catalog and lock quality budgets.

### Work

- Produce all building/service families with construction, active, unpowered, damaged, selected, and upgrade states where applicable.
- Add district-coherent prop and vegetation sets with adjacency-aware variation.
- Add icon family, sound cues, and haptic-equivalent visual feedback for command confidence.
- Add golden-city visual fixtures for sparse, growing, dense, nighttime, disaster, overlay, and compact scenarios.
- Document atlas dimensions, naming, source/license, export settings, memory cost, LOD/detail policy, and fallback treatment.

### Exit gate

- No required building or network state falls back to placeholder glyph art.
- Golden cities pass visual-diff review and hands-on play at every supported window class.
- Performance budgets hold under dense-city, effects-heavy, and overlay-heavy scenarios.

## Recommended implementation order

1. **Phase 0 + Phase 1 vertical slice** — highest visual leverage and de-risks the asset pipeline.
2. **Phase 3 interaction** — turns the richer world into a better game, not just a prettier screenshot.
3. **Phase 4 HUD** — reorganizes the interface around the improved playfield and interaction modes.
4. **Phase 2 living city** — layers believable motion onto stable art and update boundaries.
5. **Phase 5 overlays/accessibility** — uses the new rendering layers and stable identity model.
6. **Phase 6 breadth/polish** — scales only the visual language already proven in play.

## First implementation batch

The first buildable milestone should be a **golden-neighborhood vertical slice**, not a whole-game reskin:

- componentize the world renderer and add stable visual seeds;
- introduce terrain and connected-road atlases;
- implement three variants each for residential, commercial, industrial, and park lots plus one civic landmark;
- add camera detail levels and world/HUD design tokens;
- replace the top HUD with the three-region shell while retaining existing functionality;
- capture before/after proof at default and compact layouts;
- record FPS/node/draw baselines and run the complete Swift package tests.

This milestone should deliberately defer the full asset catalog, weather, night cycle, route-informed traffic, economy rebalance, and complete accessibility grid until the visual language and renderer performance are proven.

## Required evidence for every milestone

- `swift test --package-path Native/CitySimNative`
- `git diff --check` and focused source review
- staged launch through `./script/build_and_run.sh`
- hands-on mouse, trackpad, keyboard, cancel, undo, and relevant inspector flow
- real SpriteKit screenshots at default and compact layouts
- deterministic golden-scene capture where the milestone changes world rendering
- recorded performance comparison for renderer changes
- accessibility labels, focus stability, reduced-motion behavior, and non-color status review
- dated update to the remediation document with fixed, partial, deferred, or blocked dispositions

## Primary code surfaces

- `Rendering/CityScene.swift` — scene orchestration, camera, hit testing
- `Rendering/CitySceneView.swift` — SwiftUI/SpriteKit contract
- `Rendering/*Renderer.swift` — new terrain, network, lot, activity, overlay, and effects owners
- `Rendering/WorldVisualStyle.swift` — shared world tokens, quality, detail levels, seeded variants
- `Resources/WorldAssets.atlas` — authored world textures
- `Stores/CityGameStore.swift` — explicit interaction mode and player intent
- `Views/ContentView.swift` — map-first responsive composition
- `Views/TopHUDView.swift` — three-region HUD and metric summaries
- `Views/BuildToolbarView.swift` — categorized command dock and mode feedback
- `Views/InspectorView.swift` — contextual detail rail
- `Views/EventFeedView.swift` — alert center and transient toast
- `Support/GameTheme.swift` — unified HUD typography, spacing, color, shape, and motion tokens

## Main risks and controls

- **Asset effort expands without convergence:** approve the golden neighborhood before producing the full catalog.
- **SpriteKit node count grows excessively:** atlas-backed sprites, tile diffing, camera detail levels, pooling, and measured budgets precede broad effects work.
- **Art becomes decorative fiction:** every moving or warning element must have a model-derived input or be clearly ambient.
- **HUD redesign regresses functionality:** retain command parity, add store transition tests, and verify both layout classes in every batch.
- **Overlay/readability conflict:** separate overlay nodes from base art and protect interaction/selection contrast.
- **Existing user changes are overwritten:** implement in coherent batches, review the dirty worktree before each edit, and avoid unrelated Python/native files.
