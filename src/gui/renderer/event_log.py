from __future__ import annotations

import collections
from dataclasses import dataclass
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    pass

try:
    import pygame
    import pygame.freetype
    _HAS_PYGAME = True
except ImportError:  # pragma: no cover
    _HAS_PYGAME = False

# Maximum number of log entries retained in the buffer.
_MAX_ENTRIES: int = 50

# Severity levels
SEVERITY_INFO = "info"
SEVERITY_WARNING = "warning"
SEVERITY_NEUTRAL = "neutral"


@dataclass
class LogEntry:
    """A single event log entry."""
    tick: int
    message: str
    severity: str = SEVERITY_INFO


class EventLog:
    """
    Buffer of simulation event messages displayed in a bottom strip HUD.

    Pure-Python core — :meth:`append` and :attr:`entries` work without a
    display.  Only :meth:`draw` requires pygame.

    Stores at most :data:`_MAX_ENTRIES` entries; oldest entries are dropped
    when the buffer is full.
    """

    _FONT_SIZE: int = 13
    _PADDING: int = 6
    _BG_COLOR: tuple[int, int, int, int] = (0, 0, 0, 170)
    _COLOR_INFO: tuple[int, int, int] = (200, 230, 255)
    _COLOR_WARNING: tuple[int, int, int] = (255, 200, 80)
    _COLOR_NEUTRAL: tuple[int, int, int] = (200, 200, 200)
    # Number of rows to show in the overlay strip.
    _VISIBLE_ROWS: int = 4

    def __init__(self) -> None:
        self._entries: collections.deque[LogEntry] = collections.deque(
            maxlen=_MAX_ENTRIES
        )
        # Lazy font — created on first draw() call so no display is required
        # at construction time.
        self._font: object | None = None

    # ------------------------------------------------------------------
    # Pure-Python API
    # ------------------------------------------------------------------

    def append(self, tick: int, message: str, severity: str = SEVERITY_INFO) -> None:
        """Add a new log entry."""
        self._entries.append(LogEntry(tick=tick, message=message, severity=severity))

    @property
    def entries(self) -> list[LogEntry]:
        """Return a snapshot of entries (oldest first)."""
        return list(self._entries)

    # ------------------------------------------------------------------
    # Rendering (requires pygame)
    # ------------------------------------------------------------------

    def draw(self, surface: object, visible: bool = True) -> None:
        """Render the event log strip onto *surface*.

        Args:
            surface: A ``pygame.Surface`` to draw on.
            visible: When ``False`` the overlay is skipped (toggle via L key).
        """
        if not visible:
            return
        if not _HAS_PYGAME:
            return  # pragma: no cover

        import pygame  # type: ignore[import]
        import pygame.freetype  # type: ignore[import]

        surf = surface  # type: pygame.Surface
        win_w = surf.get_width()
        win_h = surf.get_height()

        if self._font is None:
            pygame.freetype.init()
            self._font = pygame.freetype.SysFont("monospace", self._FONT_SIZE)

        font = self._font  # type: ignore[assignment]

        line_h = self._FONT_SIZE + 4
        # Show last N entries.
        recent = list(self._entries)[-self._VISIBLE_ROWS:]
        panel_h = len(recent) * line_h + self._PADDING * 2

        panel = pygame.Surface((win_w, panel_h), pygame.SRCALPHA)
        panel.fill(self._BG_COLOR)
        panel_y = win_h - panel_h
        surf.blit(panel, (0, panel_y))

        for i, entry in enumerate(recent):
            color = {
                SEVERITY_WARNING: self._COLOR_WARNING,
                SEVERITY_NEUTRAL: self._COLOR_NEUTRAL,
            }.get(entry.severity, self._COLOR_INFO)
            text = f"[T{entry.tick:04d}] {entry.message}"
            y = panel_y + self._PADDING + i * line_h
            font.render_to(surf, (self._PADDING, y), text, color)
