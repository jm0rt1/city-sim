from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from src.city.city import City
    from src.gui.renderer.city_grid_layout import ICityGridLayout
    from src.gui.renderer.camera_controller import CameraController

from src.city.building import BuildingType

try:
    import pygame
    _HAS_PYGAME = True
except ImportError:  # pragma: no cover
    _HAS_PYGAME = False

# Minimap dimensions in pixels (1 px per cell).
_MAP_W: int = 80
_MAP_H: int = 80

# Cell colours by building category.
_COLORS: dict[BuildingType, tuple[int, int, int]] = {
    BuildingType.PARK:                  (56,  118,  29),
    BuildingType.EMPTY_LOT:             (30,   30,  30),
    BuildingType.RESIDENTIAL_SMALL:     (255, 200, 100),
    BuildingType.RESIDENTIAL_MEDIUM:    (255, 200, 100),
    BuildingType.RESIDENTIAL_LARGE:     (255, 200, 100),
    BuildingType.COMMERCIAL:            (100, 181, 246),
    BuildingType.INDUSTRIAL:            (158, 158, 158),
    BuildingType.CIVIC_CITY_HALL:       (149, 117, 205),
    BuildingType.CIVIC_HOSPITAL:        (149, 117, 205),
    BuildingType.CIVIC_SCHOOL:          (149, 117, 205),
    BuildingType.CIVIC_FIRE_STATION:    (149, 117, 205),
    BuildingType.CIVIC_POLICE_STATION:  (149, 117, 205),
    BuildingType.CIVIC_POWER_PLANT:     (149, 117, 205),
}
_COLOR_ROAD: tuple[int, int, int] = (110, 110, 110)
_COLOR_TERRAIN_DEFAULT: tuple[int, int, int] = (56, 118, 29)
_COLOR_VIEWPORT: tuple[int, int, int] = (255, 255, 255)
_COLOR_BORDER: tuple[int, int, int] = (80, 80, 100)

# Bottom-right margin from the grid area edge.
_MARGIN: int = 8


