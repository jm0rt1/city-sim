from __future__ import annotations

import pygame

FLOOR_H = 16  # px per floor stack


class ElevatedBuildingBlit:
    """Blits a building tile offset upward by height_tiles * FLOOR_H."""

    def blit(
        self,
        surface: pygame.Surface,
        tile: pygame.Surface,
        screen_x: int,
        screen_y: int,
        height_tiles: int = 1,
    ) -> None:
        surface.blit(tile, (screen_x, screen_y - (height_tiles - 1) * FLOOR_H))
