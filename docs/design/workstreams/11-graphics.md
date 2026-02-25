# Workstream: Graphics

## Reading Checklist
- Architecture Overview: [../../architecture/overview.md](../../architecture/overview.md)
- Class Hierarchy — UI & Reporting: [../../architecture/class-hierarchy.md](../../architecture/class-hierarchy.md#ui--reporting)
- Specs: [../../specs/graphics.md](../../specs/graphics.md), [../../specs/city.md](../../specs/city.md), [../../specs/traffic.md](../../specs/traffic.md)
- ADRs: [../../adr/001-simulation-determinism.md](../../adr/001-simulation-determinism.md), [../../adr/002-free-threaded-python.md](../../adr/002-free-threaded-python.md)
- Design Guide: [../readme.md](../readme.md)
- Consolidated Prompts: [../prompts.md](../prompts.md)
- Templates: [../templates/](../templates/)
- Guides: [../../guides/](../../guides/)
- Models: [../../models/model.mdj](../../models/model.mdj)

## Objectives
- Design and implement a fully decoupled isometric 2D tile renderer for City-Sim.
- Define how the existing City/District/Building state model maps to screen tiles and sprites.
- Establish an AI-assisted asset pipeline for generating high-quality game graphics.
- Ensure the renderer never blocks the simulation tick loop and respects determinism requirements.

## Scope
- New package: `src/gui/renderer/`
- Config: `src/shared/settings.py` (add `GraphicsSettings`)
- Specs: `docs/specs/graphics.md`
- Assets (generated, not committed unless optimized): `assets/tiles/`
- Entry point integration: `run.py` (optional `--gui` flag)

## Inputs
- `City` state (districts, buildings, road graph)
- `EventBus` events (`BuildingConstructedEvent`, `TrafficUpdatedEvent`, etc.)
- AI-generated tile PNGs (see `docs/specs/graphics.md` Section 6 for prompts)
- Tiled map editor `.tmj` export for base terrain map

## Outputs
- Running isometric city view rendered via pygame-ce
- Sprite sheet atlases (`terrain_atlas.png`, `buildings_atlas.png`)
- `GraphicsSettings` configuration
- Documentation: `docs/specs/graphics.md` (already created)

## Run Steps
```bash
./init-venv.sh && pip install -r requirements.txt
python3 run.py           # headless (no change)
python3 run.py --gui     # with isometric renderer
```

## Task Backlog
- Implement `IsometricGridMapper` with world↔screen coordinate conversion
- Implement `TileAtlas` and `BuildingSpriteSelector`
- Implement `CityRenderer` subscribing to `EventBus`
- Implement `UIOverlay` (HUD: budget, population, happiness)
- Create `BuildingRenderState` wrapper (associates `Building` with `grid_position`; do not modify core `Building` class)
- Extend `EventBus` with buffered queue support for render-thread safety
- Generate AI tile assets (see prompts in `docs/specs/graphics.md`)
- Pack individual tiles into sprite sheet atlases using Pillow
- Author base terrain map in Tiled and export as `.tmj`
- Add `--gui` CLI flag to `run.py`
- Write ADR-003 capturing pygame-ce rendering choice

## Acceptance Criteria
- Simulation runs headlessly (`python3 run.py`) with no graphical dependencies
- Renderer reads only from `City` state and `EventBus` — zero imports from simulation core
- All visual randomness uses `RandomService` with a fixed seed (deterministic output)
- Frame rate is decoupled from tick rate
- All `BuildingType` values have a corresponding sprite in the atlas
- Tileset atlas loads in < 100 ms on startup

## Copy‑Paste Prompt
```
Preflight Checklist:
- [ ] Read Architecture Overview and Class Hierarchy (UI & Reporting section)
- [ ] Read docs/specs/graphics.md in full (rendering architecture, tools, asset prompts)
- [ ] Review city.md (Building/District model), traffic.md (road network), ADR-001, ADR-002
- [ ] Confirm settings and entry points (run.py, src/main.py)
- [ ] Identify required outputs and acceptance criteria
- [ ] Plan minimal, style-consistent changes and validation steps
You are an AI coding agent working on City‑Sim, focusing on the Graphics workstream.

Objectives:
- Implement a fully decoupled isometric 2D tile renderer.
- Map existing City/District/Building state to isometric tiles and sprites.
- Establish an AI-assisted asset pipeline for game-quality graphics.
- Ensure the renderer never blocks the simulation tick loop.

Global Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Graphics Spec: docs/specs/graphics.md  ← PRIMARY reference for this workstream
- City Spec: docs/specs/city.md
- Traffic Spec: docs/specs/traffic.md
- ADRs: docs/adr/001-simulation-determinism.md, docs/adr/002-free-threaded-python.md
- Guides: docs/guides/contributing.md, docs/guides/glossary.md
- Workstreams Index: docs/design/workstreams/00-index.md

Scope & Files:
- New: src/gui/renderer/ (CityRenderer, IsometricGridMapper, TileAtlas, BuildingSpriteSelector, UIOverlay)
- New: src/shared/graphics_settings.py (GraphicsSettings)
- Modified: run.py (add --gui flag), requirements.txt (add pygame-ce, Pillow, pytmx)
- Assets: assets/tiles/ (AI-generated PNGs, packed atlases)
- Specs: docs/specs/graphics.md

Required Outputs:
- Isometric renderer that reads from City state and EventBus.
- Sprite sheet atlases (terrain + buildings).
- --gui flag wiring in run.py.
- ADR-003 capturing the pygame-ce rendering decision.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py             # headless — must still work
4) python3 run.py --gui       # with renderer
5) ./test.sh                  # existing tests must still pass

Acceptance Criteria:
- Headless run unaffected by renderer code.
- Renderer reads only City state + EventBus.
- All visual randomness via RandomService (fixed seed = deterministic visuals).
- Frame rate decoupled from tick rate.
- All BuildingType values mapped to a sprite.

Asset Generation:
- Use the prompts in docs/specs/graphics.md Section 6 with an image-generator AI
  (Midjourney, DALL-E, Stable Diffusion, or Adobe Firefly) to create tile PNGs.
- Use the Section 6.7 "Complete Tileset Sheet" prompt to generate a full atlas in one pass.
- Post-process with Pillow to normalize to 128x128 source → 64x32 display tile.

Constraints:
- Renderer must NOT import from src/simulation/ or src/city/ beyond reading City state.
- No time-based randomness; all decoration randomness via RandomService.
- Keep changes minimal and consistent with the codebase style.

Deliver:
- Concise plan + exact edits
- Validation notes (renderer screenshot or ASCII art of grid)
- Follow-up recommendations
```
