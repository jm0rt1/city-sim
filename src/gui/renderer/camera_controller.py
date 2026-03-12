from __future__ import annotations


class CameraController:
    """
    Owns viewport offset (origin_x, origin_y) and zoom_level (0.5–2.0).

    Methods:
      pan(dx, dy)                           — move viewport by pixel delta
      zoom(factor)                          — multiply zoom, clamped to [0.5, 2.0]
      world_to_screen(col, row, tw, th)     — applies zoom + pan, returns (x, y)
      screen_to_world(x, y, tw, th)         — inverse mapping for mouse hit-testing
      reset()                               — restore default origin and zoom=1.0
      frame_city(cols, rows, win_w, win_h)  — fit-to-screen zoom + centering
    """

    _MIN_ZOOM = 0.5
    _MAX_ZOOM = 2.0

    def __init__(self, origin_x: int = 0, origin_y: int = 0) -> None:
        self._default_origin_x = origin_x
        self._default_origin_y = origin_y
        self.origin_x: float = float(origin_x)
        self.origin_y: float = float(origin_y)
        self.zoom_level: float = 1.0

    def pan(self, dx: float, dy: float) -> None:
        """Move the viewport by a pixel delta."""
        self.origin_x += dx
        self.origin_y += dy

    def zoom(self, factor: float) -> None:
        """Multiply zoom level by *factor*, clamped to [0.5, 2.0]."""
        self.zoom_level = max(
            self._MIN_ZOOM, min(self._MAX_ZOOM, self.zoom_level * factor)
        )

    def world_to_screen(
        self, col: int, row: int, tw: int, th: int
    ) -> tuple[int, int]:
        """Apply zoom + pan and return screen (x, y) for isometric tile."""
        z = self.zoom_level
        x = int((col - row) * tw // 2 * z + self.origin_x)
        y = int((col + row) * th // 2 * z + self.origin_y)
        return x, y

    def screen_to_world(
        self, x: int, y: int, tw: int, th: int
    ) -> tuple[int, int]:
        """Inverse of world_to_screen: map screen (x, y) → grid (col, row)."""
        z = self.zoom_level
        dx = (x - self.origin_x) / z
        dy = (y - self.origin_y) / z
        half_tw = tw // 2
        half_th = th // 2
        col = int((dx / half_tw + dy / half_th) / 2)
        row = int((dy / half_th - dx / half_tw) / 2)
        return col, row

    def reset(self) -> None:
        """Restore the default origin and zoom=1.0."""
        self.origin_x = float(self._default_origin_x)
        self.origin_y = float(self._default_origin_y)
        self.zoom_level = 1.0

    def frame_city(
        self, cols: int, rows: int, win_w: int, win_h: int, tw: int = 64, th: int = 32
    ) -> None:
        """Adjust zoom and origin to fit the entire grid on screen."""
        grid_w = (cols + rows) * tw / 2
        grid_h = (cols + rows) * th / 2
        if grid_w == 0 or grid_h == 0:
            return
        zoom_x = win_w / grid_w
        zoom_y = win_h / grid_h
        self.zoom_level = max(
            self._MIN_ZOOM, min(self._MAX_ZOOM, min(zoom_x, zoom_y) * 0.9)
        )
        z = self.zoom_level
        self.origin_x = win_w / 2.0
        self.origin_y = (win_h - (cols + rows) * th / 2 * z) / 2.0
