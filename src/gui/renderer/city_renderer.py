from __future__ import annotations

from queue import Queue
from typing import Callable

import pygame

from src.city.city import City
from src.shared.graphics_settings import GraphicsSettings
from src.simulation.event_bus import EventBus, Event
from src.gui.renderer.action_panel import ActionPanel
from src.gui.renderer.building_palette import BuildingPalette
from src.gui.renderer.city_grid_layout import ICityGridLayout, InfrastructureCityGridLayout
from src.gui.renderer.placeable_city_grid_layout import PlaceableCityGridLayout
from src.gui.renderer.isometric_grid_mapper import IsometricGridMapper
from src.gui.renderer.tile_atlas import TileAtlas
from src.gui.renderer.building_sprite_selector import BuildingSpriteSelector
from src.gui.renderer.ui_overlay import UIOverlay

_HOVER_COLOR = (255, 255, 100, 120)   # semi-transparent yellow outline


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

        # Use PlaceableCityGridLayout by default so the player can build freely.
        self._placeable_layout = PlaceableCityGridLayout()
        self._grid_layout: ICityGridLayout = (
            grid_layout if grid_layout is not None else self._placeable_layout
        )

        self._toggle_pause: Callable[[], None] = toggle_pause or (lambda: None)
        self._is_paused: Callable[[], bool] = is_paused or (lambda: False)

        # Centre the grid in the area left of the action panel.
        grid_area_w = settings.window_width - ActionPanel.PANEL_W
        self._mapper = IsometricGridMapper(
            settings,
            origin_x=grid_area_w // 2,
            origin_y=settings.window_height // 4,
        )
        self._atlas = TileAtlas(settings.tile_width, settings.tile_height)
        self._selector = BuildingSpriteSelector()
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

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def render_frame(self, surface: pygame.Surface) -> None:
        """Render one frame onto *surface*."""
        surface.fill(self._BG_COLOR)

        render_states = self._grid_layout.build_render_states(self._city)
        # Depth-sort by painter's algorithm (back tiles first)
        render_states.sort(key=lambda brs: brs.grid_position[0] + brs.grid_position[1])

        tw_half = self._settings.tile_width // 2
        for brs in render_states:
            col, row = brs.grid_position
            sprite_id = self._selector.get_sprite_id(brs.building)
            tile = self._atlas.get_tile(sprite_id)
            sx, sy = self._mapper.world_to_screen(col, row)
            surface.blit(tile, (sx - tw_half, sy))

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
                self._action_panel.handle_keydown(ev.key)

            if ev.type == pygame.MOUSEMOTION:
                self._update_hover(ev.pos)

            if ev.type == pygame.MOUSEBUTTONDOWN:
                if ev.button == 1:
                    # Panel and palette consume clicks before the grid does
                    if not self._action_panel.handle_click(ev.pos):
                        if not self._palette.handle_click(ev.pos):
                            self._handle_grid_click(ev.pos, erase=False)
                if ev.button == 3:
                    # Right-click erases
                    self._handle_grid_click(ev.pos, erase=True)

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
        """Place or erase a building at the grid tile under *screen_pos*."""
        if not isinstance(self._grid_layout, PlaceableCityGridLayout):
            return
        if self._palette.contains(screen_pos):
            return
        col, row = self._mapper.screen_to_world(*screen_pos)
        if not self._grid_layout.in_bounds(col, row):
            return
        from src.city.building import BuildingType
        btype = BuildingType.EMPTY_LOT if erase else self._palette.selected
        self._grid_layout.place_building(col, row, btype)

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

