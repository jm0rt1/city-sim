from __future__ import annotations

from src.shared.graphics_settings import GraphicsSettings


class IsometricGridMapper:
    """
    Converts world (col, row) tile coordinates to screen (x, y) pixel
    coordinates using the standard diamond-isometric projection:

        screen_x = (col - row) * TILE_W // 2 + origin_x
        screen_y = (col + row) * TILE_H // 2 + origin_y
    """

    def __init__(
        self,
        settings: GraphicsSettings,
        origin_x: int = 0,
        origin_y: int = 0,
    ) -> None:
        self._tw = settings.tile_width
        self._th = settings.tile_height
        self.origin_x = origin_x
        self.origin_y = origin_y

    def world_to_screen(self, col: int, row: int) -> tuple[int, int]:
        """Map isometric grid (col, row) → screen (x, y)."""
        x = (col - row) * self._tw // 2 + self.origin_x
        y = (col + row) * self._th // 2 + self.origin_y
        return x, y

    def screen_to_world(self, x: int, y: int) -> tuple[int, int]:
        """Map screen (x, y) → nearest isometric grid (col, row)."""
        dx = x - self.origin_x
        dy = y - self.origin_y
        col = (dx // (self._tw // 2) + dy // (self._th // 2)) // 2
        row = (dy // (self._th // 2) - dx // (self._tw // 2)) // 2
        return col, row
