# Workstream 12 — AAA City-Builder Visual & Gameplay Upgrade Roadmap

## Reading Checklist

- Architecture Overview: [../../architecture/overview.md](../../architecture/overview.md)
- Class Hierarchy: [../../architecture/class-hierarchy.md](../../architecture/class-hierarchy.md)
- Graphics Spec: [../../specs/graphics.md](../../specs/graphics.md)
- City Spec: [../../specs/city.md](../../specs/city.md)
- Traffic Spec: [../../specs/traffic.md](../../specs/traffic.md)
- ADRs: [../../adr/](../../adr/)
- Current Renderer: [../../../src/gui/renderer/](../../../src/gui/renderer/)
- Workstream 11 (Graphics, base): [11-graphics.md](11-graphics.md)

---

## Purpose

This document is a **delegation-ready roadmap** for evolving City-Sim from its current
prototype-quality isometric renderer into a production-quality city-builder experience on
par with titles such as *Cities: Skylines*, *Anno 1800*, and *SimCity 4*.

The roadmap is divided into self-contained **phases** that can each be assigned to a
dedicated engineer or AI agent. Each phase has clear pre-conditions, deliverables, and
acceptance criteria, and is designed so that phases can be developed in parallel where
noted.

---

## Current State (Baseline)

| Capability | Status |
|---|---|
| Isometric grid rendering | ✅ Flat diamond tiles, painter's-algorithm depth sort |
| Building tile placement | ✅ Click-to-place from palette bar |
| Hover highlight | ✅ Yellow outline on hovered tile |
| Right-click erase | ✅ |
| HUD (population, happiness, facilities) | ✅ Text overlay top-left |
| Action panel (add water/elec/housing, pause) | ✅ Right sidebar |
| Keyboard shortcuts | ✅ W / E / H / P / Esc |
| Building sprites | ⚠️ Procedural colored diamonds — no real art |
| Building elevation (height stacking) | ❌ All buildings render as flat tiles |
| Camera pan / zoom | ❌ Fixed position |
| Animated tiles (water, traffic, smoke) | ❌ Static only |
| Road network rendering | ❌ No road tiles |
| Day / night cycle | ❌ |
| Weather effects | ❌ |
| Sound & music | ❌ |
| Save / load | ❌ |
| Tech tree / progression | ❌ |
| Budget / finance UI panel | ❌ |
| Population detail panel | ❌ |
| Notifications / event log | ⚠️ Toast only |
| Minimap | ❌ |

---

## Phase Overview

```
Phase 1  — Real Sprite Art & Atlas Pipeline          (Art + Pipeline)
Phase 2  — Building Elevation & Depth-Correct Render (Rendering)
Phase 3  — Camera Pan, Zoom & Grid Scroll            (Rendering)
Phase 4  — Road Network Tiles                        (Rendering + City model)
Phase 5  — Animated Tiles                            (Rendering)
Phase 6  — Rich UI: Finance, Population, Minimap     (UI)
Phase 7  — Day / Night Cycle & Lighting              (Rendering)
Phase 8  — Weather & Particle Effects                (Rendering)
Phase 9  — Save / Load                               (Simulation + IO)
Phase 10 — Sound & Music                             (Audio)
Phase 11 — Tech Tree & Progression System            (Simulation)
Phase 12 — Performance & Scalability                 (Performance)
```

Phases 1–3 are prerequisites for all later phases.
Phases 4–6 can run in parallel after Phase 1–3.
Phases 7–12 can run in parallel after Phases 4–6.

---

## Phase 1 — Real Sprite Art & Atlas Pipeline

**Goal**: Replace procedural colored diamonds with game-quality isometric sprites.

### Pre-conditions
- `TileAtlas` (`src/gui/renderer/tile_atlas.py`) exists and serves placeholder sprites.
- `BuildingSpriteSelector` maps every `BuildingType` → sprite ID.

### Deliverables

#### 1A — Source asset generation
Generate one 128×128 px source PNG per tile type using the prompts in
`docs/specs/graphics.md` Section 6. Use Midjourney, DALL-E 3, Stable Diffusion XL,
or Adobe Firefly. Aim for the prompt in **Section 6.7** (Complete Tileset Sheet) to
produce a full sprite sheet in a single pass, then slice it.

Required tiles (minimum viable set):

| Category | Tiles |
|---|---|
| Terrain | grass (3 variants), dirt, water, sand |
| Roads | straight-H, straight-V, bend NE/NW/SE/SW, T-north/south/east/west, 4-way |
| Residential | small-1f, small-2f, medium-3f, medium-4f, large-5f, large-6f, damaged variant |
| Commercial | shop-1f, shop-2f, office-4f, office-8f, mall, damaged variant |
| Industrial | small-factory, warehouse, power-plant, damaged variant |
| Civic | city-hall, hospital, school, fire-station, police, park-pavilion |
| Props | tree-deciduous, tree-pine, street-lamp, traffic-light, bench |
| Overlays | fire, construction-scaffold, flood-water |

#### 1B — Pillow normalisation script
Write `tools/pack_atlas.py` (a standalone tool, not a src module):

```python
# tools/pack_atlas.py
# Reads individual source PNGs from assets/tiles/source/
# Resizes each to 128×128 source → 64×32 diamond display tile
# Packs them into:
#   assets/tiles/terrain_atlas.png  (8 columns × N rows)
#   assets/tiles/buildings_atlas.png
# Emits assets/tiles/atlas_manifest.json mapping sprite_id → (atlas_file, col, row)
```

Key operations:
- `Image.resize((128, 64), Image.LANCZOS)` then crop to diamond mask
- Optionally apply a drop-shadow pass for elevation depth cue
- Emit `atlas_manifest.json` consumed by `TileAtlas`

#### 1C — Update `TileAtlas`
- Load `atlas_manifest.json` on init; fall back to procedural diamonds if file absent.
- `get_tile(sprite_id: str) -> pygame.Surface` looks up (atlas_file, col, row) and
  returns a pre-cropped `Surface` from an LRU cache.

#### 1D — Update `BuildingSpriteSelector`
- Map every `BuildingType` + `condition` range + `occupancy` bucket → sprite ID string
  that matches a key in `atlas_manifest.json`.
