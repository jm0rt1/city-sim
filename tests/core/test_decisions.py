import random
import unittest

from src.city.city import City
from src.city.decisions import DisasterDecision, StayDecision
from src.city.population.population import Pop, Population


class TestDisasterDecision(unittest.TestCase):

    def setUp(self):
        population = Population.from_list([Pop()])
        self.city = City(population)
        self.decision = DisasterDecision(self.city)

    def test_chance_percentage_is_one_percent(self):
        self.assertAlmostEqual(self.decision.chance_percentage, 0.01)

    def test_roll_returns_bool(self):
        random.seed(0)
        result = self.decision.roll()
        self.assertIsInstance(result, bool)

    def test_roll_rarely_true_with_1_percent_chance(self):
        # With seed producing values > 0.01, most rolls should be False
        random.seed(1)
        results = [self.decision.roll() for _ in range(100)]
        true_count = sum(results)
        # Expect roughly 1%, so less than 10 disasters in 100 rolls
        self.assertLessEqual(true_count, 10)

    def test_roll_always_true_when_chance_is_1(self):
        self.decision.chance_percentage = 1.0
        for _ in range(10):
            self.assertTrue(self.decision.roll())

    def test_roll_always_false_when_chance_is_0(self):
        self.decision.chance_percentage = 0.0
        for _ in range(10):
            self.assertFalse(self.decision.roll())


class TestStayDecision(unittest.TestCase):

    def setUp(self):
        population = Population.from_list([Pop()])
        self.city = City(population)
        self.pop = list(self.city.population)[0]

    def test_happy_pop_with_home_likely_stays(self):
        self.pop.has_home = True
        self.pop.overall_happiness = 10
        decision = StayDecision(self.city, self.pop)
        # Simulate many rolls — with high base chance most should be True
        random.seed(0)
        results = [decision.roll() for _ in range(50)]
        self.assertGreater(sum(results), 25)

    def test_no_home_increases_chance_to_stay(self):
        # StayDecision adds no_home_penalty to chance (makes staying more likely per current logic)
        self.pop.has_home = False
        self.pop.overall_happiness = 10
        decision = StayDecision(self.city, self.pop)
        self.assertEqual(decision.base_chance, 0.9)

    def test_low_happiness_adds_penalty(self):
        self.pop.has_home = True
        self.pop.overall_happiness = -5
        decision = StayDecision(self.city, self.pop)
        random.seed(0)
        decision.roll()
        # chance_percentage should exceed base_chance due to happiness penalty
        self.assertGreater(decision.chance_percentage, decision.base_chance)

    def test_roll_returns_bool(self):
        decision = StayDecision(self.city, self.pop)
        random.seed(0)
        result = decision.roll()
        self.assertIsInstance(result, bool)


if __name__ == "__main__":
    unittest.main()
