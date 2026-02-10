# Specification: Population Subsystem

## Purpose
Define population growth/decline models, happiness calculation algorithms, migration mechanics, demographic tracking, and population-related interactions with city services and economy. This specification provides the complete reference for implementing and extending the population subsystem.

## Overview

The Population Subsystem manages all aspects of city population dynamics:
- **Population Tracking**: Maintains current population count and demographic data
- **Growth/Decline Calculation**: Computes natural population changes (births, deaths)
- **Happiness Tracking**: Calculates aggregate happiness based on services, infrastructure, and economic conditions
- **Migration Modeling**: Determines population movement based on push/pull factors
- **Demographic Analysis**: Tracks population composition and trends
- **Service Integration**: Connects population needs with service provision

### Key Principles

1. **Population Conservation**: Population changes must be fully accounted for (growth + migration = delta)
2. **Deterministic Calculations**: Same inputs produce same population outcomes
3. **Happiness Responsiveness**: Happiness responds predictably to service quality and conditions
4. **Migration Feedback**: Population flows respond to city attractiveness relative to external regions
5. **Realistic Modeling**: Growth rates and happiness factors reflect plausible urban dynamics

## Data Model

### PopulationState

```python
class PopulationState:
    """
    Current population data within CityState.
    """
    
    population: int                    # Total population count (must be >= 0)
    happiness: float                   # Aggregate happiness score (0..100)
    
    # Historical Tracking
    previous_population: Optional[int] # Population at previous tick (for validation)
    previous_happiness: Optional[float] # Happiness at previous tick
    
    # Demographics (optional, for detailed modeling)
    demographics: Optional[Demographics] # Age distribution, employment, etc.
```

**Field Constraints**:
- `population`: Must be >= 0 at all times (invariant enforced by PopulationSubsystem)
- `happiness`: Must be in range [0, 100] (invariant enforced by HappinessTracker)

### PopulationDelta

```python
class PopulationDelta:
    """
    Population changes during a tick.
    """
    
    # Aggregates
    population_change: int             # Net change in population (can be negative)
    happiness_change: float            # Change in happiness (-100..100)
    
    # Change Components
    natural_growth: int                # Births minus deaths
    births: int                        # New births (>= 0)
    deaths: int                        # Deaths (>= 0)
    
    migration_net: int                 # Net migration (immigration - emigration)
    immigration: int                   # People moving in (>= 0)
    emigration: int                    # People moving out (>= 0)
    
    # Happiness Breakdown
    happiness_factors: Dict[str, float] # Contribution of each factor to happiness
    base_happiness: float              # Starting happiness before changes
    final_happiness: float             # Ending happiness after changes
    
    # Metrics for Analysis
    growth_rate: float                 # Percentage growth (population_change / population)
    migration_rate: float              # Net migration as percentage of population
    
    # Metadata
    tick_index: int
    
    def validate(self):
        """Ensure internal consistency."""
        # Natural growth = births - deaths
        assert self.natural_growth == self.births - self.deaths
        
        # Migration = immigration - emigration
        assert self.migration_net == self.immigration - self.emigration
        
        # Total change = natural growth + migration
        assert self.population_change == self.natural_growth + self.migration_net
        
        # All counts non-negative
        assert self.births >= 0
        assert self.deaths >= 0
        assert self.immigration >= 0
        assert self.emigration >= 0
        
        # Happiness change matches difference
        assert abs(self.happiness_change - 
                   (self.final_happiness - self.base_happiness)) < 1e-6
```

### Demographics

```python
class Demographics:
    """
    Detailed population composition data.
    """
    
    # Age Distribution
    age_0_17: int                      # Children and teens
    age_18_64: int                     # Working-age adults
    age_65_plus: int                   # Seniors
    
    # Employment Status
    employed: int                      # Currently employed
    unemployed: int                    # Seeking employment
    not_in_labor_force: int           # Not seeking employment
    
    # Education Level
    education_primary: int             # Primary education or less
    education_secondary: int           # Secondary/high school
    education_tertiary: int            # College/university
    
    # Housing Status
    housed: int                        # With stable housing
    homeless: int                      # Without housing
    
    def validate(self):
        """Ensure demographic counts sum to total population."""
        total_by_age = self.age_0_17 + self.age_18_64 + self.age_65_plus
        # Note: Total population may not exactly match if demographics
        # are approximate or simplified
        
    @property
    def working_age_population(self) -> int:
        """Return population in working age range."""
        return self.age_18_64
    
    @property
    def dependency_ratio(self) -> float:
        """Calculate dependency ratio (dependents per working-age person)."""
        dependents = self.age_0_17 + self.age_65_plus
        if self.age_18_64 == 0:
            return float('inf')
        return dependents / self.age_18_64
    
    @property
    def unemployment_rate(self) -> float:
        """Calculate unemployment rate as percentage."""
        labor_force = self.employed + self.unemployed
        if labor_force == 0:
            return 0.0
        return (self.unemployed / labor_force) * 100
```

### HappinessFactors

