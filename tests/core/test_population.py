from src.simulation.sim import Sim
from src.city.city import City
import random
import unittest

from src.city.population.happiness_tracker import HappinessTracker
from src.city.population.population import Pop, Population


class TestPop(unittest.TestCase):

    def setUp(self):
        random.seed(42)
        self.pop = Pop()

    def test_initial_happiness_is_zero(self):
        self.assertEqual(self.pop.overall_happiness, 0)

    def test_adjust_happiness_all_needs_met(self):
        self.pop.water_received = True
        self.pop.electricity_received = True
        self.pop.has_home = True
        self.pop.entertained = True
        self.pop.garbage_collected = True
        self.pop.sick = False
        random.seed(0)  # seed so random sick roll is predictable
        self.pop.adjust_happiness()
        # Max happiness without getting sick: 10+10+10+5+5 = 40
        self.assertGreaterEqual(self.pop.overall_happiness, 15)

    def test_adjust_happiness_no_needs_met(self):
        self.pop.water_received = False
        self.pop.electricity_received = False
        self.pop.has_home = False
        self.pop.entertained = False
        self.pop.garbage_collected = False
        random.seed(1)  # seed so no sick roll
        self.pop.adjust_happiness()
        # Minimum: -10-10-10-5-5 = -40
        self.assertLessEqual(self.pop.overall_happiness, -30)

    def test_adjust_happiness_partial_needs(self):
        self.pop.water_received = True
        self.pop.electricity_received = True
        self.pop.has_home = False
        self.pop.entertained = False
        self.pop.garbage_collected = False
        random.seed(1)
        self.pop.adjust_happiness()
        # 10 + 10 - 10 - 5 - 5 = 0 (if not sick)
        self.assertIn(self.pop.overall_happiness, range(-25, 25))


class TestPopulation(unittest.TestCase):

    def setUp(self):
        self.pop1 = Pop()
        self.pop2 = Pop()
        self.population = Population.from_list([self.pop1, self.pop2])

    def test_from_list_length(self):
        self.assertEqual(len(self.population.pops), 2)

    def test_add_pop_increases_count(self):
        new_pop = Pop()
        self.population.add_pop(new_pop)
        self.assertEqual(len(self.population.pops), 3)

    def test_remove_pop_decreases_count(self):
        self.population.remove_pop(self.pop1)
        self.assertEqual(len(self.population.pops), 1)

    def test_iter_yields_pops(self):
        result = list(self.population)
        self.assertEqual(result, [self.pop1, self.pop2])

    def test_len_returns_pop_count(self):
        self.assertEqual(len(self.population), 2)

    def test_property_tax_counts_pops_with_property(self):
        self.pop1.property = "house"
        self.assertEqual(self.population.property_tax(), 1)

    def test_property_tax_none_with_property(self):
        self.assertEqual(self.population.property_tax(), 0)

    def test_empty_population_iter(self):
        empty = Population()
        self.assertEqual(list(empty), [])


class TestHappinessTracker(unittest.TestCase):

    def setUp(self):
        self.pop = Pop()
        self.population = Population.from_list([self.pop])
        self.tracker = HappinessTracker(self.population)

    def test_initial_average_happiness_reflects_pop(self):
        self.assertEqual(self.tracker.get_average_happiness(),
                         self.pop.overall_happiness)

    def test_update_happiness_after_adjustment(self):
        self.pop.water_received = True
        self.pop.electricity_received = True
        self.pop.has_home = True
        random.seed(1)
        self.pop.adjust_happiness()
        self.tracker.update_happiness(self.population)
        self.assertEqual(self.tracker.get_average_happiness(),
                         self.pop.overall_happiness)

    def test_average_happiness_empty_population(self):
        empty = Population()
        tracker = HappinessTracker(empty)
        self.assertEqual(tracker.get_average_happiness(), 0)

    def test_average_happiness_multiple_pops(self):
        pop_a = Pop()
        pop_b = Pop()
        pop_a.overall_happiness = 10
        pop_b.overall_happiness = 20
        pop_population = Population.from_list([pop_a, pop_b])
        tracker = HappinessTracker(pop_population)
        tracker.update_happiness(pop_population)
        self.assertAlmostEqual(tracker.get_average_happiness(), 15.0)


