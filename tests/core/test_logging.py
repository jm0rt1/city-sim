"""
Tests for the structured JSONL logging system (docs/specs/logging.md).
"""
import json
import tempfile
import unittest
from pathlib import Path

from src.city.city import City
from src.city.population.population import Pop, Population
from src.simulation.logger import SimLogger, normalize_happiness
from src.simulation.sim import Sim


# ---------------------------------------------------------------------------
# SimLogger unit tests
# ---------------------------------------------------------------------------

class TestSimLogger(unittest.TestCase):

    def _make_logger(self, tmp_dir: Path) -> SimLogger:
        return SimLogger(run_id="run_test_001", log_path=tmp_dir / "test_run.jsonl")

    # --- normalize_happiness -----------------------------------------------

    def test_normalize_happiness_max(self):
        self.assertAlmostEqual(normalize_happiness(40.0), 100.0)

    def test_normalize_happiness_min(self):
        self.assertAlmostEqual(normalize_happiness(-55.0), 0.0)

    def test_normalize_happiness_clamps_above(self):
        self.assertAlmostEqual(normalize_happiness(999.0), 100.0)

    def test_normalize_happiness_clamps_below(self):
        self.assertAlmostEqual(normalize_happiness(-999.0), 0.0)

    def test_normalize_happiness_midpoint(self):
        # midpoint of [-55, 40] is -7.5 → should be 50.0
        mid = (-55.0 + 40.0) / 2.0
        self.assertAlmostEqual(normalize_happiness(mid), 50.0, places=5)

    # --- log_tick required fields -----------------------------------------

    def test_log_tick_produces_valid_json_line(self):
        with tempfile.TemporaryDirectory() as tmp:
            logger = self._make_logger(Path(tmp))
            logger.log_tick(
                tick_index=0,
                budget=1000.0,
                revenue=50.0,
                expenses=30.0,
                population=10,
                happiness=60.0,
                policies_applied=[],
                tick_duration_ms=5.2,
            )
            logger.close()

            lines = (Path(tmp) / "test_run.jsonl").read_text().splitlines()
            self.assertEqual(len(lines), 1)
            entry = json.loads(lines[0])
            self.assertIsInstance(entry, dict)

    def test_log_tick_required_fields_present(self):
        required = [
            "timestamp", "run_id", "tick_index", "budget", "revenue",
            "expenses", "population", "happiness", "policies_applied",
            "tick_duration_ms",
        ]
        with tempfile.TemporaryDirectory() as tmp:
            logger = self._make_logger(Path(tmp))
            logger.log_tick(
                tick_index=0, budget=0.0, revenue=0.0, expenses=0.0,
                population=5, happiness=50.0, policies_applied=[],
                tick_duration_ms=1.0,
            )
            logger.close()

            entry = json.loads((Path(tmp) / "test_run.jsonl").read_text())
            for field in required:
                self.assertIn(field, entry, msg=f"Missing required field: {field}")

    def test_log_tick_field_types(self):
        with tempfile.TemporaryDirectory() as tmp:
            logger = self._make_logger(Path(tmp))
            logger.log_tick(
                tick_index=3, budget=-500.0, revenue=100.0, expenses=200.0,
                population=42, happiness=33.3, policies_applied=["policy_a"],
                tick_duration_ms=7.8,
            )
            logger.close()

            e = json.loads((Path(tmp) / "test_run.jsonl").read_text())
            self.assertIsInstance(e["tick_index"], int)
            self.assertIsInstance(e["population"], int)
            self.assertIsInstance(e["budget"], float)
            self.assertIsInstance(e["revenue"], float)
            self.assertIsInstance(e["expenses"], float)
            self.assertIsInstance(e["happiness"], float)
            self.assertIsInstance(e["policies_applied"], list)
            self.assertIsInstance(e["tick_duration_ms"], float)
            self.assertIsInstance(e["run_id"], str)
            self.assertIsInstance(e["timestamp"], str)

    def test_log_tick_happiness_range(self):
        with tempfile.TemporaryDirectory() as tmp:
            logger = self._make_logger(Path(tmp))
            logger.log_tick(
                tick_index=0, budget=0.0, revenue=0.0, expenses=0.0,
                population=1, happiness=75.0, policies_applied=[],
                tick_duration_ms=1.0,
            )
            logger.close()

            e = json.loads((Path(tmp) / "test_run.jsonl").read_text())
            self.assertGreaterEqual(e["happiness"], 0.0)
            self.assertLessEqual(e["happiness"], 100.0)

    def test_log_tick_population_non_negative(self):
        with tempfile.TemporaryDirectory() as tmp:
            logger = self._make_logger(Path(tmp))
            logger.log_tick(
                tick_index=0, budget=0.0, revenue=0.0, expenses=0.0,
                population=0, happiness=50.0, policies_applied=[],
                tick_duration_ms=1.0,
            )
            logger.close()

            e = json.loads((Path(tmp) / "test_run.jsonl").read_text())
            self.assertGreaterEqual(e["population"], 0)

    def test_log_tick_run_id_matches(self):
        with tempfile.TemporaryDirectory() as tmp:
            logger = self._make_logger(Path(tmp))
            logger.log_tick(
                tick_index=0, budget=0.0, revenue=0.0, expenses=0.0,
                population=1, happiness=50.0, policies_applied=[],
                tick_duration_ms=1.0,
            )
            logger.close()

            e = json.loads((Path(tmp) / "test_run.jsonl").read_text())
            self.assertEqual(e["run_id"], "run_test_001")

    # --- Multiple ticks: monotonicity & budget reconciliation ---------------

    def test_multi_tick_index_monotonic(self):
        with tempfile.TemporaryDirectory() as tmp:
            logger = self._make_logger(Path(tmp))
            for i in range(5):
                logger.log_tick(
                    tick_index=i, budget=float(i * 10), revenue=15.0,
                    expenses=5.0, population=10 + i, happiness=50.0,
                    policies_applied=[], tick_duration_ms=1.0,
                )
            logger.close()

            entries = [
                json.loads(line)
                for line in (Path(tmp) / "test_run.jsonl").read_text().splitlines()
            ]
            for idx, entry in enumerate(entries):
                self.assertEqual(entry["tick_index"], idx)

    def test_multi_tick_budget_reconciliation(self):
        """prev_budget + revenue - expenses == current_budget within tolerance."""
        with tempfile.TemporaryDirectory() as tmp:
            logger = self._make_logger(Path(tmp))
            budget = 1000.0
            for i in range(4):
                revenue = 50.0
                expenses = 30.0
                budget += revenue - expenses
                logger.log_tick(
                    tick_index=i, budget=budget, revenue=revenue,
                    expenses=expenses, population=10, happiness=60.0,
                    policies_applied=[], tick_duration_ms=1.0,
                )
            logger.close()

            entries = [
                json.loads(line)
                for line in (Path(tmp) / "test_run.jsonl").read_text().splitlines()
            ]
            for i in range(1, len(entries)):
                expected = entries[i - 1]["budget"] + entries[i]["revenue"] - entries[i]["expenses"]
                self.assertAlmostEqual(entries[i]["budget"], expected, places=5)

    # --- log_summary -------------------------------------------------------

    def test_log_summary_required_fields_present(self):
        required_summary = [
            "run_id", "summary", "final_budget", "final_population",
            "avg_happiness", "total_ticks", "run_duration_ms", "run_kpis",
        ]
        with tempfile.TemporaryDirectory() as tmp:
            logger = self._make_logger(Path(tmp))
            logger.log_summary(
                final_budget=2000.0, final_population=15,
                avg_happiness=65.0, total_ticks=10,
                run_duration_ms=500.0, run_kpis={"avg_revenue": 50.0},
            )
            logger.close()

            e = json.loads((Path(tmp) / "test_run.jsonl").read_text())
            for field in required_summary:
                self.assertIn(field, e, msg=f"Missing summary field: {field}")

    def test_log_summary_flag_is_true(self):
        with tempfile.TemporaryDirectory() as tmp:
            logger = self._make_logger(Path(tmp))
            logger.log_summary(
                final_budget=0.0, final_population=0,
                avg_happiness=50.0, total_ticks=1,
                run_duration_ms=10.0,
            )
            logger.close()

            e = json.loads((Path(tmp) / "test_run.jsonl").read_text())
            self.assertTrue(e["summary"])


