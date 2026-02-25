from __future__ import annotations

import pygame
import pygame.freetype

from src.city.city import City


class UIOverlay:
    """
    HUD panel drawn on top of the isometric grid.

    Displays: population count, average happiness, and infrastructure counts.
    """

    _FONT_SIZE = 16
    _PADDING = 10
    _BG_COLOR = (0, 0, 0, 160)
    _TEXT_COLOR = (255, 255, 255)

    def __init__(self) -> None:
        pygame.freetype.init()
        self._font = pygame.freetype.SysFont("monospace", self._FONT_SIZE)

    def draw(self, surface: pygame.Surface, city: City) -> None:
        """Render the HUD onto *surface* using current *city* state."""
        population = len(city.population.pops)
        try:
            happiness = city.population.happiness_tracker.get_average_happiness()
        except Exception:
            happiness = 0.0

        lines = [
            f"Population : {population}",
            f"Happiness  : {happiness:.1f}",
            f"Water fac. : {city.water_facilities}",
            f"Elec. fac. : {city.electricity_facilities}",
            f"Housing    : {city.housing_units}",
        ]

        line_h = self._FONT_SIZE + 4
        panel_w = 210
        panel_h = len(lines) * line_h + self._PADDING * 2

        panel = pygame.Surface((panel_w, panel_h), pygame.SRCALPHA)
        panel.fill(self._BG_COLOR)
        surface.blit(panel, (self._PADDING, self._PADDING))

        for i, line in enumerate(lines):
            y = self._PADDING + i * line_h + self._PADDING
            self._font.render_to(
                surface,
                (self._PADDING * 2, y),
                line,
                self._TEXT_COLOR,
            )