- No change to the `BuildingType` enum itself.

### Acceptance Criteria
- `python run.py --gui` shows real artwork instead of colored diamonds.
- `tools/pack_atlas.py` runs headlessly; emits valid atlas PNGs and manifest.
- Tileset atlas loads in < 100 ms.
- All `BuildingType` values have a real sprite (no fallback placeholder shown).

---

## Phase 2 — Building Elevation & Depth-Correct Rendering

**Goal**: Buildings appear to have height (1–N floors stacked), not just flat tiles.
The renderer must correctly depth-sort tall buildings so near buildings never occlude
far ones.

### Pre-conditions
- Phase 1 complete; real building sprites exist with left-face, right-face, roof panels.

### Deliverables

#### 2A — Multi-panel building sprite format
Each building sprite is split into three surfaces (authored in Phase 1):
- `roof` — top diamond face
- `left_face` — left rhombus panel (height × tile_w/2 px tall)
- `right_face` — right rhombus panel (height × tile_w/2 px tall)

The atlas manifest adds `height_tiles: int` (number of floor stacks, 1–8).

#### 2B — `ElevatedBuildingBlit` renderer helper
```python
class ElevatedBuildingBlit:
    """
    Blits a 3-panel building sprite at (col, row, height_tiles) using painter's
    algorithm. Elevation offset is height_tiles * FLOOR_H where FLOOR_H = 16 px.
    """
    def blit(self, surface, tile_atlas, building_render_state): ...
```

#### 2C — Depth sort update in `CityRenderer`
Current sort key: `col + row`.
New sort key: `(col + row, -height_tiles)` — ensures shorter buildings render
before taller buildings in the same isometric row.

#### 2D — Shadow projection
Add a soft elliptical shadow blit under each elevated building proportional to
`height_tiles`. Use `pygame.Surface` with `SRCALPHA` and a pre-rendered shadow PNG.

### Acceptance Criteria
- A 4-floor apartment does not clip through a 1-floor house behind it.
- Building sprites show visible left/right faces giving 3D depth illusion.
- No visual artefacts (z-fighting) at tile borders.

---

## Phase 3 — Camera Pan, Zoom & Grid Scroll

**Goal**: Player can pan the camera across a large map and zoom in/out.

### Pre-conditions
- Phase 1 complete.

### Deliverables

#### 3A — `CameraController` class
```python
class CameraController:
    """
    Owns the viewport offset (origin_x, origin_y) and zoom_level.
    Methods:
      pan(dx, dy)          — move viewport by pixel delta
      zoom(factor)         — scale factor: 0.5× (out) to 2.0× (in), clamped
      world_to_screen(col, row) -> (x, y)  — applies zoom + pan
      screen_to_world(x, y) -> (float, float)  — inverse, for mouse hit-testing
    """
```

Replace the hard-coded `origin_x, origin_y` in `IsometricGridMapper` with a
`CameraController` reference injected at construction time.

#### 3B — Input bindings
| Input | Action |
|---|---|
| Middle-mouse drag | Pan camera |
| Arrow keys | Pan camera (hold for continuous) |
| Scroll wheel up | Zoom in |
| Scroll wheel down | Zoom out |
| `0` | Reset camera to default position |
| `F` | Frame the entire city (fit-to-screen) |

#### 3C — Map size increase
Increase default grid from 10×10 to 32×32 (matches Cities:Skylines starter map).
`PlaceableCityGridLayout` constructor gains `cols: int = 32, rows: int = 32`.

#### 3D — Off-screen culling
In `CityRenderer._render_tiles()`, skip any tile whose screen rect is entirely
outside the window viewport. This is required for performance at 32×32+ maps.

### Acceptance Criteria
- Player can pan smoothly across a 32×32 grid at 60 fps.
- Zoom in/out to 0.5×–2.0× without visual distortion.
- Off-screen tiles are culled (0 blit calls for invisible tiles).

---

## Phase 4 — Road Network Tiles

**Goal**: Player can place road segments; the engine auto-selects the correct road tile
(straight, bend, T-junction, intersection) based on adjacent tiles.

### Pre-conditions
- Phases 1–3 complete. Phase 1 road sprites must exist.

### Deliverables

#### 4A — `RoadNetwork` data model
```python
# src/city/road_network.py
from enum import Enum, auto

class RoadSegment(Enum):
    NONE = auto()
    ROAD = auto()

class RoadNetwork:
    """Sparse grid of road segments. City holds one RoadNetwork instance."""
    def __init__(self, cols: int, rows: int): ...
    def place_road(self, col: int, row: int): ...
    def remove_road(self, col: int, row: int): ...
    def is_road(self, col: int, row: int) -> bool: ...
    def get_neighbours(self, col: int, row: int) -> dict[str, bool]:
        """Returns {N, E, S, W: bool} — which cardinal neighbours have road."""
```

#### 4B — `RoadTileSelector`
```python
# src/gui/renderer/road_tile_selector.py
class RoadTileSelector:
    """
    Given the 4-neighbour bitmask (N, E, S, W), returns the correct road sprite ID.
    Uses a 16-entry lookup table covering all combinations.
    """
    _TABLE: dict[tuple[bool,bool,bool,bool], str] = { ... }
    def get_sprite_id(self, n: bool, e: bool, s: bool, w: bool) -> str: ...
```

#### 4C — Palette entry for Road
Add `BuildingType.ROAD` to `building.py` enum.
`BuildingPalette` adds a `Road` entry.

#### 4D — `CityRenderer` integration
- Road tiles render below buildings (depth sort: roads at `z = col+row - 0.5`).
- When a road is placed adjacent to an existing road, update both tiles' sprites.

### Acceptance Criteria
- Placing road segments next to each other auto-snaps to correct bend/T/intersection sprites.
- Roads render below buildings but above terrain.
- Removing a road updates adjacent road sprites correctly.

---

## Phase 5 — Animated Tiles

**Goal**: Water shimmers, smoke rises from factories, vehicles drive on roads.

### Pre-conditions
- Phases 1–4 complete. Animated source sprites (sprite strips or individual frames) must exist.

### Deliverables