```python
class HappinessFactors:
    """
    Individual contributions to overall happiness.
    """
    
    # Service Quality (each 0..100)
    health_quality: float              # Health service coverage and quality
    education_quality: float           # Education service quality
    safety_quality: float              # Public safety effectiveness
    housing_quality: float             # Housing availability and affordability
    
    # Infrastructure Quality (each 0..100)
    transport_quality: float           # Transport network condition
    utility_quality: float             # Utility reliability (water, power)
    
    # Economic Factors (each 0..100)
    employment_rate: float             # Employment availability (inverse of unemployment)
    income_level: float                # Income relative to cost of living
    
    # Environmental Factors (each 0..100)
    air_quality: float                 # Air pollution levels (inverted)
    noise_level: float                 # Noise pollution (inverted)
    green_space: float                 # Parks and recreation access
    
    # Weights for each factor (must sum to 1.0)
    WEIGHTS = {
        'health': 0.15,
        'education': 0.12,
        'safety': 0.15,
        'housing': 0.15,
        'transport': 0.08,
        'utility': 0.10,
        'employment': 0.12,
        'income': 0.08,
        'environment': 0.05,  # Combined air, noise, green space
    }
    
    def calculate_overall_happiness(self) -> float:
        """
        Calculate weighted overall happiness score.
        
        Returns:
            Happiness score in range [0, 100]
        """
        happiness = (
            self.health_quality * self.WEIGHTS['health'] +
            self.education_quality * self.WEIGHTS['education'] +
            self.safety_quality * self.WEIGHTS['safety'] +
            self.housing_quality * self.WEIGHTS['housing'] +
            self.transport_quality * self.WEIGHTS['transport'] +
            self.utility_quality * self.WEIGHTS['utility'] +
            self.employment_rate * self.WEIGHTS['employment'] +
            self.income_level * self.WEIGHTS['income'] +
            ((self.air_quality + self.green_space - self.noise_level) / 3) * 
                self.WEIGHTS['environment']
        )
        
        # Clamp to valid range
        return max(0.0, min(100.0, happiness))
```

### PopulationModel

```python
class PopulationModel:
    """
    Strategy for calculating natural population growth.
    """
    
    def __init__(self, base_birth_rate: float = 0.012, 
                 base_death_rate: float = 0.008):
        """
        Initialize with demographic rates.
        
        Args:
            base_birth_rate: Annual births per capita (default 1.2%)
            base_death_rate: Annual deaths per capita (default 0.8%)
        """
        self.base_birth_rate = base_birth_rate
        self.base_death_rate = base_death_rate
    
    def calculate_growth(self, city: City, context: TickContext) -> Tuple[int, int]:
        """
        Calculate births and deaths for this tick.
        
        Args:
            city: Current city state
            context: Tick context
            
        Returns:
            Tuple of (births, deaths)
        """
        population = city.state.population
        
        # Adjust rates based on happiness (happy cities grow faster)
        happiness_factor = city.state.happiness / 100.0
        birth_rate = self.base_birth_rate * (0.5 + happiness_factor)
        death_rate = self.base_death_rate * (1.5 - happiness_factor)
        
        # Calculate per-tick rates (assuming 365 ticks per year)
        ticks_per_year = context.settings.ticks_per_year or 365
        birth_rate_per_tick = birth_rate / ticks_per_year
        death_rate_per_tick = death_rate / ticks_per_year
        
        # Calculate expected values
        expected_births = population * birth_rate_per_tick
        expected_deaths = population * death_rate_per_tick
        
        # Use Poisson distribution for stochastic variation
        births = context.random_service.poisson(expected_births)
        deaths = context.random_service.poisson(expected_deaths)
        
        # Ensure deaths don't exceed population
        deaths = min(deaths, population)
        
        return (births, deaths)
```

### MigrationModel

```python
class MigrationModel:
    """
    Strategy for calculating population migration.
    """
    
    def __init__(self, base_migration_rate: float = 0.02):
        """
        Initialize migration model.
        
        Args:
            base_migration_rate: Annual migration as fraction of population (2%)
        """
        self.base_migration_rate = base_migration_rate
    
    def calculate_migration(self, city: City, context: TickContext) -> Tuple[int, int]:
        """
        Calculate immigration and emigration for this tick.
        
        Migration is driven by push/pull factors:
        - Pull factors: High happiness, employment, services
        - Push factors: Low happiness, poor services, economic hardship
        
        Args:
            city: Current city state
            context: Tick context
            
        Returns:
            Tuple of (immigration, emigration)
        """
        population = city.state.population
        happiness = city.state.happiness
        
        # Calculate attractiveness score (0..1)
        # Higher happiness = more attractive
        attractiveness = happiness / 100.0
        
        # Calculate push/pull balance (-1 to +1)
        # Positive = net immigration, Negative = net emigration
        migration_pressure = (attractiveness - 0.5) * 2
        
        # Calculate base migration volume
        ticks_per_year = context.settings.ticks_per_year or 365
        base_migration_volume = population * self.base_migration_rate / ticks_per_year
        
        # Calculate directional flows
        if migration_pressure > 0:
            # Net immigration
            immigration = int(base_migration_volume * (1 + migration_pressure))
            emigration = int(base_migration_volume * (1 - migration_pressure * 0.5))
        else:
            # Net emigration
            immigration = int(base_migration_volume * (1 + migration_pressure * 0.5))
            emigration = int(base_migration_volume * (1 - migration_pressure))
        
        # Add stochastic variation
        immigration = context.random_service.poisson(max(0, immigration))
        emigration = context.random_service.poisson(max(0, emigration))
        
        # Ensure emigration doesn't exceed population
        emigration = min(emigration, population)
        
        return (immigration, emigration)
```

