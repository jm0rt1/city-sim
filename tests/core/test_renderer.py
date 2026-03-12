"""
Tests for the pygame-free renderer components.

Intentionally avoids importing any module that requires pygame so that the
test suite runs in headless CI environments without a display.
"""
from __future__ import annotations

import inspect
import unittest

try:
    import pygame
    _HAS_PYGAME = True
except ImportError:
    _HAS_PYGAME = False

from src.city.building import Building, BuildingType, District
from src.city.city import City
from src.city.population.population import Population, Pop
from src.gui.renderer.building_render_state import BuildingRenderState
from src.gui.renderer.building_sprite_selector import BuildingSpriteSelector
from src.gui.renderer.city_grid_layout import ICityGridLayout, InfrastructureCityGridLayout
from src.gui.renderer.isometric_grid_mapper import IsometricGridMapper
from src.gui.renderer.placeable_city_grid_layout import PlaceableCityGridLayout
from src.shared.graphics_settings import GraphicsSettings

if _HAS_PYGAME:
    from src.gui.renderer.action_panel import ActionPanel


class TestBuildingType(unittest.TestCase):
    """BuildingType enum completeness checks."""

    def test_all_expected_names_present(self):
        expected = {
            "EMPTY_LOT",
            "RESIDENTIAL_SMALL",
            "RESIDENTIAL_MEDIUM",
            "RESIDENTIAL_LARGE",
            "COMMERCIAL",
            "INDUSTRIAL",
            "CIVIC_CITY_HALL",
            "CIVIC_HOSPITAL",
            "CIVIC_SCHOOL",
            "CIVIC_FIRE_STATION",
            "CIVIC_POLICE_STATION",
            "CIVIC_POWER_PLANT",
            "PARK",
        }
        actual = {bt.name for bt in BuildingType}
        self.assertEqual(actual, expected)


class TestBuilding(unittest.TestCase):

    def test_default_condition_is_pristine(self):
        b = Building(BuildingType.COMMERCIAL)
        self.assertEqual(b.condition, 1.0)

    def test_default_occupancy_is_zero(self):
        b = Building(BuildingType.RESIDENTIAL_SMALL)
        self.assertEqual(b.occupancy, 0)


class TestDistrict(unittest.TestCase):

    def test_empty_district_has_no_buildings(self):
        d = District(name="North")
        self.assertEqual(d.buildings, [])

    def test_district_stores_buildings(self):
        buildings = [Building(BuildingType.PARK), Building(BuildingType.COMMERCIAL)]
        d = District(name="East", buildings=buildings)
        self.assertEqual(len(d.buildings), 2)


class TestBuildingRenderState(unittest.TestCase):

    def test_creation_stores_building_and_position(self):
        building = Building(BuildingType.COMMERCIAL)
        brs = BuildingRenderState(building=building, grid_position=(3, 5))
        self.assertEqual(brs.grid_position, (3, 5))
        self.assertIs(brs.building, building)

    def test_different_positions_are_independent(self):
        b1 = Building(BuildingType.PARK)
        b2 = Building(BuildingType.INDUSTRIAL)
        brs1 = BuildingRenderState(b1, (0, 0))
        brs2 = BuildingRenderState(b2, (1, 1))
        self.assertNotEqual(brs1.grid_position, brs2.grid_position)


class TestIsometricGridMapper(unittest.TestCase):

    def setUp(self):
        settings = GraphicsSettings(tile_width=64, tile_height=32)
        self._mapper = IsometricGridMapper(settings, origin_x=0, origin_y=0)

    def test_origin_tile_maps_to_origin(self):
        x, y = self._mapper.world_to_screen(0, 0)
        self.assertEqual(x, 0)
        self.assertEqual(y, 0)

    def test_col_one_row_zero(self):
        # col=1, row=0 → x = 1*32, y = 1*16
        x, y = self._mapper.world_to_screen(1, 0)
        self.assertEqual(x, 32)
        self.assertEqual(y, 16)

    def test_col_zero_row_one(self):
        # col=0, row=1 → x = -32, y = 16
        x, y = self._mapper.world_to_screen(0, 1)
        self.assertEqual(x, -32)
        self.assertEqual(y, 16)

    def test_origin_offset(self):
        settings = GraphicsSettings(tile_width=64, tile_height=32)
        mapper = IsometricGridMapper(settings, origin_x=100, origin_y=50)
        x, y = mapper.world_to_screen(0, 0)
        self.assertEqual(x, 100)
        self.assertEqual(y, 50)

    def test_symmetry_col_and_row(self):
        # (2, 0) and (0, 2) should be symmetric around the origin y-axis
        x1, y1 = self._mapper.world_to_screen(2, 0)
        x2, y2 = self._mapper.world_to_screen(0, 2)
        self.assertEqual(abs(x1), abs(x2))
        self.assertEqual(y1, y2)


