import unittest

from src.city.city import City
from src.city.finance import CityBudget, FinanceDelta
from src.city.population.population import Pop, Population


def _make_city(num_pops: int = 0) -> City:
    """Create a City with a fixed number of Pops (all resources off by default)."""
    pops = [Pop() for _ in range(num_pops)]
    population = Population.from_list(pops)
    return City(population=population)


class TestFinanceDelta(unittest.TestCase):

    def test_validate_consistent_delta(self):
        delta = FinanceDelta(
            tick_index=0,
            revenue=100.0,
            expenses=60.0,
            budget_change=40.0,
            revenue_taxes=80.0,
            revenue_fees=20.0,
            expenses_infrastructure=60.0,
            expenses_debt_service=0.0,
        )
        self.assertTrue(delta.validate())

    def test_validate_detects_inconsistency(self):
        delta = FinanceDelta(
            tick_index=0,
            revenue=100.0,
            expenses=60.0,
            budget_change=30.0,  # Wrong: should be 40.0
            revenue_taxes=80.0,
            revenue_fees=20.0,
            expenses_infrastructure=60.0,
            expenses_debt_service=0.0,
        )
        self.assertFalse(delta.validate())


class TestCityBudgetEquation(unittest.TestCase):
    """The budget equation must hold: budget[t+1] = budget[t] + revenue[t] - expenses[t]."""

    def test_budget_equation_holds_empty_city(self):
        city = _make_city(num_pops=0)
        city.budget = 5000.0
        budget = CityBudget()

        delta = budget.update_budget(city, tick_index=0)

        expected = city.previous_budget + delta.revenue - delta.expenses
        self.assertAlmostEqual(city.budget, expected, places=6)

    def test_budget_equation_holds_over_multiple_ticks(self):
        city = _make_city(num_pops=5)
        # Give everyone water and electricity so utility tax applies
        for pop in city.population.pops:
            pop.water_received = True
            pop.electricity_received = True

        budget = CityBudget()
        for tick in range(5):
            prev = city.budget
            delta = budget.update_budget(city, tick_index=tick)
            self.assertAlmostEqual(
                city.budget, prev + delta.revenue - delta.expenses, places=6,
                msg=f"Budget equation failed at tick {tick}",
            )

    def test_delta_validate_passes_after_update(self):
        city = _make_city(num_pops=3)
        budget = CityBudget()
        delta = budget.update_budget(city, tick_index=0)
        self.assertTrue(delta.validate())

    def test_previous_budget_tracked(self):
        city = _make_city(num_pops=0)
        city.budget = 1000.0
        self.assertIsNone(city.previous_budget)

        budget = CityBudget()
        budget.update_budget(city, tick_index=0)

        self.assertAlmostEqual(city.previous_budget, 1000.0, places=6)

    def test_revenue_non_negative(self):
        city = _make_city(num_pops=10)
        budget = CityBudget()
        delta = budget.update_budget(city, tick_index=0)
        self.assertGreaterEqual(delta.revenue, 0.0)

    def test_expenses_non_negative(self):
        city = _make_city(num_pops=0)
        budget = CityBudget()
        delta = budget.update_budget(city, tick_index=0)
        self.assertGreaterEqual(delta.expenses, 0.0)


class TestPolicyEffects(unittest.TestCase):
    """Policies must affect revenue/expenses predictably."""

    def test_higher_income_tax_rate_increases_revenue(self):
        """Doubling income + property tax rate should roughly double tax revenue."""
        city = _make_city(num_pops=0)
        # Give all pops a property so taxes apply
        for pop in city.population.pops:
            pop.property = object()

        budget_low = CityBudget()
        budget_low.income_tax_rate = 0.05
        budget_low.property_tax_rate = 0.025

        budget_high = CityBudget()
        budget_high.income_tax_rate = 0.10
        budget_high.property_tax_rate = 0.05

        # Use a city with a few property-owning pops
        from src.city.population.population import Pop, Population

        class FakeProp:
            pass

        pops = [Pop() for _ in range(10)]
        for pop in pops:
            pop.property = FakeProp()
        city2 = City(population=Population.from_list(pops))

        delta_low = budget_low.update_budget(city2, tick_index=0)
        city2.budget = 10000.0  # reset for fair comparison
        delta_high = budget_high.update_budget(city2, tick_index=1)

        self.assertGreater(delta_high.revenue_taxes, delta_low.revenue_taxes)

    def test_zero_population_yields_zero_tax_revenue(self):
        city = _make_city(num_pops=0)
        budget = CityBudget()
        delta = budget.update_budget(city, tick_index=0)
        self.assertAlmostEqual(delta.revenue_taxes, 0.0, places=6)
        self.assertAlmostEqual(delta.revenue_fees, 0.0, places=6)

    def test_debt_service_applied_on_negative_budget(self):
        city = _make_city(num_pops=0)
        city.budget = -10000.0  # City is in debt
        budget = CityBudget()
        delta = budget.update_budget(city, tick_index=0)
        self.assertGreater(delta.expenses_debt_service, 0.0)

    def test_no_debt_service_when_budget_positive(self):
        city = _make_city(num_pops=0)
        city.budget = 10000.0
        budget = CityBudget()
        delta = budget.update_budget(city, tick_index=0)
        self.assertAlmostEqual(delta.expenses_debt_service, 0.0, places=6)

    def test_facility_maintenance_cost_affects_expenses(self):
        city = _make_city(num_pops=0)

        budget_cheap = CityBudget()
        budget_cheap.facility_maintenance_cost = 10.0

        budget_expensive = CityBudget()
        budget_expensive.facility_maintenance_cost = 100.0

        delta_cheap = budget_cheap.update_budget(city, tick_index=0)
        city.budget = 10000.0  # reset
        delta_expensive = budget_expensive.update_budget(city, tick_index=1)

        self.assertGreater(delta_expensive.expenses_infrastructure,
                           delta_cheap.expenses_infrastructure)


if __name__ == "__main__":
    unittest.main()
