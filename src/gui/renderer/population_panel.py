from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from src.city.city import City

try:
    import pygame
    import pygame.freetype
    _HAS_PYGAME = True
except ImportError:  # pragma: no cover
    _HAS_PYGAME = False


class PopulationPanel:
    """
    Top-left HUD panel showing population, happiness, and infrastructure.

    Replaces the original :class:`~src.gui.renderer.ui_overlay.UIOverlay`.

    Shows:
    * Population count with a trend arrow (↑ / ↓ / →).
    * Happiness score, colour-coded:
      - green  ≥ 70
      - amber  ≥ 40
      - red    < 40
    * Water facilities, electricity facilities, housing units.

    The font is lazy-initialised in :meth:`draw` so the class can be
    constructed without a pygame display.

    Args:
        x: Left edge of the panel in screen pixels (default 10).
        y: Top edge of the panel in screen pixels (default 10).
    """

    _FONT_SIZE: int = 15
    _PADDING: int = 10
    _BG_COLOR: tuple[int, int, int, int] = (0, 0, 0, 160)
    _TEXT_COLOR: tuple[int, int, int] = (255, 255, 255)
    _COLOR_GREEN: tuple[int, int, int] = (80, 220, 80)
    _COLOR_AMBER: tuple[int, int, int] = (255, 200, 60)
    _COLOR_RED: tuple[int, int, int] = (220, 80, 80)

    def __init__(self, x: int = 10, y: int = 10) -> None:
        self._x = x
        self._y = y
        self._font: object | None = None
        self._prev_population: int | None = None

    # ------------------------------------------------------------------
    # Rendering (requires pygame)
    # ------------------------------------------------------------------

    def draw(self, surface: object, city: City) -> None:
        """Render the population HUD onto *surface* using current *city* state.

        Args:
            surface: A ``pygame.Surface`` to draw on.
            city: Current city state.
        """
        if not _HAS_PYGAME:
            return  # pragma: no cover

        import pygame  # type: ignore[import]
        import pygame.freetype  # type: ignore[import]

        surf = surface  # type: pygame.Surface

        if self._font is None:
            pygame.freetype.init()
            self._font = pygame.freetype.SysFont("monospace", self._FONT_SIZE)

        font = self._font  # type: ignore[assignment]

        population = len(city.population.pops)
        try:
            happiness = city.population.happiness_tracker.get_average_happiness()
        except Exception:
            happiness = 0.0

        # Trend arrow
        if self._prev_population is None:
            trend = "→"
        elif population > self._prev_population:
            trend = "↑"
        elif population < self._prev_population:
            trend = "↓"
        else:
            trend = "→"
        self._prev_population = population

        # Happiness colour
        if happiness >= 70:
            hap_color = self._COLOR_GREEN
        elif happiness >= 40:
            hap_color = self._COLOR_AMBER
        else:
            hap_color = self._COLOR_RED

        # Build lines: (text, color)
        lines: list[tuple[str, tuple[int, int, int]]] = [
            (f"Pop        : {population} {trend}", self._TEXT_COLOR),
            (f"Happiness  : {happiness:.1f}", hap_color),
            (f"Water fac. : {city.water_facilities}", self._TEXT_COLOR),
            (f"Elec. fac. : {city.electricity_facilities}", self._TEXT_COLOR),
            (f"Housing    : {city.housing_units}", self._TEXT_COLOR),
        ]

        line_h = self._FONT_SIZE + 4
        panel_w = 220
        panel_h = len(lines) * line_h + self._PADDING * 2

        panel = pygame.Surface((panel_w, panel_h), pygame.SRCALPHA)
        panel.fill(self._BG_COLOR)
        surf.blit(panel, (self._x, self._y))

        for i, (text, color) in enumerate(lines):
            txt_y = self._y + self._PADDING + i * line_h
            font.render_to(surf, (self._x + self._PADDING, txt_y), text, color)