class TestBuildingSpriteSelector(unittest.TestCase):

    def setUp(self):
        self._selector = BuildingSpriteSelector()

    def test_every_building_type_returns_a_string(self):
        for btype in BuildingType:
            building = Building(building_type=btype)
            sprite_id = self._selector.get_sprite_id(building)
            self.assertIsInstance(sprite_id, str)
            self.assertGreater(len(sprite_id), 0, f"Empty sprite id for {btype}")

    def test_damaged_building_gets_damaged_suffix(self):
        building = Building(BuildingType.RESIDENTIAL_SMALL, condition=0.1)
        sprite_id = self._selector.get_sprite_id(building)
        self.assertIn("damaged", sprite_id)

    def test_healthy_building_has_no_damaged_suffix(self):
        building = Building(BuildingType.RESIDENTIAL_SMALL, condition=0.8)
        sprite_id = self._selector.get_sprite_id(building)
        self.assertNotIn("damaged", sprite_id)

    def test_park_never_gets_damaged_sprite(self):
        building = Building(BuildingType.PARK, condition=0.0)
        sprite_id = self._selector.get_sprite_id(building)
        self.assertNotIn("damaged", sprite_id)

    def test_empty_lot_never_gets_damaged_sprite(self):
        building = Building(BuildingType.EMPTY_LOT, condition=0.0)
        sprite_id = self._selector.get_sprite_id(building)
        self.assertNotIn("damaged", sprite_id)

    def test_condition_boundary_below_threshold(self):
        # Exactly at 0.3 should NOT trigger damaged (condition < 0.3)
        building = Building(BuildingType.COMMERCIAL, condition=0.3)
        sprite_id = self._selector.get_sprite_id(building)
        self.assertNotIn("damaged", sprite_id)

    def test_condition_just_below_threshold(self):
        building = Building(BuildingType.COMMERCIAL, condition=0.29)
        sprite_id = self._selector.get_sprite_id(building)
        self.assertIn("damaged", sprite_id)

    # --- Occupancy bucket tests ---

    def test_zero_occupancy_returns_base_sprite(self):
        building = Building(BuildingType.RESIDENTIAL_SMALL, condition=1.0, occupancy=0)
        sprite_id = self._selector.get_sprite_id(building)
        self.assertEqual(sprite_id, "building_res_small")

    def test_low_occupancy_returns_mid_suffix(self):
        # 10 / 100 = 10 % → _mid bucket
        building = Building(BuildingType.RESIDENTIAL_SMALL, condition=1.0, occupancy=10)
        sprite_id = self._selector.get_sprite_id(building)
        self.assertIn("_mid", sprite_id)

    def test_high_occupancy_returns_high_suffix(self):
        # 60 / 100 = 60 % → _high bucket
        building = Building(BuildingType.RESIDENTIAL_SMALL, condition=1.0, occupancy=60)
        sprite_id = self._selector.get_sprite_id(building)
        self.assertIn("_high", sprite_id)

    def test_occupancy_boundary_fifty_percent(self):
        # 50 / 100 = 50 % is NOT > 0.5, so _mid
        building = Building(BuildingType.COMMERCIAL, condition=1.0, occupancy=50)
        sprite_id = self._selector.get_sprite_id(building)
        self.assertIn("_mid", sprite_id)

    def test_damaged_overrides_occupancy_bucket(self):
        # condition < 0.3 takes priority over occupancy
        building = Building(BuildingType.RESIDENTIAL_SMALL, condition=0.1, occupancy=80)
        sprite_id = self._selector.get_sprite_id(building)
        self.assertIn("_damaged", sprite_id)
        self.assertNotIn("_high", sprite_id)
        self.assertNotIn("_mid", sprite_id)

    def test_civic_building_ignores_occupancy(self):
        # Civic buildings have no occupancy variants
        building = Building(BuildingType.CIVIC_CITY_HALL, condition=1.0, occupancy=99)
        sprite_id = self._selector.get_sprite_id(building)
        self.assertNotIn("_mid", sprite_id)
        self.assertNotIn("_high", sprite_id)

    def test_park_ignores_occupancy(self):
        building = Building(BuildingType.PARK, condition=1.0, occupancy=99)
        sprite_id = self._selector.get_sprite_id(building)
        self.assertNotIn("_mid", sprite_id)
        self.assertNotIn("_high", sprite_id)

    def test_negative_occupancy_treated_as_zero(self):
        building = Building(BuildingType.RESIDENTIAL_SMALL, condition=1.0, occupancy=-5)
        sprite_id = self._selector.get_sprite_id(building)
        self.assertEqual(sprite_id, "building_res_small")

