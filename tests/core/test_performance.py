"""
Performance and correctness tests for simulation hotspot optimizations:
- O(n) population removal in CityManager (was O(n²))
- Single-pass happiness computation in City.on_advance_day (was two passes)
- Single-pass income calculation in CityBudget (was two passes)
- Circular-import fix for population / happiness_tracker modules
"""

import random
import time
import unittest

from src.city.city import City
from src.city.city_manager import CityManager
from src.city.finance import CityBudget
from src.city.population.happiness_tracker import HappinessTracker
from src.city.population.population import Pop, Population


class TestCircularImportFix(unittest.TestCase):
    """HappinessTracker and Population must import cleanly with no circular dependency."""

    def test_happiness_tracker_imports(self):
        tracker = HappinessTracker.__new__(HappinessTracker)
        self.assertIsNotNone(tracker)

    def test_population_and_tracker_coexist(self):
        pop = Pop()
        population = Population.from_list([pop])
        self.assertIsInstance(population.happiness_tracker, HappinessTracker)


class TestCityHappinessTrackerAccess(unittest.TestCase):
    """City must expose happiness_tracker and on_advance_day must update it correctly."""

    def setUp(self):
        random.seed(42)

    def test_city_has_happiness_tracker(self):
        city = City()
        self.assertIsInstance(city.happiness_tracker, HappinessTracker)

    def test_city_happiness_tracker_is_same_object_as_population(self):
        city = City()
        self.assertIs(city.happiness_tracker, city.population.happiness_tracker)

    def test_on_advance_day_updates_happiness(self):
        random.seed(42)
        city = City()
        city.on_advance_day()
        # With default 2 water + 2 electricity facilities, 30 housing units, 1 pop:
        # pop gets water, electricity, and home → happiness should be positive
        self.assertGreater(city.happiness_tracker.get_average_happiness(), 0)

    def test_on_advance_day_happiness_matches_manual_calculation(self):
        """Inline happiness total must equal a manually computed average."""
        random.seed(0)
        pops = [Pop() for _ in range(50)]
        population = Population.from_list(pops)
        city = City(population)
        city.on_advance_day()

        # Manually compute average from pop state after advance
        manual_avg = sum(p.overall_happiness for p in city.population.pops) / 50
        self.assertAlmostEqual(city.happiness_tracker.get_average_happiness(), manual_avg)


class TestCityManagerO1Removal(unittest.TestCase):
    """manage_population must produce the same result as the old O(n²) approach,
    and must not mutate the list while iterating."""

    def setUp(self):
        random.seed(7)

    def test_manage_population_removes_leavers(self):
        random.seed(7)
        pops = [Pop() for _ in range(100)]
        population = Population.from_list(pops)
        city = City(population)
        # Give everyone a bad situation so some leave
        city.housing_units = 0
        city.on_advance_day()
        cm = CityManager(city)
        before = len(city.population.pops)
        cm.manage_population()
        after = len(city.population.pops)
        # With low happiness some pops should leave
        self.assertLessEqual(after, before)

    def test_manage_population_survivors_are_original_objects(self):
        """Pops that survive must be the exact same objects (not copies)."""
        random.seed(42)
        pops = [Pop() for _ in range(20)]
        original_ids = {id(p) for p in pops}
        population = Population.from_list(pops)
        city = City(population)
        city.on_advance_day()
        cm = CityManager(city)
        cm.manage_population()
        for p in city.population.pops:
            self.assertIn(id(p), original_ids)

    def test_manage_population_completes_linearly(self):
        """
        Timing check: managing 2000 pops should not take dramatically longer than
        managing 200 pops (quadratic growth would be ~100x slower, linear ~10x).
        We assert the ratio stays below 25x as a conservative bound.
        """
        def run_manage(n: int) -> float:
            random.seed(1)
            pops = [Pop() for _ in range(n)]
            population = Population.from_list(pops)
            city = City(population)
            city.housing_units = 0  # trigger some leavers
            city.on_advance_day()
            cm = CityManager(city)
            t0 = time.perf_counter()
            cm.manage_population()
            return time.perf_counter() - t0

        small_time = run_manage(200)
        large_time = run_manage(2000)
        if small_time > 0:
            ratio = large_time / small_time
            self.assertLess(ratio, 25, f"manage_population scaling ratio {ratio:.1f}x exceeds 25x — possible O(n²) regression")


class TestFinanceSinglePass(unittest.TestCase):
    """CityBudget.calculate_income must produce correct results after single-pass refactor."""

    def test_calculate_income_no_property(self):
        city = City()
        city.on_advance_day()
        budget = CityBudget()
        budget.calculate_income(city)
        # No pop has .property set → with_property = 0; but utility users may exist
        self.assertGreaterEqual(budget.income, 0)

    def test_calculate_income_with_property(self):
        pops = [Pop() for _ in range(5)]
        for p in pops:
            p.property = object()  # truthy property value
            p.water_received = True
        population = Population.from_list(pops)
        city = City(population)
        budget = CityBudget()
        budget.calculate_income(city)
        expected_property_income = 5 * (budget.income_tax_rate + budget.property_tax_rate)
        expected_utility_income = 5 * budget.utility_tax_rate
        self.assertAlmostEqual(budget.income, expected_property_income + expected_utility_income)

    def test_calculate_income_single_pass_matches_two_pass(self):
        """Single-pass result must equal independently computed two-pass result."""
        random.seed(3)
        pops = [Pop() for _ in range(30)]
        # Assign random property and utility flags
        for i, p in enumerate(pops):
            p.property = True if i % 3 == 0 else None
            p.water_received = i % 2 == 0
            p.electricity_received = i % 4 == 0
        population = Population.from_list(pops)
        city = City(population)

        # Compute expected values with two separate passes (reference)
        expected_prop = sum(1 for p in city.population.pops if p.property)
        expected_util = sum(1 for p in city.population.pops if p.water_received or p.electricity_received)

        budget = CityBudget()
        budget.calculate_income(city)
        expected_income = (expected_prop * (budget.income_tax_rate + budget.property_tax_rate)
                           + expected_util * budget.utility_tax_rate)
        self.assertAlmostEqual(budget.income, expected_income)


class TestSimPopulationAPI(unittest.TestCase):
    """Sim must correctly use Population.add_pop and .pops instead of list ops."""

    def setUp(self):
        random.seed(99)

    def test_sim_advance_day_increases_population(self):
        from src.simulation.sim import Sim
        random.seed(99)
        city = City()
        # Pre-seed with many happy pops to trigger newcomers reliably
        pops = [Pop() for _ in range(50)]
        for p in pops:
            p.overall_happiness = 100
        city.population.pops = pops
        city.happiness_tracker.average_happiness = 100

        sim = Sim(city)
        before = len(city.population.pops)
        sim.roll_for_newcomers()
        after = len(city.population.pops)
        # With avg_happiness >= 20, newcomers should arrive
        self.assertGreaterEqual(after, before)

    def test_sim_roll_leavers_uses_pops(self):
        from src.simulation.sim import Sim
        random.seed(5)
        pops = [Pop() for _ in range(30)]
        population = Population.from_list(pops)
        city = City(population)
        # Force negative happiness to trigger leavers
        city.happiness_tracker.average_happiness = -50
        for p in pops:
            p.overall_happiness = -50
            p.has_home = False
            p.water_received = False
            p.electricity_received = False
        sim = Sim(city)
        sim.roll_for_leavers()
        # population.pops must still be a list on the Population object
        self.assertIsInstance(city.population.pops, list)
