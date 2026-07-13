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
        self.assertEqual(self.tracker.get_average_happiness(), self.pop.overall_happiness)

    def test_update_happiness_after_adjustment(self):
        self.pop.water_received = True
        self.pop.electricity_received = True
        self.pop.has_home = True
        random.seed(1)
        self.pop.adjust_happiness()
        self.tracker.update_happiness(self.population)
        self.assertEqual(self.tracker.get_average_happiness(), self.pop.overall_happiness)

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
