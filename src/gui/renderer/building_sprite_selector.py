from __future__ import annotations

from src.city.building import Building, BuildingType

# Mapping from BuildingType to base sprite atlas tile ID.
_SPRITE_MAP: dict[BuildingType, str] = {
    BuildingType.EMPTY_LOT:           "terrain_grass_0",
    BuildingType.RESIDENTIAL_SMALL:   "building_res_small",
    BuildingType.RESIDENTIAL_MEDIUM:  "building_res_medium",
    BuildingType.RESIDENTIAL_LARGE:   "building_res_large",
    BuildingType.COMMERCIAL:          "building_commercial",
    BuildingType.INDUSTRIAL:          "building_industrial",
    BuildingType.CIVIC_CITY_HALL:     "building_city_hall",
    BuildingType.CIVIC_HOSPITAL:      "building_hospital",
    BuildingType.CIVIC_SCHOOL:        "building_school",
    BuildingType.CIVIC_FIRE_STATION:  "building_fire_station",
    BuildingType.CIVIC_POLICE_STATION:"building_police_station",
    BuildingType.CIVIC_POWER_PLANT:   "building_power_plant",
    BuildingType.PARK:                "terrain_park_0",
}

# Verify every BuildingType value has a mapping at import time.
_missing = set(BuildingType) - set(_SPRITE_MAP)
assert not _missing, f"Missing sprite mappings for: {_missing}"


class BuildingSpriteSelector:
    """
    Maps :class:`~src.city.building.Building` state
    (type + condition + occupancy) to a sprite atlas tile ID.
    """

    def get_sprite_id(self, building: Building) -> str:
        """
        Return the atlas tile ID for *building*.

        Uses a ``_damaged`` variant when ``condition < 0.3``, except for
        terrain-only types (EMPTY_LOT, PARK) that have no damage state.
        """
        base = _SPRITE_MAP.get(building.building_type, "terrain_grass_0")
        _terrain_types = (BuildingType.EMPTY_LOT, BuildingType.PARK)
        if building.condition < 0.3 and building.building_type not in _terrain_types:
            return f"{base}_damaged"
        return base
