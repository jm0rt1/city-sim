# Specification: Finance Subsystem

## Purpose
Define revenue/expense models, budget update rules, fiscal policy effects, and financial calculations for the city simulation. This specification provides the complete reference for implementing and extending the financial subsystem.

## Overview

The Finance Subsystem manages all economic aspects of the city:
- **Budget Tracking**: Maintains city treasury balance
- **Revenue Generation**: Calculates income from taxes, fees, and other sources
- **Expense Calculation**: Computes costs for services, infrastructure, and operations
- **Policy Effects**: Applies fiscal policy decisions (tax rates, subsidies, investments)
- **Financial Reporting**: Produces detailed financial deltas for analysis

### Key Principles

1. **Budget Reconciliation**: The budget equation must hold every tick (within tolerance)
2. **Deterministic Calculations**: Same inputs produce same financial outputs
3. **Policy Responsiveness**: Financial metrics respond predictably to policy changes
4. **Realistic Modeling**: Revenue and expenses scale appropriately with city size and conditions

## Data Model

### Budget

```python
class Budget:
    """
    Current financial balance of the city.
    """
    
    balance: float                     # Current treasury balance
    
    # Can be negative (representing debt)
    # No hard limit, but policies may constrain
    
    def can_afford(self, amount: float) -> bool:
        """Check if budget can cover an expense."""
        return self.balance >= amount
    
    def apply_delta(self, revenue: float, expenses: float):
        """Update budget: balance += revenue - expenses."""
        self.balance += (revenue - expenses)
```

### FinanceDelta

```python
class FinanceDelta:
    """
    Financial changes during a tick.
    """
    
    # Aggregates
    revenue: float                     # Total revenue generated (>= 0)
    expenses: float                    # Total expenses incurred (>= 0)
    budget_change: float              # Net change: revenue - expenses
    
    # Revenue Breakdown
    revenue_taxes: float              # Revenue from all taxes
    revenue_property_tax: float       # Property tax specifically
    revenue_income_tax: float         # Income tax specifically
    revenue_sales_tax: float          # Sales tax specifically
    revenue_fees: float               # Fees (permits, fines, etc.)
    revenue_grants: float             # External grants or transfers
    revenue_other: float              # Other revenue sources
    
    # Expense Breakdown
    expenses_services: float          # Service operating costs
    expenses_health: float            # Healthcare expenses
    expenses_education: float         # Education expenses
    expenses_safety: float            # Public safety expenses
    expenses_housing: float           # Housing program expenses
    expenses_infrastructure: float    # Infrastructure maintenance
    expenses_transport: float         # Transport system maintenance
    expenses_utilities: float         # Utility maintenance
    expenses_debt_service: float      # Interest on debt
    expenses_other: float             # Other expenses
    
    # Policy Effects
    policy_effects: Dict[str, float]  # Impact of each policy on finances
    
    # Metadata
    tick_index: int
    
    def validate(self):
        """Ensure internal consistency."""
        # Revenue components sum to total
        revenue_sum = (self.revenue_taxes + self.revenue_fees + 
                      self.revenue_grants + self.revenue_other)
        assert abs(revenue_sum - self.revenue) < 1e-6
        
        # Expense components sum to total
        expense_sum = (self.expenses_services + self.expenses_infrastructure + 
                      self.expenses_debt_service + self.expenses_other)
        assert abs(expense_sum - self.expenses) < 1e-6
        
        # Budget change equals net
        assert abs(self.budget_change - (self.revenue - self.expenses)) < 1e-6
```

### RevenueModel

```python
class RevenueModel:
    """
    Strategy for calculating city revenue.
    """
    
    def calculate(self, city: City, context: TickContext) -> float:
        """
        Calculate total revenue for this tick.
        
        Args:
            city: Current city state
            context: Tick context with policies
            
        Returns:
            Total revenue (>= 0)
        """
        
    def calculate_property_tax(self, city: City, tax_rate: float) -> float:
        """Calculate property tax revenue."""
        # Based on total property value in city
        
    def calculate_income_tax(self, city: City, tax_rate: float) -> float:
        """Calculate income tax revenue."""
        # Based on population and average income
        
    def calculate_sales_tax(self, city: City, tax_rate: float) -> float:
        """Calculate sales tax revenue."""
        # Based on economic activity (population, commercial capacity)
```

