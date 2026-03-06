from __future__ import annotations

from abc import ABC, abstractmethod

from src.city.city import City
from src.city.building import Building, BuildingType
from src.gui.renderer.building_render_state import BuildingRenderState


class ICityGridLayout(ABC):
    """
    Strategy interface for mapping :class:`~src.city.city.City` state to a
    list of :class:`~src.gui.renderer.building_render_state.BuildingRenderState`
    objects ready for isometric rendering.

    Concrete implementations can use any placement strategy (infrastructure-
    count-based, zone-based, explicit coordinate lookup, etc.) without
    modifying :class:`~src.gui.renderer.city_renderer.CityRenderer`.
    """

    @abstractmethod
    def build_render_states(self, city: City) -> list[BuildingRenderState]:
        """Return a list of render states derived from *city*'s current state."""


class _GridPlacer:
    """
    Assigns :class:`~src.city.building.Building` objects to sequential
    (col, row) positions on an isometric grid.

    Replaces the `nonlocal col` closure pattern: state is held as normal
    instance variables and mutated through the public :meth:`place` method.
    """

    def __init__(self, cols: int, rows: int) -> None:
        self._cols = cols
        self._rows = rows
        self._next_index: int = 0
        self.states: list[BuildingRenderState] = []
        self.occupied: set[tuple[int, int]] = set()

    def place(self, building: Building) -> None:
        """Place *building* at the next available grid position."""
        pos = (self._next_index % self._cols, self._next_index // self._cols)
        self.states.append(BuildingRenderState(building, pos))
        self.occupied.add(pos)
        self._next_index += 1

    def fill_remaining(self) -> None:
        """Fill every unoccupied grid cell with grass or park tiles."""
        for row in range(self._rows):
            for col in range(self._cols):
                if (col, row) not in self.occupied:
                    btype = (
                        BuildingType.PARK
                        if (col + row) % 4 == 0
                        else BuildingType.EMPTY_LOT
                    )
                    self.states.append(BuildingRenderState(Building(btype), (col, row)))


class InfrastructureCityGridLayout(ICityGridLayout):
    """
    Concrete layout strategy that maps the flat infrastructure counts on
    :class:`~src.city.city.City` (electricity, water, housing) to a grid
    of :class:`~src.gui.renderer.building_render_state.BuildingRenderState`
    objects.

    Buildings are placed in row-major order; any remaining cells are filled
    with grass or park tiles.

    Args:
        cols: Number of grid columns. Defaults to 8.
        rows: Number of grid rows. Defaults to 8.
    """

    def __init__(self, cols: int = 8, rows: int = 8) -> None:
        self._cols = cols
        self._rows = rows

    # ------------------------------------------------------------------
    # ICityGridLayout
    # ------------------------------------------------------------------

    def build_render_states(self, city: City) -> list[BuildingRenderState]:
        placer = _GridPlacer(self._cols, self._rows)

        self._place_electricity(city, placer)
        self._place_water(city, placer)
        self._place_housing(city, placer)
        placer.fill_remaining()

        return placer.states

    # ------------------------------------------------------------------
    # Private helpers — one method per infrastructure category
    # ------------------------------------------------------------------

    def _place_electricity(self, city: City, placer: _GridPlacer) -> None:
        for _ in range(city.electricity_facilities):
            placer.place(Building(BuildingType.CIVIC_POWER_PLANT))

    def _place_water(self, city: City, placer: _GridPlacer) -> None:
        for _ in range(city.water_facilities):
            placer.place(Building(BuildingType.CIVIC_HOSPITAL))

    def _place_housing(self, city: City, placer: _GridPlacer) -> None:
        units = city.housing_units
        for _ in range(units // 20):
            placer.place(Building(BuildingType.RESIDENTIAL_LARGE, occupancy=20))
        for _ in range((units % 20) // 5):
            placer.place(Building(BuildingType.RESIDENTIAL_MEDIUM, occupancy=5))
        for _ in range(units % 5):
            placer.place(Building(BuildingType.RESIDENTIAL_SMALL, occupancy=1))
