# World Rendering Recovery — From Diagram to Living Miniature

**Authority:** Integration lane

**Task:** PLAY-021

**Date:** July 19, 2026

## Why PLAY-020 under-delivered

PLAY-020 is a sound renderer-engineering slice, but it is not the visual breakthrough the product needs. Its retained live proof shows a small cluster of procedural buildings surrounded by a dominant, repetitive green grid. Construction and condition states are more truthful, yet floating labels still do much of the explanatory work. The improvement concentrates on lifecycle props and tests while the terrain, road language, building art, composition, ambient life, and sense of place remain close to the prototype.

The lane optimized the measurable contract—state mapping, deterministic variation, node reuse, Reduce Motion, and diagnostics—more strongly than the player-facing standard. It also treated missing spatial analytics as a broad visual blocker, although substantial truth-safe work remained available: authored terrain, roads, facades, frontage, vacant-land dressing, shadows, camera framing, decorative ambient life, and stronger family silhouettes.

## Required outcome

Deliver the Phase 1 golden-neighborhood vertical slice from `docs/NATIVE_GRAPHICS_UI_UPGRADE_PLAN_2026-07-18.md` as a visible product transformation. The same staged starting state must look composed, dense, inviting, and legible before the player builds anything. This is not a recolor, label pass, fixture-only showcase, or another renderer refactor presented as art progress.

### 1. Establish a real art pipeline

- Add original, repo-owned world art under a clearly named native resource directory with a small manifest describing source, authoring method, scale, filtering, and license/provenance.
- Integration pre-approves the narrow SwiftPM change required to register world-only resources. Do not add dependencies, products, targets, plugins, or unrelated package changes.
- Prefer reusable authored textures/atlases and composited sprite families over thousands of bespoke `SKShapeNode` primitives. Procedural geometry may remain where it is the right tool for topology, selection, and effects.
- Define coherent palette, light direction, outline weight, shadow depth, material language, and scale. All families must visibly belong to the same miniature world.

### 2. Make the ground and roads intentional

- Replace the repeated flat-green field with stable seeded grass/soil/lot-edge variants, restrained vacant-land dressing, park ground, contextual borders, and an intentional map edge/vignette. Vacant dressing must not imply developed or serviced land.
- Build the full connected-road family: ends, straights, corners, T junctions, crossings, sidewalks, curbs, lane markings, and crosswalks. Topology must be readable without debug outlines.
- Remove visual noise that competes with buildings, selection, placement, and overlays.

### 3. Author five complete place families

- Residential, commercial, industrial, park, and civic lots each need a distinct silhouette, footprint treatment, frontage, roof detail, props, shadow, and at least three stable seeded variants where the family supports variation.
- Buildings must remain identifiable at city, neighborhood, and block detail without glyph badges or floating lifecycle labels.
- Preserve PLAY-020 construction/condition truth, but integrate those cues into the authored architecture instead of drawing a second debug-like layer over it.
- Use depth, overlap, landscaping, street furniture, and lot-edge treatment to create neighborhood rhythm without inventing occupancy or economy facts.

### 4. Compose the camera around the city

- The real starting camera should frame the developed neighborhood with useful expansion context, not default to a mostly empty 24 x 24 board.
- City detail communicates silhouette and district rhythm; neighborhood detail communicates lots, trees, vehicles/ambient dressing, and condition; block detail communicates frontage and construction props.
- Zoom and pan must preserve hit testing, selection, placement, overlays, and compact usability.

### 5. Add truth-safe ambient life

- Add bounded deterministic ambient motion such as vegetation, park activity, decorative service motion, or lighting only where it does not claim nonexistent traffic, utility, employment, or prosperity.
- Treat gameplay-derived traffic, shortages, pollution sources, and strategy effects as typed inputs; do not infer them from art.
- Reduce Motion must retain static meaning, and unchanged pulses must not accumulate actions or nodes.

## Non-negotiable visual gate

The lane may not self-accept this task from tests or a renderer fixture. It must retain a same-camera contact sheet containing:

1. current integrated staged app before;
2. candidate staged app after;
3. default window;
4. real 900 x 600 content viewport;
5. city, neighborhood, and block detail;
6. normal city plus one diagnostic overlay;
7. selection and valid/invalid placement;
8. Reduce Motion.

The golden 8 x 8 proof must use the same shipping renderer/assets as the real app. The real authored start must show the improvement; a dense fixture cannot conceal a sparse or poorly framed live city.

Integration and PLAY-050 will judge the images with these rejection criteria:

- the board is still dominated by empty repetitive grid;
- visual interest comes mainly from labels, neon outlines, or saturation;
- buildings still read as unrelated procedural icons;
- road topology, sidewalks, frontage, and lot boundaries do not form a coherent place;
- camera cropping is the only reason the city appears denser;
- interaction feedback becomes harder to see;
- the delta would be described as polish rather than a new visual standard.

## Engineering and proof gate

- Stable asset/variant identity across relaunch, save/load, and camera changes.
- Focused coverage for road masks, deterministic variant selection, camera LOD, hit testing, Reduce Motion, and unchanged-pulse reuse.
- Full native suite, `git diff --check`, build-script syntax, and exact staged `--verify` pass.
- No node/action growth during a 30-minute equivalent soak; report update time, unchanged-pulse time, node/draw/action counts, and RSS observations against PLAY-020.
- Operate the real staged app with pointer and keyboard: pan, zoom, inspect, select, build preview, invalid placement, commit, overlay, undo, and compact flow.
- Commit coherent milestones continuously. The final handoff must be clean, unpushed, and list exact ordered commits, asset provenance, proof paths, measured tradeoffs, and any remaining blocked typed inputs.

## Recommended milestone order

1. Art direction, resource contract, terrain, and map edge.
2. Connected roads, sidewalks, curbs, and frontage system.
3. Five authored place families and seeded variants.
4. Camera composition and LOD integration.
5. Ambient life, lifecycle integration, accessibility, performance, and live proof.

Do not stop after milestone 1 or return another checkpoint as completion. If a real blocker prevents the complete slice, preserve a coherent commit, report the exact blocker, and leave PLAY-021 open.