### ExpenseModel

```python
class ExpenseModel:
    """
    Strategy for calculating city expenses.
    """
    
    def calculate(self, city: City, context: TickContext) -> float:
        """
        Calculate total expenses for this tick.
        
        Args:
            city: Current city state
            context: Tick context
            
        Returns:
            Total expenses (>= 0)
        """
        
    def calculate_service_costs(self, city: City) -> float:
        """Calculate costs for all city services."""
        # Based on service levels and population
        
    def calculate_infrastructure_costs(self, city: City) -> float:
        """Calculate infrastructure maintenance costs."""
        # Based on infrastructure size and condition
        
    def calculate_debt_service(self, city: City) -> float:
        """Calculate interest payments on debt."""
        # Based on negative budget (if any) and interest rate
```

### FinanceReport

```python
class FinanceReport:
    """
    Summary of financial performance over time.
    """
    
    run_id: str
    
    # Aggregates
    total_revenue: float              # Sum across all ticks
    total_expenses: float             # Sum across all ticks
    avg_revenue_per_tick: float
    avg_expenses_per_tick: float
    
    # Trends
    revenue_trend: List[float]        # Revenue at each tick
    expense_trend: List[float]        # Expenses at each tick
    budget_trend: List[float]         # Budget at each tick
    
    # Analysis
    budget_surplus: float             # Final budget - initial budget
    max_budget: float                 # Peak budget reached
    min_budget: float                 # Lowest budget reached
    ticks_in_deficit: int             # Number of ticks with negative budget
    
    def plot_trends(self):
        """Generate visualization of financial trends."""
```

## Interfaces

### FinanceSubsystem

```python
class FinanceSubsystem:
    """
    Manages city finances.
    """
    
    def __init__(self, revenue_model: RevenueModel, 
                 expense_model: ExpenseModel):
        """Initialize with revenue and expense calculation strategies."""
        
    def update(self, city: City, context: TickContext) -> FinanceDelta:
        """
        Perform financial updates for one tick.
        
        Execution order:
        1. Calculate revenue based on city state and tax policies
        2. Calculate expenses based on service levels and infrastructure
        3. Apply budget change: city.state.budget += revenue - expenses
        4. Validate budget reconciliation
        5. Return FinanceDelta
        
        Args:
            city: City to update (modified in-place)
            context: Tick context with policies
            
        Returns:
            FinanceDelta describing financial changes
            
        Side Effects:
            - Modifies city.state.budget
            - Updates city.state.previous_budget
        """
```

## Revenue Calculation

### Revenue Sources

1. **Property Tax**
   - Base: Total property value across all buildings
   - Rate: Configurable via `TaxPolicy` (default: 1% per year, ~0.00003% per tick for 365-day year)
   - Formula: `property_tax = total_property_value * property_tax_rate`

2. **Income Tax**
   - Base: Population × average income
   - Rate: Configurable via `TaxPolicy` (default: 15%)
   - Formula: `income_tax = population * avg_income * income_tax_rate`

3. **Sales Tax**
   - Base: Economic activity (approximated by population × commercial capacity factor)
   - Rate: Configurable via `TaxPolicy` (default: 8%)
   - Formula: `sales_tax = population * commercial_factor * sales_tax_rate`

4. **Fees & Fines**
   - Base: Per-capita fee amount
   - Formula: `fees = population * fee_per_capita`
   - Examples: Building permits, parking fines, utility connection fees

5. **Grants & Transfers**
   - External funding (not based on city state)
   - Configured per scenario or policy

### Example Revenue Calculation

