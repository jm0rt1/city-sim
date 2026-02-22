# Graphics Specification

## Overview

This specification describes how to achieve high-quality, "good graphics" in City-Sim under the current system design. It covers the rendering architecture, required tools, existing components that need deeper consideration, and AI image-generation prompts for producing game-ready assets.

City-Sim's simulation engine is fully decoupled from the presentation layer (see [Architecture Overview](../architecture/overview.md#future-ui-architecture-considerations)). This means the rendering subsystem reads from City state and event streams rather than being embedded in simulation logic, and can be added or replaced without touching core simulation code.

---

## 1. Visual Style Target

The recommended style for City-Sim is **isometric 2D tile-based rendering**, which matches the grid-oriented City/District/Building data model and is achievable with pure Python tooling.

### Style Reference

| Property | Target value |
|---|---|
| Tile shape | Diamond isometric (2:1 width-to-height ratio) |
| Tile base size | 64 × 32 px (screen pixels) |
| Color palette | Soft, saturated "sim city" palette (see prompts below) |
| Building height | 1–4 floor stacks, each ~24 px tall |
| Art resolution | 128 × 128 px source, scaled to 64 × 32 display tile |
| Animated elements | Water shimmer, vehicle movement, smoke particles (optional) |

---

## 2. Architecture Fit

### 2.1 Data Source

The renderer consumes the existing `City` state model:

```
City
 └── districts: List[District]
       └── buildings: List[Building]
             ├── building_type: BuildingType  ← determines sprite
             ├── condition: float             ← can affect sprite variant
             └── occupancy: int               ← drives lighting effects
```

And subscribes to `EventBus` events for live updates:

- `BuildingConstructedEvent` → swap empty-lot tile for building sprite
- `BuildingDamagedEvent` → switch to crumbled/fire overlay sprite
- `TrafficUpdatedEvent` → animate vehicles along road tiles
- `WeatherChangedEvent` → overlay rain/snow particle effects

### 2.2 Rendering Pipeline

```
City State / EventBus
        ↓
  CityRenderer  ─────────────────────────────────────────────┐
        │                                                     │
  IsometricGridMapper                                         │
  (world coords → screen coords)                             │
        ↓                                                     ↓
  TileMap (tile_x, tile_y, sprite_id)         UIOverlay (HUD, charts)
        ↓                                                     │
  SpriteSheet (tile atlas image)               ←─────────────┘
        ↓
  pygame / PyQt Surface
        ↓
  Screen
```

The `CityRenderer` is a new class that implements the `IUIAdapter` contract described in the Architecture Overview. It consumes `City` state and `EventBus` events; it does **not** depend on simulation internals.

### 2.3 Coordinate Mapping

For a standard diamond isometric grid, world tile `(col, row)` maps to screen position:

```
screen_x = (col - row) * TILE_W // 2 + origin_x
screen_y = (col + row) * TILE_H // 2 + origin_y
```

Where `TILE_W = 64` and `TILE_H = 32`.

---

## 3. Required Tools

### 3.1 Core Rendering — pygame

**Package**: `pygame-ce` (Community Edition, maintained fork of pygame)  
**Version**: ≥ 2.4.0  
**Install**: `pip install pygame-ce`

**Why pygame-ce**:
- Pure Python, minimal dependencies
- Hardware-accelerated 2D surfaces via SDL2
- Built-in sprite groups, clock, and event loop
- Active maintenance, compatible with Python 3.13+

**Key usage areas**:
- `pygame.Surface` — off-screen tile compositing
- `pygame.sprite.LayeredUpdates` — depth-sorted rendering for isometric buildings
- `pygame.transform.scale` / `smoothscale` — tile scaling
- `pygame.time.Clock` — deterministic frame timing

### 3.2 Image Loading & Processing — Pillow

**Package**: `Pillow`  
**Version**: ≥ 10.0.0  
**Install**: `pip install Pillow`

**Why Pillow**:
- Load AI-generated PNG/WEBP/PSD source assets
- Pack individual tiles into a sprite sheet atlas
- Resize and convert to the 64 × 32 isometric format
- Apply palette-normalization before runtime loading

### 3.3 Tile Map Editor — Tiled