### HappinessTracker

```python
class HappinessTracker:
    """
    Tracks and updates city happiness based on multiple factors.
    """
    
    def __init__(self):
        """Initialize happiness tracker."""
        self.happiness_factors = HappinessFactors()
    
    def update(self, city: City, context: TickContext) -> float:
        """
        Update happiness based on current city conditions.
        
        Args:
            city: Current city state
            context: Tick context
            
        Returns:
            Updated happiness score (0..100)
        """
        # Extract factor values from city state
        factors = self._calculate_factors(city)
        
        # Calculate overall happiness
        new_happiness = factors.calculate_overall_happiness()
        
        # Apply smoothing (happiness changes gradually)
        smoothing_factor = 0.1  # 10% of new value, 90% of old
        current_happiness = city.state.happiness or 50.0  # Default to neutral
        smoothed_happiness = (
            current_happiness * (1 - smoothing_factor) +
            new_happiness * smoothing_factor
        )
        
        # Clamp to valid range
        final_happiness = max(0.0, min(100.0, smoothed_happiness))
        
        return final_happiness
    
    def _calculate_factors(self, city: City) -> HappinessFactors:
        """
        Calculate individual happiness factors from city state.
        
        Args:
            city: Current city state
            
        Returns:
            HappinessFactors with calculated values
        """
        factors = HappinessFactors()
        
        # Service quality factors
        if city.state.services:
            factors.health_quality = city.state.services.health_coverage or 50.0
            factors.education_quality = city.state.services.education_coverage or 50.0
            factors.safety_quality = city.state.services.safety_coverage or 50.0
            factors.housing_quality = city.state.services.housing_availability or 50.0
        else:
            # Default to neutral
            factors.health_quality = 50.0
            factors.education_quality = 50.0
            factors.safety_quality = 50.0
            factors.housing_quality = 50.0
        
        # Infrastructure quality factors
        if city.state.infrastructure:
            factors.transport_quality = city.state.infrastructure.transport_quality or 50.0
            factors.utility_quality = city.state.infrastructure.utility_quality or 50.0
        else:
            factors.transport_quality = 50.0
            factors.utility_quality = 50.0
        
        # Economic factors
        if city.state.demographics:
            factors.employment_rate = 100 - city.state.demographics.unemployment_rate
        else:
            factors.employment_rate = 95.0  # Assume 5% unemployment baseline
        
        # Income relative to budget health
        budget_per_capita = city.state.budget / city.state.population if city.state.population > 0 else 0
        factors.income_level = min(100.0, max(0.0, 50.0 + budget_per_capita / 100))
        
        # Environmental factors (simplified - default to moderate)
        factors.air_quality = 70.0
        factors.noise_level = 30.0
        factors.green_space = 60.0
        
        return factors
```

## Interfaces

### PopulationSubsystem

```python
class PopulationSubsystem:
    """
    Manages population dynamics including growth, migration, and happiness.
    """
    
    def __init__(self, 
                 population_model: PopulationModel,
                 migration_model: MigrationModel,
                 happiness_tracker: HappinessTracker):
        """
        Initialize with calculation strategies.
        
        Args:
            population_model: Strategy for natural growth calculations
            migration_model: Strategy for migration calculations
            happiness_tracker: Component for happiness tracking
        """
        self.population_model = population_model
        self.migration_model = migration_model
        self.happiness_tracker = happiness_tracker
    
    def update(self, city: City, context: TickContext) -> PopulationDelta:
        """
        Perform population updates for one tick.
        
        Execution order:
        1. Update happiness based on current city conditions
        2. Calculate natural growth (births and deaths)
        3. Calculate migration (immigration and emigration)
        4. Apply population change: city.state.population += births - deaths + immigration - emigration
        5. Validate population invariants (population >= 0)
        6. Return PopulationDelta
        
        Args:
            city: City to update (modified in-place)
            context: Tick context
            
        Returns:
            PopulationDelta describing population changes
            
        Side Effects:
            - Modifies city.state.population
            - Modifies city.state.happiness
            - Updates city.state.previous_population
            - Updates city.state.previous_happiness
        """
        # Store previous values
        base_population = city.state.population
        base_happiness = city.state.happiness or 50.0
        
        # Update happiness first (affects migration)
        new_happiness = self.happiness_tracker.update(city, context)
        happiness_factors = self.happiness_tracker._calculate_factors(city)
        
        # Calculate natural growth
        births, deaths = self.population_model.calculate_growth(city, context)
        natural_growth = births - deaths
        
        # Calculate migration
        immigration, emigration = self.migration_model.calculate_migration(city, context)
        migration_net = immigration - emigration
        
        # Calculate total population change
        population_change = natural_growth + migration_net
        new_population = max(0, base_population + population_change)
        
        # Apply changes to city state
        city.state.previous_population = base_population
        city.state.previous_happiness = base_happiness
        city.state.population = new_population
        city.state.happiness = new_happiness
        
        # Calculate rates
        growth_rate = (population_change / base_population * 100) if base_population > 0 else 0.0
        migration_rate = (migration_net / base_population * 100) if base_population > 0 else 0.0
        
        # Build delta
        delta = PopulationDelta(
            population_change=population_change,
            happiness_change=new_happiness - base_happiness,
            
            natural_growth=natural_growth,
            births=births,
            deaths=deaths,
            
            migration_net=migration_net,
            immigration=immigration,
            emigration=emigration,
            
            happiness_factors={
                'health': happiness_factors.health_quality,
                'education': happiness_factors.education_quality,
                'safety': happiness_factors.safety_quality,
                'housing': happiness_factors.housing_quality,
                'transport': happiness_factors.transport_quality,
                'utility': happiness_factors.utility_quality,
                'employment': happiness_factors.employment_rate,
                'income': happiness_factors.income_level,
            },
            base_happiness=base_happiness,
            final_happiness=new_happiness,
            
            growth_rate=growth_rate,
            migration_rate=migration_rate,
            
            tick_index=context.tick_index
        )
        
        # Validate delta consistency
        delta.validate()
        
        return delta
```

