# CitySim World Rendering Issue Report

**Date:** July 21, 2026

**Authority:** Integration lane, read-only product audit

**Audited candidate:** `codex/citysim-world-rendering` at evidence commit `8cb45b5848f070c25803213ee48b2523e8057d09`

**Product commit beneath evidence:** `4887ebad9519fccb08844e2746f9bfbbc93aaa4d`

**Staged bundle:** `CitySim-world-rendering-w5f893ad1da1b.app`

**Bundle identifier:** `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`

## Executive verdict

The candidate is not visually shippable and does not pass the world-playability gate. The weakness is not one bad texture or a missing polish pass. Five systems amplify one another:

1. generated sprites do not have a safe physical footprint contract;
2. generated, legacy, and procedural art coexist in the same focal block;
3. tile-level diagnostic and interaction layers are stacked above already crowded art;
4. camera and HUD composition leave too little unobstructed world;
5. simulation consequences are explained primarily with symbols instead of changes to the place.

The result is a city with individually attractive civic, park, water, and industrial illustrations that does not cohere as a world. Buildings collide visually, roads disappear beneath assets or end without a believable continuation, the construction site reads as a placeholder, the grass repeats as a visible grid, and selection/build/utility states turn the map into a diagnostic display.

This audit records **28 issues: 10 P1 release blockers, 13 P2 major issues, and 5 P3 quality issues**. There is no P0 crash or data-loss finding. The staged app remained operable, keyboard selection worked, an invalid occupied-lot build was rejected safely, Escape cancelled build mode, and no production save was touched.

## Method and scope

The exact staged candidate was rebuilt with `./script/build_and_run.sh --verify`, launched with its isolated renderer data root, and operated as a player with pointer and keyboard. The pass covered:

- default and approximately 900-pixel-wide compact windows;
- city, selection, build, invalid placement, and utilities-overlay states;
- inspect/details open and closed;
- hover, zoom, Escape, focus, and accessibility state;
- visible comparison across city hall, residential, industrial, water, park, roads, terrain, construction, and empty land;
- source correlation in `CityScene`, `LotRenderer`, `TerrainRenderer`, `RoadRenderer`, `WorldOverlayRenderer`, `SpatialConsequenceRenderer`, `WorldAssetCatalog`, and SwiftUI HUD composition;
- retained Gate A-R screenshots and candidate performance evidence.

The isolated staged city advanced from Day 108 to Day 116 before being paused. The app was restored to 1x, City overlay, Inspect mode, closed Details, and no selected block, then the exact audit process was terminated. No build was committed and no production save was opened.

### Severity scale

| Severity | Meaning |
|---|---|
| P0 | Crash, data loss, or inability to operate the world. |
| P1 | Release blocker: materially breaks physical coherence, readability, playability, or the approved performance envelope. |
| P2 | Major: conspicuous degradation or missing world capability that prevents the intended quality bar. |
| P3 | Quality: noticeable polish, variety, or presentation deficit after higher-order systems are repaired. |

## Root-cause map

| Root cause | Direct evidence | Downstream failures |
|---|---|---|
| No asset-to-grid footprint contract | The grid is 72×36 world units, while all nine generated manifest entries declare a 216×144 envelope and a low anchor. `WorldAssetCatalog` applies those values verbatim. | Building/road occlusion, neighboring-lot overlap, scale mismatch, hit/render disagreement, repeated terrain interference. |
| Mixed rendering paths | Generated sprites are used only for six level-1 kinds. Other levels and services fall back to earlier sprites or procedural geometry; construction is a separate shape-node system. | High- and low-fidelity art in one frame, inconsistent projection/light/material, obvious placeholders. |
| Tile-root depth instead of declared visual volume | Each complete lot is mounted on one tile root and depth-sorted only by `x + y`; no opaque bounds, overhang, entrance, shadow, or reserved-neighbor metadata exists. | Large sprites cover roads or adjacent buildings even when tile truth is valid. |
| Annotation-first state presentation | Per-tile overlay washes/patterns, consequence glyphs, selection outline/brackets/beam/label, hover billboard, placement ghost/hatches, and SwiftUI toast can all be visible together. | The city becomes obscured precisely when the player needs to reason about it. |
| HUD and camera are independent compositions | SwiftUI measures top/bottom chrome and gives the map insets, but the initial camera uses a fixed core center/scale and the HUD still overlays the full-screen SpriteKit view. | Compact world band is too shallow; important art and previews sit beneath UI; empty-board and crowded-core extremes coexist. |

