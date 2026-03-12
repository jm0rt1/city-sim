from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable

import pygame
import pygame.freetype


@dataclass
class _Button:
    """Describes one interactive button in the action panel."""
    label: str
    key_hint: str
    action_key: str
    pygame_key: int
    rect: pygame.Rect = field(default_factory=lambda: pygame.Rect(0, 0, 0, 0))
    flash_frames: int = field(default=0)


class ActionPanel:
    """
    Right-hand sidebar panel with clickable buttons for city controls.

    Supports both left-click and keyboard-shortcut interaction.

    Callback dispatch via :meth:`trigger_action` and :meth:`handle_keydown`
    is pure Python — no pygame display is required for those methods.
    Rendering is performed only when :meth:`draw` is called.

    Args:
        x: Left edge of the panel in screen pixels.
        y: Top edge of the panel in screen pixels.
        actions: Mapping from ``action_key`` strings to zero-argument callables.
        is_paused: Callable returning ``True`` when the simulation is paused.
    """

    PANEL_W: int = 220

    _BTN_H: int = 40
    _PADDING: int = 8
    _TITLE_H: int = 32
    _FONT_SIZE: int = 14

    _COLOR_BG:        tuple[int, int, int, int] = (25, 25, 35, 210)
    _COLOR_BTN:       tuple[int, int, int]       = (55, 58, 80)
    _COLOR_BTN_HOVER: tuple[int, int, int]       = (80, 84, 115)
    _COLOR_BTN_FLASH: tuple[int, int, int]       = (80, 170, 100)
    _COLOR_TEXT:      tuple[int, int, int]       = (220, 220, 230)
    _COLOR_HINT:      tuple[int, int, int]       = (130, 130, 150)
    _COLOR_TITLE:     tuple[int, int, int]       = (180, 180, 255)
    _COLOR_RUNNING:   tuple[int, int, int]       = (80, 220, 80)
    _COLOR_PAUSED:    tuple[int, int, int]       = (255, 200, 80)
    _COLOR_NOTIFY:    tuple[int, int, int]       = (160, 220, 160)

    # Notification toast stays visible for this many rendered frames (~3 s at 30 fps).
    _NOTIFY_FRAMES: int = 90

    # (label, key_hint, action_key, pygame_key)
    _BUTTON_DEFS: list[tuple[str, str, str, int]] = [
        ("+ Water Fac.",   "W", "add_water",    pygame.K_w),
        ("+ Elec. Fac.",   "E", "add_elec",     pygame.K_e),
        ("+ 10 Housing",   "H", "add_housing",  pygame.K_h),
        ("Pause / Resume", "P", "toggle_pause", pygame.K_p),
    ]

    def __init__(
        self,
        x: int,
        y: int,
        actions: dict[str, Callable[[], None]],
        is_paused: Callable[[], bool],
    ) -> None:
        self._x = x
        self._y = y
        self._actions = actions
        self._is_paused = is_paused

        # Font and rects are initialised lazily in draw() so that this class
        # can be instantiated and its callback methods used without a display.
        self._font_instance: pygame.freetype.Font | None = None
        self._rects_built: bool = False

        self._last_msg: str = ""
        self._msg_frames: int = 0

        # Build button specs (rects have zero size until _ensure_rects is called)
        self._buttons: list[_Button] = [
            _Button(label=label, key_hint=hint, action_key=ak, pygame_key=pk)
            for label, hint, ak, pk in self._BUTTON_DEFS
        ]
        self._key_map: dict[int, _Button] = {
            btn.pygame_key: btn for btn in self._buttons
        }

    @property
    def _font(self) -> pygame.freetype.Font:
        """Return the lazily-initialised font, guaranteed non-None after first draw."""
        self._ensure_font()
        assert self._font_instance is not None
        return self._font_instance

    # ------------------------------------------------------------------
    # Callback dispatch — no pygame display required
    # ------------------------------------------------------------------

    def trigger_action(self, action_key: str) -> bool:
        """
        Execute the callable registered for *action_key*.

        Returns ``True`` if the key was found and the callback invoked.
        This method does not require a pygame display.
        """
        callback = self._actions.get(action_key)
        if callback is None:
            return False
        callback()
        label = next(
            (b.label for b in self._buttons if b.action_key == action_key),
            action_key,
        )
        self._last_msg = f"\u2713 {label}"
        self._msg_frames = self._NOTIFY_FRAMES
        return True

    def handle_keydown(self, key: int) -> bool:
        """
        Dispatch the action bound to pygame key constant *key*.

        Returns ``True`` if the key matched a button and the action fired.
        This method does not require a pygame display.
        """
        btn = self._key_map.get(key)
        if btn is None:
            return False
        btn.flash_frames = 6
        return self.trigger_action(btn.action_key)

    def handle_click(self, pos: tuple[int, int]) -> bool:
        """
        Dispatch the action for the button whose rect contains screen *pos*.

        Returns ``True`` if a button was hit.  Requires rects to be built
        (i.e. :meth:`draw` must have been called at least once first).
        """
        self._ensure_rects()
        for btn in self._buttons:
            if btn.rect.collidepoint(pos):
                btn.flash_frames = 6
                return self.trigger_action(btn.action_key)
        return False

    # ------------------------------------------------------------------
    # Rendering
    # ------------------------------------------------------------------

    def draw(self, surface: pygame.Surface) -> None:
        """Render the action panel onto *surface*."""
        self._ensure_rects()

        # Semi-transparent background
        panel = pygame.Surface((self.PANEL_W, surface.get_height()), pygame.SRCALPHA)
        panel.fill(self._COLOR_BG)
        surface.blit(panel, (self._x, self._y))

        # Title
        self._font.render_to(
            surface,
            (self._x + self._PADDING, self._y + self._PADDING + 4),
            "CITY CONTROLS",
            self._COLOR_TITLE,
        )

        mouse_pos = pygame.mouse.get_pos()
        for btn in self._buttons:
            if btn.flash_frames > 0:
                color = self._COLOR_BTN_FLASH
                btn.flash_frames -= 1
            elif btn.rect.collidepoint(mouse_pos):
                color = self._COLOR_BTN_HOVER
            else:
                color = self._COLOR_BTN

            pygame.draw.rect(surface, color, btn.rect, border_radius=4)
            pygame.draw.rect(surface, (100, 100, 130), btn.rect, 1, border_radius=4)

            text_y = btn.rect.y + (self._BTN_H - self._FONT_SIZE) // 2 + 1
            self._font.render_to(
                surface,
                (btn.rect.x + self._PADDING, text_y),
                btn.label,
                self._COLOR_TEXT,
            )
            hint_surf, hint_rect = self._font.render(
                f"[{btn.key_hint}]", self._COLOR_HINT
            )
            surface.blit(
                hint_surf,
                (btn.rect.right - hint_rect.width - self._PADDING, text_y),
            )

        # Status line (Running / Paused)
        status = "\u23f8 Paused" if self._is_paused() else "\u25b6 Running"
        color = self._COLOR_PAUSED if self._is_paused() else self._COLOR_RUNNING
        status_y = self._buttons[-1].rect.bottom + self._PADDING * 2
        self._font.render_to(
            surface, (self._x + self._PADDING, status_y), status, color
        )

        # Notification toast
        if self._msg_frames > 0:
            self._font.render_to(
                surface,
                (self._x + self._PADDING, status_y + self._FONT_SIZE + self._PADDING),
                self._last_msg,
                self._COLOR_NOTIFY,
            )
            self._msg_frames -= 1

    # ------------------------------------------------------------------
    # Private
    # ------------------------------------------------------------------

    def _ensure_font(self) -> None:
        if self._font_instance is None:
            pygame.freetype.init()
            self._font_instance = pygame.freetype.SysFont("monospace", self._FONT_SIZE)

    def _ensure_rects(self) -> None:
        if self._rects_built:
            return
        y = self._y + self._TITLE_H + self._PADDING
        for btn in self._buttons:
            btn.rect = pygame.Rect(
                self._x + self._PADDING,
                y,
                self.PANEL_W - 2 * self._PADDING,
                self._BTN_H,
            )
            y += self._BTN_H + self._PADDING
        self._rects_built = True
