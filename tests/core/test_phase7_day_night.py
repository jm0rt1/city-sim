"""
Phase 7 unit tests — DayNightCycle and BuildingSpriteSelector night_mode.

All tests here are pygame-free (DayNightCycle.get_ambient_overlay is the only
method that requires pygame, and it is not tested in this file).
"""
from __future__ import annotations

import unittest

from src.city.building import Building, BuildingType
from src.gui.renderer.building_sprite_selector import BuildingSpriteSelector
from src.gui.renderer.day_night_cycle import DayNightCycle


class TestDayNightCycle(unittest.TestCase):
    """Behaviour tests for DayNightCycle (pure Python, no display needed)."""

    def setUp(self) -> None:
        self.dnc = DayNightCycle()

    # ------------------------------------------------------------------
    # get_time
    # ------------------------------------------------------------------

    def test_noon_returns_half(self) -> None:
        """get_time(12) should return 0.5 with the default ticks_per_day=24."""
        self.assertAlmostEqual(self.dnc.get_time(12), 0.5)

    def test_time_wraps(self) -> None:
        """get_time(24) must equal get_time(0) == 0.0."""
        self.assertEqual(self.dnc.get_time(24), 0.0)
        self.assertEqual(self.dnc.get_time(0), 0.0)

    def test_time_wraps_multiple_days(self) -> None:
        """get_time(48) must equal get_time(0) == 0.0."""
        self.assertEqual(self.dnc.get_time(48), 0.0)

    def test_dawn_returns_quarter(self) -> None:
        """get_time(6) should return 0.25 with ticks_per_day=24."""
        self.assertAlmostEqual(self.dnc.get_time(6), 0.25)

    def test_dusk_returns_three_quarters(self) -> None:
        """get_time(18) should return 0.75 with ticks_per_day=24."""
        self.assertAlmostEqual(self.dnc.get_time(18), 0.75)

    # ------------------------------------------------------------------
    # is_night
    # ------------------------------------------------------------------

    def test_is_night_at_midnight(self) -> None:
        """is_night(0.0) must be True (midnight)."""
        self.assertTrue(self.dnc.is_night(0.0))

    def test_is_not_night_at_noon(self) -> None:
        """is_night(0.5) must be False (noon)."""
        self.assertFalse(self.dnc.is_night(0.5))

    def test_is_night_before_dawn(self) -> None:
        """is_night(0.1) must be True (early morning, still night)."""
        self.assertTrue(self.dnc.is_night(0.1))

    def test_is_night_at_dusk(self) -> None:
        """is_night(0.75) must be True (dusk boundary → night)."""
        self.assertTrue(self.dnc.is_night(0.75))

    def test_is_night_after_dusk(self) -> None:
        """is_night(0.9) must be True (late evening)."""
        self.assertTrue(self.dnc.is_night(0.9))

    def test_is_not_night_at_dawn(self) -> None:
        """is_night(0.25) must be False (just past dawn, day begins)."""
        self.assertFalse(self.dnc.is_night(0.25))

    # ------------------------------------------------------------------
    # get_sky_color
    # ------------------------------------------------------------------

    def test_sky_color_is_tuple_of_three_ints(self) -> None:
        """get_sky_color must return a 3-tuple of ints."""
        color = self.dnc.get_sky_color(0.5)
        self.assertIsInstance(color, tuple)
        self.assertEqual(len(color), 3)
        for channel in color:
            self.assertIsInstance(channel, int)

    def test_sky_color_channels_in_range(self) -> None:
        """All colour channels must be in [0, 255]."""
        for tick in range(24):
            t = self.dnc.get_time(tick)
            r, g, b = self.dnc.get_sky_color(t)
            self.assertGreaterEqual(r, 0)
            self.assertLessEqual(r, 255)
            self.assertGreaterEqual(g, 0)
            self.assertLessEqual(g, 255)
            self.assertGreaterEqual(b, 0)
            self.assertLessEqual(b, 255)

    def test_sky_color_noon_is_blue_toned(self) -> None:
        """Noon sky should be blue-dominant (day sky)."""
        r, g, b = self.dnc.get_sky_color(0.5)
        self.assertGreater(b, r, "Noon sky should have more blue than red")

    def test_sky_color_midnight_is_dark(self) -> None:
        """Midnight sky should be very dark (low values)."""
        r, g, b = self.dnc.get_sky_color(0.0)
        self.assertLess(r, 50)
        self.assertLess(g, 50)