#### 5A — `AnimationController`
```python
# src/gui/renderer/animation_controller.py
class AnimationController:
    """
    Manages per-tile frame advancement at a configurable frame rate (default 8 fps).
    Decoupled from the simulation tick rate and the display frame rate.
    """
    def tick(self, elapsed_ms: float): ...
    def get_frame(self, sprite_id: str) -> int: ...  # current frame index
    def register(self, sprite_id: str, frame_count: int, fps: float = 8.0): ...
```

#### 5B — Water animation
Water tiles (`WATER`) use a 4-frame shimmer strip. `AnimationController` advances
the frame index each render tick.

#### 5C — Factory smoke particle system
```python
# src/gui/renderer/particle_system.py
class Particle:
    pos: tuple[float, float]
    vel: tuple[float, float]
    alpha: int
    radius: float

class ParticleSystem:
    """
    Emits rising smoke particles from `BuildingType.POWER_PLANT` and
    `BuildingType.INDUSTRIAL` tiles. Uses `RandomService` for deterministic
    particle seeds.
    """
    def emit(self, world_col: int, world_row: int): ...
    def update(self, elapsed_ms: float): ...
    def draw(self, surface: pygame.Surface, camera: CameraController): ...
```

#### 5D — Vehicle sprites on roads
A minimal traffic visualiser:
- When `TrafficUpdatedEvent` fires, create `VehicleSprite` objects that lerp from
  one road tile to the next over one tick duration.
- Sprites drawn above road tiles, below building tiles.
- 4-frame car animation strip per direction (N, E, S, W).

### Acceptance Criteria
- Water tiles animate at 8 fps independent of sim tick rate.
- Smoke particles rise from factories and fade out correctly.
- At least one vehicle type drives along placed roads.

---

## Phase 6 — Rich UI: Finance Panel, Population Detail, Minimap, Event Log

**Goal**: Player can see detailed city stats, browse an event log, and navigate via minimap.

### Pre-conditions
- Phases 1–3 complete.

### Deliverables

#### 6A — `FinancePanel`
Right sidebar tab showing:
- Current budget balance (large number)
- Per-tick revenue bar chart (last 20 ticks)
- Per-tick expense bar chart
- Revenue breakdown: residential tax, commercial tax
- Expense breakdown: water, electricity, civic services

#### 6B — `PopulationPanel`
- Total population counter with trend arrow
- Happiness score with color-coded indicator (green/amber/red)
- Population breakdown by district
- Unemployment rate, migration delta

#### 6C — `Minimap`
```python
# src/gui/renderer/minimap.py
class Minimap:
    """
    80×80 px overview of the full city grid drawn in the bottom-right corner.
    Each occupied cell = 1 px colored by building type category.
    Viewport rectangle drawn as a white outline.
    Click-to-pan: clicking a minimap position pans the main camera to that area.
    """
    def draw(self, surface: pygame.Surface, layout: ICityGridLayout,
             camera: CameraController): ...
    def handle_click(self, pos: tuple[int,int], camera: CameraController): ...
```

#### 6D — `EventLog`
Scrollable bottom panel (collapsed by default, toggle with `L`):
- Displays last 50 city events as timestamped text lines.
- Event types: building placed/demolished, population milestone, budget warning,
  disaster struck.
- Color-coded: green (positive), amber (neutral), red (danger).

#### 6E — `NotificationManager` upgrade
- Replace the current single-toast system with a stacked notification queue.
- Each notification has a severity (info / warning / critical) with matching icon.
- Critical notifications pulse and require acknowledgement.

### Acceptance Criteria
- Finance panel correctly reflects `CityBudget` values from the simulation.
- Minimap accurately reflects the placed building layout at all times.
- Event log shows at least the last 20 tick events.
- All panels are toggleable with keyboard shortcuts and do not overlap the game view.

---

## Phase 7 — Day / Night Cycle & Lighting

**Goal**: The game world transitions through dawn, day, dusk, and night over simulation
ticks. Buildings light up at night.

### Pre-conditions
- Phases 1–3 complete.

### Deliverables

#### 7A — `DayNightCycle`
```python
# src/gui/renderer/day_night_cycle.py
class DayNightCycle:
    """
    Maps simulation tick index → time-of-day factor in [0.0, 1.0).
    0.0 = midnight, 0.25 = dawn, 0.5 = noon, 0.75 = dusk.
    Default: 24 ticks per full day cycle.
    """
    ticks_per_day: int = 24

    def get_time(self, tick_index: int) -> float: ...
    def get_sky_color(self, time: float) -> tuple[int,int,int]: ...
    def get_ambient_overlay(self, time: float) -> pygame.Surface:
        """Returns a full-screen semi-transparent surface tinted by time of day."""
```

The renderer applies `get_ambient_overlay()` as the final blit pass over the tile
layer (before the HUD layer).

#### 7B — Building window lights at night
At night (time ∈ [0.75, 1.0) ∪ [0.0, 0.25]), occupied residential and commercial
buildings render a `_lit` sprite variant (windows glowing warm amber).
`BuildingSpriteSelector` gains a `night_mode: bool` parameter.

#### 7C — Street lamp glow
Street lamp prop sprites have a `_glow` overlay circle that is only drawn at night.
`AnimationController` can vary glow alpha as a pseudo-flicker effect.

### Acceptance Criteria
- Sky color transitions smoothly through the 24-tick cycle.
- Lit building variants are visible at night and dark during day.
- Performance: day/night overlay blit adds < 1 ms per frame.

---

## Phase 8 — Weather & Particle Effects

**Goal**: Rain, snow, and thunderstorms affect the visual atmosphere and can trigger
simulation events (floods, happiness drops).

### Pre-conditions
- Phase 5 particle system complete.

### Deliverables

#### 8A — `WeatherSystem`
```python
# src/gui/renderer/weather_system.py
class WeatherType(Enum):
    CLEAR = auto()
    RAIN = auto()
    HEAVY_RAIN = auto()
    SNOW = auto()
    THUNDERSTORM = auto()

class WeatherSystem:
    """
    Driven by `WeatherChangedEvent` from the simulation EventBus.
    Manages particle emitters for rain/snow and overlay tints for atmosphere.
    Uses RandomService for deterministic particle seeding.
    """
    def set_weather(self, weather: WeatherType): ...
    def update(self, elapsed_ms: float): ...
    def draw(self, surface: pygame.Surface): ...
```

