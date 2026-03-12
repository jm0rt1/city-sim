from __future__ import annotations

from src.city.city import City
from src.city.building import Building, BuildingType
from src.gui.renderer.building_render_state import BuildingRenderState
from src.gui.renderer.city_grid_layout import ICityGridLayout

_GRID_COLS = 8
_GRID_ROWS = 8


class PlaceableCityGridLayout(ICityGridLayout):
    """
    An :class:`ICityGridLayout` that lets the player place individual buildings
    at explicit (col, row) grid positions.

    The grid is ``cols × rows`` tiles.  Any cell that has not been explicitly
    built on is filled with either a :data:`~src.city.building.BuildingType.PARK`
    or :data:`~src.city.building.BuildingType.EMPTY_LOT` tile.  Placed buildings
    persist across frames — the map is owned by this layout object.

    Args:
        cols: Number of grid columns (default 8).
        rows: Number of grid rows (default 8).
    """

    def __init__(self, cols: int = _GRID_COLS, rows: int = _GRID_ROWS) -> None:
        self._cols = cols
        self._rows = rows
        # Explicit map of placed buildings.  Key = (col, row).
        self._placed: dict[tuple[int, int], Building] = {}

    # ------------------------------------------------------------------
    # ICityGridLayout
    # ------------------------------------------------------------------

    def build_render_states(self, city: City) -> list[BuildingRenderState]:
        """Return the full grid, mixing placed buildings with background tiles."""
        states: list[BuildingRenderState] = []
        for row in range(self._rows):
            for col in range(self._cols):
                pos = (col, row)
                if pos in self._placed:
                    states.append(BuildingRenderState(self._placed[pos], pos))
                else:
                    btype = (
                        BuildingType.PARK
                        if (col + row) % 4 == 0
                        else BuildingType.EMPTY_LOT
                    )
                    states.append(BuildingRenderState(Building(btype), pos))
        return states

    # ------------------------------------------------------------------
    # Placement API
    # ------------------------------------------------------------------

    def place_building(self, col: int, row: int, building_type: BuildingType) -> bool:
        """
        Place a building of *building_type* at *(col, row)*.

        Returns ``True`` if the position is within the grid bounds.
        Placing on an already-occupied cell replaces the existing building.
        Placing :data:`~src.city.building.BuildingType.EMPTY_LOT` clears
        the cell back to background terrain.
        """
        if not self._in_bounds(col, row):
            return False
        if building_type == BuildingType.EMPTY_LOT:
            self._placed.pop((col, row), None)
        else:
            self._placed[(col, row)] = Building(building_type)
        return True

    def get_building(self, col: int, row: int) -> Building | None:
        """Return the placed building at *(col, row)*, or ``None`` if empty."""
        return self._placed.get((col, row))

    def in_bounds(self, col: int, row: int) -> bool:
        """Return ``True`` if *(col, row)* is a valid grid position."""
        return self._in_bounds(col, row)

    # ------------------------------------------------------------------
    # Private
    # ------------------------------------------------------------------

    def _in_bounds(self, col: int, row: int) -> bool:
        return 0 <= col < self._cols and 0 <= row < self._rows