class TestBuildingSpriteSelectorNightMode(unittest.TestCase):
    """Tests for BuildingSpriteSelector.get_sprite_id() night_mode parameter."""

    def setUp(self) -> None:
        self.selector = BuildingSpriteSelector()

    def test_lit_suffix_for_occupied_residential_at_night(self) -> None:
        """Occupied residential building should return a _lit sprite ID at night."""
        building = Building(BuildingType.RESIDENTIAL_SMALL)
        building.occupancy = 10
        sprite_id = self.selector.get_sprite_id(building, night_mode=True)
        self.assertTrue(
            sprite_id.endswith("_lit"),
            f"Expected _lit suffix, got: {sprite_id}",
        )

    def test_lit_suffix_for_occupied_commercial_at_night(self) -> None:
        """Occupied commercial building should return a _lit sprite ID at night."""
        building = Building(BuildingType.COMMERCIAL)
        building.occupancy = 5
        sprite_id = self.selector.get_sprite_id(building, night_mode=True)
        self.assertTrue(
            sprite_id.endswith("_lit"),
            f"Expected _lit suffix, got: {sprite_id}",
        )

    def test_no_lit_suffix_for_unoccupied_at_night(self) -> None:
        """Unoccupied building must NOT get a _lit suffix even at night."""
        building = Building(BuildingType.RESIDENTIAL_SMALL)
        building.occupancy = 0
        sprite_id = self.selector.get_sprite_id(building, night_mode=True)
        self.assertFalse(
            sprite_id.endswith("_lit"),
            f"Unoccupied building should not be lit, got: {sprite_id}",
        )

    def test_damaged_takes_priority_over_night(self) -> None:
        """Damaged building must return _damaged variant, not _lit, at night."""
        building = Building(BuildingType.RESIDENTIAL_SMALL)
        building.occupancy = 20
        building.condition = 0.1  # damaged
        sprite_id = self.selector.get_sprite_id(building, night_mode=True)
        self.assertTrue(
            sprite_id.endswith("_damaged"),
            f"Damaged building should use _damaged variant, got: {sprite_id}",
        )
        self.assertFalse(
            sprite_id.endswith("_lit"),
            f"Damaged building must not be lit, got: {sprite_id}",
        )

    def test_industrial_no_lit_at_night(self) -> None:
        """Industrial buildings are not in _OCCUPANCY_TYPES, so no _lit suffix."""
        building = Building(BuildingType.INDUSTRIAL)
        building.occupancy = 50
        sprite_id = self.selector.get_sprite_id(building, night_mode=True)
        self.assertFalse(
            sprite_id.endswith("_lit"),
            f"Industrial should not be lit at night, got: {sprite_id}",
        )

    def test_no_night_mode_returns_same_as_day(self) -> None:
        """With night_mode=False, result must equal the default (day) sprite."""
        building = Building(BuildingType.RESIDENTIAL_MEDIUM)
        building.occupancy = 30
        day_id = self.selector.get_sprite_id(building, night_mode=False)
        default_id = self.selector.get_sprite_id(building)
        self.assertEqual(day_id, default_id)

    def test_civic_no_lit_at_night(self) -> None:
        """Civic buildings are not in _OCCUPANCY_TYPES, so no _lit suffix."""
        building = Building(BuildingType.CIVIC_HOSPITAL)
        sprite_id = self.selector.get_sprite_id(building, night_mode=True)
        self.assertFalse(
            sprite_id.endswith("_lit"),
            f"Civic building should not be lit at night, got: {sprite_id}",
        )


if __name__ == "__main__":
    unittest.main()