## Ranked issue inventory

### P1 — release blockers

| ID | Issue | Evidence and impact | Corrective direction |
|---|---|---|---|
| WR-001 | **Generated assets have no safe footprint contract** | Every generated manifest asset declares 216×144 against a 72×36 tile. The catalog applies only `worldSize` and `anchor`; there is no opaque footprint, allowed overhang, frontage edge, entrance, shadow extent, or neighbor reservation. Attractive sprites therefore cannot be composed safely. | Define an asset geometry schema: occupied tile footprint, opaque bounds at every LOD, ground contact polygon, height, entrance/frontage, shadow bounds, allowed overhang, and collision exclusions. Reject assets that violate it during ingestion. |
| WR-002 | **The focal block visibly overlaps** | In the live default and compact views, city hall crowds the neighboring low-fidelity structure and road, the central construction site obscures the crossing, and water/park/industrial silhouettes compete across tile boundaries. Tile truth remains distinct, but the visual scene does not. | Re-author the golden block after WR-001. Add automated opaque-bounds neighbor tests plus staged visual review at all three camera stops. |
| WR-003 | **High- and low-fidelity art are mixed in the same frame** | City hall, park, water tower, and industrial art are painterly and detailed; nearby residential/service/fallback geometry and construction are flat or primitive. `generatedLogicalID` covers only six kinds and only level 1 uses it. | Freeze new breadth. Complete one unified visible starting-set family across every kind, level, construction stage, terrain, road, vegetation, and prop visible in the audited start. No legacy fallback may appear in acceptance frames. |
| WR-004 | **Generated grass is an oversized repeated plate on every tile** | `TerrainRenderer` mounts `grass_material` for each tile using the same 216×144 manifest envelope, offset by half a tile. The visible board becomes a mustard diamond grid whose repetition competes with roads and buildings and whose sprites overlap multiple cells. | Replace per-cell full plates with a macro terrain mesh/atlas plus small tile-edge/material variation. Terrain must be continuous, low-contrast, and authored at map scale. |
| WR-005 | **Depth sorting does not account for visual volume** | `CityScene` sorts a tile root by `x + y`; the entire large sprite, frontage, lifecycle, and consequence stack inherits that root. No child-level ground-contact or cross-tile ordering contract exists. | Sort architecture by declared ground-contact baseline and split ground, structure, canopy, and foreground overhang into controlled depth bands. Validate crossing sprites against adjacent road and lot volumes. |
| WR-006 | **The camera alternates between empty-board composition and over-crowded core** | Retained city view reduces the settlement to a tiny island inside a mostly empty 24×24 board. Default core framing makes the large sprites collide. The initial scale is a fixed environment/window heuristic rather than a fit of developed bounds plus a playable expansion corridor. | Fit developed bounds, one intentional corridor, and HUD-safe world band. Target 55–70% developed occupancy in default and compact. Make city/neighborhood/block stops art-directed compositions, not only scale thresholds. |
| WR-007 | **The HUD occludes too much of the playable world** | At roughly 900×650, the two-tier top HUD and bottom command deck leave a shallow central strip. The city hall and industrial building remain visible, but residential content and the central construction site are clipped or hidden behind chrome. Opening Details consumes nearly half the world. | Recompose compact HUD as a restrained single summary rail with progressive disclosure. Reserve a minimum unobstructed world band and have the camera refit whenever measured chrome changes. |
| WR-008 | **Selection, hover, build, feedback, and overlay layers can overwhelm the map simultaneously** | The live invalid-placement state showed the grounded selection, four brackets, vertical beam, `SELECTED` label, large black hover/rejection billboard, ghost, red hatch/footprint, consequence marks, overlay wash/pattern, legend, and duplicate SwiftUI feedback. | Establish one visual-priority arbiter. At most one primary world affordance and one secondary confirmation may occupy a parcel. Suppress hover and persistent diagnostics during placement; render rejection copy once. |
| WR-009 | **World consequences are glyphs rather than environmental storytelling** | Utilities mode adds color wash, grid marks, brackets, bolts/drops, bars, and status marks, but the buildings, fountain, planting, windows, service equipment, and activity do not become the primary explanation of strain or recovery. | Drive local materials and bounded props from accepted consequence truth: dark windows/electrical fixtures, dry planting/fountain, wear, repair vehicle, restored activity. Glyphs become small secondary confirmation. |
| WR-010 | **Regular-window memory is outside the approved envelope** | Candidate evidence records approximately 609,168 KiB fresh RSS / 475 MiB footprint and 936,640 KiB RSS / 707.7 MiB footprint after long traversal, against the earlier roughly 205.8 MiB settled baseline. `WorldAssetCatalog` retains every loaded texture for process lifetime. | Instrument decoded bytes and per-LOD residency. Remove unused plates, enforce texture budgets, load/evict LODs deliberately, atlas compatible assets, and pass baseline +128 MiB in regular and compact repeated traversal. |