```python
def calculate_revenue(city: City, context: TickContext) -> FinanceDelta:
    """Calculate revenue for this tick."""
    
    # Extract tax rates from policies
    tax_policy = context.policy_set.get_policy(TaxPolicy)
    property_tax_rate = tax_policy.property_tax_rate if tax_policy else 0.01
    income_tax_rate = tax_policy.income_tax_rate if tax_policy else 0.15
    sales_tax_rate = tax_policy.sales_tax_rate if tax_policy else 0.08
    
    # Calculate each revenue source
    total_property_value = sum(b.capacity * 1000 for d in city.districts 
                                for b in d.buildings if b.type == BuildingType.RESIDENTIAL)
    property_tax = total_property_value * property_tax_rate / 365  # Per day
    
    avg_income = 50000  # Annual income per capita
    income_tax = city.state.population * avg_income * income_tax_rate / 365
    
    commercial_factor = 100  # Spending per capita per year
    sales_tax = city.state.population * commercial_factor * sales_tax_rate / 365
    
    fee_per_capita = 10  # Annual fees per person
    fees = city.state.population * fee_per_capita / 365
    
    # Total revenue
    revenue_total = property_tax + income_tax + sales_tax + fees
    
    return FinanceDelta(
        revenue=revenue_total,
        revenue_property_tax=property_tax,
        revenue_income_tax=income_tax,
        revenue_sales_tax=sales_tax,
        revenue_fees=fees,
        ...
    )
```

## Expense Calculation

### Expense Categories

1. **Service Operating Costs**
   - Base: Service level × population × cost per capita
   - Formula: `service_cost = service_level * population * cost_per_capita_per_day`
   - Categories: Health, Education, Public Safety, Housing

2. **Infrastructure Maintenance**
   - Base: Infrastructure size × maintenance rate
   - Degradation: Higher costs for poor condition
   - Formula: `maintenance = infrastructure_size * maintenance_rate * (2 - condition/100)`

3. **Debt Service**
   - Base: Negative budget (debt) × interest rate
   - Formula: `debt_service = max(0, -budget) * interest_rate_per_day`

### Example Expense Calculation

```python
def calculate_expenses(city: City, context: TickContext) -> FinanceDelta:
    """Calculate expenses for this tick."""
    
    # Service costs
    health_cost_per_capita = 5.0 / 365  # $5 per person per year
    health_cost = city.state.population * health_cost_per_capita * \
                  (city.state.services.health_coverage / 100)
    
    education_cost_per_capita = 8.0 / 365
    education_cost = city.state.population * education_cost_per_capita * \
                     (city.state.services.education_coverage / 100)
    
    safety_cost_per_capita = 3.0 / 365
    safety_cost = city.state.population * safety_cost_per_capita * \
                  (city.state.services.safety_coverage / 100)
    
    services_total = health_cost + education_cost + safety_cost
    
    # Infrastructure maintenance
    transport_size = len(city.state.infrastructure.transport.road_segments) \
                     if city.state.infrastructure.transport else 0
    transport_cost_per_segment = 10.0 / 365
    transport_cost = transport_size * transport_cost_per_segment * \
                     (2 - city.state.infrastructure.transport_quality / 100)
    
    infrastructure_total = transport_cost
    
    # Debt service (if budget is negative)
    if city.state.budget < 0:
        annual_interest_rate = 0.05  # 5% per year
        debt_service = -city.state.budget * annual_interest_rate / 365
    else:
        debt_service = 0.0
    
    expenses_total = services_total + infrastructure_total + debt_service
    
    return FinanceDelta(
        expenses=expenses_total,
        expenses_services=services_total,
        expenses_health=health_cost,
        expenses_education=education_cost,
        expenses_safety=safety_cost,
        expenses_infrastructure=infrastructure_total,
        expenses_transport=transport_cost,
        expenses_debt_service=debt_service,
        ...
    )
```

## Budget Reconciliation

### The Budget Equation

**Invariant**: `budget[t+1] = budget[t] + revenue[t] - expenses[t]`

**Tolerance**: Within floating-point precision (1e-6)

### Validation