## Population Growth/Decline Formulas

### Natural Growth Rate

**Formula**: `natural_growth = births - deaths`

**Birth Rate Calculation**:
```
happiness_factor = happiness / 100.0
adjusted_birth_rate = base_birth_rate * (0.5 + happiness_factor)
births_per_tick = population * adjusted_birth_rate / ticks_per_year
actual_births = Poisson(births_per_tick)
```

**Death Rate Calculation**:
```
happiness_factor = happiness / 100.0
adjusted_death_rate = base_death_rate * (1.5 - happiness_factor)
deaths_per_tick = population * adjusted_death_rate / ticks_per_year
actual_deaths = min(Poisson(deaths_per_tick), population)
```

**Parameters**:
- `base_birth_rate`: 0.012 (1.2% annual births per capita)
- `base_death_rate`: 0.008 (0.8% annual deaths per capita)
- `ticks_per_year`: 365 (default, configurable)

**Happiness Effect**:
- At 100% happiness: birth_rate = 1.5 × base, death_rate = 0.5 × base → high growth
- At 50% happiness: birth_rate = 1.0 × base, death_rate = 1.0 × base → moderate growth
- At 0% happiness: birth_rate = 0.5 × base, death_rate = 1.5 × base → decline

### Example Growth Calculation

```python
def example_growth_calculation():
    """Example of natural growth calculation."""
    
    population = 10000
    happiness = 75.0  # 75% happiness
    base_birth_rate = 0.012
    base_death_rate = 0.008
    ticks_per_year = 365
    
    # Adjust rates by happiness
    happiness_factor = happiness / 100.0  # 0.75
    birth_rate = base_birth_rate * (0.5 + happiness_factor)  # 0.012 * 1.25 = 0.015
    death_rate = base_death_rate * (1.5 - happiness_factor)  # 0.008 * 0.75 = 0.006
    
    # Per-tick rates
    birth_rate_tick = birth_rate / ticks_per_year  # 0.015 / 365 = 0.0000411
    death_rate_tick = death_rate / ticks_per_year  # 0.006 / 365 = 0.0000164
    
    # Expected values
    expected_births = population * birth_rate_tick  # 10000 * 0.0000411 = 0.411
    expected_deaths = population * death_rate_tick  # 10000 * 0.0000164 = 0.164
    
    # Actual values (Poisson distributed)
    # births ~= 0 or 1 (most likely 0)
    # deaths ~= 0 or 1 (most likely 0)
    # Over many ticks, averages converge to expected values
    
    natural_growth_rate_annual = birth_rate - death_rate  # 0.015 - 0.006 = 0.009 (0.9%)
    
    print(f"Annual growth rate: {natural_growth_rate_annual * 100:.2f}%")
    # Output: "Annual growth rate: 0.90%"
```

## Happiness Calculation Model

### Overall Happiness Formula

**Formula**:
```
happiness = Σ(factor_value × factor_weight)
where factors include: health, education, safety, housing, transport, 
                       utility, employment, income, environment
```

**Weights** (must sum to 1.0):
- Health: 0.15 (15%)
- Education: 0.12 (12%)
- Safety: 0.15 (15%)
- Housing: 0.15 (15%)
- Transport: 0.08 (8%)
- Utility: 0.10 (10%)
- Employment: 0.12 (12%)
- Income: 0.08 (8%)
- Environment: 0.05 (5%)

