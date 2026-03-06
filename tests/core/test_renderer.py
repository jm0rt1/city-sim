"""
Tests for the pygame-free renderer components.

Intentionally avoids importing any module that requires pygame so that the
test suite runs in headless CI environments without a display.
"""
import inspect
import unittest

from src.city.building import Building, BuildingType, District
from src.city.city import City
from src.city.population.population import Population, Pop
from src.gui.renderer.building_render_state import BuildingRenderState
from src.gui.renderer.building_sprite_selector import BuildingSpriteSelector
from src.gui.renderer.city_grid_layout import ICityGridLayout, InfrastructureCityGridLayout
from src.gui.renderer.isometric_grid_mapper import IsometricGridMapper
from src.shared.graphics_settings import GraphicsSettings


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


if __name__ == "__main__":
    unittest.main()