```python
def validate_budget_reconciliation(city: City, delta: FinanceDelta) -> bool:
    """
    Verify budget equation holds.
    
    Returns:
        True if reconciliation is valid
    """
    
    if city.state.previous_budget is None:
        # First tick, no validation needed
        return True
    
    expected_budget = city.state.previous_budget + delta.revenue - delta.expenses
    actual_budget = city.state.budget
    
    difference = abs(expected_budget - actual_budget)
    
    if difference > 1e-6:
        logger.error(f"Budget reconciliation failed: "
                    f"expected {expected_budget:.2f}, got {actual_budget:.2f}, "
                    f"difference {difference:.2e}")
        return False
    
    return True
```

## Policy Effects

### Tax Policies

```python
class TaxPolicy(IPolicy):
    """
    Defines tax rates for various revenue sources.
    """
    
    property_tax_rate: float          # Annual rate (e.g., 0.01 = 1%)
    income_tax_rate: float            # Fraction of income (e.g., 0.15 = 15%)
    sales_tax_rate: float             # Fraction of sales (e.g., 0.08 = 8%)
    
    def evaluate(self, city: City, context: TickContext) -> List[Decision]:
        """
        Evaluate if tax rates should change based on city conditions.
        
        Example logic:
        - If budget < 0 and deficit > threshold: increase taxes
        - If budget surplus > threshold: decrease taxes
        """
```

**Effect on Revenue**:
- Increasing tax rates → proportional increase in revenue
- Decreasing tax rates → proportional decrease in revenue
- **Secondary Effect**: High taxes may reduce happiness, leading to emigration and reduced future revenue

### Subsidy Policies

```python
class SubsidyPolicy(IPolicy):
    """
    Provides financial support to services or populations.
    """
    
    subsidy_type: str                 # "service", "business", "housing"
    subsidy_amount: float             # Per-capita or flat amount
    
    def apply(self, city: City, delta: FinanceDelta):
        """Add subsidy to expenses."""
        delta.expenses_other += self.subsidy_amount
```

**Effect on Expenses**:
- Subsidies increase expenses directly
- **Secondary Effect**: May improve service coverage or happiness

### Infrastructure Investment Policies

```python
class InfrastructureInvestmentPolicy(IPolicy):
    """
    Allocates budget to infrastructure improvements.
    """
    
    budget_fraction: float            # Fraction of revenue to invest (e.g., 0.20 = 20%)
    target_infrastructure: str        # "transport", "power", "water", "all"
    
    def apply(self, city: City, delta: FinanceDelta):
        """Add investment to expenses and improve infrastructure quality."""
        investment = delta.revenue * self.budget_fraction
        delta.expenses_infrastructure += investment
        
        # Improve infrastructure quality
        if self.target_infrastructure == "transport":
            city.state.infrastructure.transport_quality += investment / 10000
```

**Effect**:
- Increases expenses (investment cost)
- Improves infrastructure quality over time
- **Secondary Effect**: Better infrastructure may improve happiness and attract population

## Edge Cases

### Bankruptcy (Negative Budget)

**Scenario**: Budget drops below zero (city is in debt)

**Handling**:
1. Allow negative budget (representing debt)
2. Apply debt service (interest) as additional expense each tick
3. Optional: Trigger policy to reduce expenses or increase taxes
4. **Secondary Effects**:
   - Service quality degrades (less funding available)
   - Infrastructure maintenance deferred
   - Happiness decreases
   - Population may emigrate

```python
def handle_negative_budget(city: City, delta: FinanceDelta):
    """Apply consequences of debt."""
    
    if city.state.budget < 0:
        # Calculate and apply debt service
        annual_interest = 0.05  # 5% per year
        delta.expenses_debt_service = -city.state.budget * annual_interest / 365
        city.state.budget -= delta.expenses_debt_service
        
        # Degrade services due to lack of funding
        degradation_factor = min(0.1, -city.state.budget / 1000000)
        city.state.services.health_coverage *= (1 - degradation_factor)
        city.state.services.education_coverage *= (1 - degradation_factor)
```

### Zero Population

**Scenario**: City population drops to zero

**Handling**:
1. Revenue from taxes drops to zero (no tax base)
2. Service expenses drop to zero (no one to serve)
3. Infrastructure maintenance continues (fixed costs)
4. City can recover if migration brings new population

