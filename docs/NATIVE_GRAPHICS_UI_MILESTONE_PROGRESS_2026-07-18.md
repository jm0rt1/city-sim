# Native graphics and UI milestone progress — 2026-07-18

## Status

The first implementation milestone from `NATIVE_GRAPHICS_UI_UPGRADE_PLAN_2026-07-18.md` is implemented as a golden-neighborhood vertical slice.

The staged native app now presents a map-first HUD around a substantially richer programmatic SpriteKit city: stable terrain variation and map edges, topology-aware roads with curbs and markings, recognizable lot families with deterministic variants, zoom-dependent detail, sparse data overlays, and explicit build/inspect/bulldoze feedback. The implementation does not change simulation ownership, persistence fields, or the legacy Python renderer.

All shipping world art in this milestone is programmatic and local. No generated image assets, network fetches, or runtime network dependencies were added.

## Completed scope and implementation paths

### Renderer foundation

- `Native/CitySimNative/Sources/CitySimNative/Rendering/WorldVisualStyle.swift`
  - shared terrain, road, structure, vegetation, overlay, and interaction tokens;
  - deterministic coordinate-and-kind visual seeds independent of simulation seed and Swift `hashValue`;
  - camera detail tiers and cached reusable geometry.
- `Rendering/TerrainRenderer.swift`
  - stable grass and lot variation, intentional map skirts/edges, park surfaces, and camera-detail layers.
- `Rendering/RoadRenderer.swift`
  - all 16 connection masks, including isolated/end, straight, corner, T, and four-way topologies;
  - asphalt, sidewalks, curbs, center markings, crossings, lamps, and restrained street props.
- `Rendering/LotRenderer.swift`
  - three deterministic variants each for residential, commercial, industrial, and park lots;
  - distinct silhouettes for City Hall, utilities, emergency services, and school;
  - frontage, roof equipment, trees, planters, shadows, and contextual props without floating type glyphs.
- `Rendering/WorldOverlayRenderer.swift`
  - separate sparse overlay nodes for traffic, land value, pollution, and service coverage;
  - patterns and hatching reinforce color while selection and interaction nodes remain above data layers.
- `Rendering/CityScene.swift`
  - orchestration, camera, hit testing, interaction feedback, and tile-root registry;
  - unchanged base tile roots are retained across simulation pulses;
  - road mutations invalidate only the changed road and connected road neighbors;
  - camera detail changes and overlay changes do not rebuild base tile roots;
  - direct SpriteKit keyboard routing preserves unmodified Space, 1/2/3, B, V, Escape, +, -, and 0 commands while allowing modified app commands such as Command-Z to pass through.
- `Rendering/CitySceneView.swift`
  - SpriteKit/SwiftUI bridge, right-click routing, Reduce Motion propagation, pointer tracking, and optional FPS/node/draw diagnostics.

### HUD and interaction shell

- `Views/ContentView.swift`
  - map-first composition, one contextual inspector rail, responsive regular/compact layouts, and a lifecycle-bound simulation task;
  - objectives and inspector default closed;
  - transient action feedback uses positive, neutral, or caution semantics and honors Reduce Motion.
- `Views/TopHUDView.swift`
  - top-left identity/current objective, central metric ribbon, and top-right labeled Pause/1x/2x/3x plus consolidated alerts.
- `Views/BuildToolbarView.swift`
  - explicit Inspect, Build, and Bulldoze modes;
  - categorized regular dock and compact catalog;
  - selected item cost/upkeep/access context and residential/commercial/industrial demand.
- `Models/CityModels.swift` and `Stores/CityGameStore.swift`
  - explicit interaction and build-category state;
  - deterministic labeled simulation speeds;
  - valid/invalid placement and protected-demolition feedback;
  - secondary click inspects rather than silently demolishing;
  - existing save schema and undo behavior preserved.
- `Views/EventFeedView.swift`, `ObjectivesView.swift`, `OverlayPickerView.swift`, and `OverlayLegendView.swift`
  - consolidated alerts, contextual objectives, labeled layer reset, and accessible layer legends.
- `Support/GameTheme.swift`
  - shared HUD spacing, typography, control-size, material, contrast, and motion tokens.

## Audit finding dispositions

