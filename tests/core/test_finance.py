import random
import unittest

from src.city.city import City
from src.city.finance import CityBudget
from src.city.population.population import Pop, Population


def _make_city_with_pops(n: int) -> City:
    random.seed(0)
    pops = [Pop() for _ in range(n)]
    population = Population.from_list(pops)
    return City(population)


class TestCityBudgetInit(unittest.TestCase):

    def test_initial_balance_is_zero(self):
        budget = CityBudget()
        self.assertEqual(budget.balance, 0)

    def test_initial_income_is_zero(self):
        budget = CityBudget()
        self.assertEqual(budget.income, 0)

    def test_initial_expenditure_is_zero(self):
        budget = CityBudget()
        self.assertEqual(budget.expenditure, 0)

    def test_default_tax_rates(self):
        budget = CityBudget()
        self.assertAlmostEqual(budget.income_tax_rate, 0.1)
        self.assertAlmostEqual(budget.property_tax_rate, 0.05)
        self.assertAlmostEqual(budget.utility_tax_rate, 0.02)


class TestCityBudgetExpenditure(unittest.TestCase):

    def test_expenditure_increases_with_facilities(self):
        city = _make_city_with_pops(5)
        budget = CityBudget()
        budget.calculate_expenditure(city)
        # 2 water + 2 electricity = 4 facilities * 50 = 200
        # 30 housing units * 5 = 150
        expected = (city.water_facilities + city.electricity_facilities) * 50 + city.housing_units * 5
        self.assertAlmostEqual(budget.expenditure, expected)

    def test_expenditure_zero_facilities(self):
        city = _make_city_with_pops(0)
        city.water_facilities = 0
        city.electricity_facilities = 0
        city.housing_units = 0
        budget = CityBudget()
        budget.calculate_expenditure(city)
        self.assertEqual(budget.expenditure, 0)


class TestCityBudgetIncome(unittest.TestCase):

    def test_income_includes_utility_tax_for_pop_with_water(self):
        city = _make_city_with_pops(1)
        pop = list(city.population)[0]
        pop.water_received = True
        pop.electricity_received = False
        pop.property = None
        budget = CityBudget()
        budget.calculate_income(city)
        self.assertGreater(budget.income, 0)

    def test_income_zero_for_pop_with_no_resources(self):
        city = _make_city_with_pops(1)
        pop = list(city.population)[0]
        pop.water_received = False
        pop.electricity_received = False
        pop.property = None
        budget = CityBudget()
        budget.calculate_income(city)
        self.assertEqual(budget.income, 0)

    def test_income_includes_property_and_income_tax(self):
        city = _make_city_with_pops(1)
        pop = list(city.population)[0]
        pop.property = "house"
        pop.water_received = False
        pop.electricity_received = False
        budget = CityBudget()
        budget.calculate_income(city)
        expected = 1 * (budget.income_tax_rate + budget.property_tax_rate)
        self.assertAlmostEqual(budget.income, expected)


class TestCityBudgetUpdate(unittest.TestCase):

    def test_balance_equals_income_minus_expenditure(self):
        city = _make_city_with_pops(10)
        random.seed(0)
        city.on_advance_day()
        budget = CityBudget()
        budget.update_budget(city)
        self.assertAlmostEqual(budget.balance, budget.income - budget.expenditure)

    def test_balance_negative_with_high_infrastructure(self):
        city = _make_city_with_pops(0)
        # No citizens means no income, but facilities cost money
        budget = CityBudget()
        budget.update_budget(city)
        self.assertLess(budget.balance, 0)


if __name__ == "__main__":
    unittest.main()