### P2 — major issues

| ID | Issue | Evidence and impact | Corrective direction |
|---|---|---|---|
| WR-011 | **Roads do not form a believable street grammar** | Road arms terminate in rounded caps without a continuation socket, barrier, cul-de-sac, or construction context. Curbs, crossings, sidewalks, and frontage joins are inconsistent, so the player cannot read where expansion belongs. | Author a complete topology family with intentional termini and truthful build-corridor sockets. Validate every mask in connected neighborhoods, not isolated tiles. |
| WR-012 | **Buildings do not reliably face or sit on streets** | Frontage is a separate layer rotated toward the first adjacent edge while the generated building is a fixed baked view. Entrances, shadows, and road relationship can disagree. | Make orientation and entrance part of the asset contract. Supply rotational variants or restrict placement to supported frontage; never rotate only the ground treatment beneath fixed architecture. |
| WR-013 | **Construction is conspicuously lower fidelity** | The central site is built from procedural silhouettes, scaffold, progress marks, cones, and dust. Against painterly architecture it reads as a debug placeholder and physically blocks the crossing. | Author footprint-safe prepared-site, foundation/frame, and finishing art in the same projection, palette, light, and material language as completed lots. |
| WR-014 | **The art has inconsistent scale and projection** | City hall dominates multiple neighboring parcels, the water tower and park share a large plate scale, and industrial/residential masses do not establish a consistent floor, door, road-width, tree-height, or vehicle scale. | Publish a scale sheet with human/door/floor/tree/vehicle/road constants and allowed landmark exceptions. Reject sources outside tolerance before ingestion. |
| WR-015 | **Baked context and systemic props double-count visual content** | Generated sprites already contain landscaping, shadows, or ground context while `LotRenderer`, frontage, ambient vegetation, lifecycle, and consequence renderers add more around them. This creates crowding and incompatible detail. | Separate architecture, ground, shadow, vegetation, and props into explicit asset roles. Prohibit baked context outside declared bounds. |
| WR-016 | **The terrain value hierarchy is too loud** | Repeated gold-green diamonds and boundary lines dominate empty acreage. Fine tile texture is visible at city scale while the settlement lacks a quiet visual bed. | Use large-scale terrain variation and suppress parcel micro-detail at city scale. Empty land should frame the city and highlight real opportunity, not form the loudest pattern. |
| WR-017 | **LOD changes resolution more than information** | The manifest supplies city/neighborhood/block exports, but the world does not gain a clear hierarchy of district form, frontage opportunity, and parcel detail. The same large composition remains, merely sampled differently. | Art-direct each LOD: aggregated massing at city, street/lot relationships at neighborhood, entrances/materials/props at block. Add transition tests and a continuous recording gate. |
| WR-018 | **The hover billboard is too large and too persistent** | Zooming and moving over open land produced a large black `INSPECT · OPEN LAND` panel across the city center. It obscures exactly the area under inspection and remains alongside selection/build feedback. | Use a small anchored tooltip outside the footprint, delayed hover, edge-aware placement, and suppression during keyboard focus, selection, build, or active feedback. |
| WR-019 | **Invalid placement copy is duplicated** | Clicking an occupied industrial lot safely rejected the action, but the same reason appeared in a center SwiftUI toast and a large black/red world billboard while `BLOCKED · ROAD` and hatching added two more signals. | Announce one reason in one stable surface. Keep a small non-color invalid footprint; remove duplicate prose and redundant labels. |
| WR-020 | **Selection is over-specified** | A selection uses outline, four corner brackets, pulse, beam, cap, cyan/white color, and `SELECTED` text. The cue is accessible but visually louder than the parcel. | Retain one grounded non-color boundary and one compact anchor. Make the selected building/lot remain fully visible and move prose to the accessible value/details surface. |
| WR-021 | **Diagnostic overlays erase local structure** | Every sampled tile receives a heat-color diamond wash; many receive white patterns; consequence cues are raised from 0.16 to 0.82 alpha. Utilities mode becomes an orange/yellow field over buildings and open land. | Use contours, networks, edge treatments, and sparse affected-place emphasis. Cap map-wide opacity, preserve material contrast, and avoid patterning unrelated empty tiles. |
| WR-022 | **Buildability is not legible from the world before Build mode** | Roads and frontage do not explain opportunity. The player must enter Build mode and rely on colored preview/rejection layers to learn whether land is useful. | Create restrained, authority-derived frontage sockets in Build mode and compose the default camera around three real opportunities. Never infer validity in SpriteKit. |
| WR-023 | **Pointer target and selected state can diverge visually** | During invalid placement over the industrial building, the accessibility map value still described the previously selected open block while hover/build feedback referred to the occupied target. The player sees several coordinates/states without a clear hierarchy. | Distinguish keyboard selection, pointer hover, and pending placement in both visual and accessibility output; suppress stale selected prose during an active pointer preview or clearly label both roles. |