class TestGraphicsSettings(unittest.TestCase):

    def test_default_tile_dimensions(self):
        s = GraphicsSettings()
        self.assertEqual(s.tile_width, 64)
        self.assertEqual(s.tile_height, 32)

    def test_default_window_dimensions(self):
        s = GraphicsSettings()
        self.assertEqual(s.window_width, 1280)
        self.assertEqual(s.window_height, 720)

    def test_custom_values(self):
        s = GraphicsSettings(tile_width=32, tile_height=16, fps_cap=30)
        self.assertEqual(s.tile_width, 32)
        self.assertEqual(s.tile_height, 16)
        self.assertEqual(s.fps_cap, 30)


class TestInfrastructureCityGridLayout(unittest.TestCase):
    """Tests for the OOP grid layout strategy."""

    def _make_city(self, electricity=1, water=1, housing=0):
        city = City(population=Population.from_list([Pop()]))
        city.electricity_facilities = electricity
        city.water_facilities = water
        city.housing_units = housing
        return city

    def test_returns_list_of_building_render_states(self):
        layout = InfrastructureCityGridLayout(cols=4, rows=4)
        city = self._make_city()
        states = layout.build_render_states(city)
        self.assertTrue(all(isinstance(s, BuildingRenderState) for s in states))

    def test_fills_entire_grid(self):
        layout = InfrastructureCityGridLayout(cols=4, rows=4)
        city = self._make_city(electricity=1, water=1, housing=0)
        states = layout.build_render_states(city)
        self.assertEqual(len(states), 4 * 4)

    def test_positions_are_unique(self):
        layout = InfrastructureCityGridLayout(cols=4, rows=4)
        city = self._make_city(electricity=2, water=2, housing=5)
        states = layout.build_render_states(city)
        positions = [s.grid_position for s in states]
        self.assertEqual(len(positions), len(set(positions)))

    def test_electricity_places_power_plants(self):
        layout = InfrastructureCityGridLayout(cols=4, rows=4)
        city = self._make_city(electricity=3, water=0, housing=0)
        states = layout.build_render_states(city)
        power_plants = [
            s for s in states
            if s.building.building_type == BuildingType.CIVIC_POWER_PLANT
        ]
        self.assertEqual(len(power_plants), 3)

    def test_housing_places_residential_buildings(self):
        layout = InfrastructureCityGridLayout(cols=8, rows=8)
        city = self._make_city(electricity=0, water=0, housing=26)
        # 26 units = 1 large (20) + 1 medium (5) + 1 small (1)
        states = layout.build_render_states(city)
        large = [s for s in states if s.building.building_type == BuildingType.RESIDENTIAL_LARGE]
        medium = [s for s in states if s.building.building_type == BuildingType.RESIDENTIAL_MEDIUM]
        small = [s for s in states if s.building.building_type == BuildingType.RESIDENTIAL_SMALL]
        self.assertEqual(len(large), 1)
        self.assertEqual(len(medium), 1)
        self.assertEqual(len(small), 1)

    def test_interface_is_abstract(self):
        self.assertTrue(inspect.isabstract(ICityGridLayout))

    def test_custom_layout_is_pluggable(self):
        """A custom ICityGridLayout subclass can be injected into CityRenderer."""

        class FixedLayout(ICityGridLayout):
            def build_render_states(self, city):
                return [BuildingRenderState(Building(BuildingType.PARK), (0, 0))]

        layout = FixedLayout()
        city = self._make_city()
        states = layout.build_render_states(city)
        self.assertEqual(len(states), 1)
        self.assertEqual(states[0].grid_position, (0, 0))