# ---------------------------------------------------------------------------
# Integration: Sim.advance_day() produces log entries
# ---------------------------------------------------------------------------

class TestSimLoggingIntegration(unittest.TestCase):

    def _make_sim(self, tmp_dir: Path) -> Sim:
        """Create a Sim whose logger writes to tmp_dir."""
        sim = Sim(city=City())
        # Redirect logger to a temp location so we don't pollute output/
        log_path = tmp_dir / f"{sim.run_id}.jsonl"
        sim.logger.close()
        sim.logger = SimLogger(run_id=sim.run_id, log_path=log_path)
        sim._log_path = log_path
        return sim

    def _log_path(self, sim: Sim, tmp_dir: Path) -> Path:
        return tmp_dir / f"{sim.run_id}.jsonl"

    def test_advance_day_creates_log_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            sim = self._make_sim(tmp_path)
            sim.advance_day()
            sim.logger.close()

            log_file = self._log_path(sim, tmp_path)
            self.assertTrue(log_file.exists(), "Log file was not created")

    def test_advance_day_produces_one_entry_per_tick(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            sim = self._make_sim(tmp_path)
            for _ in range(3):
                sim.advance_day()
            sim.logger.close()

            lines = self._log_path(sim, tmp_path).read_text().splitlines()
            self.assertEqual(len(lines), 3)

    def test_advance_day_tick_index_increments(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            sim = self._make_sim(tmp_path)
            for _ in range(4):
                sim.advance_day()
            sim.logger.close()

            entries = [
                json.loads(line)
                for line in self._log_path(sim, tmp_path).read_text().splitlines()
            ]
            for i, entry in enumerate(entries):
                self.assertEqual(entry["tick_index"], i)

    def test_advance_day_all_required_fields(self):
        required = [
            "timestamp", "run_id", "tick_index", "budget", "revenue",
            "expenses", "population", "happiness", "policies_applied",
            "tick_duration_ms",
        ]
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            sim = self._make_sim(tmp_path)
            sim.advance_day()
            sim.logger.close()

            entry = json.loads(self._log_path(sim, tmp_path).read_text())
            for field in required:
                self.assertIn(field, entry, msg=f"Missing field: {field}")

    def test_advance_day_happiness_in_valid_range(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            sim = self._make_sim(tmp_path)
            sim.advance_day()
            sim.logger.close()

            entry = json.loads(self._log_path(sim, tmp_path).read_text())
            self.assertGreaterEqual(entry["happiness"], 0.0)
            self.assertLessEqual(entry["happiness"], 100.0)

    def test_advance_day_population_non_negative(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            sim = self._make_sim(tmp_path)
            sim.advance_day()
            sim.logger.close()

            entry = json.loads(self._log_path(sim, tmp_path).read_text())
            self.assertGreaterEqual(entry["population"], 0)

    def test_write_run_summary_appends_summary_entry(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            sim = self._make_sim(tmp_path)
            for _ in range(3):
                sim.advance_day()
            sim._write_run_summary()

            lines = self._log_path(sim, tmp_path).read_text().splitlines()
            # 3 tick entries + 1 summary
            self.assertEqual(len(lines), 4)
            summary = json.loads(lines[-1])
            self.assertTrue(summary.get("summary"))
            self.assertEqual(summary["total_ticks"], 3)


if __name__ == "__main__":
    unittest.main()