#### 8B — Rain particle emitter
Full-width rain streaks falling at a slight angle. Intensity varies by weather type.
Puddle sprites appear on road tiles during heavy rain.

#### 8C — Snow particle emitter
Soft circular snowflakes drifting down. After heavy snowfall, tile sprites switch to
a `_snow` variant (white rooftops).

#### 8D — Lightning flash
`THUNDERSTORM` triggers an occasional full-screen white flash (< 100 ms) followed by
a `WeatherChangedEvent` to the simulation that may spawn a fire event.

### Acceptance Criteria
- Rain / snow particles are visually convincing and run at 60 fps on a 32×32 grid.
- Weather type changes propagate from simulation → renderer via `WeatherChangedEvent`.
- Snow accumulation visual is tied to a `RandomService` seed (deterministic).

---

## Phase 9 — Save / Load

**Goal**: Player can save their city at any point and resume later.

### Pre-conditions
- Phases 1–4 complete. `PlaceableCityGridLayout` owns the canonical building map.

### Deliverables

#### 9A — `CitySerializer`
```python
# src/city/city_serializer.py
import json
from pathlib import Path

class CitySerializer:
    """Serializes and deserializes City + PlaceableCityGridLayout to/from JSON."""

    def save(self, city: City, layout: PlaceableCityGridLayout,
             path: Path, tick_index: int, budget_balance: float): ...

    def load(self, path: Path) -> tuple[City, PlaceableCityGridLayout, int, float]: ...
```

Save format (`saves/<name>.citysim.json`):
```json
{
  "version": 1,
  "tick_index": 142,
  "budget_balance": 52000.0,
  "grid": {
    "cols": 32, "rows": 32,
    "buildings": [
      {"col": 3, "row": 5, "building_type": "RESIDENTIAL_SMALL", "condition": 0.9}
    ]
  },
  "population": { "count": 1823, "happiness": 74.2 }
}
```

#### 9B — `SaveManager` UI
- `Ctrl+S` → quicksave to `saves/quicksave.citysim.json` + toast notification.
- `Ctrl+L` → load quicksave.
- `Ctrl+Shift+S` → open file name prompt (pygame text input) for named save.
- Save files stored in `saves/` directory (gitignored).

#### 9C — Autosave
Every 60 ticks the sim automatically writes `saves/autosave.citysim.json`.
Configurable interval in `GraphicsSettings.autosave_interval_ticks`.

### Acceptance Criteria
- A saved city loads back with identical grid layout, tick index, and budget.
- Save files survive a headless run restart.
- Quicksave / load are < 200 ms on a 32×32 grid.

---

## Phase 10 — Sound & Music

**Goal**: Sound effects on actions and ambient background music.

### Pre-conditions
- pygame-ce is already installed (includes `pygame.mixer`).

### Deliverables

#### 10A — `SoundManager`
```python
# src/gui/audio/sound_manager.py
class SoundManager:
    """
    Wraps pygame.mixer. Loads .ogg audio files from assets/audio/.
    Methods: play_sfx(name), play_music(name, loop=True), set_sfx_volume(v),
             set_music_volume(v), stop_music().
    """
```

#### 10B — Sound effects
| Trigger | SFX file |
|---|---|
| Building placed | `build_click.ogg` |
| Building erased | `demolish.ogg` |
| Add water / elec / housing | `button_confirm.ogg` |
| Disaster (fire, flood) | `alarm.ogg` |
| Population milestone | `fanfare.ogg` |
| UI button hover | `hover_tick.ogg` |

Free sound sources: freesound.org (CC0 licence), Kenney.nl game assets.

#### 10C — Background music
- 3 ambient tracks (`city_ambient_day.ogg`, `city_ambient_night.ogg`,
  `city_ambient_rain.ogg`).
- `SoundManager` cross-fades between tracks as `DayNightCycle` and `WeatherSystem`
  change state.
- Music volume defaults to 40% and is user-adjustable via `M` key.

#### 10D — Settings integration
Add to `GraphicsSettings`:
```python
sfx_volume: float = 0.8      # 0.0–1.0
music_volume: float = 0.4
enable_sfx: bool = True
enable_music: bool = True
```

### Acceptance Criteria
- Build/demolish SFX play within 50 ms of the triggering action.
- Music cross-fades smoothly between day / night / rain states.
- Audio is fully optional — `python run.py` headless is unaffected.

---

## Phase 11 — Tech Tree & Progression System

**Goal**: City starts small and unlocks advanced buildings and services as population
and happiness milestones are reached.

### Pre-conditions
- Finance (WS-03) and Population (WS-04) subsystems stable.

### Deliverables

#### 11A — `TechTree` data model
```python
# src/city/tech_tree.py
from dataclasses import dataclass, field
from typing import Callable

@dataclass
class TechNode:
    id: str
    name: str
    description: str
    requires: list[str]                       # IDs of prerequisite nodes
    unlock_condition: Callable[[City], bool]  # evaluated each tick
    unlocks: list[BuildingType]               # building types made available
    is_unlocked: bool = False

class TechTree:
    """Holds the full directed-acyclic-graph of tech nodes. Evaluated per tick."""
    nodes: dict[str, TechNode]

    def evaluate(self, city: City): ...       # unlocks nodes whose condition is met
    def is_available(self, bt: BuildingType) -> bool: ...
```

#### 11B — Example tech nodes

| Node | Unlock condition | Unlocks |
|---|---|---|
| `basic_services` | population ≥ 100 | HOSPITAL, FIRE_STATION |
| `education` | happiness ≥ 50 AND population ≥ 500 | CIVIC_SCHOOL |
| `heavy_industry` | POWER_PLANT placed | INDUSTRIAL |
| `civic_center` | happiness ≥ 70 AND tick ≥ 200 | CIVIC_CITY_HALL |

#### 11C — UI integration
- Locked building types in `BuildingPalette` render greyed-out with a lock icon.
- Hovering a locked tile shows a tooltip: "Unlock: requires population ≥ 500".
- When a node unlocks, a notification fires: "🏫 Schools unlocked!".

#### 11D — Simulation integration
`Sim.advance_day()` calls `tech_tree.evaluate(city)` after updating finance/population.