| Finding | Disposition | Milestone evidence |
| --- | --- | --- |
| P1-01 persistent panels | Fixed for milestone | Map-first shell; objectives and inspector default closed; compact 900 x 600 layout verified. |
| P1-02 live updates destabilize assistive interaction | Partial | One lifecycle-bound pulse task replaced view-driven timer subscriptions; SKView focus survived accelerated and keyboard runs. Whole-store observation remains and needs a dedicated assistive-technology soak. |
| P1-03 map accessibility | Partial/deferred | Selection/hover/validity state is exposed as concise text and all changed controls have names. A complete keyboard-accessible grid remains explicitly deferred. |
| P1-04 no placement preview/validity | Fixed | Programmatic building ghost, VALID/BLOCKED text, reason, cost/upkeep, outline, and hatch pattern. |
| P1-05 hidden primary-click meaning | Fixed | Inspect, Build, and Bulldoze are explicit modes; right-click consistently inspects; Escape cancels. |
| P1-06 repetitive notifications | Fixed | Six-second transient toast plus grouped consolidated alert access. |
| P1-07 economy pressure | Deferred | Economy rebalance is outside this milestone. |
| P2-01 objectives consume prime space | Fixed | Compact objective summary at top-left; full objectives remain closed until requested. |
| P2-02 glyph-only overlays | Fixed | Labeled City Data menu, named layers, and explicit City/off reset. |
| P2-03 overlays compete with identity | Fixed for slice | Sparse separated overlays, pattern reinforcement, and selection/interaction layers above overlay art. |
| P2-04 shallow inspector navigation | Partial | One contextual inspector rail opens on selection/request; deeper cross-navigation remains later work. |
| P2-05 inspector open/default sizing | Fixed | Closed by default, single responsive rail, explicit close control. |
| P2-06 conflicting top metrics | Fixed | Treasury and cycle delta, population/capacity, happiness/approval, and jobs-filled/resident coverage use explicit terminology. |
| P2-07 ambiguous time controls | Fixed | Labeled Pause, 1x, 2x, and 3x controls with selection values and keyboard help. |
| P2-08 flat build palette | Fixed | Roads, Zones, Utilities, Services, and Civic categories; compact catalog at small size. |
| P2-09 bulldoze safety | Fixed | Dedicated mode, warning styling/text, protected-building reason, and undo confirmation. |
| P2-10 tiny pointer-only instructions | Partial | Mode/status copy and keyboard routes are now explicit; some compact supplemental copy remains deliberately terse. |
| P2-11 weak selection visibility | Fixed | High-contrast diamond, corner marks, contextual text, and selection layer above world/overlays. |
| P2-12 oversized minimum window | Fixed for target | 900 x 600 content minimum and compact layout verified in the real staged app. |
| P3-01 command placement | Partial | Map actions are consolidated in the command dock; Save and Undo remain available in native window chrome and keyboard commands. |
| P3-02 unlabeled close controls | Fixed on changed surfaces | Inspector, feedback, objective, and alert dismissal controls have semantic labels. |
| P3-03 terminology | Fixed on changed surfaces | “Cycle,” “jobs filled,” “resident coverage,” mode names, and speed names are consistent. |
| P3-04 overloaded status color | Fixed on changed surfaces | Validity and feedback combine color with shape, pattern, symbol, and text. |

## Automated evidence

- Complete native suite:
  - command: `swift test --package-path Native/CitySimNative`;
  - sandbox note: the unmodified command could not write Swift/Clang module caches, so the successful run used the same command with `CLANG_MODULE_CACHE_PATH` and `SWIFTPM_MODULECACHE_OVERRIDE` set to `/private/tmp` and ran outside the outer filesystem sandbox;
  - result: 31 tests executed, 0 failures, 0 unexpected, 4.307 seconds on 2026-07-18 22:50 EDT.
- Renderer regression coverage includes stable visual seeds, camera thresholds, all 16 road masks/rotations, localized road invalidation, base-root identity preservation, overlay and LOD transitions, selection accessibility lifecycle, proof-frame exports, keyboard routing, camera shortcuts, and build/bulldoze undo.
- `git diff --check`: passed after the final implementation and documentation update.
- `./script/build_and_run.sh`: passed; final staged build completed in 0.11 seconds and launched `dist/CitySim.app`.

## Hands-on staged-app evidence

The real staged app was exercised with macOS accessibility inspection and direct pointer/keyboard operation:

