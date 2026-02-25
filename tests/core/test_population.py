import unittest

from src.city.city import City
from src.city.population.population import Pop, Population
from src.simulation.sim import Sim


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
        self.assertGreater(final, initial, "Population should grow with good infrastructure")


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