### Acceptance Criteria
- Locked buildings cannot be placed; palette shows them greyed with a lock icon.
- Tech nodes unlock correctly when their conditions are met.
- `TechTree` is deterministic: same seed produces same unlock sequence.

---

## Phase 12 — Performance & Scalability

**Goal**: The game runs at a stable 60 fps on a 64×64 grid with 500+ buildings.

### Pre-conditions
- All previous phases complete.

### Deliverables

#### 12A — Dirty-tile rendering
Track which tiles changed since the last frame (building placed/removed, animation
frame advanced). Only re-blit changed tiles to an off-screen `pygame.Surface` backing
store. Composite the backing store to screen in one `blit` call per frame.

#### 12B — Sprite atlas pre-baking
Pre-bake all building sprites (roof + left + right panels composited at each zoom
level) into a `dict[zoom: float, dict[sprite_id: str, Surface]]` cache on startup.
Eliminates per-frame `pygame.transform.scale` calls.

#### 12C — Particle system budget
Cap particle count at 1000 globally. New particles replace oldest when cap is
reached. Use `numpy` arrays for batch position update if available.

#### 12D — Profiling harness
```python
# src/gui/renderer/perf_hud.py
class PerfHUD:
    """
    Optional overlay (toggle with F3) showing:
    - Frame time (ms) — last frame and 60-frame rolling average
    - Tile blit count per frame
    - Particle count
    - Active animation count
    """
```

### Acceptance Criteria
- 60 fps maintained on a 64×64 grid with all Phase 1–11 features active on a mid-range
  laptop (Intel i5, integrated GPU).
- `PerfHUD` shows ≤ 16.7 ms average frame time.
- Memory usage for sprite caches < 200 MB.

---

## Recommended Delegation Order

For a single engineer working sequentially:
1. Phase 1 (art pipeline) — unblocks everything visual
2. Phase 3 (camera) — dramatically improves playability
3. Phase 2 (elevation) — transforms flat tiles into 3D-looking buildings
4. Phase 6 (rich UI) — makes stats visible and actionable
5. Phase 4 (roads) + Phase 5 (animation) — concurrent
6. Phase 9 (save/load) — required for any meaningful gameplay loop
7. Phase 7 (day/night) + Phase 10 (sound) — concurrent, atmosphere
8. Phase 8 (weather) — atmosphere
9. Phase 11 (tech tree) — progression
10. Phase 12 (performance) — polish

For a team of 3 engineers working in parallel after Phase 1:
- Engineer A: Phases 2, 3, 7 (rendering track)
- Engineer B: Phases 4, 5, 8 (world simulation track)
- Engineer C: Phases 6, 9, 10, 11 (UI + systems track)
- All: Phase 12 (shared responsibility)

---

## Release Milestones & Timeline

The 12 technical phases map onto four release milestones. Estimates assume a **3-engineer
team** working in parallel after Phase 1 completes; solo timelines are shown in
parentheses.

| Milestone | Phases included | Team ETA | Solo ETA | Exit condition |
|---|---|---|---|---|
| **Alpha** | 1, 2, 3, 6, 9 | Week 10 | Week 14 | All acceptance criteria for included phases met; QA sign-off |
| **Beta** | 4, 5, 7, 10, 11 | Week 20 | Week 25 | Feature-complete; no P1/P2 bugs; sound and tech-tree integrated |
| **Release Candidate** | 8, 12 | Week 25 | Week 29 | 60 fps on target hardware; zero crash bugs; save/load round-trip verified |
| **v1.0** | Polish, localization, store prep | Week 28 | Week 32 | Cert requirements met; all platform targets verified |

### Milestone Definitions

#### Alpha (end of Week 10)
Goal: *Playable prototype with real art, camera, 3D buildings, basic UI, and save/load.*

Included phases and why:
- **Phase 1** — art pipeline (unblocks all visual work; zero substitutes)
- **Phase 2** — building elevation (transforms flat prototype into 3D feel)
- **Phase 3** — camera pan/zoom (makes map usable beyond a tiny grid)
- **Phase 6** — rich UI panels (makes finance/population data legible)
- **Phase 9** — save/load (minimum viable gameplay loop; prerequisite for playtesting)

Alpha Go/No-Go gate: All five phase acceptance criteria met + 15-minute play session
possible without a crash.

#### Beta (end of Week 20)
Goal: *Feature-complete world: roads, animations, day/night, sound, tech tree.*

Included phases:
- **Phase 4** — road tiles (city connectivity visible)
- **Phase 5** — animated tiles (brings world to life: water, smoke, vehicles)
- **Phase 7** — day/night cycle (atmosphere; city lighting distinguishes itself)
- **Phase 10** — sound & music (sensory completeness)
- **Phase 11** — tech tree (gameplay progression loop)

Beta Go/No-Go gate: Full 30-minute play session, all building types unlockable, music
cross-fades correctly, no P1 bugs.

#### Release Candidate (end of Week 25)
Goal: *Weather, particle effects, 60 fps performance on target hardware.*

Included phases:
- **Phase 8** — weather & particle effects (atmospheric depth)
- **Phase 12** — performance & scalability (64×64 grid, 60 fps target)

RC Go/No-Go gate: `PerfHUD` shows ≤ 16.7 ms average on reference hardware (Intel i5,
integrated GPU); all weather effects deterministic.

#### v1.0 (end of Week 28)
Polish, localisation pass, platform store submission, marketing materials finalised.

---

## Effort Estimates

Estimates are in **person-weeks** for a single engineer. Parallelism opportunities are
noted.

| Phase | Description | Solo weeks | Parallelisable with |
|---|---|---|---|
| 1 | Real sprite art & atlas pipeline | 3 | — (prerequisite for all) |
| 2 | Building elevation & depth-correct render | 2 | Phase 3 |
| 3 | Camera pan, zoom & grid scroll | 2 | Phase 2 |
| 4 | Road network tiles | 2 | Phase 5, 6 |
| 5 | Animated tiles | 2 | Phase 4, 6 |
| 6 | Rich UI: Finance, Population, Minimap | 3 | Phase 4, 5 |
| 7 | Day / night cycle & lighting | 2 | Phase 10 |
| 8 | Weather & particle effects | 2 | Phase 12 |
| 9 | Save / load | 2 | Phase 6 |
| 10 | Sound & music | 2 | Phase 7 |
| 11 | Tech tree & progression | 3 | Phase 7, 10 |
| 12 | Performance & scalability | 2 | Phase 8 |
| **Total sequential** | | **27** | |
| **Total with 3 engineers** | | **≈ 10** | |

