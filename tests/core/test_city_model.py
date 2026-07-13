"""
Tests for city model invariants and decision effects.

Covers:
- City attribute invariants (non-negative infrastructure counts).
- StayDecision: penalties correctly reduce stay-probability.
- DisasterDecision: base chance is 1%.
- CityManager.manage_population: removes pops whose StayDecision returns False.
"""

import random
import unittest

from src.city.city import City
from src.city.city_manager import CityManager
from src.city.decisions import DisasterDecision, StayDecision
from src.city.population.population import Pop, Population


class TestCityInvariants(unittest.TestCase):
    """City infrastructure attributes must stay non-negative."""

    def setUp(self):
        self.city = City()

    # --- water_facilities ---

    def test_add_water_facilities_increases_count(self):
        initial = self.city.water_facilities
        self.city.add_water_facilities(3)
        self.assertEqual(self.city.water_facilities, initial + 3)

    def test_add_water_facilities_zero_is_noop(self):
        initial = self.city.water_facilities
        self.city.add_water_facilities(0)
        self.assertEqual(self.city.water_facilities, initial)

    def test_add_water_facilities_rejects_negative(self):
        with self.assertRaises(ValueError):
            self.city.add_water_facilities(-1)

    # --- electricity_facilities ---

    def test_add_electricity_facilities_increases_count(self):
        initial = self.city.electricity_facilities
        self.city.add_electricity_facilities(5)
        self.assertEqual(self.city.electricity_facilities, initial + 5)

    def test_add_electricity_facilities_rejects_negative(self):
        with self.assertRaises(ValueError):
            self.city.add_electricity_facilities(-1)

    # --- housing_units ---

    def test_add_housing_units_increases_count(self):
        initial = self.city.housing_units
        self.city.add_housing_units(10)
        self.assertEqual(self.city.housing_units, initial + 10)

    def test_add_housing_units_rejects_negative(self):
        with self.assertRaises(ValueError):
            self.city.add_housing_units(-1)

    # --- initial values are non-negative ---

    def test_initial_infrastructure_non_negative(self):
        self.assertGreaterEqual(self.city.water_facilities, 0)
        self.assertGreaterEqual(self.city.electricity_facilities, 0)
        self.assertGreaterEqual(self.city.housing_units, 0)


class TestStayDecision(unittest.TestCase):
    """StayDecision must reduce stay-probability when basic needs are unmet."""

    def _make_happy_pop(self):
        """Return a Pop with all basic needs satisfied and positive happiness."""
        pop = Pop()
        pop.has_home = True
        pop.water_received = True
        pop.electricity_received = True
        pop.overall_happiness = 30
        return pop

    def test_stay_chance_reduced_when_no_home(self):
        city = City()
        pop = self._make_happy_pop()
        pop.has_home = False

        decision = StayDecision(city, pop)
        decision.roll()  # sets chance_percentage as side-effect

        expected = decision.base_chance - decision.no_home_penalty
        self.assertAlmostEqual(decision.chance_percentage, expected)

    def test_stay_chance_reduced_when_low_happiness(self):
        city = City()
        pop = self._make_happy_pop()
        pop.overall_happiness = -5

        decision = StayDecision(city, pop)
        decision.roll()

        expected = decision.base_chance - decision.low_happiness_penalty
        self.assertAlmostEqual(decision.chance_percentage, expected)

    def test_stay_chance_reduced_by_both_penalties(self):
        city = City()
        pop = self._make_happy_pop()
        pop.has_home = False
        pop.overall_happiness = -5

        decision = StayDecision(city, pop)
        decision.roll()

        expected = (decision.base_chance
                    - decision.no_home_penalty
                    - decision.low_happiness_penalty)
        self.assertAlmostEqual(decision.chance_percentage, expected)

    def test_stay_chance_unchanged_when_needs_met(self):
        city = City()
        pop = self._make_happy_pop()

        decision = StayDecision(city, pop)
        decision.roll()

        self.assertAlmostEqual(decision.chance_percentage, decision.base_chance)

    def test_penalties_reduce_not_increase_chance(self):
        """Penalties must never raise the stay-chance above base."""
        city = City()
        pop = self._make_happy_pop()
        pop.has_home = False
        pop.overall_happiness = -10

        decision = StayDecision(city, pop)
        decision.roll()

        self.assertLess(decision.chance_percentage, decision.base_chance)

    def test_stay_always_when_chance_is_one(self):
        """Pop always stays when effective chance is 1.0."""
        city = City()
        pop = self._make_happy_pop()

        decision = StayDecision(city, pop)
        # Set base_chance to 1.0 so roll() computes chance_percentage = 1.0
        decision.base_chance = 1.0
        for _ in range(20):
            self.assertTrue(decision.roll())

    def test_never_stays_when_chance_is_zero(self):
        """Pop never stays when effective chance is 0.0."""
        city = City()
        pop = self._make_happy_pop()

        decision = StayDecision(city, pop)
        # Set base_chance to 0.0 so roll() computes chance_percentage = 0.0
        decision.base_chance = 0.0
        for _ in range(20):
            self.assertFalse(decision.roll())