@unittest.skipUnless(_HAS_PYGAME, "pygame-ce not installed")
class TestActionPanelCallbacks(unittest.TestCase):
    """
    Tests for ActionPanel callback dispatch.

    These tests exercise trigger_action() and handle_keydown() which are
    pure Python and do not require a pygame display (no draw() called).
    """

    def _make_panel(self) -> tuple[ActionPanel, dict[str, list[int]]]:
        """Return a panel and a call-count registry keyed by action_key."""
        counts: dict[str, list[int]] = {
            "add_water":    [0],
            "add_elec":     [0],
            "add_housing":  [0],
            "toggle_pause": [0],
        }

        def _make_counter(key: str):
            def _increment():
                counts[key][0] += 1
            return _increment

        actions = {key: _make_counter(key) for key in counts}
        panel = ActionPanel(x=0, y=0, actions=actions, is_paused=lambda: False)
        return panel, counts

    def test_trigger_known_action_returns_true(self):
        panel, _ = self._make_panel()
        self.assertTrue(panel.trigger_action("add_water"))

    def test_trigger_unknown_action_returns_false(self):
        panel, _ = self._make_panel()
        self.assertFalse(panel.trigger_action("nonexistent"))

    def test_trigger_action_calls_callback(self):
        panel, counts = self._make_panel()
        panel.trigger_action("add_water")
        self.assertEqual(counts["add_water"][0], 1)

    def test_trigger_action_sets_notification(self):
        panel, _ = self._make_panel()
        panel.trigger_action("add_water")
        self.assertIn("Water", panel._last_msg)
        self.assertGreater(panel._msg_frames, 0)

    def test_handle_keydown_w_fires_add_water(self):
        panel, counts = self._make_panel()
        panel.handle_keydown(pygame.K_w)
        self.assertEqual(counts["add_water"][0], 1)

    def test_handle_keydown_e_fires_add_elec(self):
        panel, counts = self._make_panel()
        panel.handle_keydown(pygame.K_e)
        self.assertEqual(counts["add_elec"][0], 1)

    def test_handle_keydown_h_fires_add_housing(self):
        panel, counts = self._make_panel()
        panel.handle_keydown(pygame.K_h)
        self.assertEqual(counts["add_housing"][0], 1)

    def test_handle_keydown_p_fires_toggle_pause(self):
        panel, counts = self._make_panel()
        panel.handle_keydown(pygame.K_p)
        self.assertEqual(counts["toggle_pause"][0], 1)

    def test_handle_keydown_unknown_key_returns_false(self):
        panel, _ = self._make_panel()
        self.assertFalse(panel.handle_keydown(pygame.K_z))

    def test_handle_keydown_returns_true_on_match(self):
        panel, _ = self._make_panel()
        self.assertTrue(panel.handle_keydown(pygame.K_w))

    def test_each_button_def_has_a_registered_action(self):
        panel, counts = self._make_panel()
        for btn in panel._buttons:
            with self.subTest(action_key=btn.action_key):
                self.assertIn(btn.action_key, panel._actions)