**Smoothing**:
To prevent rapid happiness swings, changes are smoothed:
```
new_happiness_raw = calculate_weighted_happiness(factors)
smoothing_factor = 0.1
happiness[t] = happiness[t-1] * (1 - smoothing_factor) + 
               new_happiness_raw * smoothing_factor
```

### Factor Calculation Details

**Service Quality Factors** (0..100):
```python
health_quality = health_coverage  # From ServiceState
education_quality = education_coverage
safety_quality = safety_coverage
housing_quality = housing_availability
```

**Infrastructure Quality Factors** (0..100):
```python
transport_quality = infrastructure.transport_quality
utility_quality = infrastructure.utility_quality
```

**Economic Factors**:
```python
employment_rate = 100 - unemployment_rate  # (0..100)
income_level = clamp(50 + budget_per_capita / 100, 0, 100)
```

**Environmental Factors** (simplified):
```python
environment_score = (air_quality + green_space - noise_level) / 3
```

### Example Happiness Calculation

```python
def example_happiness_calculation():
    """Example of happiness calculation."""
    
    # Factor values (each 0..100)
    factors = {
        'health': 80.0,        # Good health coverage
        'education': 75.0,     # Good education
        'safety': 85.0,        # Very good safety
        'housing': 60.0,       # Moderate housing
        'transport': 70.0,     # Good transport
        'utility': 90.0,       # Excellent utilities
        'employment': 92.0,    # 8% unemployment = 92% employment rate
        'income': 65.0,        # Moderate income
        'environment': 70.0,   # Good environment
    }
    
    # Weights
    weights = {
        'health': 0.15,
        'education': 0.12,
        'safety': 0.15,
        'housing': 0.15,
        'transport': 0.08,
        'utility': 0.10,
        'employment': 0.12,
        'income': 0.08,
        'environment': 0.05,
    }
    
    # Calculate weighted sum
    happiness_raw = sum(factors[k] * weights[k] for k in factors.keys())
    
    # Result: 80*0.15 + 75*0.12 + 85*0.15 + 60*0.15 + 70*0.08 + 
    #         90*0.10 + 92*0.12 + 65*0.08 + 70*0.05
    #       = 12.0 + 9.0 + 12.75 + 9.0 + 5.6 + 9.0 + 11.04 + 5.2 + 3.5
    #       = 77.09
    
    print(f"Raw happiness: {happiness_raw:.2f}")
    # Output: "Raw happiness: 77.09"
    
    # Apply smoothing (assuming previous happiness was 70.0)
    previous_happiness = 70.0
    smoothing_factor = 0.1
    happiness_smoothed = previous_happiness * 0.9 + happiness_raw * 0.1
    
    print(f"Smoothed happiness: {happiness_smoothed:.2f}")
    # Output: "Smoothed happiness: 70.71"
```

## Migration Model

### Push/Pull Factor System

Migration is driven by city **attractiveness** relative to external regions:
- **Attractiveness Score**: `attractiveness = happiness / 100.0` (0..1)
- **Migration Pressure**: `pressure = (attractiveness - 0.5) * 2` (-1..+1)

**Interpretation**:
- Pressure > 0: City is attractive → net immigration
- Pressure = 0: City is neutral (happiness = 50) → balanced migration
- Pressure < 0: City is unattractive → net emigration

### Migration Volume Calculation

**Base Migration Volume**:
```
base_volume = population * base_migration_rate / ticks_per_year
```

**Directional Flows**:

If `pressure > 0` (net immigration):
```
immigration = base_volume * (1 + pressure)
emigration = base_volume * (1 - pressure * 0.5)
```

If `pressure < 0` (net emigration):
```
immigration = base_volume * (1 + pressure * 0.5)
emigration = base_volume * (1 - pressure)
```

**Stochastic Variation**:
```
immigration = Poisson(immigration)
emigration = min(Poisson(emigration), population)
```

### Example Migration Calculation

```python
def example_migration_calculation():
    """Example of migration calculation."""
    
    population = 50000
    happiness = 70.0  # Above-average happiness
    base_migration_rate = 0.02  # 2% annual migration
    ticks_per_year = 365
    
    # Calculate attractiveness and pressure
    attractiveness = happiness / 100.0  # 0.70
    migration_pressure = (attractiveness - 0.5) * 2  # (0.70 - 0.5) * 2 = 0.40
    
    # Base migration volume per tick
    base_volume = population * base_migration_rate / ticks_per_year
    # 50000 * 0.02 / 365 = 2.74 people per tick
    
    # Directional flows (pressure > 0, so net immigration)
    immigration = base_volume * (1 + migration_pressure)
    # 2.74 * (1 + 0.40) = 2.74 * 1.40 = 3.836
    
    emigration = base_volume * (1 - migration_pressure * 0.5)
    # 2.74 * (1 - 0.40 * 0.5) = 2.74 * 0.80 = 2.192
    
    # Net migration
    net_migration = immigration - emigration
    # 3.836 - 2.192 = 1.644 people per tick
    
    # Annualized net migration
    annual_net = net_migration * ticks_per_year
    # 1.644 * 365 = 600 people per year
    
    # As percentage of population
    annual_net_rate = (annual_net / population) * 100
    # (600 / 50000) * 100 = 1.2%
    
    print(f"Immigration per tick: {immigration:.2f}")
    print(f"Emigration per tick: {emigration:.2f}")
    print(f"Net migration per tick: {net_migration:.2f}")
    print(f"Annual net migration: {annual_net:.0f} ({annual_net_rate:.2f}%)")
    
    # Output:
    # Immigration per tick: 3.84
    # Emigration per tick: 2.19
    # Net migration per tick: 1.64
    # Annual net migration: 600 (1.20%)
```

