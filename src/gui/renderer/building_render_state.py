from __future__ import annotations

from dataclasses import dataclass, field

from src.city.building import Building


@dataclass
class BuildingRenderState:
    """
    Associates a :class:`~src.city.building.Building` with its isometric grid
    position for rendering purposes.

    This wrapper keeps rendering concerns out of the core Building data model,
    as recommended by the Graphics Specification (Section 4.5).
    """

    building: Building
    grid_position: tuple[int, int]  # (col, row)
    height_tiles: int = field(default=1)
    road_sprite_id: str | None = field(default=None)
