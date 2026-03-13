from __future__ import annotations

from queue import Queue
from typing import Callable

import pygame

from src.city.building import Building, BuildingType
from src.city.city import City
from src.shared.graphics_settings import GraphicsSettings
from src.simulation.event_bus import EventBus, Event
from src.gui.renderer.action_panel import ActionPanel
from src.gui.renderer.building_palette import BuildingPalette, ROAD_TOOL
from src.gui.renderer.camera_controller import CameraController
from src.gui.renderer.city_grid_layout import ICityGridLayout, InfrastructureCityGridLayout
from src.gui.renderer.elevated_building_blit import ElevatedBuildingBlit, FLOOR_H
from src.gui.renderer.placeable_city_grid_layout import PlaceableCityGridLayout
from src.gui.renderer.isometric_grid_mapper import IsometricGridMapper
from src.gui.renderer.road_tile_selector import RoadTileSelector
from src.gui.renderer.tile_atlas import TileAtlas
from src.gui.renderer.building_render_state import BuildingRenderState
from src.gui.renderer.building_sprite_selector import BuildingSpriteSelector
from src.gui.renderer.ui_overlay import UIOverlay

_HOVER_COLOR = (255, 255, 100, 120)   # semi-transparent yellow outline
_SHADOW_ALPHA = 102  # ~40 % of 255

# Building types that represent empty terrain (no visible structure).
# Used in render_frame to filter terrain tiles covered by road segments.
_TERRAIN_BUILDING_TYPES: frozenset[BuildingType] = frozenset({
    BuildingType.PARK,
    BuildingType.EMPTY_LOT,
})

# Default grid size matching City.road_network and PlaceableCityGridLayout defaults.
_DEFAULT_GRID_SIZE: int = 32


