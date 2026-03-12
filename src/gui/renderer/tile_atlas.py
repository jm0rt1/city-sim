from __future__ import annotations

from pathlib import Path

import pygame

# Placeholder fill colors (R, G, B) per tile ID.
_PLACEHOLDER_COLORS: dict[str, tuple[int, int, int]] = {
    "terrain_grass_0":              (106, 168,  79),
    "terrain_park_0":               ( 56, 118,  29),
    "terrain_road_h":               (100, 100, 100),
    "terrain_road_v":               ( 80,  80,  80),
    "terrain_water_0":              ( 66, 133, 244),
    "building_res_small":           (255, 200, 100),
    "building_res_medium":          (255, 153,  51),
    "building_res_large":           (255, 111,   0),
    "building_commercial":          (100, 181, 246),
    "building_industrial":          (158, 158, 158),
    "building_city_hall":           (149, 117, 205),
    "building_hospital":            (239,  83,  80),
    "building_school":              (255, 238,  88),
    "building_fire_station":        (244,  67,  54),
    "building_police_station":      ( 66,  66, 160),
    "building_power_plant":         ( 78,  52,  46),
    # Damaged variants
    "building_res_small_damaged":   (180, 140,  70),
    "building_res_medium_damaged":  (180, 107,  36),
    "building_res_large_damaged":   (180,  77,   0),
    "building_commercial_damaged":  ( 70, 127, 172),
    "building_industrial_damaged":  (110, 110, 110),
    "building_city_hall_damaged":   (104,  82, 144),
    "building_hospital_damaged":    (167,  58,  56),
    "building_school_damaged":      (178, 167,  62),
    "building_fire_station_damaged":(171,  47,  38),
    "building_police_station_damaged":(46, 46, 112),
    "building_power_plant_damaged": ( 54,  36,  32),
}


class TileAtlas:
    """
    Manages sprite sheets and provides per-tile :class:`pygame.Surface` lookup.

    If the atlas image is absent on disk the class generates simple
    colored diamond placeholders so the renderer always has something to draw.
    """

    def __init__(self, tile_width: int = 64, tile_height: int = 32) -> None:
        self._tw = tile_width
        self._th = tile_height
        self._tiles: dict[str, pygame.Surface] = {}

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def load_atlas(self, path: str | Path) -> None:
        """
        Load a packed atlas image from *path*.

        Falls back to procedurally-generated placeholder tiles when the file
        does not exist, so the renderer works out-of-the-box without assets.
        """
        atlas_path = Path(path)
        if atlas_path.exists():
            self._load_from_image(atlas_path)
        else:
            self._generate_placeholders()

    def get_tile(self, tile_id: str) -> pygame.Surface:
        """
        Return the :class:`pygame.Surface` for *tile_id*.

        Falls back to a bright-magenta diamond for unknown IDs so missing
        tiles are immediately visible during development.
        """
        if not self._tiles:
            self._generate_placeholders()
        if tile_id not in self._tiles:
            self._tiles[tile_id] = self._make_diamond((255, 0, 255))
        return self._tiles[tile_id]

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _load_from_image(self, path: Path) -> None:
        """Load tiles from a packed PNG atlas (full implementation placeholder)."""
        # Full atlas parsing requires a JSON sidecar layout definition.
        # Until that is authored, fall through to placeholder generation.
        self._generate_placeholders()

    def _generate_placeholders(self) -> None:
        """Create simple colored isometric diamond tiles for every known ID."""
        for tile_id, color in _PLACEHOLDER_COLORS.items():
            self._tiles[tile_id] = self._make_diamond(color)

    def _make_diamond(self, color: tuple[int, int, int]) -> pygame.Surface:
        """Draw a filled isometric diamond onto a transparent Surface."""
        surf = pygame.Surface((self._tw, self._th), pygame.SRCALPHA)
        w, h = self._tw, self._th
        points = [
            (w // 2, 0),
            (w,      h // 2),
            (w // 2, h),
            (0,      h // 2),
        ]
        pygame.draw.polygon(surf, (*color, 255), points)
        pygame.draw.polygon(surf, (0, 0, 0, 180), points, 1)
        return surf