---

## Cross-Workstream Dependency Map

Each AAA phase draws on one or more of the core simulation workstreams (WS-00 through
WS-11). The table below shows which workstreams must be stable before each AAA phase
can begin.

| AAA Phase | Depends on WS | Notes |
|---|---|---|
| Phase 1 (Art pipeline) | WS-11 (Graphics) | `TileAtlas`, `BuildingSpriteSelector` must exist |
| Phase 2 (Elevation) | WS-11, Phase 1 | Sprite format extension |
| Phase 3 (Camera) | WS-11, Phase 1 | `IsometricGridMapper` viewport math |
| Phase 4 (Roads) | WS-10 (Traffic), WS-02 (City), Phase 1 | Road graph must be in `City` state |
| Phase 5 (Animations) | WS-11, Phase 1 | `AnimationController` in renderer |
| Phase 6 (Rich UI) | WS-03 (Finance), WS-04 (Population), Phase 3 | Panel data from simulation subsystems |
| Phase 7 (Day/Night) | WS-01 (Sim core — tick index), Phase 1–3 | Tick index drives time-of-day |
| Phase 8 (Weather) | WS-01 (EventBus), Phase 5 | `WeatherChangedEvent` from sim |
| Phase 9 (Save/Load) | WS-02 (City model), WS-01 (tick state) | `City` and `PlaceableCityGridLayout` serialisable |
| Phase 10 (Sound) | WS-05 (UI events), Phase 7 | SFX triggers from UI + day/night state |
| Phase 11 (Tech tree) | WS-03 (Finance), WS-04 (Population), WS-02 | `City` state read per tick |
| Phase 12 (Performance) | All previous phases | Profiling requires complete feature set |

### Workstream readiness prerequisites

Before starting AAA Phase 1, confirm:
- **WS-00A/B/C** — shared interfaces, data contracts, and integration protocols complete
- **WS-01** — simulation tick loop and `EventBus` stable
- **WS-02** — `City` model, `BuildingType` enum, grid state finalised
- **WS-11** — baseline renderer (`CityRenderer`, `TileAtlas`, `ICityGridLayout`) in place

---

## Decision Gates

Each gate is a formal go/no-go checkpoint. A phase may not begin until its gate passes.

