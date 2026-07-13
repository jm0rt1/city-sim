from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from src.city.finance import CityBudget

try:
    import pygame
    import pygame.freetype
    _HAS_PYGAME = True
except ImportError:  # pragma: no cover
    _HAS_PYGAME = False


class FinancePanel:
    """
    Right-sidebar finance overlay drawn below the ActionPanel button area.

    Shows the current budget balance as a large number (green ≥ 0, red < 0)
    and two rows of bar charts for the last 20 ticks of revenue (green) and
    expenses (red).

    Font is lazy-initialised in :meth:`draw` so the class can be constructed
    without a pygame display (matching the ActionPanel pattern).

    Args:
        x: Left edge of the panel (pixels from left of screen).
        y: Top edge of the panel (pixels from top of screen).
        width: Panel width in pixels (defaults to :data:`PANEL_W`).
    """

    PANEL_W: int = 220

    _FONT_SIZE_LARGE: int = 22
    _FONT_SIZE_SMALL: int = 12
    _PADDING: int = 8
    _BAR_H: int = 30
    _BAR_SECTION_H: int = 48
    _BG_COLOR: tuple[int, int, int, int] = (20, 20, 30, 200)
    _COLOR_TITLE: tuple[int, int, int] = (180, 180, 255)
    _COLOR_POSITIVE: tuple[int, int, int] = (80, 220, 80)
    _COLOR_NEGATIVE: tuple[int, int, int] = (220, 80, 80)
    _COLOR_REVENUE: tuple[int, int, int] = (80, 200, 80)
    _COLOR_EXPENSE: tuple[int, int, int] = (200, 80, 80)
    _COLOR_LABEL: tuple[int, int, int] = (160, 160, 180)

    def __init__(self, x: int, y: int, width: int = PANEL_W) -> None:
        self._x = x
        self._y = y
        self._width = width
        self._font_large: object | None = None
        self._font_small: object | None = None

    # ------------------------------------------------------------------
    # Rendering (requires pygame)
    # ------------------------------------------------------------------

    def draw(
        self,
        surface: object,
        budget: CityBudget,
        history: list[tuple[float, float, float]],
    ) -> None:
        """Render the finance panel onto *surface*.

        Args:
            surface: A ``pygame.Surface`` to draw on.
            budget: Current :class:`~src.city.finance.CityBudget` instance.
            history: List of ``(revenue, expenses, balance)`` tuples
                     (last 20 ticks); may be empty.
        """
        if not _HAS_PYGAME:
            return  # pragma: no cover

        import pygame  # type: ignore[import]
        import pygame.freetype  # type: ignore[import]

        surf = surface  # type: pygame.Surface

        if self._font_large is None:
            pygame.freetype.init()
            self._font_large = pygame.freetype.SysFont("monospace", self._FONT_SIZE_LARGE)
            self._font_small = pygame.freetype.SysFont("monospace", self._FONT_SIZE_SMALL)

        font_large = self._font_large  # type: ignore[assignment]
        font_small = self._font_small  # type: ignore[assignment]

        # Panel height: title + balance + label + revenue bars + label + expense bars + padding
        panel_h = (
            self._PADDING + self._FONT_SIZE_SMALL + self._PADDING  # title
            + self._FONT_SIZE_LARGE + self._PADDING               # balance
            + self._FONT_SIZE_SMALL + 4                            # revenue label
            + self._BAR_SECTION_H + self._PADDING                  # revenue bars
            + self._FONT_SIZE_SMALL + 4                            # expense label
            + self._BAR_SECTION_H + self._PADDING                  # expense bars
        )

        panel = pygame.Surface((self._width, panel_h), pygame.SRCALPHA)
        panel.fill(self._BG_COLOR)
        surf.blit(panel, (self._x, self._y))

        y = self._y + self._PADDING

        # --- Title ---
        font_small.render_to(
            surf, (self._x + self._PADDING, y), "FINANCE", self._COLOR_TITLE
        )
        y += self._FONT_SIZE_SMALL + self._PADDING

        # --- Balance ---
        balance = budget.balance
        bal_color = self._COLOR_POSITIVE if balance >= 0 else self._COLOR_NEGATIVE
        bal_text = f"${balance:,.0f}"
        font_large.render_to(surf, (self._x + self._PADDING, y), bal_text, bal_color)
        y += self._FONT_SIZE_LARGE + self._PADDING

        # --- Revenue bars ---
        font_small.render_to(
            surf, (self._x + self._PADDING, y), "Revenue (last 20)", self._COLOR_LABEL
        )
        y += self._FONT_SIZE_SMALL + 4
        self._draw_bars(surf, history, slot=0, color=self._COLOR_REVENUE, y=y)
        y += self._BAR_SECTION_H + self._PADDING

        # --- Expense bars ---
        font_small.render_to(
            surf, (self._x + self._PADDING, y), "Expenses (last 20)", self._COLOR_LABEL
        )
        y += self._FONT_SIZE_SMALL + 4
        self._draw_bars(surf, history, slot=1, color=self._COLOR_EXPENSE, y=y)

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _draw_bars(
        self,
        surface: object,
        history: list[tuple[float, float, float]],
        slot: int,
        color: tuple[int, int, int],
        y: int,
    ) -> None:
        """Draw a row of 20 mini bar-chart rectangles.

        Args:
            surface: Target pygame.Surface.
            history: Ring-buffer list; each entry is (revenue, expenses, balance).
            slot: Index within each tuple (0=revenue, 1=expenses).
            color: Bar fill colour.
            y: Top-y of the bar area in screen pixels.
        """
        if not _HAS_PYGAME or not history:
            return

        import pygame  # type: ignore[import]

        surf = surface  # type: pygame.Surface
        bar_area_w = self._width - 2 * self._PADDING
        n = 20
        bar_w = max(1, bar_area_w // n - 1)
        gap = bar_area_w // n

        values = [entry[slot] for entry in history]
        max_val = max(values) if values else 1.0
        if max_val <= 0:
            max_val = 1.0

        # Pad to 20 slots (oldest on the left = index 0 of values).
        padded = [0.0] * (n - len(values)) + values

        for i, val in enumerate(padded):
            bar_h = int(val / max_val * self._BAR_H)
            bar_x = self._x + self._PADDING + i * gap
            bar_y = y + self._BAR_H - bar_h
            if bar_h > 0:
                pygame.draw.rect(
                    surf, color, pygame.Rect(bar_x, bar_y, bar_w, bar_h)
                )
