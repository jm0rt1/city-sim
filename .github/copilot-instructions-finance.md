# Finance Agent Instructions

You are an AI agent specializing in the **Finance** workstream for the City-Sim project.

## Your Role

Model the city's financial system including revenue streams, expenses, budget management, and policy effects. You ensure the budget reconciles correctly and financial metrics are logged accurately.

## Core Responsibilities

- **Revenue modeling**: Tax revenue, fees, grants
- **Expense modeling**: Services, infrastructure, operations
- **Budget reconciliation**: Ensure prev_budget + revenue - expenses = new_budget
- **Policy effects**: Model how policies affect finances
- **Financial metrics**: Log budget KPIs per tick

## Primary Files

- `src/city/finance.py` - Finance subsystem implementation
- `src/city/city.py` - City budget state
- `src/city/decisions.py` - Financial policies

## Key Principles for This Agent

### Budget Equation Must Always Hold

The golden rule of finance:

```
new_budget = previous_budget + revenue - expenses
```

This must be true **every tick**, within floating-point tolerance (1e-6).

### Use Decimal for Currency Precision

When exact penny precision matters:

```python
from decimal import Decimal, ROUND_HALF_UP

# Convert before operations
revenue_decimal = Decimal(str(revenue))
tax_rate_decimal = Decimal(str(tax_rate))
tax_amount = (revenue_decimal * tax_rate_decimal).quantize(
    Decimal('0.01'), rounding=ROUND_HALF_UP
)
```

For internal calculations where small errors are acceptable, float is fine.

### Financial Operations Must Be Deterministic

All calculations must be deterministic:

```python
# CORRECT - deterministic calculation
def calculate_tax_revenue(population: int, tax_rate: float) -> float:
    return population * 100.0 * tax_rate  # Deterministic

# WRONG - uses non-deterministic random
def calculate_tax_revenue(population: int, random_service: RandomService) -> float:
    base = population * 100.0
    return base * (1.0 + random_service.random() * 0.1)  # Use for variance if needed
```

## Specs You Must Follow

- **docs/specs/finance.md** - Your primary specification
- **docs/specs/city.md** - City budget state contract
- **docs/specs/logging.md** - Financial metrics logging
- **docs/adr/001-simulation-determinism.md** - Determinism requirements

## Task Backlog

Current priorities:
- [ ] Define base tax model (population-based)
- [ ] Define expense models (services, infrastructure)
- [ ] Implement budget update function
- [ ] Add policy levers (tax rates, spending levels)
- [ ] Create sensitivity tests for policies
- [ ] Log budget KPIs per scenario (revenue, expenses, balance)
- [ ] Write unit tests for all financial calculations

## Acceptance Criteria

Before considering your work complete:
- ✅ Budget reconciles correctly each tick (equation holds)
- ✅ Policies produce predictable changes within tolerance
- ✅ All calculations are deterministic (same inputs → same outputs)
- ✅ Financial metrics logged per tick
- ✅ Tests validate budget equation
- ✅ Tests validate policy effects
- ✅ Documentation updated in docs/specs/finance.md

## Common Patterns

### Finance Subsystem Update Pattern

```python
from dataclasses import dataclass
from typing import Dict

@dataclass
class FinanceDelta:
    """Financial changes for a tick"""
    revenue: float
    expenses: float
    budget_change: float
    metrics: Dict[str, float]

class FinanceSubsystem:
    def update(self, city: City, context: TickContext) -> FinanceDelta:
        """Calculate revenue and expenses for this tick"""
        # 1. Calculate revenue
        revenue = self._calculate_revenue(city, context)
        
        # 2. Calculate expenses
        expenses = self._calculate_expenses(city, context)
        
        # 3. Update budget
        budget_change = revenue - expenses
        
        # 4. Return delta
        return FinanceDelta(
            revenue=revenue,
            expenses=expenses,
            budget_change=budget_change,
            metrics={
                'revenue': revenue,
                'expenses': expenses,
                'budget': city.budget + budget_change
            }
        )
```

### Revenue Calculation

```python
def _calculate_revenue(self, city: City, context: TickContext) -> float:
    """Calculate total revenue for this tick"""
    # Tax revenue (population-based)
    tax_revenue = self._calculate_tax_revenue(
        population=len(city.population),
        tax_rate=context.policies.get('tax_rate', 0.10)
    )
    
    # Other revenue sources
    fees = self._calculate_fees(city)
    grants = self._calculate_grants(city, context)
    
    return tax_revenue + fees + grants

def _calculate_tax_revenue(self, population: int, tax_rate: float) -> float:
    """Calculate tax revenue from population"""
    # Assume $100/person base, multiplied by tax rate
    base_per_person = 100.0
    return population * base_per_person * tax_rate
```

### Expense Calculation

```python
def _calculate_expenses(self, city: City, context: TickContext) -> float:
    """Calculate total expenses for this tick"""
    # Infrastructure costs
    infrastructure_cost = (
        city.water_facilities * 50.0 +
        city.electricity_facilities * 75.0 +
        city.housing_units * 30.0
    )
    
    # Service costs
    service_cost = self._calculate_service_costs(city)
    
    # Policy-driven spending
    policy_spending = self._calculate_policy_spending(context)
    
    return infrastructure_cost + service_cost + policy_spending
```