### P3 — quality issues

| ID | Issue | Evidence and impact | Corrective direction |
|---|---|---|---|
| WR-024 | **Vegetation repeats as lollipop forms** | Repeated round-canopy trees expose procedural origin and clash with detailed painterly planting. | Add coherent vegetation clusters, seasonal/value variation, scale hierarchy, and sparse deterministic placement. |
| WR-025 | **The city feels static and uninhabited** | No clearly readable people, parked service object, local work, or occupancy activity was evident in the live default/compact pass. | Add bounded truth-safe life at neighborhood/block LOD, with equivalent static meaning under Reduce Motion. |
| WR-026 | **Props and lights appear detached from street geometry** | Lamps, bars, markers, and small roadside pieces sit near road edges without a consistent curb/socket system, sometimes reading as floating icons. | Place props through authored curb/frontage sockets with scale, orientation, and occlusion tests. |
| WR-027 | **Color and material grading are inconsistent** | Warm painterly civic/industrial art, mustard terrain, cyan interaction marks, bright red diagnostics, and native-system overlay colors do not share a controlled value/saturation hierarchy. | Define world, interaction, warning, and diagnostic palettes separately; verify grayscale hierarchy and color-vision variants. |
| WR-028 | **Unused or superseded visual resources remain a residency risk** | The resource catalog still supports prior golden-district textures and caches loaded textures indefinitely while the new pack adds explicit LOD exports. Even if not all are active at launch, traversal can retain superseded content. | Inventory shipped/loaded resources, delete or quarantine superseded plates after rollback proof, and add a residency report that names every live texture and decoded byte count. |

## Detailed system findings

### 1. Asset geometry is the first blocker

The generated pack currently describes images, not composable world objects. All nine entries share a 216×144 world envelope and `[0.5, 0.125]` anchor. The runtime grid is 72×36. `WorldAssetCatalog.generatedSprite` trusts the manifest and constructs an `SKSpriteNode` at that size. `TerrainRenderer` and `LotRenderer` then attach it to one tile, while `CityScene` reserves and sorts only that tile.