## Edge Cases

### Zero Population

**Scenario**: City population drops to zero

**Handling**:
1. Population cannot go below zero (enforced by `max(0, population + change)`)
2. When population = 0:
   - No births (no one to give birth)
   - No deaths (no one to die)
   - No emigration (no one to leave)
   - Immigration can still occur (repopulation possible)
   - Happiness remains at last value or defaults to neutral (50.0)
3. City can recover through immigration if conditions improve

```python
def handle_zero_population(city: City, delta: PopulationDelta):
    """Handle edge case of zero population."""
    
    if city.state.population == 0:
        # No natural growth
        delta.births = 0
        delta.deaths = 0
        delta.natural_growth = 0
        
        # No emigration possible
        delta.emigration = 0
        
        # Immigration can still happen (external factors)
        # Attractiveness based on infrastructure/services, not current population
        
        # Happiness stays neutral or last known value
        if city.state.happiness is None:
            city.state.happiness = 50.0
```

### Extreme Happiness

**Scenario**: Happiness reaches extreme values (0 or 100)

**Handling**:
1. Clamp happiness to valid range [0, 100]
2. At happiness = 0:
   - Maximum emigration rate
   - Minimal immigration
   - Reduced birth rate, increased death rate
   - Risk of population collapse
3. At happiness = 100:
   - Maximum immigration rate
   - Minimal emigration
   - Increased birth rate, reduced death rate
   - Rapid population growth

```python
def clamp_happiness(happiness: float) -> float:
    """Ensure happiness is in valid range."""
    clamped = max(0.0, min(100.0, happiness))
    
    if clamped != happiness:
        logger.warning(f"Happiness {happiness} clamped to {clamped}")
    
    return clamped
```

**Secondary Effects**:
- Extreme happiness (0 or 100) may indicate unrealistic conditions
- Consider adding noise or variability to prevent sustained extremes
- Monitor for feedback loops (e.g., low happiness → emigration → lower services → lower happiness)

### Rapid Population Growth

**Scenario**: Population grows very quickly (e.g., doubling in short time)

**Handling**:
1. Allow growth, but track rate for policy response
2. Rapid growth strains services and infrastructure
3. Secondary effects:
   - Service coverage per capita decreases (same services, more people)
   - Infrastructure quality degrades (higher usage)
   - Housing shortage increases (demand exceeds supply)
   - May trigger happiness decline, slowing future growth

```python
def handle_rapid_growth(city: City, delta: PopulationDelta, threshold: float = 5.0):
    """
    Detect and respond to rapid population growth.
    
    Args:
        city: Current city state
        delta: Population change
        threshold: Growth rate threshold (percent per tick)
    """
    
    if delta.growth_rate > threshold:
        logger.warning(f"Rapid growth detected: {delta.growth_rate:.2f}% per tick")
        
        # Strain on services (coverage decreases)
        if city.state.services:
            strain_factor = min(0.1, delta.growth_rate / 100)
            city.state.services.health_coverage *= (1 - strain_factor)
            city.state.services.education_coverage *= (1 - strain_factor)
            city.state.services.housing_availability *= (1 - strain_factor)
        
        # Infrastructure degradation
        if city.state.infrastructure:
            degradation = min(5.0, delta.growth_rate / 2)
            city.state.infrastructure.transport_quality -= degradation
            city.state.infrastructure.utility_quality -= degradation
```

### Rapid Population Decline

**Scenario**: Population declines very quickly (e.g., losing >10% per tick)

**Handling**:
1. Allow decline (within constraints: population >= 0)
2. Rapid decline indicates severe problems (very low happiness, emigration)
3. Secondary effects:
   - Revenue decreases (fewer taxpayers)
   - Services become inefficient (high per-capita cost)
   - "Death spiral" risk: decline → budget crisis → worse services → more decline

```python
def handle_rapid_decline(city: City, delta: PopulationDelta, threshold: float = -5.0):
    """
    Detect and respond to rapid population decline.
    
    Args:
        city: Current city state
        delta: Population change
        threshold: Decline rate threshold (negative percent per tick)
    """
    
    if delta.growth_rate < threshold:
        logger.warning(f"Rapid decline detected: {delta.growth_rate:.2f}% per tick")
        
        # Trigger emergency policy response
        # (Optional: Reduce expenses, increase services, etc.)
        
        # Risk of death spiral
        if city.state.budget < 0 and city.state.happiness < 30:
            logger.critical("City in death spiral: negative budget and low happiness")
```

## Integration with Other Subsystems

