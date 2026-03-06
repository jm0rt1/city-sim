from __future__ import annotations

from queue import Queue

import pygame

from src.city.city import City
from src.shared.graphics_settings import GraphicsSettings
from src.simulation.event_bus import EventBus, Event
from src.gui.renderer.city_grid_layout import ICityGridLayout, InfrastructureCityGridLayout
from src.gui.renderer.isometric_grid_mapper import IsometricGridMapper
from src.gui.renderer.tile_atlas import TileAtlas
from src.gui.renderer.building_sprite_selector import BuildingSpriteSelector
from src.gui.renderer.ui_overlay import UIOverlay


class CityRenderer:
    """
    Top-level isometric renderer.

    Reads ``City`` state and drains the ``EventBus`` queue each frame.
    Never blocks the simulation tick loop — all heavy work (asset loading,
    surface compositing) happens on the calling thread (the pygame main thread).

    The layout strategy (:class:`~src.gui.renderer.city_grid_layout.ICityGridLayout`)
    is injected at construction time, making it easy to swap placement algorithms
    without modifying this class.

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
    ) -> None:
        self._city = city
        self._event_bus = event_bus
        self._settings = settings
        self._event_queue: Queue[Event] = event_bus.subscribe()
        self._grid_layout: ICityGridLayout = (
            grid_layout if grid_layout is not None else InfrastructureCityGridLayout()
        )
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

