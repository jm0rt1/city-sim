from __future__ import annotations

import enum
from dataclasses import dataclass, field


class BuildingType(enum.Enum):
    EMPTY_LOT = "empty_lot"
    RESIDENTIAL_SMALL = "residential_small"
    RESIDENTIAL_MEDIUM = "residential_medium"
    RESIDENTIAL_LARGE = "residential_large"
    COMMERCIAL = "commercial"
    INDUSTRIAL = "industrial"
    CIVIC_CITY_HALL = "civic_city_hall"
    CIVIC_HOSPITAL = "civic_hospital"
    CIVIC_SCHOOL = "civic_school"
    CIVIC_FIRE_STATION = "civic_fire_station"
    CIVIC_POLICE_STATION = "civic_police_station"
    CIVIC_POWER_PLANT = "civic_power_plant"
    PARK = "park"


@dataclass
class Building:
    """A single structure on the city grid."""
    building_type: BuildingType
    condition: float = 1.0   # 0.0 (destroyed) – 1.0 (pristine)
    occupancy: int = 0


@dataclass
class District:
    """A named collection of buildings."""
    name: str
    buildings: list[Building] = field(default_factory=list)
