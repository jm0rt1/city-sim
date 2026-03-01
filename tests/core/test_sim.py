import io
import random
import unittest
from unittest.mock import patch

from src.city.city import City
from src.city.population.population import Pop, Population
from src.simulation.sim import Sim


class TestPopulationIterable(unittest.TestCase):
    def test_iteration(self):
        pop = Population.from_list([Pop(), Pop()])
        count = sum(1 for _ in pop)
        self.assertEqual(count, 2)

    def test_len(self):
        pop = Population.from_list([Pop(), Pop(), Pop()])
        self.assertEqual(len(pop), 3)

    def test_append(self):
        pop = Population()
        pop.append(Pop())
        self.assertEqual(len(pop), 1)


class TestCityHappinessTracker(unittest.TestCase):
    def test_happiness_tracker_initialized(self):
        city = City()
        self.assertIsNotNone(city.happiness_tracker)

    def test_happiness_tracker_after_advance_day(self):
        city = City()
        city.on_advance_day()
        avg = city.happiness_tracker.get_average_happiness()
        self.assertIsInstance(avg, float)


class TestSimDayCounter(unittest.TestCase):
    def setUp(self):
        random.seed(0)
        self.sim = Sim(city=City())

    def test_day_starts_at_zero(self):
        self.assertEqual(self.sim.day, 0)

    def test_advance_day_increments_counter(self):
        self.sim.advance_day()
        self.assertEqual(self.sim.day, 1)
        self.sim.advance_day()
        self.assertEqual(self.sim.day, 2)


class TestSimDisplayOutput(unittest.TestCase):
    def setUp(self):
        random.seed(0)
        self.sim = Sim(city=City())

    def test_display_city_info_contains_day(self):
        with patch('sys.stdout', new_callable=io.StringIO) as mock_out:
            self.sim.display_city_info()
            output = mock_out.getvalue()
        self.assertIn("Day 0", output)
        self.assertIn("Population", output)
        self.assertIn("Avg Happiness", output)

    def test_display_run_summary_contains_days_simulated(self):
        self.sim.advance_day()
        with patch('sys.stdout', new_callable=io.StringIO) as mock_out:
            self.sim.display_run_summary()
            output = mock_out.getvalue()
        self.assertIn("Run Summary", output)
        self.assertIn("Total Days Simulated:  1", output)
        self.assertIn("Final Population", output)

    def test_display_city_info_shows_infrastructure(self):
        with patch('sys.stdout', new_callable=io.StringIO) as mock_out:
            self.sim.display_city_info()
            output = mock_out.getvalue()
        self.assertIn("Water Facilities", output)
        self.assertIn("Elec. Facilities", output)
        self.assertIn("Housing Units", output)


class TestSimRollForLeavers(unittest.TestCase):
    def test_leavers_do_not_corrupt_population(self):
        """Ensure roll_for_leavers properly uses remove_pop, not list replacement."""
        city = City(population=Population.from_list([Pop() for _ in range(10)]))
        sim = Sim(city=city)
        # Force negative happiness so leavers logic triggers
        for pop in city.population:
            pop.overall_happiness = -100
        city.happiness_tracker.update_happiness(city.population)
        initial_count = len(city.population)
        random.seed(1)
        sim.roll_for_leavers()
        # Population should still be a Population object (not replaced with a list)
        self.assertIsInstance(city.population, Population)
        self.assertLessEqual(len(city.population), initial_count)


if __name__ == "__main__":
    unittest.main()