**Tool**: [Tiled Map Editor](https://www.mapeditor.org/) (desktop app, free/open source)  
**File format**: `.tmx` (XML) or `.tmj` (JSON)  
**Python reader**: `pytmx` (`pip install pytmx`)

**Why Tiled**:
- Visual tile placement and layer management
- Export tileset and map data as JSON consumed directly by `CityRenderer`
- Defines walkable/non-walkable tiles used by the Transport subsystem pathfinder
- Can be used to author the initial "empty city" background map

### 3.4 Asset Pipeline Automation — Sprite Sheet Packer

**Package**: `spritesheet-packer` or manual Pillow script  
**Purpose**: Combine all individual AI-generated tile PNGs into a single atlas texture

**Recommended atlas layout**:

```
terrain_atlas.png
 ├── row 0: grass variants (0–7)
 ├── row 1: road types (straight H/V, turns, T/X junctions) (0–7)
 ├── row 2: water / river tiles (0–7)
 └── row 3: sandy/dirt transition tiles (0–7)

buildings_atlas.png
 ├── row 0: residential small (1–4 floors)
 ├── row 1: residential medium (1–4 floors)
 ├── row 2: commercial (1–4 floors)
 ├── row 3: industrial (1–4 floors)
 └── row 4: civic / public buildings
```

### 3.5 Font Rendering — pygame.font / pygame.freetype

Already bundled with pygame. Use `pygame.freetype.Font` for crisp HUD text at arbitrary sizes.

---

## 4. Existing Components Needing Deeper Consideration

### 4.1 EventBus

The `EventBus` is the primary communication bridge between simulation and renderer. Currently documented as conceptual. For graphics it must:

- Support **synchronous fan-out** to registered UI listeners without blocking the tick loop
- Deliver events on the **main thread** (pygame requires all surface operations on the thread that called `pygame.init()`)
- Implement **event buffering**: the simulation runs at its own tick rate; the renderer runs at the display frame rate (e.g. 60 fps). Events must be buffered and drained per render frame.

**Recommended pattern**: The renderer registers a `Queue`-backed listener. The simulation pushes events to the queue at tick time; the renderer drains the queue each frame.

### 4.2 City State Serialization

`City.to_dict()` (planned) is used by the renderer to take a full snapshot for initial render or replay. This must:

- Include `District → Building → building_type, condition, occupancy` hierarchy
- Include `RoadGraph` node/edge data for road tile placement
- Serialize in a format that maps directly to tile coordinates

### 4.3 TickContext / Frame Rate Decoupling

The simulation tick rate and render frame rate are independent. The renderer must not block on tick completion and must interpolate positions for smooth vehicle animation. Consider:

- Storing previous and current vehicle positions per tick
- Lerping between them over the inter-tick interval at render time

### 4.4 RandomService (for Procedural Decoration)

Grass dithering, tree placement, and decorative variance (cracked road variants, window-light randomness) should use `RandomService` with a dedicated seed so the visual layout is deterministic and reproducible given the same seed.

### 4.5 District/Building Grid Coordinates

Currently `District` and `Building` do not have explicit (col, row) grid coordinates. For rendering, each building needs a `grid_position: tuple[int, int]`. The preferred approach is a **renderer-side `BuildingRenderState` wrapper** that associates a `Building` with its grid position without modifying the core data model. This keeps the simulation model free of rendering concerns and avoids breaking existing simulation code.

---

## 5. Rendering Architecture Classes

```python
# New module: src/gui/renderer/

class CityRenderer:
    """Top-level renderer. Subscribes to EventBus, reads City state."""
    def __init__(self, city: City, event_bus: EventBus, settings: GraphicsSettings): ...
    def render_frame(self, surface: pygame.Surface): ...
    def handle_events(self, events: List[Event]): ...

class IsometricGridMapper:
    """Converts world (col, row) to screen (x, y)."""
    def world_to_screen(self, col: int, row: int) -> tuple[int, int]: ...
    def screen_to_world(self, x: int, y: int) -> tuple[int, int]: ...

class TileAtlas:
    """Manages sprite sheets and tile lookup."""
    def get_tile(self, tile_id: str) -> pygame.Surface: ...
    def load_atlas(self, path: str): ...

class BuildingSpriteSelector:
    """Maps BuildingType + condition + occupancy → sprite id."""
    def get_sprite_id(self, building: Building) -> str: ...

class UIOverlay:
    """HUD: budget bar, population counter, happiness indicator."""
    def draw(self, surface: pygame.Surface, city: City): ...

class GraphicsSettings:
    """Configuration for the renderer."""
    tile_width: int = 64
    tile_height: int = 32
    window_width: int = 1280
    window_height: int = 720
    fps_cap: int = 60
    fullscreen: bool = False
    vsync: bool = True
```

---

## 6. AI Image-Generation Prompts

The following prompts can be used with image-generation AI tools (e.g. Midjourney, DALL-E, Stable Diffusion, Adobe Firefly) to produce game-ready tile graphics.

### 6.1 General Style Prefix

Prefix each prompt below with this style block for consistency:

```
Isometric pixel-art style, 64x32 tile, isometric three-quarter view,
clean crisp edges, soft warm color palette, city builder game, no background,
transparent background PNG, 2D sprite, game asset, consistent lighting from
upper-left at 45 degrees, slight shadow on right and bottom faces
```

### 6.2 Terrain Tiles

**Grass base tile:**
```
[STYLE PREFIX] lush green grass tile, flat ground, subtle texture variation,
single isometric diamond tile
```

**Road — straight horizontal:**
```
[STYLE PREFIX] paved asphalt road tile, white center line, horizontal direction,
flat surface, clean lane markings, city road, two-lane road
```

**Road — straight vertical:**
```
[STYLE PREFIX] paved asphalt road tile, white center line, road running from
top-left to bottom-right of the isometric diamond (perpendicular to the
horizontal variant), flat surface, clean lane markings, city road, two-lane road
```

**Road — 4-way intersection:**
```
[STYLE PREFIX] four-way asphalt road intersection tile, crosswalk markings on all four sides,
stop lines, flat top-down view adapted to isometric diamond, city road intersection
```

**Water / river:**
```
[STYLE PREFIX] calm blue water tile, gentle ripple texture, isometric diamond,
river section, subtle shimmer, no waves, city sim water tile
```

**Park / green space:**
```
[STYLE PREFIX] manicured park grass tile, small decorative flowers, trimmed hedges at edges,
flat isometric ground tile, urban park section
```

### 6.3 Building Sprites

**Small residential house (1 floor):**
```
[STYLE PREFIX] small single-story residential house, red-orange roof, cream walls,
front door visible, small windows, isometric building sprite, suburban home,
no background, full building visible from isometric angle
```

**Medium apartment block (3 floors):**
```
[STYLE PREFIX] three-story apartment building, flat roof, light gray facade,
grid of windows with warm interior light, small balconies, isometric building,
city apartment block, medium density residential
```

**Commercial shop (2 floors):**
```
[STYLE PREFIX] two-story commercial shop, large ground floor display window,
colorful storefront awning, signage area, isometric building, city main street shop,
retail building sprite
```

**Office tower (8 floors):**
```
[STYLE PREFIX] tall office tower, glass curtain wall facade, modern architecture,
dark glass windows with interior glow, isometric high-rise sprite, 8 floors visible,
city center office building, no background
```

**Industrial warehouse:**
```
[STYLE PREFIX] large industrial warehouse building, corrugated metal siding,
loading dock door, flat roof with rooftop vent, isometric factory building,
industrial zone, gray and rust tones, no background
```

**Civic — city hall:**
```
[STYLE PREFIX] grand city hall building, neoclassical facade, large columns,
dome or pitched roof, wide steps at entrance, isometric civic building,
government building sprite, beige stone exterior
```

**Hospital:**
```
[STYLE PREFIX] modern hospital building, white exterior, red cross sign on roof,
large windows, multi-wing structure, isometric medical building sprite,
emergency entrance visible, clean clinical design
```

**School / university:**
```
[STYLE PREFIX] two-story school building, brick exterior, tall arched windows,
clock tower element, courtyard entrance, isometric educational building sprite,
academic architecture, warm brick tones
```

**Fire station:**
```
[STYLE PREFIX] red fire station building, large vehicle bay doors, tower element,
brick facade, American flag detail, isometric civic building sprite,
emergency services station
```

**Police station:**
```
[STYLE PREFIX] police station building, institutional architecture, flag pole,
blue and white color scheme, secure entrance, isometric government building sprite,
law enforcement facility
```

**Power plant:**
```
[STYLE PREFIX] power plant building, two large cooling towers emitting steam,
industrial infrastructure, large structure, isometric sprite, utility building,
gray concrete and metal, energy generation facility
```

**Park pavilion / bandstand:**
```
[STYLE PREFIX] ornate park pavilion, Victorian-style gazebo, white wooden structure,
peaked roof with decorative trim, open sides, isometric civic amenity sprite,
public park feature, green copper or white finish
```

### 6.4 Road Infrastructure

**Traffic signal (standalone prop):**
```
[STYLE PREFIX] standalone traffic light on pole, three-light signal head,
isometric prop sprite, city street furniture, no background,
green/amber/red lights, urban intersection equipment
```

**Street lamp:**
```
[STYLE PREFIX] classic street lamp post, warm amber glow halo, cast iron pole,
ornate lantern head, isometric prop, nighttime glow effect, urban street furniture
```

**Bus stop shelter:**
```
[STYLE PREFIX] modern bus stop shelter, clear glass panels, roof overhang,
bench inside, route sign, isometric street furniture sprite, urban transit
```

### 6.5 Natural Elements

**Deciduous tree:**
```
[STYLE PREFIX] full leafy deciduous tree, round canopy, green summer leaves,
isometric sprite, park tree, city tree, slight cast shadow, medium size
```

**Pine / evergreen tree:**
```
[STYLE PREFIX] tall pine tree, conical shape, dark green needles, pointed top,
isometric sprite, park conifer, forest edge tree
```

### 6.6 Overlay / Effect Sprites

**Fire overlay:**
```
[STYLE PREFIX] flame and smoke overlay sprite, orange-red fire, dark smoke,
transparent background, building damage overlay, city disaster effect, no outlines
```

**Construction scaffold:**
```
[STYLE PREFIX] construction scaffolding overlay, metal poles and platforms,
orange safety netting, under construction effect, isometric overlay sprite,
building under construction, transparent background
```

### 6.7 Complete Tileset Sheet — Single Generation Prompt

Use this prompt to request a **complete tiled sprite sheet** from an AI image generator in a single pass:

```
A complete isometric city-builder game sprite sheet on a single image, white
or transparent background, organized as a grid of tiles. Each tile is 128x128
pixels in source resolution. Include the following rows of tiles:

Row 1 (Terrain): grass plain, road straight H, road straight V, road bend NE,
road bend SE, road T-junction N, road 4-way intersection, water tile

Row 2 (Residential buildings): 1-story house, 2-story house, 3-story apartment,
4-story apartment, small condo block, townhouse row, detached villa, 
abandoned/ruined house

Row 3 (Commercial buildings): small shop 1-story, cafe 2-story, retail 2-story,
supermarket 1-story wide, office 4-story, office 6-story, office tower 10-story,
shopping mall entrance

Row 4 (Industrial buildings): small factory, medium factory, warehouse, 
power plant (cooling towers), water treatment plant, waste facility,
construction site (in-progress), cleared land / empty lot

Row 5 (Civic buildings): city hall, police station, fire station, hospital,
school, library, park pavilion, stadium

Row 6 (Props & overlays): deciduous tree, pine tree, street lamp, traffic light,
bus stop, park bench, fire overlay, construction scaffold

Isometric perspective, consistent 45-degree lighting from upper-left, soft warm
colors, clean pixel art style, clear tile boundaries, no text labels on tiles,
suitable for a city simulation game, professional quality game asset sheet
```

---

## 7. Implementation Checklist

- [ ] Add `pygame-ce` and `Pillow` to `requirements.txt`
- [ ] Add `pytmx` to `requirements.txt` (for Tiled map file loading)
- [ ] Create `src/gui/renderer/` package with classes from Section 5
- [ ] Create `BuildingRenderState` wrapper in `src/gui/renderer/` that associates each `Building` with its `grid_position: tuple[int, int]` (do not modify core `Building` class)
- [ ] Extend `EventBus` with buffered queue support for renderer thread safety
- [ ] Implement `GraphicsSettings` in `src/shared/settings.py` or as a separate config
- [ ] Generate AI assets using prompts in Section 6 and pack into atlases using Pillow
- [ ] Author the base map in Tiled and export as `.tmj`
- [ ] Wire `CityRenderer` into the main loop in `run.py` (optional flag `--gui`)
- [ ] Add `docs/adr/003-graphics-rendering.md` capturing pygame-ce choice

---

## 8. Acceptance Criteria

- Simulation runs headlessly with no graphical dependencies when `--gui` flag is absent
- Renderer reads only from `City` state and `EventBus`; zero imports from simulation core
- All visual randomness (tile dithering, decoration) goes through `RandomService` with a fixed seed, making visual output deterministic
- Frame rate is decoupled from tick rate; simulation speed is unaffected by renderer
- Tileset atlas loads in < 100 ms on startup
- All building types in `BuildingType` have a corresponding sprite in the atlas

---

## Related Documentation

- [Architecture Overview — Future UI Architecture](../architecture/overview.md#future-ui-architecture-considerations)
- [Class Hierarchy — UI & Reporting](../architecture/class-hierarchy.md#ui--reporting)
- [Workstream 05 — UI](../design/workstreams/05-ui.md)
- [Workstream 11 — Graphics](../design/workstreams/11-graphics.md)
- [City Specification](city.md) — Building and District data model
- [Traffic Specification](traffic.md) — Road network for road tile placement
- [ADR-002 — Free-Threaded Python](../adr/002-free-threaded-python.md) — threading considerations for renderer