### Finance Subsystem

**Population → Finance**:
- **Revenue Impact**: Population size directly affects tax revenue
  - Income tax: `population × avg_income × tax_rate`
  - Sales tax: `population × spending × tax_rate`
  - Fees: `population × fee_per_capita`
- **Expense Impact**: Service costs scale with population
  - Health: `population × health_cost_per_capita × coverage`
  - Education: `population × education_cost_per_capita × coverage`
  - Safety: `population × safety_cost_per_capita × coverage`

**Finance → Population**:
- **Budget Affects Services**: Low budget → reduced service coverage → lower happiness
- **Budget Affects Infrastructure**: Insufficient maintenance → degraded infrastructure → lower happiness
- **Feedback Loop**: Budget → Services → Happiness → Population → Revenue → Budget

### Services Subsystem

**Services → Population**:
- **Service Coverage → Happiness**: Each service contributes to happiness
  - Health coverage: 15% weight
  - Education coverage: 12% weight
  - Safety coverage: 15% weight
  - Housing availability: 15% weight
- **Service Quality → Demographic Outcomes**:
  - Good health → lower death rate
  - Good education → higher employment
  - Good safety → higher happiness

**Population → Services**:
- **Population Size → Service Demand**: More people → more service capacity needed
- **Demographics → Service Needs**: Age distribution affects education vs. health needs

### Infrastructure Subsystem

**Infrastructure → Population**:
- **Infrastructure Quality → Happiness**:
  - Transport quality: 8% weight
  - Utility quality: 10% weight
- **Infrastructure Capacity → Migration**: Good infrastructure attracts population

**Population → Infrastructure**:
- **Population Size → Usage**: More people → higher infrastructure load
- **High Usage → Degradation**: Infrastructure quality decreases without maintenance

## Usage Examples

### Example 1: Basic Population Update

```python
# Initialize subsystem
population_model = PopulationModel(base_birth_rate=0.012, base_death_rate=0.008)
migration_model = MigrationModel(base_migration_rate=0.02)
happiness_tracker = HappinessTracker()

population_subsystem = PopulationSubsystem(
    population_model=population_model,
    migration_model=migration_model,
    happiness_tracker=happiness_tracker
)

# Execute update
delta = population_subsystem.update(city, context)

# Log results
print(f"Population change: {delta.population_change:+d}")
print(f"  Natural growth: {delta.natural_growth:+d} (births: {delta.births}, deaths: {delta.deaths})")
print(f"  Migration: {delta.migration_net:+d} (in: {delta.immigration}, out: {delta.emigration})")
print(f"Happiness: {delta.final_happiness:.1f} (change: {delta.happiness_change:+.1f})")
print(f"New population: {city.state.population}")

# Example output:
# Population change: +8
#   Natural growth: +3 (births: 5, deaths: 2)
#   Migration: +5 (in: 12, out: 7)
# Happiness: 72.3 (change: +0.5)
# New population: 10008
```

### Example 2: Analyzing Happiness Factors

```python
# Update population (calculates happiness)
delta = population_subsystem.update(city, context)

# Examine which factors contribute most to happiness
print("Happiness Factor Contributions:")
for factor_name, factor_value in delta.happiness_factors.items():
    weight = HappinessFactors.WEIGHTS.get(factor_name, 0)
    contribution = factor_value * weight
    print(f"  {factor_name:12s}: {factor_value:5.1f} × {weight:.2f} = {contribution:5.2f}")

# Example output:
# Happiness Factor Contributions:
#   health      :  80.0 × 0.15 = 12.00
#   education   :  75.0 × 0.12 =  9.00
#   safety      :  85.0 × 0.15 = 12.75
#   housing     :  60.0 × 0.15 =  9.00
#   transport   :  70.0 × 0.08 =  5.60
#   utility     :  90.0 × 0.10 =  9.00
#   employment  :  92.0 × 0.12 = 11.04
#   income      :  65.0 × 0.08 =  5.20

# Identify weakest factor
weakest_factor = min(delta.happiness_factors.items(), key=lambda x: x[1])
print(f"\nWeakest factor: {weakest_factor[0]} ({weakest_factor[1]:.1f})")
# Output: "Weakest factor: housing (60.0)"
```

### Example 3: Simulating Policy Impact on Population

```python
# Baseline: Current population and happiness
baseline_delta = population_subsystem.update(city, context)
print(f"Baseline: pop={city.state.population}, happiness={city.state.happiness:.1f}")

# Simulate policy: Increase health coverage
city.state.services.health_coverage = 95.0  # Up from 80.0

# Recalculate happiness with improved health
delta_after_policy = population_subsystem.update(city, context)
print(f"After health improvement: happiness={city.state.happiness:.1f}")
print(f"Happiness change: {delta_after_policy.happiness_change:+.2f}")

# Over time, higher happiness should lead to:
# - Lower death rate (healthier population)
# - Higher immigration (more attractive city)
# - Higher birth rate (happier families)

# Example output:
# Baseline: pop=10000, happiness=72.3
# After health improvement: happiness=74.5
# Happiness change: +2.20
```