class TestPauseController(unittest.TestCase):
    """Tests for the _PauseController class in src/main.py."""

    def _make_controller(self):
        from src.main import _PauseController
        return _PauseController()

    def test_initially_not_paused(self):
        ctrl = self._make_controller()
        self.assertFalse(ctrl.is_paused())

    def test_toggle_pauses(self):
        ctrl = self._make_controller()
        ctrl.toggle()
        self.assertTrue(ctrl.is_paused())

    def test_toggle_twice_resumes(self):
        ctrl = self._make_controller()
        ctrl.toggle()
        ctrl.toggle()
        self.assertFalse(ctrl.is_paused())

    def test_is_paused_thread_safe(self):
        """Multiple threads toggling should not raise exceptions."""
        import threading
        ctrl = self._make_controller()
        errors: list[Exception] = []

        def worker():
            try:
                for _ in range(100):
                    ctrl.toggle()
                    _ = ctrl.is_paused()
            except Exception as exc:
                errors.append(exc)

        threads = [threading.Thread(target=worker) for _ in range(4)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        self.assertEqual(errors, [])


class TestPlaceableCityGridLayout(unittest.TestCase):
    """Tests for the free-placement grid layout strategy."""

    def _make_city(self) -> City:
        return City(population=Population.from_list([Pop()]))

    def _make_layout(self, cols: int = 4, rows: int = 4) -> PlaceableCityGridLayout:
        return PlaceableCityGridLayout(cols=cols, rows=rows)

    def test_fills_entire_grid_with_background(self):
        layout = self._make_layout(cols=4, rows=4)
        states = layout.build_render_states(self._make_city())
        self.assertEqual(len(states), 16)

    def test_positions_are_unique(self):
        layout = self._make_layout(cols=4, rows=4)
        states = layout.build_render_states(self._make_city())
        positions = [s.grid_position for s in states]
        self.assertEqual(len(positions), len(set(positions)))

    def test_place_building_sets_type(self):
        layout = self._make_layout()
        layout.place_building(1, 1, BuildingType.COMMERCIAL)
        b = layout.get_building(1, 1)
        self.assertIsNotNone(b)
        assert b is not None
        self.assertEqual(b.building_type, BuildingType.COMMERCIAL)

    def test_place_building_appears_in_render_states(self):
        layout = self._make_layout(cols=4, rows=4)
        layout.place_building(2, 2, BuildingType.PARK)
        states = layout.build_render_states(self._make_city())
        placed = next(s for s in states if s.grid_position == (2, 2))
        self.assertEqual(placed.building.building_type, BuildingType.PARK)

    def test_place_empty_lot_clears_cell(self):
        layout = self._make_layout()
        layout.place_building(0, 0, BuildingType.INDUSTRIAL)
        layout.place_building(0, 0, BuildingType.EMPTY_LOT)
        self.assertIsNone(layout.get_building(0, 0))

    def test_out_of_bounds_returns_false(self):
        layout = self._make_layout(cols=4, rows=4)
        self.assertFalse(layout.place_building(10, 10, BuildingType.PARK))

    def test_in_bounds_returns_correct_values(self):
        layout = self._make_layout(cols=4, rows=4)
        self.assertTrue(layout.in_bounds(0, 0))
        self.assertTrue(layout.in_bounds(3, 3))
        self.assertFalse(layout.in_bounds(4, 0))
        self.assertFalse(layout.in_bounds(0, 4))
        self.assertFalse(layout.in_bounds(-1, 0))

    def test_replace_existing_building(self):
        layout = self._make_layout()
        layout.place_building(1, 1, BuildingType.COMMERCIAL)
        layout.place_building(1, 1, BuildingType.PARK)
        b = layout.get_building(1, 1)
        assert b is not None
        self.assertEqual(b.building_type, BuildingType.PARK)

    def test_multiple_buildings_all_appear(self):
        layout = self._make_layout(cols=4, rows=4)
        layout.place_building(0, 0, BuildingType.CIVIC_CITY_HALL)
        layout.place_building(3, 3, BuildingType.CIVIC_SCHOOL)
        states = layout.build_render_states(self._make_city())
        types_at = {
            s.grid_position: s.building.building_type for s in states
        }
        self.assertEqual(types_at[(0, 0)], BuildingType.CIVIC_CITY_HALL)
        self.assertEqual(types_at[(3, 3)], BuildingType.CIVIC_SCHOOL)

    def test_implements_interface(self):
        self.assertIsInstance(PlaceableCityGridLayout(), ICityGridLayout)


@unittest.skipUnless(_HAS_PYGAME, "pygame-ce not installed")
class TestBuildingPaletteSelection(unittest.TestCase):
    """Tests for BuildingPalette selection logic (no pygame display needed)."""

    def _make_palette(self):
        from src.gui.renderer.building_palette import BuildingPalette
        from src.gui.renderer.tile_atlas import TileAtlas
        atlas = TileAtlas(64, 32)
        return BuildingPalette(screen_w=1280, screen_h=720, atlas=atlas)

    def test_default_selection_is_residential_small(self):
        palette = self._make_palette()
        self.assertEqual(palette.selected, BuildingType.RESIDENTIAL_SMALL)

    def test_all_placeable_types_are_represented(self):
        from src.gui.renderer.building_palette import PLACEABLE_TYPES
        palette = self._make_palette()
        entry_types = {e.building_type for e in palette._entries}
        self.assertEqual(entry_types, set(PLACEABLE_TYPES))

    def test_bar_height_is_positive(self):
        palette = self._make_palette()
        self.assertGreater(palette.bar_height, 0)

    def test_bar_y_is_near_bottom_of_screen(self):
        palette = self._make_palette()
        self.assertLess(palette.bar_y, 720)
        self.assertGreater(palette.bar_y, 500)

    def test_contains_returns_true_inside_bar(self):
        palette = self._make_palette()
        inside_pos = (640, palette.bar_y + 5)
        self.assertTrue(palette.contains(inside_pos))

    def test_contains_returns_false_above_bar(self):
        palette = self._make_palette()
        above_pos = (640, palette.bar_y - 10)
        self.assertFalse(palette.contains(above_pos))


if __name__ == "__main__":
    unittest.main()