The 216×144 declaration is a **three-tile-wide by four-tile-high envelope**. Transparent padding may reduce the opaque portion of some sources, but the engine has no metadata or validation to know that. It also cannot distinguish acceptable vertical height from unacceptable sideways overlap. This is why adding better-looking images has produced a better individual illustration and a worse composition.

Required geometry record per source/LOD:

- logical tile footprint and supported orientations;
- ground-contact polygon and baseline;
- opaque bounds, including alpha threshold used to calculate them;
- allowed roof/canopy overhang versus forbidden neighbor intrusion;
- baked shadow bounds and light direction;
- entrance/frontage edge and road setback;
- prop sockets and exclusion zones;
- safe selection/overlay mask;
- expected physical pixel density at each supported camera stop.

Ingestion should fail if the opaque ground portion crosses its declared footprint, if a shadow points against the shared light, or if the per-LOD contact point moves.

### 2. Renderer layers lack a single visual-priority policy

The live map can place the following above one coordinate:

1. generated terrain plate;
2. overlay wash and pattern;
3. road or lot;
4. authored frontage and strategy ground;
5. construction/completed lifecycle effects;
6. ambient vegetation/decoration;
7. persistent spatial consequence brackets, marks, bars, and hatches;
8. selected outline, brackets, beam, cap, pulse, and label;
9. hover panel;
10. placement ghost, invalid footprint, hatch, and marker;
11. event cue;
12. SwiftUI feedback capsule and overlay legend above the SpriteKit view.

Each individual renderer is bounded, but the **composition is not**. A global arbiter should decide what survives for Normal, Hover, Selected, Build-valid, Build-invalid, Consequence-focus, and Overlay states. The base architecture must remain the largest readable signal in every state.

### 3. Fidelity cannot be repaired one asset at a time

`LotRenderer` selects generated art only when `tile.level == 1` and only for residential, commercial, industrial, park, city hall, and water tower. Power plant and services use procedural/fallback paths; higher-level strategy buildings use earlier place-family art; incomplete lots use procedural lifecycle art. That guarantees a mixed frame as soon as the city contains normal gameplay variety.

The next art gate therefore needs a **visible-set completion rule**, not an asset-count rule: every source the accepted starting state can show in normal, construction, strain, and recovery states must share one projection, scale, palette, material, light, shadow, and detail hierarchy before the gate can pass.

### 4. Camera and HUD must be designed as one viewport

SwiftUI correctly measures top and bottom chrome and sends viewport insets to selection reveal. That protects a coordinate during explicit keyboard reveal but does not make the initial world composition good. The initial core camera still uses a fixed scale (`0.48` regular, `0.72` compact under its heuristic), and `frameCity` fits the full board. Meanwhile the full-height SpriteKit view runs underneath the top HUD, objectives/feed, feedback, legend, and bottom command deck.

The solution is not another smaller scale constant. Camera framing must consume the **actual unobstructed world rectangle**, fit developed opaque bounds plus one expansion corridor, and reframe when HUD chrome opens, closes, or changes compact presentation.

### 5. Gameplay truth must become place change

The accepted simulation snapshot already provides per-coordinate power, water, pollution, vitality, and transition truth. The candidate largely maps that truth into generic marks. This is accurate but weak: it asks the player to decode a graphic overlay instead of observe a town.

The renderer should map typed state into restrained, asset-specific channels. Examples:

- power: window emission, signs, fixtures, service equipment, and bounded repair prop;
- water: fountain operation, planting health, soil/surface treatment, and utility object;
- pollution: localized haze/material grime near sources, not a global hatch field;
- vitality: maintenance, occupied frontage, canopy/awning, and bounded activity;
- recovery: removal of the physical symptom at the same coordinate plus one short confirmation cue.

These presentations must never invent simulation truth, but they should make the truth recognizable without a legend.

## Source correlation