### Example 4: Tracking Population Trends Over Time

```python
# Run simulation and track population metrics
population_history = []
happiness_history = []

for tick in range(365):  # One year
    context = create_tick_context(tick)
    delta = population_subsystem.update(city, context)
    
    population_history.append(city.state.population)
    happiness_history.append(city.state.happiness)

# Analyze trends
import statistics

print(f"Population: start={population_history[0]}, end={population_history[-1]}")
print(f"  Growth: {population_history[-1] - population_history[0]} " +
      f"({((population_history[-1] / population_history[0]) - 1) * 100:.2f}%)")
print(f"Happiness: mean={statistics.mean(happiness_history):.1f}, " +
      f"stdev={statistics.stdev(happiness_history):.2f}")

# Example output:
# Population: start=10000, end=10092
#   Growth: 92 (0.92%)
# Happiness: mean=73.5, stdev=1.23
```

## Acceptance Criteria

A compliant Population Subsystem implementation must satisfy:

1. **Population Conservation**
   - Population change fully accounted for: `change = natural_growth + migration_net`
   - Components sum correctly: `natural_growth = births - deaths`, `migration_net = immigration - emigration`
   - Verified via delta validation every tick

2. **Population Invariants**
   - Population never negative: `population >= 0` at all times
   - Population is integer: no fractional people
   - Enforced by PopulationSubsystem

3. **Happiness Bounds**
   - Happiness constrained to [0, 100] at all times
   - Verified via HappinessTracker clamping

4. **Deterministic Calculations**
   - Same city state + context + seed → same population delta
   - Stochastic elements (Poisson sampling) use seeded RNG
   - Verified via determinism tests

5. **Happiness Responds to Conditions**
   - Improved services → higher happiness (within smoothing lag)
   - Degraded infrastructure → lower happiness
   - Verified via unit tests with controlled inputs

6. **Migration Responds to Happiness**
   - High happiness → net immigration
   - Low happiness → net emigration
   - Neutral happiness (~50) → balanced migration
   - Verified via migration model tests

7. **Natural Growth Responds to Happiness**
   - High happiness → higher birth rate, lower death rate
   - Low happiness → lower birth rate, higher death rate
   - Verified via population model tests

8. **Edge Cases Handled Gracefully**
   - Zero population: no births/deaths/emigration, immigration possible
   - Extreme happiness: clamped to [0, 100]
   - Rapid growth/decline: logged and monitored
   - Verified via edge case tests

## Testing Strategy

### Unit Tests

**Population Model Tests**:
- Test birth/death calculation with various happiness levels
- Test rate adjustments (happiness effects)
- Test stochastic variation (Poisson distribution)
- Test edge case: zero population

**Migration Model Tests**:
- Test migration calculation with various happiness levels
- Test push/pull factor mechanics
- Test edge cases: attractiveness = 0, 0.5, 1.0
- Test constraint: emigration <= population

**Happiness Tracker Tests**:
- Test factor calculation from city state
- Test weighted happiness calculation
- Test smoothing mechanism
- Test clamping to [0, 100]

**PopulationDelta Validation Tests**:
- Test delta validation logic
- Test component summation constraints
- Test with valid and invalid deltas

### Integration Tests

**Full Population Update**:
- Test complete update cycle with real city and context
- Verify all subsystems interact correctly
- Test over multiple ticks (happiness smoothing, cumulative growth)

**Cross-Subsystem Integration**:
- Test population-finance interaction (population affects revenue)
- Test population-services interaction (services affect happiness)
- Test population-infrastructure interaction (infrastructure affects happiness)

### Edge Case Tests

**Zero Population**:
- Initialize city with population = 0
- Verify no births, deaths, or emigration
- Verify immigration can repopulate city

**Extreme Happiness**:
- Set happiness to 0: verify high emigration, low immigration
- Set happiness to 100: verify high immigration, low emigration
- Verify happiness clamped to bounds

**Rapid Growth**:
- Create conditions for rapid growth (very high happiness)
- Verify population can grow quickly but sustainably
- Test service/infrastructure strain effects

**Rapid Decline**:
- Create conditions for rapid decline (very low happiness)
- Verify population can decline but not below zero
- Test death spiral risk

### Property-Based Tests

**Population Conservation**:
- Generate random valid city states
- Verify population change always equals natural_growth + migration_net
- Verify components always sum correctly

**Non-Negative Population**:
- Generate random population changes
- Verify population never goes negative after update

**Happiness Bounds**:
- Generate random factor values
- Verify happiness always in [0, 100] after update

**Determinism**:
- Run same scenario twice with same seed
- Verify identical population trajectories

## Related Documentation

- **[Architecture Overview](../architecture/overview.md)**: Population component in system architecture
- **[City Specification](city.md)**: City state and population fields
- **[Finance Specification](finance.md)**: Finance-population interactions
- **[Simulation Specification](simulation.md)**: Population subsystem in tick loop
- **[Logging Specification](logging.md)**: Population fields in logs
- **[Glossary](../guides/glossary.md)**: Population-related term definitions
