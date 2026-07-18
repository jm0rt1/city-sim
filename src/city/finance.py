from __future__ import annotations
from dataclasses import dataclass
from src.city.city import City

@dataclass(frozen=True)
class FinanceDelta:
    tick_index: int; revenue: float; expenses: float; budget_change: float; revenue_taxes: float; revenue_fees: float; expenses_infrastructure: float; expenses_debt_service: float
    def validate(self) -> bool: return abs(self.budget_change - self.revenue + self.expenses) < 1e-9

class CityBudget:
    def __init__(self) -> None:
        self.income_tax_rate = .1; self.property_tax_rate = .05; self.utility_tax_rate = .02; self.facility_maintenance_cost = 50.; self.home_maintenance_cost = 5.
        self.balance = 0.0
    def update_budget(self, city: City, tick_index: int = 0) -> FinanceDelta:
        previous = float(getattr(city, "budget", 0.)); city.previous_budget = previous; self.balance = previous
        taxes = sum(self.income_tax_rate + self.property_tax_rate for p in city.population.pops if p.property)
        fees = sum(self.utility_tax_rate for p in city.population.pops if p.water_received or p.electricity_received)
        infrastructure = (city.water_facilities + city.electricity_facilities) * self.facility_maintenance_cost + city.housing_units * self.home_maintenance_cost
        debt = max(0., -previous) * .01; revenue = taxes + fees; expenses = infrastructure + debt; change = revenue - expenses; city.budget = previous + change
        self.balance = city.budget
        return FinanceDelta(tick_index, revenue, expenses, change, taxes, fees, infrastructure, debt)
    def calculate_income(self, city: City) -> None:
        self.income = sum(1 for p in city.population.pops if p.property) * (self.income_tax_rate + self.property_tax_rate) + sum(1 for p in city.population.pops if p.water_received or p.electricity_received) * self.utility_tax_rate
    def calculate_expenditure(self, city: City) -> None: self.expenditure = (city.water_facilities + city.electricity_facilities) * self.facility_maintenance_cost + city.housing_units * self.home_maintenance_cost