### Gate 0 — Project Kickoff
**Trigger**: Before any AAA work begins.
**Criteria**:
- [ ] WS-00A/B/C complete and `docs/specs/interfaces.md` finalised
- [ ] WS-11 baseline renderer ships (`python run.py --gui` shows a working isometric grid)
- [ ] Simulation headless run stable (no crashes over 500 ticks, seed-reproducible)
- [ ] Art direction approved (see [Concept Art Direction](#concept-art-direction) below)

### Gate 1 — Alpha Entry (before Phase 2, 3, 6, 9)
**Trigger**: Phase 1 complete.
**Criteria**:
- [ ] Full sprite atlas present; `python run.py --gui` shows real sprites (no colored diamonds)
- [ ] `tools/pack_atlas.py` runs headlessly and emits valid manifest
- [ ] All `BuildingType` values mapped to a real sprite
- [ ] Atlas load time < 100 ms verified by automated test

### Gate 2 — Alpha Exit / Beta Entry (before Phase 4, 5, 7, 10, 11)
**Trigger**: Phases 1, 2, 3, 6, 9 all complete.
**Criteria**:
- [ ] 15-minute play session without crash
- [ ] Camera pan/zoom functional; large grid navigable
- [ ] Finance and Population panels correctly reflect simulation state
- [ ] Quicksave and quickload round-trip verified (identical grid layout on reload)
- [ ] No open P1 (crash) or P2 (data-loss) bugs

### Gate 3 — Beta Exit / RC Entry (before Phase 8, 12)
**Trigger**: Phases 4, 5, 7, 10, 11 all complete.
**Criteria**:
- [ ] Roads render; at least 3 road tile variants placed successfully
- [ ] Water/smoke animations play at target frame rate
- [ ] Day/night cycle transitions visible; building windows lit at night
- [ ] Tech tree: at least 4 nodes unlock correctly; locked buildings greyed in palette
- [ ] Sound: build SFX plays within 50 ms; music cross-fades
- [ ] No P1/P2 bugs

### Gate 4 — RC Exit / v1.0 Entry (before platform submission)
**Trigger**: Phases 8, 12 complete.
**Criteria**:
- [ ] 60 fps on reference hardware (32×32 grid, all Phase 1–11 features active)
- [ ] `PerfHUD` reports ≤ 16.7 ms average frame time
- [ ] Weather deterministic: same seed → same particle positions
- [ ] Save files survive application restart (binary identical re-load)
- [ ] All targeted platforms pass smoke test
- [ ] All targeted locales render correctly (text overflow, RTL if applicable)

### Scope Trade-off Rules
If a gate is missed due to time pressure, apply these rules in order:

1. **Cut Phase 8 (Weather)** before cutting any other phase — weather is atmospheric
   only and has no simulation gameplay dependency.
2. **Defer Phase 11 (Tech tree)** scope to v1.1 if unlock conditions need extensive
   balance tuning.
3. **Never cut Phase 9 (Save/Load)** — absence of save/load blocks playtesting and is
   a hard user expectation.
4. **Never cut Phase 12 (Performance)** optimisations — frame-rate failures block
   all platform certifications.

---

## Feature Prioritization Matrix

Each feature is rated on a 1–5 scale for **Player Impact** (how much players notice/value
it) and **Implementation Effort** (relative engineering cost). The resulting quadrant
drives ordering.

```
High Impact │ Phase 3 (Camera)    Phase 1 (Art)     Phase 9 (Save/Load) │
            │ Phase 6 (UI)        Phase 11 (Tech)                        │
────────────┼───────────────────────────────────────────────────────────┤
Low Impact  │ Phase 12 (Perf)     Phase 2 (Elev)    Phase 7 (Day/Night) │
            │ Phase 5 (Anim)      Phase 4 (Roads)   Phase 8 (Weather)   │
            │ Phase 10 (Sound)                                           │
            │──────────── Low Effort ────────────── High Effort ─────────
```

| Phase | Impact (1–5) | Effort (1–5) | Quadrant | Priority |
|---|---|---|---|---|
| 1 — Art pipeline | 5 | 3 | 🟢 Quick Win+ | **P0** — prerequisite |
| 3 — Camera | 5 | 2 | 🟢 Quick Win | **P1** |
| 9 — Save/Load | 5 | 2 | 🟢 Quick Win | **P1** |
| 6 — Rich UI | 4 | 3 | 🟢 High Value | **P1** |
| 11 — Tech tree | 4 | 4 | 🟡 Strategic | **P2** |
| 2 — Elevation | 4 | 2 | 🟢 Quick Win | **P1** |
| 4 — Roads | 3 | 3 | 🟡 Strategic | **P2** |
| 7 — Day/Night | 3 | 2 | 🟢 Quick Win | **P2** |
| 5 — Animation | 3 | 3 | 🟡 Strategic | **P2** |
| 10 — Sound | 3 | 2 | 🟢 Quick Win | **P2** |
| 8 — Weather | 2 | 3 | 🔵 Nice-to-Have | **P3** |
| 12 — Performance | 2 | 3 | 🔵 Nice-to-Have | **P3 (required for cert)** |

Legend: 🟢 High Impact / Low-Medium Effort · 🟡 High Impact / High Effort · 🔵 Low Impact / Any Effort

---

## Risk Register

### R-01 — AI-generated art quality below bar
- **Probability**: Medium (3/5)
- **Impact**: High (4/5) — all visual phases depend on Phase 1 assets
- **Mitigation**: Use multiple AI generators (DALL-E 3, Midjourney, SDXL) with the
  prompts in `docs/specs/graphics.md §6`. Maintain a fallback "clean geometric" style
  that still looks intentional. Commission a human pixel artist for hero tiles if AI
  output is rejected at Gate 1.
- **Owner**: Art lead / Phase 1 engineer
- **Review at**: Gate 1

### R-02 — pygame-ce rendering bottleneck at large grid sizes
- **Probability**: Medium (3/5)
- **Impact**: High (4/5) — blocks RC certification on Phase 12
- **Mitigation**: Phase 12 dirty-tile + atlas pre-baking approach is the primary
  mitigation. If insufficient, evaluate SDL2 hardware-accelerated blitting or a
  partial migration to `pygame.sprite.LayeredDirty`. Profile early using `PerfHUD`
  from Phase 12 deliverable 12D.
- **Owner**: Performance engineer (Phase 12)
- **Review at**: Gate 3

### R-03 — Save/Load format instability across phases
- **Probability**: High (4/5) — each phase may add new serialisable fields
- **Impact**: Medium (3/5) — breaks save-file compatibility between releases
- **Mitigation**: Version-stamp every save file (`"version": 1`). Write a
  `CitySerializer.migrate(v_old, v_new, data)` migration hook from day one. Increment
  version on every format change and ship migration tests.
- **Owner**: Phase 9 engineer; all subsequent phase engineers must update version
- **Review at**: Gate 2, Gate 3, Gate 4

### R-04 — Non-determinism introduced by particle / weather systems
- **Probability**: Medium (3/5) — weather and particle phases use per-frame randomness
- **Impact**: High (4/5) — violates ADR-001 determinism contract
- **Mitigation**: All particle emitters and weather systems must be seeded via
  `RandomService`. Document in `WeatherSystem` and `AnimationController` that
  non-`RandomService` randomness is prohibited. Add a determinism regression test:
  run two identical seeds and assert identical frame output.
- **Owner**: WS-01 maintainer; Phase 5 and Phase 8 engineers
- **Review at**: Gate 3

### R-05 — Tech tree balance requires extended playtesting
- **Probability**: High (4/5) — unlock conditions and building costs are guesses
- **Impact**: Medium (3/5) — gameplay feel but not a crash
- **Mitigation**: Expose all unlock thresholds as JSON config (`tech_tree.json`)
  rather than hard-coded constants. Ship a scenario that exercises the full tree from
  tick 0. Allocate 2 weeks of balance iteration after Beta gate.
- **Owner**: Phase 11 engineer + game designer
- **Review at**: Gate 3

### R-06 — Audio licensing issues with third-party assets
- **Probability**: Low (2/5)
- **Impact**: High (4/5) — legal bloat or forced asset replacement at RC
- **Mitigation**: Use only CC0 sources (freesound.org, opengameart.org, Kenney.nl).
  Maintain `assets/audio/LICENSES.md` with source URL and licence for every file.
  Automated CI check: any new file in `assets/audio/` requires a corresponding entry
  in `LICENSES.md`.
- **Owner**: Phase 10 engineer; CI (WS-07)
- **Review at**: Gate 3

### R-07 — Scope creep from optional phases
- **Probability**: Medium (3/5)
- **Impact**: Medium (3/5) — delays v1.0 without proportional player value
- **Mitigation**: Apply the scope trade-off rules in the [Decision Gates](#decision-gates)
  section. Any feature not in the defined 12 phases requires a written scope-change
  request reviewed at the next gate.
- **Owner**: Project lead
- **Review at**: Every gate

---

## Platform & Localization Targets

### Target Platforms

| Platform | Priority | Notes |
|---|---|---|
| **Windows 10/11 (x86-64)** | P0 — primary | pygame-ce wheels available; main dev OS |
| **macOS 13+ (Apple Silicon + Intel)** | P1 | Universal binary via `pyinstaller`; test both arches |
| **Linux (Ubuntu 22.04 LTS, x86-64)** | P1 | CI pipeline runs on Linux; SDL2 deps via apt |
| **Steam Deck (SteamOS, x86-64)** | P2 | Proton compatibility; controller input if Phase 6 adds it |
| **Web (Pyodide / Emscripten)** | P3 — stretch | Evaluate at RC; pygame-ce Wasm support experimental |

### Distribution Channels
- **itch.io** (all platforms, v0.x early access) — zero cert requirements, fast turnaround
- **Steam** (v1.0) — requires Steamworks SDK integration and store page assets
- **GitHub Releases** (always) — zip bundles with bundled Python runtime via PyInstaller/Nuitka

### Localization Targets

| Locale | Priority | Script | Notes |
|---|---|---|---|
| `en-US` | P0 | Latin | Default; all strings coded in English |
| `de-DE` | P1 | Latin | Large PC gaming market; compound nouns need overflow testing |
| `fr-FR` | P1 | Latin | |
| `pt-BR` | P1 | Latin | Large emerging market |
| `zh-Hans` | P2 | CJK | Requires CJK font bundle; no RTL issues |
| `ja-JP` | P2 | CJK | |
| `ko-KR` | P2 | Hangul | |
| `ar-SA` | P3 | RTL | Requires full RTL layout pass; defer to v1.1 |

### Localization Technical Requirements
- All user-visible strings must be wrapped in `_()` from the `gettext` module.
- String extraction via `xgettext`; `.po` files in `locale/<locale>/LC_MESSAGES/`.
- Font must include full Latin, CJK, and Hangul ranges or be swapped per locale.
- Minimum font size 12 px to ensure readability at 1080p.
- German overflow test: UI panels must handle strings up to 40% longer than English.

---

## Concept Art Direction

### Visual Identity
City-Sim targets a **warm, readable isometric style** positioned between the realism of
*Cities: Skylines* and the charm of *A-Train* / *Mini Metro*:

- **Colour palette**: Saturated but not garish. Warm amber/terracotta for residential,
  cool slate/glass for commercial, muted grey/brown for industrial, vivid green for
  parks. Reference: [Lospec Palette DB — "Endesga 64"](https://lospec.com/palette-list/endesga-64).
- **Tile silhouette**: Buildings should read clearly at 64×32 px base; rooflines and
  chimneys act as immediate category signals.
- **Mood**: Optimistic daytime tone; cozy lamp-lit night scene. Avoid gritty/dystopian
  aesthetics.
- **Perspective**: Standard 2:1 isometric (26.565° elevation angle). All tiles share
  the same projection — do not mix cabinet and isometric projections.

### Art Style Reference Prompts
See `docs/specs/graphics.md §6` for the full prompt library. Core style descriptor for
all AI generation:

```
isometric city-builder game tile, warm colour palette, clean outlines,
stylised realism, 2:1 isometric perspective, 128x128 px source PNG,
transparent background, [TILE_DESCRIPTION], game-ready sprite
```

### UI Visual Language
- **HUD**: Dark translucent panels (rgba(0,0,0,160)) with white text; accent colour
  matches the tile category being shown.
- **Icons**: Kenney.nl "City Kit" icon set as baseline; custom icons for unique
  building types.
- **Typography**: [Inter](https://fonts.google.com/specimen/Inter) (OFL licence) for UI
  text; a display/headline font (e.g., [Oxanium](https://fonts.google.com/specimen/Oxanium)) for
  title screen and milestones.

---

## Marketing Narrative & Monetization

### Positioning Statement
> *City-Sim is the open-source city-builder that proves great gameplay doesn't need a
> AAA budget — just great engineering and great taste.*

Target audience: PC strategy/simulation gamers (25–40), indie game enthusiasts,
Python/open-source developer community.

### Key Differentiators
1. **Fully open-source** — every asset prompt, algorithm, and save format is documented
   and reproducible.
2. **Deterministic simulation** — share a seed; anyone can replay your city's history
   exactly.
3. **Moddable by design** — tech tree, building types, and event rules are JSON-driven
   from day one.
4. **Transparent AI asset pipeline** — every generated sprite ships with its source
   prompt (see `assets/tiles/source/`).

### Monetization Strategy (v1.0 and beyond)

| Revenue stream | When | Notes |
|---|---|---|
| **Pay-what-you-want (itch.io)** | Alpha onward | Builds community; zero friction |
| **Steam paid release (~$9.99)** | v1.0 | Standard city-builder price point for indie |
| **DLC — Scenario Packs** | v1.1+ | New maps, disasters, and scenario objectives |
| **DLC — Art Packs** | v1.1+ | Alternative tilesets (e.g., sci-fi, fantasy) |
| **OSS sponsorship (GitHub Sponsors)** | Any time | Sustains development; targets contributors |

### Minimum Marketing Milestones
- **Alpha**: Dev-log post on itch.io + Reddit r/gamedev; GIF of camera pan with real art
- **Beta**: 60-second gameplay trailer (OBS capture + light editing)
- **RC**: Steam store page live; presskit on presskit.html
- **v1.0**: Launch week: itch.io launch + Steam launch + Reddit r/games post

---

## Asset Requirements Summary

| Asset type | Format | Count | Source |
|---|---|---|---|
| Terrain tile sprites | PNG 128×128 | ~20 | AI-generated (see `docs/specs/graphics.md` §6) |
| Building sprites (3-panel) | PNG strips | ~45 | AI-generated |
| Road tile sprites | PNG 128×128 | 16 (4-bit neighbourhood) | AI-generated |
| Animated tile strips | PNG strips (4–8 frames) | ~10 | AI-generated |
| Vehicle sprites | PNG strips (4 dir × 4 frames) | 3 types | AI-generated |
| Sound effects | OGG (mono, 44.1 kHz) | ~8 | freesound.org CC0 |
| Background music | OGG (stereo, 44.1 kHz) | 3 tracks | opengameart.org CC0 |
| UI icons | PNG 32×32 | ~20 | Kenney.nl UI pack |
| Font | TTF | 1–2 | Google Fonts (Open Font Licence) |

---

## Related Documentation

- [Graphics Specification](../../specs/graphics.md) — rendering architecture and AI asset prompts
- [Workstream 11 — Graphics (base)](11-graphics.md) — baseline renderer workstream
- [Workstream 03 — Finance](03-finance.md)
- [Workstream 04 — Population](04-population.md)
- [Workstream 10 — Traffic](10-traffic.md) — road network model (input to Phase 4)
- [ADR-004 — pygame-ce rendering decision](../../adr/004-graphics-rendering.md)