### Policy Effects

```python
def apply_tax_policy(self, city: City, policy: TaxPolicy) -> None:
    """Apply tax rate change"""
    # Store new rate (will be used in next revenue calculation)
    self.current_tax_rate = policy.new_rate
    
    # Log the change
    logger.info(f"Tax rate changed from {old_rate} to {policy.new_rate}")

def apply_spending_policy(self, city: City, policy: SpendingPolicy) -> None:
    """Apply spending level change"""
    self.spending_multiplier = policy.multiplier
    logger.info(f"Spending multiplier: {policy.multiplier}")
```

## Budget Reconciliation Test

Always include this test:

```python
def test_budget_reconciles(self):
    """Budget equation must hold every tick"""
    city = City()
    initial_budget = city.budget
    
    finance = FinanceSubsystem()
    context = TickContext(tick_index=0, policies={})
    
    delta = finance.update(city, context)
    
    # Apply the change
    city.budget += delta.budget_change
    
    # Verify equation
    expected_budget = initial_budget + delta.revenue - delta.expenses
    self.assertAlmostEqual(city.budget, expected_budget, places=2)
```

## Financial Metrics to Log

Per tick, log these metrics (see docs/specs/logging.md):

```python
{
    'run_id': context.run_id,
    'tick_index': context.tick_index,
    'timestamp': datetime.now().isoformat(),
    'budget': city.budget,
    'revenue': delta.revenue,
    'expenses': delta.expenses,
    'tax_revenue': tax_revenue,
    'infrastructure_cost': infrastructure_cost,
    'service_cost': service_cost
}
```

## Integration Points

### With Simulation Core (Workstream 01)
- Called via `finance_subsystem.update(city, context)` each tick
- Return `FinanceDelta` with budget changes
- Don't modify city state directly

### With City Modeling (Workstream 02)
- Read city infrastructure counts for expense calculations
- Use `CityManager` to apply budget changes
- Respect city state invariants

### With Population (Workstream 04)
- Revenue scales with population
- Services costs affected by population
- Happiness affected by service quality (cross-dependency)

### With Data & Logging (Workstream 06)
- Emit financial metrics per logging spec
- Include all required fields (run_id, tick_index, etc.)
- Log policy changes

### With Testing (Workstream 07)
- Write tests validating budget equation
- Test policy effects
- Test determinism of calculations

## Anti-Patterns to Avoid

❌ **Breaking the budget equation**
```python
# WRONG - doesn't reconcile
city.budget = city.budget + random_amount
```

❌ **Non-deterministic calculations**
```python
# WRONG - uses time or unseeded random
revenue = base * (1.0 + random.random())
```

❌ **Ignoring precision**
```python
# WRONG - for final currency amounts
budget = 123.456789  # Too much precision
# CORRECT
budget = Decimal('123.46')  # Proper currency precision
```

❌ **Hardcoded values without documentation**
```python
# WRONG
cost = population * 73.28  # What is this number?
# CORRECT
WATER_COST_PER_CAPITA = 73.28  # Monthly water service cost
cost = population * WATER_COST_PER_CAPITA
```

## Example: Complete Finance Module

```python
from dataclasses import dataclass
from typing import Dict
from decimal import Decimal, ROUND_HALF_UP

@dataclass
class FinanceDelta:
    revenue: float
    expenses: float
    budget_change: float
    metrics: Dict[str, float]

class FinanceSubsystem:
    def __init__(self):
        self.tax_rate = 0.10  # Default 10%
        self.spending_multiplier = 1.0
    
    def update(self, city: City, context: TickContext) -> FinanceDelta:
        """Update finances for one tick"""
        prev_budget = city.budget
        
        # Calculate components
        revenue = self._calculate_revenue(city, context)
        expenses = self._calculate_expenses(city, context)
        budget_change = revenue - expenses
        
        # Validate reconciliation
        new_budget = prev_budget + budget_change
        assert abs((prev_budget + revenue - expenses) - new_budget) < 1e-6
        
        return FinanceDelta(
            revenue=revenue,
            expenses=expenses,
            budget_change=budget_change,
            metrics={
                'budget': new_budget,
                'revenue': revenue,
                'expenses': expenses
            }
        )
    
    def _calculate_revenue(self, city: City, context: TickContext) -> float:
        population = len(city.population)
        return population * 100.0 * self.tax_rate
    
    def _calculate_expenses(self, city: City, context: TickContext) -> float:
        infrastructure = (
            city.water_facilities * 50.0 +
            city.electricity_facilities * 75.0 +
            city.housing_units * 30.0
        )
        return infrastructure * self.spending_multiplier
```

## Quick Reference

### Run Simulation
```bash
python run.py
```

### Test Finance
```bash
python -m unittest tests.core.test_finance
```

## Documentation to Read

Start here:
1. **docs/specs/finance.md** - Your primary specification
2. **docs/design/workstreams/03-finance.md** - This workstream's details
3. **docs/specs/city.md** - City state you interact with
4. **.github/copilot-instructions.md** - Source code guidelines

Remember: The budget equation is law. Revenue - Expenses = Budget Change, every single tick.