| Finding | Source |
|---|---|
| 72×36 tile geometry and tile-root depth | `Native/CitySimNative/Sources/CitySimNative/Rendering/WorldVisualStyle.swift:212-248` |
| Generated manifest sizes and anchors are applied verbatim | `Native/CitySimNative/Sources/CitySimNative/Rendering/WorldAssetCatalog.swift:56-69` |
| Generated grass mounted on every tile | `Native/CitySimNative/Sources/CitySimNative/Rendering/TerrainRenderer.swift:14-49` |
| Generated art limited to six level-1 kinds | `Native/CitySimNative/Sources/CitySimNative/Rendering/LotRenderer.swift:118-197` |
| Fallback and construction paths coexist with generated art | `Native/CitySimNative/Sources/CitySimNative/Rendering/LotRenderer.swift:41-107` |
| First-adjacent-edge frontage rotation | `Native/CitySimNative/Sources/CitySimNative/Rendering/LotRenderer.swift:212-250` |
| One root/depth record per tile | `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift:739-808` |
| Fixed camera framing heuristics | `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift:1281-1316` |
| Selection label, brackets, beam, cap, and pulse | `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift:1048-1067,1337-1387` |
| Placement ghost and invalid hatch stack | `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift:1178-1238` |
| Persistent consequence emphasis rises to 0.82 in overlays | `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift:818-820` |
| Per-tile overlay wash and pattern | `Native/CitySimNative/Sources/CitySimNative/Rendering/WorldOverlayRenderer.swift:27-57,144-227` |
| Utility/pollution/vitality glyph construction | `Native/CitySimNative/Sources/CitySimNative/Rendering/SpatialConsequenceRenderer.swift:162-264` |
| Full-screen SpriteKit under top/bottom HUD | `Native/CitySimNative/Sources/CitySimNative/Views/ContentView.swift:165-239` |
| Compact viewport fallbacks and measured insets | `Native/CitySimNative/Sources/CitySimNative/Views/ContentView.swift:100-115` |
| Texture cache has no eviction | `Native/CitySimNative/Sources/CitySimNative/Rendering/WorldAssetCatalog.swift:7-41` |

## Corrective order

This order is deliberate. Generating more assets before correcting the geometry and composition contracts will create more expensive overlap.

### Work package 1 — physical world contract

- Introduce the asset geometry schema and offline validator.
- Split ground, structure, shadow, canopy/foreground, and props into declared layers.
- Add opaque-bounds neighbor tests for every rotation and LOD.
- Make depth use ground contact and controlled cross-tile layers.
- Build a deterministic collision contact sheet for the golden block.

**Exit:** zero unintended opaque overlap across the golden block; every visible building has a readable road and parcel contact.

### Work package 2 — unified golden block

- Rebuild terrain, complete road topology, lots, construction, vegetation, and visible services in one art language.
- Remove all visible fallback/procedural placeholder paths from the accepted start.
- Establish scale, projection, light, palette, shadow, and physical pixel budgets.

**Exit:** both independent reviewers score at least 3/4 in projection/coherence and material/depth, with no automatic rejection.

### Work package 3 — camera and HUD composition

- Compute the actual unobstructed world rectangle from HUD chrome.
- Fit developed visual bounds plus three truthful frontage opportunities.
- Reframe on compact/detail/objective changes.
- Create useful city, neighborhood, and block information designs.

**Exit:** developed content occupies 55–70% of the world band at default and exact 900×600; no selected/active coordinate is hidden by HUD.

### Work package 4 — interaction restraint

- Implement the visual-priority arbiter.
- Reduce selection to boundary + anchor.
- Show invalid reason once and suppress hover during build.
- Replace map-wide washes with sparse topology/local emphasis.

**Exit:** all interaction states preserve building, road, and parcel legibility; persistent glyphs occupy less than 3% of the viewport.

### Work package 5 — embodied consequences and life

- Map authoritative state into asset-specific materials/props/activity.
- Add same-coordinate strain/recovery and restrained deterministic life.
- Preserve static equivalence under Reduce Motion.