class CityRenderer:
    """
    Top-level isometric renderer.

    Reads ``City`` state and drains the ``EventBus`` queue each frame.
    Never blocks the simulation tick loop — all heavy work (asset loading,
    surface compositing) happens on the calling thread (the pygame main thread).

    **Build mode** — the player selects a building type from the bottom palette
    bar and left-clicks any tile on the grid to place it.  The grid is owned by
    a :class:`~src.gui.renderer.placeable_city_grid_layout.PlaceableCityGridLayout`
    so placements persist across frames.  Right-click erases a tile.

    The layout strategy (:class:`~src.gui.renderer.city_grid_layout.ICityGridLayout`)
    is injected at construction time, making it easy to swap placement algorithms
    without modifying this class.

    Keyboard shortcuts (always active):

    * **W** — add 1 water facility
    * **E** — add 1 electricity facility
    * **H** — add 10 housing units
    * **P** — pause / resume auto-advance
    * **Arrow keys** — pan camera
    * **0** — reset camera
    * **F** — frame (fit) entire city on screen
    * **Esc** — close window

    Usage::

        renderer = CityRenderer(city, event_bus, settings)
        renderer.run()   # blocking pygame loop; returns when window is closed
    """

    _BG_COLOR = (40, 44, 52)

    def __init__(
        self,
        city: City,
        event_bus: EventBus,
        settings: GraphicsSettings,
        grid_layout: ICityGridLayout | None = None,
        toggle_pause: Callable[[], None] | None = None,
        is_paused: Callable[[], bool] | None = None,
    ) -> None:
        self._city = city
        self._event_bus = event_bus
        self._settings = settings
        self._event_queue: Queue[Event] = event_bus.subscribe()

        # Use PlaceableCityGridLayout with 32×32 grid by default.
        self._placeable_layout = PlaceableCityGridLayout(cols=32, rows=32)
        self._grid_layout: ICityGridLayout = (
            grid_layout if grid_layout is not None else self._placeable_layout
        )

        self._toggle_pause: Callable[[], None] = toggle_pause or (lambda: None)
        self._is_paused: Callable[[], bool] = is_paused or (lambda: False)

        # Camera controller for pan/zoom
        grid_area_w = settings.window_width - ActionPanel.PANEL_W
        self._camera = CameraController(
            origin_x=grid_area_w // 2,
            origin_y=settings.window_height // 4,
        )
        self._mapper = IsometricGridMapper(
            settings,
            origin_x=grid_area_w // 2,
            origin_y=settings.window_height // 4,
            camera=self._camera,
        )
        self._atlas = TileAtlas(settings.tile_width, settings.tile_height)
        self._selector = BuildingSpriteSelector()
        self._road_selector = RoadTileSelector()
        self._elevated_blit = ElevatedBuildingBlit()
        self._overlay = UIOverlay()
        self._palette = BuildingPalette(
            screen_w=grid_area_w,
            screen_h=settings.window_height,
            atlas=self._atlas,
        )
        self._action_panel = ActionPanel(
            x=settings.window_width - ActionPanel.PANEL_W,
            y=0,
            actions={
                "add_water":    lambda: self._city.add_water_facilities(1),
                "add_elec":     lambda: self._city.add_electricity_facilities(1),
                "add_housing":  lambda: self._city.add_housing_units(10),
                "toggle_pause": self._toggle_pause,
            },
            is_paused=self._is_paused,
        )
        self._clock = pygame.time.Clock()
        # Hovered tile (col, row) or None
        self._hovered_tile: tuple[int, int] | None = None
        # Middle-mouse pan tracking
        self._mid_dragging = False
        self._mid_last: tuple[int, int] = (0, 0)

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def render_frame(self, surface: pygame.Surface) -> None:
        """Render one frame onto *surface*."""
        surface.fill(self._BG_COLOR)

        win_w = self._settings.window_width
        win_h = self._settings.window_height
        tw = self._settings.tile_width
        th = self._settings.tile_height

        render_states = self._grid_layout.build_render_states(self._city)

        # Remove terrain tiles that are covered by a road so the road tile
        # renders in their place.
        road_network = getattr(self._city, "road_network", None)
        if road_network is not None:
            render_states = [
                brs for brs in render_states
                if not (
                    brs.road_sprite_id is None
                    and brs.building.building_type in _TERRAIN_BUILDING_TYPES
                    and road_network.is_road(*brs.grid_position)
                )
            ]
            # Add road render states for every road cell in the grid.
            cols = rows = _DEFAULT_GRID_SIZE
            if isinstance(self._grid_layout, PlaceableCityGridLayout):
                cols = self._grid_layout.cols
                rows = self._grid_layout.rows
            for r in range(rows):
                for c in range(cols):
                    if road_network.is_road(c, r):
                        nb = road_network.get_neighbours(c, r)
                        road_sid = self._road_selector.get_sprite_id(
                            nb["N"], nb["E"], nb["S"], nb["W"]
                        )
                        road_brs = BuildingRenderState(
                            building=Building(BuildingType.EMPTY_LOT),
                            grid_position=(c, r),
                            height_tiles=1,
                            road_sprite_id=road_sid,
                        )
                        render_states.append(road_brs)

        # Assign height_tiles from atlas manifest for non-road tiles.
        for brs in render_states:
            if brs.road_sprite_id is None:
                sprite_id = self._selector.get_sprite_id(brs.building)
                brs.height_tiles = self._atlas.get_height_tiles(sprite_id)

        # Depth-sort by painter's algorithm (back tiles first).
        # Roads sort at col+row-0.5 (below buildings at same cell).
        # Taller buildings in the same row render after shorter ones.
        render_states.sort(
            key=lambda brs: (
                brs.grid_position[0] + brs.grid_position[1]
                + (-0.5 if brs.road_sprite_id else 0.0),
                -brs.height_tiles,
            )
        )

        tw_half = tw // 2
        z = self._camera.zoom_level
        scaled_tw = int(tw * z)
        scaled_th = int(th * z)

        for brs in render_states:
            col, row = brs.grid_position
            # Road tiles use their pre-computed road_sprite_id; others use selector.
            if brs.road_sprite_id is not None:
                sprite_id = brs.road_sprite_id
            else:
                sprite_id = self._selector.get_sprite_id(brs.building)
            tile = self._atlas.get_tile(sprite_id)
            sx, sy = self._mapper.world_to_screen(col, row)
            blit_x = sx - int(tw_half * z)

            # Off-screen culling
            elevation_offset = (brs.height_tiles - 1) * FLOOR_H
            top_y = sy - elevation_offset
            if (blit_x + scaled_tw < 0 or blit_x > win_w
                    or top_y + scaled_th < 0 or sy > win_h):
                continue

            # Scale tile for zoom
            if z != 1.0:
                tile = pygame.transform.smoothscale(tile, (scaled_tw, scaled_th))

            # Soft shadow under elevated buildings
            if brs.height_tiles > 1:
                shadow_w = scaled_tw
                shadow_h = max(1, scaled_th // 2)
                shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
                pygame.draw.ellipse(shadow_surf, (0, 0, 0, _SHADOW_ALPHA),
                                    (0, 0, shadow_w, shadow_h))
                surface.blit(shadow_surf, (blit_x, sy + scaled_th // 4))

            # Blit building with elevation offset
            self._elevated_blit.blit(
                surface, tile, blit_x, sy,
                height_tiles=brs.height_tiles,
            )

            # Hover highlight — yellow diamond outline over the hovered tile
            if self._hovered_tile == (col, row):
                self._draw_hover(surface, sx, sy)

        self._overlay.draw(surface, self._city)
        self._action_panel.draw(surface)
        self._palette.draw(surface)

    def handle_events(self, events: list) -> bool:
        """
        Process pygame events.

        Returns ``False`` when the window should close (QUIT or ESC).
        """
        for ev in events:
            if ev.type == pygame.QUIT:
                return False

            if ev.type == pygame.KEYDOWN:
                if ev.key == pygame.K_ESCAPE:
                    return False
                if ev.key == pygame.K_0:
                    self._camera.reset()
                    continue
                if ev.key == pygame.K_f:
                    cols = rows = 32
                    if isinstance(self._grid_layout, PlaceableCityGridLayout):
                        cols = self._grid_layout.cols
                        rows = self._grid_layout.rows
                    self._camera.frame_city(
                        cols, rows,
                        self._settings.window_width,
                        self._settings.window_height,
                        self._settings.tile_width,
                        self._settings.tile_height,
                    )
                    continue
                self._action_panel.handle_keydown(ev.key)

            if ev.type == pygame.MOUSEMOTION:
                self._update_hover(ev.pos)
                # Middle-mouse drag panning
                if self._mid_dragging:
                    dx = ev.pos[0] - self._mid_last[0]
                    dy = ev.pos[1] - self._mid_last[1]
                    self._camera.pan(dx, dy)
                    self._mid_last = ev.pos

            if ev.type == pygame.MOUSEBUTTONDOWN:
                if ev.button == 2:  # middle mouse
                    self._mid_dragging = True
                    self._mid_last = ev.pos
                elif ev.button == 1:
                    # Panel and palette consume clicks before the grid does
                    if not self._action_panel.handle_click(ev.pos):
                        if not self._palette.handle_click(ev.pos):
                            self._handle_grid_click(ev.pos, erase=False)
                elif ev.button == 3:
                    # Right-click erases
                    self._handle_grid_click(ev.pos, erase=True)
                elif ev.button == 4:  # scroll up
                    self._camera.zoom(1.1)
                elif ev.button == 5:  # scroll down
                    self._camera.zoom(0.9)

            if ev.type == pygame.MOUSEBUTTONUP:
                if ev.button == 2:
                    self._mid_dragging = False

            if ev.type == pygame.MOUSEWHEEL:
                if ev.y > 0:
                    self._camera.zoom(1.1)
                elif ev.y < 0:
                    self._camera.zoom(0.9)

        # Arrow key held-down panning
        keys = pygame.key.get_pressed()
        if keys[pygame.K_LEFT]:
            self._camera.pan(8, 0)
        if keys[pygame.K_RIGHT]:
            self._camera.pan(-8, 0)
        if keys[pygame.K_UP]:
            self._camera.pan(0, 8)
        if keys[pygame.K_DOWN]:
            self._camera.pan(0, -8)

        return True

    def run(self) -> None:
        """
        Blocking pygame main loop.  Must be called from the main thread.

        Returns when the user closes the window or presses ESC.
        """
        pygame.init()
        flags = pygame.FULLSCREEN if self._settings.fullscreen else 0
        screen = pygame.display.set_mode(
            (self._settings.window_width, self._settings.window_height),
            flags | pygame.DOUBLEBUF,
        )
        pygame.display.set_caption("City-Sim")

        # Load atlas from manifest (falls back to procedural diamonds if absent)
        self._atlas.load_manifest("assets/tiles/atlas_manifest.json")

        running = True
        while running:
            events = pygame.event.get()
            running = self.handle_events(events)
            self.render_frame(screen)
            pygame.display.flip()
            self._clock.tick(self._settings.fps_cap)

        pygame.quit()

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _update_hover(self, screen_pos: tuple[int, int]) -> None:
        """Update the hovered-tile tracker from the current mouse position."""
        if self._palette.contains(screen_pos):
            self._hovered_tile = None
            return
        col, row = self._mapper.screen_to_world(*screen_pos)
        if isinstance(self._grid_layout, PlaceableCityGridLayout):
            if self._grid_layout.in_bounds(col, row):
                self._hovered_tile = (col, row)
                return
        self._hovered_tile = None

    def _handle_grid_click(
        self,
        screen_pos: tuple[int, int],
        erase: bool,
    ) -> None:
        """Place or erase a building/road at the grid tile under *screen_pos*."""
        if not isinstance(self._grid_layout, PlaceableCityGridLayout):
            return
        if self._palette.contains(screen_pos):
            return
        col, row = self._mapper.screen_to_world(*screen_pos)
        if not self._grid_layout.in_bounds(col, row):
            return

        selected = self._palette.selected
        road_network = getattr(self._city, "road_network", None)

        if erase:
            if selected == ROAD_TOOL and road_network is not None:
                road_network.remove_road(col, row)
            else:
                self._grid_layout.place_building(col, row, BuildingType.EMPTY_LOT)
        else:
            if selected == ROAD_TOOL and road_network is not None:
                road_network.place_road(col, row)
            else:
                assert isinstance(selected, BuildingType), (
                    f"expected BuildingType, got {selected!r}"
                )
                self._grid_layout.place_building(col, row, selected)

    def _draw_hover(
        self, surface: pygame.Surface, sx: int, sy: int
    ) -> None:
        """Draw a semi-transparent yellow diamond outline at tile screen position."""
        w = self._settings.tile_width
        h = self._settings.tile_height
        points = [
            (sx,           sy),
            (sx + w // 2,  sy + h // 2),
            (sx,           sy + h),
            (sx - w // 2,  sy + h // 2),
        ]
        hover_surf = pygame.Surface((w, h * 2), pygame.SRCALPHA)
        hover_surf.fill((0, 0, 0, 0))
        adj = [(p[0] - (sx - w // 2), p[1] - sy) for p in points]
        pygame.draw.polygon(hover_surf, _HOVER_COLOR, adj)
        surface.blit(hover_surf, (sx - w // 2, sy))

