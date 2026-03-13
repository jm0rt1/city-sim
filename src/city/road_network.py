from __future__ import annotations

from enum import Enum, auto


class RoadSegment(Enum):
    NONE = auto()
    ROAD = auto()


class RoadNetwork:
    """Sparse grid of road segments. City holds one RoadNetwork instance."""

    def __init__(self, cols: int, rows: int) -> None:
        self._cols = cols
        self._rows = rows
        self._roads: set[tuple[int, int]] = set()

    def place_road(self, col: int, row: int) -> None:
        """Place a road segment at *(col, row)*."""
        self._roads.add((col, row))

    def remove_road(self, col: int, row: int) -> None:
        """Remove the road segment at *(col, row)*, if any."""
        self._roads.discard((col, row))

    def is_road(self, col: int, row: int) -> bool:
        """Return ``True`` if there is a road segment at *(col, row)*."""
        return (col, row) in self._roads

    def get_neighbours(self, col: int, row: int) -> dict[str, bool]:
        """Return ``{N, E, S, W: bool}`` — which cardinal neighbours have road."""
        return {
            "N": self.is_road(col, row - 1),
            "E": self.is_road(col + 1, row),
            "S": self.is_road(col, row + 1),
            "W": self.is_road(col - 1, row),
        }
