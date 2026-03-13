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

# Building types that can have occupancy (and eventually occupancy-variant sprites).
_OCCUPANCY_TYPES = frozenset({
    BuildingType.RESIDENTIAL_SMALL,
    BuildingType.RESIDENTIAL_MEDIUM,
    BuildingType.RESIDENTIAL_LARGE,
    BuildingType.COMMERCIAL,
})


def _occupancy_bucket(occupancy: int, building_type: BuildingType) -> str:
    """
    Return an occupancy-tier suffix string for *building_type* at *occupancy*.

    Three buckets are defined for building types listed in ``_OCCUPANCY_TYPES``:

    * ``""``       — zero occupancy (no suffix; base sprite)
    * ``"_mid"``   — 1 – 50 % capacity (reserved for Phase 5 animation sprites)
    * ``"_high"``  — > 50 % capacity (reserved for Phase 5 animation sprites)

    Phase 1 note: occupancy-variant sprites are not yet authored, so the
    non-empty suffixes are returned only when the building type supports them.
    :class:`TileAtlas` will return a magenta fallback for any unknown ID,
    making missing occupancy sprites immediately visible during development.
    Terrain types (EMPTY_LOT, PARK) and civic buildings always return ``""``.
    Negative occupancy values are treated as zero (returns ``""``).
    """
    if building_type not in _OCCUPANCY_TYPES or occupancy <= 0:
        return ""
    # Capacity upper bound is intentionally absent from the data model in
    # Phase 1; use a fixed reference value of 100 as a reasonable default.
    # max(1, ...) guards against any future change that might set this to 0.
    _CAPACITY_REF = max(1, 100)
    fraction = min(occupancy / _CAPACITY_REF, 1.0)
    if fraction > 0.5:
        return "_high"
    return "_mid"


class BuildingSpriteSelector:
    """
    Maps :class:`~src.city.building.Building` state
    (type + condition + occupancy) to a sprite atlas tile ID.

    Condition ranges
    ----------------
    * ``condition < 0.3``  → ``<base>_damaged``
    * ``condition >= 0.3`` → ``<base>``

    Occupancy buckets (for types in ``_OCCUPANCY_TYPES``)
    ------------------------------------------------------
    * ``occupancy == 0``              → no suffix (base sprite)
    * ``1 ≤ occupancy ≤ 50 % cap``   → ``_mid`` suffix
    * ``occupancy > 50 % cap``        → ``_high`` suffix

    Damaged condition takes priority over occupancy bucketing: a damaged
    building always returns the ``_damaged`` variant regardless of occupancy.
    """

    def get_sprite_id(self, building: Building, night_mode: bool = False) -> str:
        """
        Return the atlas tile ID for *building*.

        Uses a ``_damaged`` variant when ``condition < 0.3``, except for
        terrain-only types (EMPTY_LOT, PARK) that have no damage state.
        For non-terrain types with positive occupancy the occupancy bucket
        suffix is appended (``_mid`` or ``_high``) when available.

        When *night_mode* is ``True`` and the building type is in
        ``_OCCUPANCY_TYPES`` (residential + commercial) and occupancy > 0,
        a ``_lit`` suffix is appended to signal that lit-window sprites
        should be used.  Damaged condition takes priority over night mode.
        :class:`TileAtlas` returns a magenta fallback for unknown ``_lit``
        IDs, making missing sprites visible during development.
        """
        base = _SPRITE_MAP.get(building.building_type, "terrain_grass_0")
        _terrain_types = (BuildingType.EMPTY_LOT, BuildingType.PARK)
        if building.condition < 0.3 and building.building_type not in _terrain_types:
            return f"{base}_damaged"
        if (night_mode
                and building.building_type in _OCCUPANCY_TYPES
                and building.occupancy > 0):
            return f"{base}_lit"
        occ_suffix = _occupancy_bucket(building.occupancy, building.building_type)
        if occ_suffix:
            return f"{base}{occ_suffix}"
        return base
