from __future__ import annotations

from queue import Queue, Empty

import pygame

from src.city.city import City
from src.city.building import Building, BuildingType
from src.shared.graphics_settings import GraphicsSettings
from src.simulation.event_bus import EventBus, Event
from src.gui.renderer.isometric_grid_mapper import IsometricGridMapper
from src.gui.renderer.tile_atlas import TileAtlas
from src.gui.renderer.building_sprite_selector import BuildingSpriteSelector
from src.gui.renderer.building_render_state import BuildingRenderState
from src.gui.renderer.ui_overlay import UIOverlay

_GRID_COLS = 8
_GRID_ROWS = 8


def _build_render_states(city: City) -> list[BuildingRenderState]:
    """
    Derive a list of :class:`BuildingRenderState` objects from current City
    infrastructure state.

    This is a pure renderer-side mapping that bridges the existing ``City``
    model (which does not yet carry explicit grid coordinates) to the
    isometric grid.  It does **not** modify any city model class.
    """
    occupied: set[tuple[int, int]] = set()
    states: list[BuildingRenderState] = []
    col = 0

    def _place(building: Building) -> None:
        nonlocal col
        pos = (col % _GRID_COLS, col // _GRID_COLS)
        states.append(BuildingRenderState(building, pos))
        occupied.add(pos)
        col += 1

    # Electricity facilities → power plant tiles
    for _ in range(city.electricity_facilities):
        _place(Building(BuildingType.CIVIC_POWER_PLANT))

    # Water facilities → hospital tiles (civic utility stand-in)
    for _ in range(city.water_facilities):
        _place(Building(BuildingType.CIVIC_HOSPITAL))

    # Housing units → residential tiles (large=20, medium=5, small=1)
    units = city.housing_units
    for _ in range(units // 20):
        _place(Building(BuildingType.RESIDENTIAL_LARGE, occupancy=20))
    for _ in range((units % 20) // 5):
        _place(Building(BuildingType.RESIDENTIAL_MEDIUM, occupancy=5))
    for _ in range(units % 5):
        _place(Building(BuildingType.RESIDENTIAL_SMALL, occupancy=1))

    # Fill remaining cells with park / grass
    for r in range(_GRID_ROWS):
        for c in range(_GRID_COLS):
            if (c, r) not in occupied:
                btype = BuildingType.PARK if (c + r) % 4 == 0 else BuildingType.EMPTY_LOT
                states.append(BuildingRenderState(Building(btype), (c, r)))

    return states


class CityRenderer:
    """
    Top-level isometric renderer.

    Reads ``City`` state and drains the ``EventBus`` queue each frame.
    Never blocks the simulation tick loop — all heavy work (asset loading,
    surface compositing) happens on the calling thread (the pygame main thread).

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
    ) -> None:
        self._city = city
        self._event_bus = event_bus
        self._settings = settings
        self._event_queue: Queue[Event] = event_bus.subscribe()
        self._mapper = IsometricGridMapper(
            settings,
            origin_x=settings.window_width // 2,
            origin_y=settings.window_height // 4,
        )
        self._atlas = TileAtlas(settings.tile_width, settings.tile_height)
        self._selector = BuildingSpriteSelector()
        self._overlay = UIOverlay()
        self._clock = pygame.time.Clock()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def render_frame(self, surface: pygame.Surface) -> None:
        """Render one frame onto *surface*."""
        surface.fill(self._BG_COLOR)

        render_states = _build_render_states(self._city)
        # Depth-sort by painter's algorithm (back tiles first)
        render_states.sort(key=lambda brs: brs.grid_position[0] + brs.grid_position[1])

        tw_half = self._settings.tile_width // 2
        for brs in render_states:
            col, row = brs.grid_position
            sprite_id = self._selector.get_sprite_id(brs.building)
            tile = self._atlas.get_tile(sprite_id)
            sx, sy = self._mapper.world_to_screen(col, row)
            surface.blit(tile, (sx - tw_half, sy))

        self._overlay.draw(surface, self._city)

    def handle_events(self, events: list) -> bool:
        """
        Process pygame events.

        Returns ``False`` when the window should close (QUIT or ESC).
        """
        for ev in events:
            if ev.type == pygame.QUIT:
                return False
            if ev.type == pygame.KEYDOWN and ev.key == pygame.K_ESCAPE:
                return False
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

        # Load atlas (generates placeholders automatically if file absent)
        self._atlas.load_atlas("assets/tiles/terrain_atlas.png")

        running = True
        while running:
            events = pygame.event.get()
            running = self.handle_events(events)
            self.render_frame(screen)
            pygame.display.flip()
            self._clock.tick(self._settings.fps_cap)

        pygame.quit()