**Exit:** fresh players classify normal/strained/recovered state correctly in at least 4 of 5 unlabeled grayscale trials.

### Work package 6 — residency and final acceptance

- Remove superseded resources; instrument decoded texture residency by name/LOD.
- Cycle all LODs and interactions repeatedly in compact and regular windows.
- Run the complete build → diagnose → remedy → recover → undo journey with pointer and keyboard.

**Exit:** regular and compact memory stay within accepted baseline +128 MiB; integration and playtest each score at least 17/20 with no category below 3.

## Acceptance matrix

| Area | Required evidence |
|---|---|
| Overlap | Automated alpha/opaque-bounds reports for every neighboring golden-block pair and uncropped staged frames at three LODs. No road, entrance, or separate building is unintentionally covered. |
| Fidelity | No legacy or procedural placeholder visible in the accepted starting state, construction journey, or strain/recovery pair. |
| Scale/projection | Scale-sheet tolerances for door, floor, road, curb, tree, vehicle, and landmark exception; per-asset ingestion validation. |
| Composition | Developed content fills 55–70% of the unobstructed world band at default and exact 900×600. Three truthful opportunities visible within five seconds. |
| Interaction | Valid/blocked classification at least 4/5 without Details. One rejection message. Selection/build/hover never obscure the target parcel. |
| Consequences | At least 4/5 correct classification for localized trouble and recovery in unlabeled grayscale pairs. |
| LOD | Continuous 20-second pan/zoom recording; each stop exposes different useful information with no contact-point jump. |
| Accessibility | Selection, hover, and placement target roles are distinct; selected coordinate/kind/construction/consequence are announced without duplicate unknown labels. |
| Performance | Named decoded texture residency, stable node/draw/action counts, no repeated-LOD high-water growth, and baseline +128 MiB RSS/footprint ceiling. |
| Playability | Uncoached pointer and keyboard journey from opportunity discovery through construction, diagnosis, remedy, recovery, and undo in at most three minutes. |

## Evidence index

The following retained files are on `codex/citysim-world-rendering` at `8cb45b5848f070c25803213ee48b2523e8057d09` and should be reviewed together, not as curated individual wins:

- `docs/production/evidence/PLAY-022/gate-a-r/after-default-live.png`
- `docs/production/evidence/PLAY-022/gate-a-r/after-default-grayscale.png`
- `docs/production/evidence/PLAY-022/gate-a-r/after-compact-900x600-live.png`
- `docs/production/evidence/PLAY-022/gate-a-r/after-city-live.png`
- `docs/production/evidence/PLAY-022/gate-a-r/after-neighborhood-live.png`
- `docs/production/evidence/PLAY-022/gate-a-r/after-block-live.png`
- `docs/production/evidence/PLAY-022/gate-a-r/after-selection-live.png`
- `docs/production/evidence/PLAY-022/gate-a-r/after-valid-placement-live.png`
- `docs/production/evidence/PLAY-022/gate-a-r/after-invalid-placement-live.png`
- `docs/production/evidence/PLAY-022/gate-a-r/after-utilities-overlay-live.png`
- `docs/production/evidence/PLAY-022/gate-a-r/EVIDENCE.md`
- `docs/production/PLAY-022_WORLD_PLAYABILITY_DIRECTIVE.md` on `master`

To inspect a branch-retained image without checking out the candidate:

```sh
git show 8cb45b5848f070c25803213ee48b2523e8057d09:docs/production/evidence/PLAY-022/gate-a-r/after-default-live.png > /tmp/citysim-world-default.png
```

## Limitations

- This was a hands-on rendering audit of one exact staged starting state, not a full enumeration of every building level or possible save.
- The app was evaluated visually with normal macOS accessibility state; a complete VoiceOver listening session was not performed.
- No product source was changed, no new art was generated, and no renderer benchmark was rerun during this report. Performance figures are the candidate's retained measurements and are treated as disclosed evidence, not newly reproduced numbers.
- The report does not accept the candidate, broaden the active PLAY-022 claim, or authorize shared contract changes. It supplies the issue inventory and acceptance standard for the existing renderer mission.