class TestDisasterDecision(unittest.TestCase):
    """DisasterDecision must carry a 1% base probability."""

    def test_disaster_chance_is_one_percent(self):
        city = City()
        decision = DisasterDecision(city)
        self.assertAlmostEqual(decision.chance_percentage, 0.01)

    def test_disaster_never_occurs_when_chance_zero(self):
        city = City()
        decision = DisasterDecision(city)
        decision.chance_percentage = 0.0
        for _ in range(20):
            self.assertFalse(decision.roll())

    def test_disaster_always_occurs_when_chance_one(self):
        city = City()
        decision = DisasterDecision(city)
        decision.chance_percentage = 1.0
        for _ in range(20):
            self.assertTrue(decision.roll())


class TestCityManagerPopulation(unittest.TestCase):
    """CityManager.manage_population must remove pops whose StayDecision is False."""

    def test_population_does_not_go_negative(self):
        """Population size must remain >= 0 after manage_population."""
        pop1 = Pop()
        pop1.has_home = False
        pop1.overall_happiness = -30
        population = Population.from_list([pop1])
        city = City(population=population)
        manager = CityManager(city)

        # Force all pops to leave by patching roll
        original_roll = StayDecision.roll
        StayDecision.roll = lambda self: False  # type: ignore[assignment]
        try:
            manager.manage_population()
        finally:
            StayDecision.roll = original_roll  # type: ignore[assignment]

        self.assertGreaterEqual(len(city.population.pops), 0)

    def test_pop_removed_when_stay_decision_false(self):
        """A pop that rolls False on StayDecision is removed from population."""
        pop = Pop()
        pop.has_home = True
        pop.overall_happiness = 10
        population = Population.from_list([pop])
        city = City(population=population)
        manager = CityManager(city)

        original_roll = StayDecision.roll
        StayDecision.roll = lambda self: False  # type: ignore[assignment]
        try:
            manager.manage_population()
        finally:
            StayDecision.roll = original_roll  # type: ignore[assignment]

        self.assertEqual(len(city.population.pops), 0)

    def test_pop_retained_when_stay_decision_true(self):
        """A pop that rolls True on StayDecision is kept in population."""
        pop = Pop()
        pop.has_home = True
        pop.overall_happiness = 10
        population = Population.from_list([pop])
        city = City(population=population)
        manager = CityManager(city)

        original_roll = StayDecision.roll
        StayDecision.roll = lambda self: True  # type: ignore[assignment]
        try:
            manager.manage_population()
        finally:
            StayDecision.roll = original_roll  # type: ignore[assignment]

        self.assertEqual(len(city.population.pops), 1)


if __name__ == "__main__":
    unittest.main()