class Minimap:
    """
    80×80 px minimap overlay at the bottom-right of the grid area.

    Each cell is rendered as 1 px, coloured by building category.  A white
    rectangle outlines the current camera viewport.  Clicking inside the
    minimap pans the camera to the corresponding world position.

    The class can be constructed without a pygame display; only :meth:`draw`
    requires pygame.

    Args:
        grid_area_w: Pixel width of the isometric grid area (excluding the
                     ActionPanel column).
        win_h: Window height in pixels.
    """

    def __init__(self, grid_area_w: int, win_h: int) -> None:
        self._grid_area_w = grid_area_w
        self._win_h = win_h
        # Top-left corner of the minimap on screen.
        self._x = grid_area_w - _MAP_W - _MARGIN
        self._y = win_h - _MAP_H - _MARGIN
        self._surface: object | None = None  # lazy-created pygame.Surface

    @property
    def rect(self) -> tuple[int, int, int, int]:
        """Screen rect ``(x, y, w, h)`` of the minimap."""
        return (self._x, self._y, _MAP_W, _MAP_H)

    # ------------------------------------------------------------------
    # Pure-Python hit-test
    # ------------------------------------------------------------------

    def contains(self, pos: tuple[int, int]) -> bool:
        """Return ``True`` if screen *pos* is inside the minimap area."""
        x, y, w, h = self.rect
        return x <= pos[0] < x + w and y <= pos[1] < y + h

    def handle_click(
        self,
        pos: tuple[int, int],
        camera: CameraController,
        cols: int,
        rows: int,
        tw: int,
        th: int,
    ) -> bool:
        """Pan *camera* to the world position corresponding to *pos*.

        Args:
            pos: Screen position of the click.
            camera: Camera controller to pan.
            cols: Grid column count.
            rows: Grid row count.
            tw: Tile width in pixels.
            th: Tile height in pixels.

        Returns:
            ``True`` if the click was inside the minimap and was consumed.
        """
        if not self.contains(pos):
            return False
        if cols == 0 or rows == 0:
            return False

        # Map click offset within minimap to grid fraction.
        mx = pos[0] - self._x
        my = pos[1] - self._y
        frac_c = mx / _MAP_W
        frac_r = my / _MAP_H
        target_col = frac_c * cols
        target_row = frac_r * rows

        # Compute the screen position that corresponds to (target_col, target_row)
        # using zoom = current zoom; then set origin so that point maps to centre
        # of the grid area.
        z = camera.zoom_level
        iso_x = (target_col - target_row) * tw // 2 * z
        iso_y = (target_col + target_row) * th // 2 * z
        camera.origin_x = self._grid_area_w / 2.0 - iso_x
        camera.origin_y = self._win_h / 2.0 - iso_y
        return True

    # ------------------------------------------------------------------
    # Rendering (requires pygame)
    # ------------------------------------------------------------------

    def draw(
        self,
        surface: object,
        layout: ICityGridLayout,
        city: City,
        camera: CameraController,
        tw: int = 64,
        th: int = 32,
    ) -> None:
        """Render the minimap onto *surface*.

        Args:
            surface: A ``pygame.Surface`` to draw on.
            layout: Grid layout to read cell types from.
            city: City state (used to check road network).
            camera: Camera controller (used to draw viewport rect).
            tw: Tile width in pixels.
            th: Tile height in pixels.
        """
        if not _HAS_PYGAME:
            return  # pragma: no cover

        import pygame  # type: ignore[import]

        surf = surface  # type: pygame.Surface

        if self._surface is None:
            self._surface = pygame.Surface((_MAP_W, _MAP_H))

        mm: pygame.Surface = self._surface  # type: ignore[assignment]
        mm.fill((20, 20, 20))

        states = layout.build_render_states(city)
        road_network = getattr(city, "road_network", None)

        from src.gui.renderer.placeable_city_grid_layout import PlaceableCityGridLayout
        if isinstance(layout, PlaceableCityGridLayout):
            cols = layout.cols
            rows = layout.rows
        else:
            cols = rows = 32

        cell_w = max(1, _MAP_W // cols) if cols > 0 else 1
        cell_h = max(1, _MAP_H // rows) if rows > 0 else 1

        for brs in states:
            c, r = brs.grid_position
            px = int(c * _MAP_W / cols) if cols > 0 else 0
            py = int(r * _MAP_H / rows) if rows > 0 else 0
            # Road takes priority.
            if road_network is not None and road_network.is_road(c, r):
                color = _COLOR_ROAD
            else:
                btype = brs.building.building_type
                color = _COLORS.get(btype, _COLOR_TERRAIN_DEFAULT)
            pygame.draw.rect(mm, color, pygame.Rect(px, py, cell_w, cell_h))

        # Border
        pygame.draw.rect(mm, _COLOR_BORDER, pygame.Rect(0, 0, _MAP_W, _MAP_H), 1)

        # Viewport rectangle
        z = camera.zoom_level
        grid_w_px = (cols + rows) * tw / 2 * z
        grid_h_px = (cols + rows) * th / 2 * z

        if grid_w_px > 0 and grid_h_px > 0:
            # Approximate viewport: origin offset relative to grid centre.
            vp_left = int((-camera.origin_x + 0) / grid_w_px * _MAP_W)
            vp_top = int((-camera.origin_y + 0) / grid_h_px * _MAP_H)
            vp_w = int(self._grid_area_w / grid_w_px * _MAP_W)
            vp_h = int(self._win_h / grid_h_px * _MAP_H)
            pygame.draw.rect(
                mm,
                _COLOR_VIEWPORT,
                pygame.Rect(vp_left, vp_top, max(2, vp_w), max(2, vp_h)),
                1,
            )

        surf.blit(mm, (self._x, self._y))
