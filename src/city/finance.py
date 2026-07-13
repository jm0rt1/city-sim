from __future__ import annotations
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from src.city.city import City


@dataclass
class FinanceDelta:
    """Financial changes during a single tick."""

    tick_index: int
    revenue: float
    expenses: float
    budget_change: float

    # Revenue breakdown
    revenue_taxes: float = 0.0
    revenue_fees: float = 0.0

    # Expense breakdown
    expenses_infrastructure: float = 0.0
    expenses_debt_service: float = 0.0

    # Policy effects: policy name -> financial impact
    policy_effects: dict[str, float] = field(default_factory=dict)

    def validate(self) -> bool:
        """Verify internal consistency within floating-point tolerance."""
        if abs((self.revenue_taxes + self.revenue_fees) - self.revenue) > 1e-6:
            return False
        if abs((self.expenses_infrastructure + self.expenses_debt_service) - self.expenses) > 1e-6:
            return False
        if abs(self.budget_change - (self.revenue - self.expenses)) > 1e-6:
            return False
        return True


class CityBudget:
    def __init__(self):
        # Tax rates (applied per tick)
        self.income_tax_rate: float = 0.1   # 10% tax on income
        self.property_tax_rate: float = 0.05  # 5% tax on property
        self.utility_tax_rate: float = 0.02  # 2% tax on utilities

        # Expense rates
        self.facility_maintenance_cost: float = 50.0  # Cost per facility per tick
        self.home_maintenance_cost: float = 5.0       # Cost per home per tick

        # Annual interest rate on debt
        self.debt_interest_rate: float = 0.05

    def calculate_revenue(self, city: City) -> tuple[float, float]:
        """Calculate per-tick revenue. Returns (taxes, fees)."""
        # Taxes: property owners pay income + property tax
        with_property = sum(1 for person in city.population.pops if person.property)
        taxes = with_property * (self.income_tax_rate + self.property_tax_rate)

        # Utility tax treated as fees
        utility_users = sum(
            1 for person in city.population.pops
            if person.water_received or person.electricity_received
        )
        fees = utility_users * self.utility_tax_rate

        return taxes, fees

    def calculate_expenses(self, city: City) -> tuple[float, float]:
        """Calculate per-tick expenses. Returns (infrastructure, debt_service)."""
        infrastructure = (
            city.water_facilities * self.facility_maintenance_cost
            + city.electricity_facilities * self.facility_maintenance_cost
            + city.housing_units * self.home_maintenance_cost
        )

        # Debt service: interest on negative budget
        debt_service = 0.0
        if city.budget < 0:
            debt_service = (-city.budget) * self.debt_interest_rate / 365.0

        return infrastructure, debt_service

    def update_budget(self, city: City, tick_index: int = 0) -> FinanceDelta:
        """
        Update the city budget for one tick.

        Budget equation: budget[t+1] = budget[t] + revenue[t] - expenses[t]

        Returns a FinanceDelta describing financial changes this tick.
        """
        taxes, fees = self.calculate_revenue(city)
        infrastructure, debt_service = self.calculate_expenses(city)

        revenue = taxes + fees
        expenses = infrastructure + debt_service
        budget_change = revenue - expenses

        # Record previous budget before updating
        city.previous_budget = city.budget
        city.budget = city.budget + budget_change

        return FinanceDelta(
            tick_index=tick_index,
            revenue=revenue,
            expenses=expenses,
            budget_change=budget_change,
            revenue_taxes=taxes,
            revenue_fees=fees,
            expenses_infrastructure=infrastructure,
            expenses_debt_service=debt_service,
        )
