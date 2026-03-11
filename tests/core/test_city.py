import random
import unittest

from src.city.city import City
from src.city.population.population import Pop, Population


class TestCityInit(unittest.TestCase):

    def test_default_water_facilities(self):
        city = City()
        self.assertEqual(city.water_facilities, 2)

    def test_default_electricity_facilities(self):
        city = City()
        self.assertEqual(city.electricity_facilities, 2)

    def test_default_housing_units(self):
        city = City()
        self.assertEqual(city.housing_units, 30)

    def test_happiness_tracker_initialized(self):
        city = City()
        self.assertIsNotNone(city.happiness_tracker)

    def test_happiness_tracker_is_population_tracker(self):
        population = Population.from_list([Pop()])
        city = City(population)
        self.assertIs(city.happiness_tracker, population.happiness_tracker)


class TestCityAddFacilities(unittest.TestCase):

    def setUp(self):
        self.city = City()

    def test_add_water_facilities_increases_count(self):
        self.city.add_water_facilities(3)
        self.assertEqual(self.city.water_facilities, 5)

    def test_add_water_facilities_rejects_negative(self):
        with self.assertRaises(ValueError):
            self.city.add_water_facilities(-1)

    def test_add_electricity_facilities_increases_count(self):
        self.city.add_electricity_facilities(4)
        self.assertEqual(self.city.electricity_facilities, 6)

    def test_add_electricity_facilities_rejects_negative(self):
        with self.assertRaises(ValueError):
            self.city.add_electricity_facilities(-1)

    def test_add_housing_units_increases_count(self):
        self.city.add_housing_units(10)
        self.assertEqual(self.city.housing_units, 40)

    def test_add_housing_units_rejects_negative(self):
        with self.assertRaises(ValueError):
            self.city.add_housing_units(-5)

    def test_add_zero_facilities_no_change(self):
        self.city.add_water_facilities(0)
        self.assertEqual(self.city.water_facilities, 2)


class TestCityAdvanceDay(unittest.TestCase):

    def setUp(self):
        random.seed(42)
        pops = [Pop() for _ in range(5)]
        self.population = Population.from_list(pops)
        self.city = City(self.population)

    def test_advance_day_runs_without_error(self):
        random.seed(0)
        self.city.on_advance_day()

    def test_water_distributed_to_first_pops(self):
        # 2 water facilities * 20 = 40 capacity, all 5 pops should receive water
        random.seed(0)
        self.city.on_advance_day()
        for pop in self.population:
            self.assertTrue(pop.water_received)

    def test_electricity_distributed_to_first_pops(self):
        # 2 electricity facilities * 20 = 40 capacity, all 5 pops should receive electricity
        random.seed(0)
        self.city.on_advance_day()
        for pop in self.population:
            self.assertTrue(pop.electricity_received)

    def test_housing_assigned_when_sufficient(self):
        # 30 housing units for 5 pops — all should have homes
        random.seed(0)
        self.city.on_advance_day()
        for pop in self.population:
            self.assertTrue(pop.has_home)

    def test_water_limited_when_facilities_scarce(self):
        pops = [Pop() for _ in range(50)]
        population = Population.from_list(pops)
        city = City(population)
        city.water_facilities = 1  # only 20 capacity
        random.seed(0)
        city.on_advance_day()
        with_water = sum(1 for p in population if p.water_received)
        without_water = sum(1 for p in population if not p.water_received)
        self.assertEqual(with_water, 20)
        self.assertEqual(without_water, 30)

    def test_happiness_tracker_updated_after_advance_day(self):
        random.seed(0)
        self.city.on_advance_day()
        avg = self.city.happiness_tracker.get_average_happiness()
        # After a day with sufficient resources, happiness should be positive
        self.assertGreater(avg, 0)


if __name__ == "__main__":
    unittest.main()