```python
if city.state.population == 0:
    delta.revenue_taxes = 0.0
    delta.revenue_fees = 0.0
    delta.expenses_services = 0.0
    # Infrastructure costs remain
```

### Extreme Tax Rates

**Scenario**: Tax rates set very high (> 50%) or negative

**Handling**:
1. Clamp tax rates to valid range [0.0, 1.0] or [0%, 100%]
2. Log warning if clamping occurs
3. High taxes have diminishing returns (people leave)

```python
def clamp_tax_rate(rate: float) -> float:
    """Ensure tax rate is in valid range."""
    if rate < 0.0 or rate > 1.0:
        logger.warning(f"Invalid tax rate {rate}, clamping to [0, 1]")
        return max(0.0, min(1.0, rate))
    return rate
```

## Integration with Other Subsystems

### Population Subsystem
- **Revenue Impact**: Population size directly affects tax revenue and fees
- **Expense Impact**: Service costs scale with population
- **Feedback Loop**: Budget affects service quality, which affects happiness, which affects population

### Infrastructure Subsystem
- **Expense Impact**: Infrastructure size and condition affect maintenance costs
- **Investment**: Finance subsystem can allocate budget to infrastructure improvements
- **Feedback**: Better infrastructure may boost economic activity (future work)

## Usage Examples

### Example 1: Basic Finance Update

```python
# Initialize subsystem
revenue_model = RevenueModel()
expense_model = ExpenseModel()
finance = FinanceSubsystem(revenue_model, expense_model)

# Execute update
delta = finance.update(city, context)

# Log results
print(f"Revenue: ${delta.revenue:,.2f}")
print(f"Expenses: ${delta.expenses:,.2f}")
print(f"Net: ${delta.budget_change:,.2f}")
print(f"New Budget: ${city.state.budget:,.2f}")
```

### Example 2: Applying Tax Policy

```python
# Create tax policy
tax_policy = TaxPolicy(
    property_tax_rate=0.012,  # 1.2% annually
    income_tax_rate=0.18,     # 18%
    sales_tax_rate=0.10       # 10%
)

# Add to policy set
context.policy_set.add(tax_policy)

# Update finances (policy effects applied automatically)
delta = finance.update(city, context)

# Verify policy effect
print(f"Total revenue increased by policy: ${delta.policy_effects.get('tax_policy', 0):,.2f}")
```

## Acceptance Criteria

A compliant Finance Subsystem implementation must satisfy:

1. **Budget Equation Holds Within Tolerance**
   - Budget reconciliation verified every tick
   - Difference < 1e-6 (floating-point tolerance)

2. **Policies Affect Revenue/Expenses Predictably**
   - Increasing tax rate by X% increases revenue by ~X%
   - Adding subsidy increases expenses by subsidy amount
   - Verified via unit tests with known inputs

3. **Edge Cases Handled Gracefully**
   - Negative budget (debt) supported
   - Zero population results in zero tax revenue
   - Extreme values clamped with warnings

4. **Deterministic Calculations**
   - Same city state + policies → same financial delta
   - Verified via determinism tests

5. **Complete Reporting**
   - FinanceDelta includes all revenue/expense breakdowns
   - Policy effects tracked individually

## Testing Strategy

### Unit Tests
- Test revenue calculation with various city states and tax rates
- Test expense calculation with different service levels
- Test budget reconciliation validation
- Test policy application

### Integration Tests
- Test finance update with real city and policies
- Verify interaction with other subsystems
- Test over multiple ticks

### Edge Case Tests
- Test with zero population
- Test with negative budget (debt)
- Test with extreme tax rates
- Test with zero revenue or zero expenses

### Property-Based Tests
- Generate random valid city states
- Verify budget equation always holds
- Verify revenue/expenses always non-negative

## Related Documentation

- **[Architecture Overview](../architecture/overview.md)**: Finance component in system architecture
- **[City Specification](city.md)**: City state and budget field
- **[Logging Specification](logging.md)**: Financial fields in logs
- **[Population Specification](population.md)**: Population affects revenue and expenses
- **[Glossary](../guides/glossary.md)**: Financial term definitions
