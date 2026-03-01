import json
import random
import unittest
from pathlib import Path

from src.city.city import City
from src.city.population.population import Population, Pop
from src.simulation.sim import Sim
from src.shared.settings import GlobalSettings


def _make_sim(seed: int, run_id: str) -> Sim:
    """Seed global random, create a fresh City, and return a configured Sim."""
    random.seed(seed)
    city = City(population=Population.from_list([Pop()]))
    return Sim(city=city, seed=seed, run_id=run_id)


class TestSimDeterminism(unittest.TestCase):

    def setUp(self):
        # Clean up any log files created during tests
        self._test_log_paths: list[Path] = []

    def tearDown(self):
        for path in self._test_log_paths:
            if path.exists():
                path.unlink()

    def _register_log(self, run_id: str) -> Path:
        path = GlobalSettings.GLOBAL_LOGS_DIR / f"{run_id}.jsonl"
        self._test_log_paths.append(path)
        return path

    def test_same_seed_produces_same_population(self):
        """Two runs with the same seed must produce identical final population."""
        seed = 42
        ticks = 5

        sim1 = _make_sim(seed, "det_test_run1")
        self._register_log("det_test_run1")
        sim1.run(ticks)

        sim2 = _make_sim(seed, "det_test_run2")
        self._register_log("det_test_run2")
        sim2.run(ticks)

        pop1 = len(sim1.city.population.pops)
        pop2 = len(sim2.city.population.pops)
        self.assertEqual(pop1, pop2, "Population must be identical for same seed")

    def test_same_seed_produces_same_happiness(self):
        """Two runs with the same seed must produce identical final happiness."""
        seed = 99
        ticks = 5

        sim1 = _make_sim(seed, "det_test_happy1")
        self._register_log("det_test_happy1")
        sim1.run(ticks)

        sim2 = _make_sim(seed, "det_test_happy2")
        self._register_log("det_test_happy2")
        sim2.run(ticks)

        h1 = sim1.city.happiness_tracker.get_average_happiness()
        h2 = sim2.city.happiness_tracker.get_average_happiness()
        self.assertEqual(h1, h2, "Happiness must be identical for same seed")

    def test_tick_log_written_per_tick(self):
        """advance_day must write one JSONL log entry per tick."""
        seed = 7
        ticks = 3
        run_id = "det_test_log"
        log_path = self._register_log(run_id)

        sim = _make_sim(seed, run_id)
        sim.run(ticks)

        self.assertTrue(log_path.exists(), "Log file must be created")
        entries = [json.loads(line) for line in log_path.read_text().splitlines()]
        self.assertEqual(len(entries), ticks, "One log entry per tick")

    def test_tick_log_required_fields(self):
        """Each tick log entry must include all required fields."""
        seed = 13
        run_id = "det_test_fields"
        log_path = self._register_log(run_id)

        sim = _make_sim(seed, run_id)
        sim.advance_day()

        entry = json.loads(log_path.read_text().splitlines()[0])
        required = [
            "timestamp", "run_id", "tick_index", "budget", "revenue",
            "expenses", "population", "happiness", "policies_applied",
            "tick_duration_ms",
        ]
        for field in required:
            self.assertIn(field, entry, f"Required field '{field}' missing from tick log")

    def test_tick_duration_ms_recorded(self):
        """tick_duration_ms must be a non-negative float in each log entry."""
        seed = 5
        run_id = "det_test_duration"
        log_path = self._register_log(run_id)

        sim = _make_sim(seed, run_id)
        sim.run(3)

        for line in log_path.read_text().splitlines():
            entry = json.loads(line)
            self.assertGreaterEqual(entry["tick_duration_ms"], 0.0)

    def test_different_seeds_may_differ(self):
        """Different seeds should generally produce different outcomes (statistical check)."""
        ticks = 10
        results = set()
        for seed in [1, 2, 3, 4, 5]:
            run_id = f"det_test_diff_{seed}"
            self._register_log(run_id)
            s = _make_sim(seed, run_id)
            s.run(ticks)
            results.add(len(s.city.population.pops))
        # At least 2 distinct outcomes expected across 5 different seeds
        self.assertGreater(len(results), 1, "Different seeds should produce different outcomes")