if __name__ == "__main__":
    unittest.main()


def _make_sim(seed: int = 42) -> Sim:
    """Helper: create a fresh Sim with a default city and given seed."""
    return Sim(city=City(), seed=seed)


class TestPopulationDeterminism(unittest.TestCase):
    """Population metrics are deterministic with a fixed seed."""

    def test_same_seed_same_population_after_ticks(self):
        """Two sims with the same seed must yield identical population counts."""
        sim1 = _make_sim(seed=42)
        sim2 = _make_sim(seed=42)

        for _ in range(20):
            sim1.advance_day()
            sim2.advance_day()

        self.assertEqual(
            len(sim1.city.population.pops),
            len(sim2.city.population.pops),
        )

    def test_same_seed_same_happiness_after_ticks(self):
        """Two sims with the same seed must yield identical happiness."""
        sim1 = _make_sim(seed=7)
        sim2 = _make_sim(seed=7)

        for _ in range(20):
            sim1.advance_day()
            sim2.advance_day()

        self.assertAlmostEqual(
            sim1.city.happiness_tracker.get_average_happiness(),
            sim2.city.happiness_tracker.get_average_happiness(),
        )


class TestHappinessRange(unittest.TestCase):
    """Happiness must always be in [0, 100]."""

    def test_happiness_bounds_over_ticks(self):
        sim = _make_sim(seed=123)
        for _ in range(30):
            sim.advance_day()
            h = sim.city.happiness_tracker.get_average_happiness()
            self.assertGreaterEqual(h, 0.0, "Happiness dropped below 0")
            self.assertLessEqual(h, 100.0, "Happiness exceeded 100")

    def test_happiness_bounds_empty_population(self):
        city = City(population=Population.from_list([]))
        sim = Sim(city=city, seed=1)
        sim.advance_day()
        h = sim.city.happiness_tracker.get_average_happiness()
        self.assertEqual(h, 0.0)


class TestPopulationNonNegative(unittest.TestCase):
    """Population count must never go negative."""

    def test_population_nonnegative_over_ticks(self):
        sim = _make_sim(seed=42)
        for _ in range(30):
            sim.advance_day()
            self.assertGreaterEqual(len(sim.city.population.pops), 0)


class TestPopulationGrowth(unittest.TestCase):
    """With generous infrastructure, population should grow over time."""

    def test_growth_with_good_infrastructure(self):
        pop = Population.from_list([Pop() for _ in range(10)])
        city = City(population=pop)
        # Enough resources for many more people than the initial 10
        city.water_facilities = 20
        city.electricity_facilities = 20
        city.housing_units = 500

        sim = Sim(city=city, seed=42)
        initial = len(sim.city.population.pops)

        for _ in range(50):
            sim.advance_day()

        final = len(sim.city.population.pops)
        self.assertGreater(
            final, initial, "Population should grow with good infrastructure")


class TestJSONLLogging(unittest.TestCase):
    """advance_day must write a JSONL entry with required fields."""

    def test_tick_log_written(self):
        import json
        sim = _make_sim(seed=99)
        sim.advance_day()

        self.assertTrue(sim._log_path.exists(), "Log file should be created")
        with open(sim._log_path) as f:
            entry = json.loads(f.readline())

        required = [
            "timestamp", "run_id", "tick_index", "budget",
            "revenue", "expenses", "population", "happiness",
            "policies_applied", "tick_duration_ms",
        ]
        for field in required:
            self.assertIn(field, entry, f"Missing required log field: {field}")

        self.assertEqual(entry["tick_index"], 0)
        self.assertIsInstance(entry["population"], int)
        self.assertGreaterEqual(entry["population"], 0)
        self.assertGreaterEqual(entry["happiness"], 0.0)
        self.assertLessEqual(entry["happiness"], 100.0)