- panned the map and verified zoom at neighborhood and city levels;
- verified `+`, `-`, and `0` camera shortcuts while the SKView retained focus;
- inspected open land, residential, and City Hall tiles; opened and closed objectives and inspector surfaces;
- selected and placed Road, Residential, and School representatives;
- verified valid preview and invalid re-placement with BLOCKED text, hatch, reason, and caution feedback;
- bulldozed an existing residence and restored it with Command-Z;
- verified right-click from Bulldoze switches to Inspect and does not demolish City Hall;
- changed Pause/1x/2x/3x with both labeled controls and Space/1/2/3;
- verified Escape cancellation and stale selection accessibility text removal;
- exercised the regular layout and a fresh 900 x 600 compact launch;
- enabled Reduce ambient animation, inspected the changed accessibility tree, restored the setting, and confirmed the staged app uses the system Reduce Motion value as well;
- opened a Land Value diagnostic overlay and reset it to City.

## Performance evidence

| Measurement | Previous renderer | Golden-neighborhood renderer |
| --- | ---: | ---: |
| Deterministic fixture base tile roots | 576 | 576 |
| Recursive nodes after initial render | 1,418 | 10,309 |
| Ten unchanged pulse average | 6.935 ms | 1.456 ms |
| Tile roots reused across ten pulses | 0 / 5,760 after the first full replacement | 5,760 / 5,760 |
| Tile roots updated across ten unchanged pulses | first pulse replaced all 576 | 0 |

The retained art is approximately 7.3 times denser, but unchanged-pulse renderer work fell by about 79%. The final test diagnostic reported 14.565 ms total across ten pulses, 10,309 nodes, and zero tile updates. A regular live diagnostic capture showed approximately 9,297 nodes, 7,743 draws, and 56.8-57.1 FPS while screen capture/inspection was active.

Limitations: the live capture did not demonstrate a locked 60 FPS under instrumentation, the full retained node set remains allocated when lower-detail layers are hidden, and a 30-minute accumulation soak was not completed. Node/draw reduction and a long-session profile remain required before broad asset/effects expansion.

## Proof index

### Before

- `docs/visuals/citysim-native-map-first-live.jpg`

### Real staged application

- `docs/visuals/citysim-golden-default-live.jpg` — regular/default layout class, normal city view.
- `docs/visuals/citysim-golden-compact-live.jpg` — fresh 900 x 600 compact launch.
- `docs/visuals/citysim-golden-neighborhood-live.jpg` — neighborhood zoom reached with `+`.
- `docs/visuals/citysim-golden-city-zoom-live.jpg` — city zoom reached with `-`.
- `docs/visuals/citysim-golden-valid-placement-live.jpg` — valid Road preview.
- `docs/visuals/citysim-golden-invalid-placement-live.jpg` — blocked Road placement with non-color state communication.
- `docs/visuals/citysim-golden-build-state-live.jpg` — active build mode.
- `docs/visuals/citysim-golden-overlay-live.jpg` — Land Value diagnostic layer.
- `docs/visuals/citysim-golden-diagnostics-live.jpg` — SpriteKit FPS/node/draw proof.

### Deterministic renderer harness

- `docs/visuals/citysim-golden-default-renderer.png`
- `docs/visuals/citysim-golden-compact-renderer.png`
- `docs/visuals/citysim-golden-neighborhood-renderer.png`
- `docs/visuals/citysim-golden-city-zoom-renderer.png`
- `docs/visuals/citysim-golden-overlay-renderer.png`
- `docs/visuals/citysim-golden-active-build-renderer.png`
- `docs/visuals/citysim-golden-selection-renderer.png`

## Deferred work and remaining risks

- Full authored asset catalog, weather, night cycle, route-informed traffic, economy rebalance, and a complete keyboard-accessible grid remain deferred as planned.
- The golden fixture proves the visual language and the tests cover every road mask/variant, but the sparse starter city does not show every variant and topology in one live frame.
- P1-02 remains partial until whole-store observation is narrowed and a dedicated VoiceOver/keyboard focus soak is recorded.
- Dense retained programmatic art raises memory/node-count risk even though pulse work is substantially lower.
- Overlay and long-session performance should be profiled without screen-capture overhead before claiming a sustained 60 FPS budget.
- Existing user-owned changes in the dirty worktree were preserved. Nothing was staged, committed, pushed, or submitted as a pull request.

## Integration disposition — 2026-07-19

Integration reviewed this retained milestone, reran the complete native suite (35 tests, 0 failures), passed `git diff --check` and build-script syntax validation, and built and launched the staged app with `./script/build_and_run.sh --verify`. The implementation was accepted as `PLAY-001` in commit `cb30157`. The earlier dirty-worktree statement above records the milestone author's handoff state; it is superseded by this integration disposition.
