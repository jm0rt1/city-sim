# Specification: City Model

## Purpose
Define `City` data structures, invariants, update rules via `CityManager`, and the contracts for managing city state throughout the simulation lifecycle. This specification provides the complete reference for implementing and extending the city model.

## Overview

The City Model represents the complete state of a simulated city and provides operations for transitioning between states. It serves as the aggregate root for all city-related data and is the central data structure manipulated during simulation ticks.

The model follows these key principles:
- **Immutability of Structure**: City structure (districts, buildings) changes rarely; state within structures changes frequently
- **Validation**: All state transitions validate invariants before committing changes
- **Delta Tracking**: Changes are tracked via delta objects for logging and analysis
- **Subsystem Composition**: Complex behavior is delegated to specialized subsystems (Finance, Population, Transport)

## Data Model

### City (Aggregate Root)

The `City` class is the aggregate root containing all city state:

```python
class City:
    """
    Aggregate root representing a complete city.
    
    All state modifications should go through CityManager to ensure
    invariants are maintained and deltas are properly tracked.
    """
    
    # Core Attributes
    city_id: str                    # Unique identifier for this city
    name: str                       # Human-readable city name
    
    # State Components
    state: CityState                # Current city state (budget, pop, happiness)
    districts: List[District]       # Geographical subdivisions
    
    # Metadata
    founded_tick: int               # Tick when city was founded
    current_tick: int               # Current simulation tick
```

### CityState

`CityState` contains the frequently-changing scalar values:

```python
class CityState:
    """
    Mutable state values for a city.
    Updated each tick by subsystems through CityManager.
    """
    
    # Financial State
    budget: float                   # Current treasury balance (must reconcile each tick)
    
    # Population State
    population: int                 # Total population (must be >= 0)
    happiness: float                # Aggregate happiness (0..100)
    
    # Infrastructure State
    infrastructure: InfrastructureState  # Transport, utilities, power, water
    
    # Service State  
    services: ServiceState          # Health, education, safety, housing
    
    # Historical Tracking (Optional)
    previous_budget: Optional[float]      # Budget at previous tick (for validation)
    previous_population: Optional[int]    # Population at previous tick
```

**Field Constraints**:
- `budget`: Any float value (can be negative representing debt, but policies may prevent this)
- `population`: Must be >= 0 at all times (invariant enforced by CityManager)
- `happiness`: Must be in range [0, 100] (invariant enforced by HappinessTracker)

### InfrastructureState

```python
class InfrastructureState:
    """
    State of city infrastructure systems.
    """
    
    transport: TransportNetwork     # Roads, intersections, transit (see traffic spec)
    utilities: Utilities            # General utility infrastructure
    power: PowerGrid                # Electricity generation and distribution
    water: WaterSystem              # Water supply and distribution
    
    # Quality Metrics (0..100)
    transport_quality: float        # Overall transport network quality
    utility_quality: float          # Overall utility reliability
    power_quality: float            # Power grid reliability
    water_quality: float            # Water system reliability
```

### ServiceState

```python
class ServiceState:
    """
    State of city services.
    """
    
    health: HealthService           # Healthcare facilities and programs
    education: EducationService     # Schools and educational programs
    public_safety: PublicSafetyService  # Police, fire, emergency services
    housing: HousingService         # Residential capacity and quality
    
    # Coverage Metrics (0..100)
    health_coverage: float          # % population with healthcare access
    education_coverage: float       # % children with school access
    safety_coverage: float          # % area with adequate safety services
    housing_coverage: float         # % population with adequate housing
```

### District

```python
class District:
    """
    A geographical subdivision of the city.
    """
    
    district_id: str                # Unique identifier
    name: str                       # Human-readable name
    position: Tuple[float, float]   # (x, y) coordinates
    area: float                     # Area in square units
    buildings: List[Building]       # Buildings within this district
    
    # Computed Properties
    @property
    def total_capacity(self) -> int:
        """Total capacity across all buildings."""
        return sum(b.capacity for b in self.buildings)
    
    @property
    def occupancy_rate(self) -> float:
        """Current occupancy as fraction of capacity (0..1)."""
        # Implementation delegates to buildings
```

### Building

```python
class Building:
    """
    A structure within a district.
    """
    
    building_id: str                # Unique identifier
    name: str                       # Human-readable name
    type: BuildingType              # Residential/Commercial/Industrial/Civic
    capacity: int                   # Max occupancy or utility
    current_occupancy: int          # Current utilization
    condition: float                # Building condition (0..100)
    
    # Validation
    def validate(self):
        """Ensure building state is consistent."""
        assert 0 <= current_occupancy <= capacity
        assert 0 <= condition <= 100

class BuildingType(Enum):
    RESIDENTIAL = "residential"     # Housing for population
    COMMERCIAL = "commercial"       # Businesses, retail, offices  
    INDUSTRIAL = "industrial"       # Manufacturing, production
    CIVIC = "civic"                 # Schools, hospitals, government
```

## Operations

### CityManager

`CityManager` is the primary orchestrator for city state transitions:

```python
class CityManager:
    """
    Manages city state transitions and coordinates subsystems.
    
    All modifications to City state should flow through CityManager
    to ensure proper validation, invariant checking, and delta tracking.
    """
    
    def apply_decisions(self, city: City, decisions: List[Decision], 
                       context: TickContext) -> CityDelta:
        """
        Apply a list of decisions to modify city state.
        
        Args:
            city: The city to modify (modified in-place)
            decisions: List of decision rules to apply
            context: Current tick context
            
        Returns:
            CityDelta summarizing all changes made
            
        Raises:
            InvariantViolation: If decisions would violate city invariants
        """
        
    def update(self, city: City, context: TickContext) -> CityDelta:
        """
        Perform per-tick subsystem updates.
        
        Update order (critical for determinism):
        1. Finance subsystem (budget, revenue, expenses)
        2. Population subsystem (growth, migration, happiness)
        3. Transport subsystem (traffic, vehicles)
        4. Infrastructure maintenance (degradation, upgrades)
        5. Service updates (capacity, coverage)
        
        Args:
            city: The city to update (modified in-place)
            context: Current tick context
            
        Returns:
            CityDelta summarizing all changes
            
        Side Effects:
            - Modifies city.state in-place
            - Updates city.current_tick
            - May emit events via EventBus
        """
        
    def validate_invariants(self, city: City) -> List[InvariantViolation]:
        """
        Check all city invariants.
        
        Returns:
            List of violations (empty list if all invariants hold)
        """
```

### CityDelta

`CityDelta` summarizes changes to city state:

```python
class CityDelta:
    """
    Summary of changes to city state during a tick or operation.
    
    Used for logging, analysis, and debugging.
    """
    
    # Financial Changes
    budget_change: float            # Net change in budget
    revenue: float                  # Revenue generated
    expenses: float                 # Expenses incurred
    
    # Population Changes
    population_change: int          # Net population change
    births: int                     # New births
    deaths: int                     # Deaths
    migration_in: int               # Immigration
    migration_out: int              # Emigration
    happiness_change: float         # Change in happiness
    
    # Infrastructure Changes
    infrastructure_investments: Dict[str, float]  # Investments by type
    infrastructure_degradation: Dict[str, float]  # Degradation by type
    
    # Service Changes
    service_expansions: Dict[str, float]  # Service capacity increases
    service_reductions: Dict[str, float]  # Service capacity decreases
    
    # Metadata
    tick_index: int                 # Tick when changes occurred
    applied_decisions: List[str]    # IDs of decisions applied
    
    def to_log_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for logging."""
        
    def __add__(self, other: 'CityDelta') -> 'CityDelta':
        """Combine two deltas (useful for aggregating multiple operations)."""
```

## Invariants

### Core Invariants

These must hold at the end of every tick:

1. **Budget Reconciliation**
   ```python
   # After finance update
   assert abs(city.state.budget - 
              (city.state.previous_budget + delta.revenue - delta.expenses)) < 1e-6
   ```
   
2. **Non-Negative Population**
   ```python
   # After population update
   assert city.state.population >= 0
   ```
   
3. **Happiness Bounds**
   ```python
   # After happiness update
   assert 0 <= city.state.happiness <= 100
   ```

4. **Building Capacity**
   ```python
   # Always
   for district in city.districts:
       for building in district.buildings:
           assert 0 <= building.current_occupancy <= building.capacity
   ```

5. **Quality Metrics Bounds**
   ```python
   # Always
   assert 0 <= city.state.infrastructure.transport_quality <= 100
   assert 0 <= city.state.services.health_coverage <= 100
   # ... and similar for all quality/coverage metrics
   ```

### Handling Invariant Violations

When invariants are violated:

1. **Critical Violations** (e.g., negative population): 
   - Log error with full context
   - Clamp to valid range
   - Mark simulation run as invalid
   - Continue execution for debugging purposes

2. **Tolerance Violations** (e.g., budget reconciliation within 1e-6):
   - Log warning with details
   - Continue execution (likely floating-point rounding)
   
3. **Development Mode**: 
   - Raise exceptions immediately for fast failure
   - Halt execution to prevent cascading errors

## Usage Examples

### Example 1: Initializing a New City

```python
# Create initial city state
initial_state = CityState(
    budget=1_000_000.0,
    population=10_000,
    happiness=60.0,
    infrastructure=InfrastructureState(),
    services=ServiceState()
)

# Create districts and buildings
downtown = District(
    district_id="district_001",
    name="Downtown",
    position=(0.0, 0.0),
    area=10.0,
    buildings=[
        Building("bldg_001", "City Hall", BuildingType.CIVIC, 500, 0, 100.0),
        Building("bldg_002", "Apartments", BuildingType.RESIDENTIAL, 5000, 4000, 85.0)
    ]
)

# Create city
city = City(
    city_id="city_001",
    name="New Springfield",
    state=initial_state,
    districts=[downtown],
    founded_tick=0,
    current_tick=0
)

# Initialize manager
manager = CityManager(
    finance_subsystem=FinanceSubsystem(),
    population_subsystem=PopulationSubsystem(),
    transport_subsystem=None  # Not yet implemented
)
```

### Example 2: Applying Tax Policy Decision

```python
# Policy engine produces a decision
tax_decision = Decision(
    decision_id="dec_001",
    type=DecisionType.TAX_RATE_CHANGE,
    parameters={
        "old_rate": 0.10,
        "new_rate": 0.12,
        "reason": "Budget deficit"
    }
)

# Apply through CityManager
context = TickContext(tick_index=100, settings=settings, ...)
delta = manager.apply_decisions(city, [tax_decision], context)

# Verify results
assert delta.applied_decisions == ["dec_001"]
print(f"Expected revenue impact: +{delta.revenue * 0.02}")  # 2% increase
```

### Example 3: Running Tick Update

```python
# Execute a single tick
context = TickContext(tick_index=42, ...)
delta = manager.update(city, context)

# Log results
logger.log({
    "tick_index": context.tick_index,
    "budget": city.state.budget,
    "budget_change": delta.budget_change,
    "revenue": delta.revenue,
    "expenses": delta.expenses,
    "population": city.state.population,
    "population_change": delta.population_change,
    "happiness": city.state.happiness
})

# Validate invariants
violations = manager.validate_invariants(city)
if violations:
    logger.error(f"Invariant violations detected: {violations}")
```

### Example 4: Handling Edge Cases

```python
# Edge Case 1: Population decline to zero
city.state.population = 100
delta = manager.update(city, context)
if delta.population_change < -100:
    # Prevent negative population
    city.state.population = 0
    delta.population_change = -100
    logger.warning("Population reached zero")

# Edge Case 2: Budget goes negative (debt)
city.state.budget = 1000.0
delta = manager.update(city, context)
if city.state.budget < 0:
    logger.warning(f"City in debt: {city.state.budget}")
    # Optional: Apply debt penalties to happiness or services

# Edge Case 3: Extreme happiness values
city.state.happiness = 150.0  # Invalid!
city.state.happiness = np.clip(city.state.happiness, 0.0, 100.0)
logger.warning("Clamped happiness to valid range")
```

## Edge Cases & Special Scenarios

### Empty City (No Population)
- **Behavior**: Revenue drops to zero (no tax base), fixed expenses remain
- **Budget**: Continues decreasing each tick until bankruptcy
- **Recovery**: Migration can repopulate if conditions improve

### Bankruptcy (Negative Budget)
- **Behavior**: Service quality degrades, infrastructure maintenance deferred
- **Impact on Population**: Happiness decreases, accelerating emigration
- **Recovery**: Requires policy changes or external funding

### Maximum Capacity
- **Behavior**: When building capacity is fully utilized, new population must emigrate or new buildings must be constructed
- **Impact**: Happiness may decrease due to overcrowding
- **Resolution**: Zoning policies to enable new construction

### Rapid Growth
- **Behavior**: Sudden population influx can strain services and infrastructure
- **Impact**: Service coverage drops, infrastructure quality degrades faster
- **Mitigation**: Preemptive infrastructure investment policies

## Integration with Subsystems

### Finance Integration
- `CityManager` invokes `FinanceSubsystem.update(city, context)`
- Finance subsystem reads `city.state.population`, `city.state.infrastructure`, and policies
- Finance produces `FinanceDelta` which is merged into `CityDelta`
- See [Finance Specification](finance.md) for details

### Population Integration
- `CityManager` invokes `PopulationSubsystem.update(city, context)`
- Population subsystem reads `city.state.budget`, `city.state.services`, `city.state.happiness`
- Population produces `PopulationDelta` which is merged into `CityDelta`
- See [Population Specification](population.md) for details

### Transport Integration
- `CityManager` invokes `TransportSubsystem.update(city, context)`
- Transport subsystem reads and modifies `city.state.infrastructure.transport`
- Transport produces `TrafficDelta` which is merged into `CityDelta`
- See [Traffic Specification](traffic.md) for details

## Acceptance Criteria

A correct City Model implementation must satisfy:

1. **Standard Decisions Produce Expected Deltas**
   - Tax increase → revenue increases proportionally
   - Infrastructure investment → quality increases, budget decreases
   - Service expansion → coverage increases, expenses increase
   - Validated via unit tests with known inputs/outputs

2. **Transitions Validated Under Baseline Scenarios**
   - Run baseline scenario (stable city, moderate policies)
   - Verify all invariants hold every tick
   - Verify delta aggregations match final state

3. **Deterministic Behavior**
   - Same seed, settings, and initial city → identical state trajectory
   - Verified by running scenario twice and comparing logs

4. **Proper Error Handling**
   - Invalid inputs raise clear exceptions
   - Invariant violations logged with context
   - Graceful degradation for edge cases

5. **Complete Delta Tracking**
   - Every state change reflected in `CityDelta`
   - Delta aggregation matches state differences
   - All fields populated (no None for numeric fields)

6. **Documentation Completeness**
   - All public methods documented with docstrings
   - Examples provided for common operations
   - Edge cases identified and handled

## Testing Strategy

### Unit Tests
- Test individual `CityManager` methods in isolation
- Mock subsystems to control their outputs
- Verify invariant checking logic
- Test edge cases (zero population, negative budget, etc.)

### Integration Tests
- Test full tick update with real subsystems
- Verify subsystem interactions
- Check delta aggregation correctness

### Scenario Tests
- Run complete scenarios (100+ ticks)
- Verify invariants hold throughout
- Compare outputs to expected trajectories

### Property-Based Tests
- Generate random valid city states
- Verify invariants hold after arbitrary operations
- Discover edge cases through fuzzing

## Future Extensions

### Planned Enhancements
- **Historical State Tracking**: Maintain time-series of key metrics for analysis
- **Spatial Modeling**: Add 2D grid for more sophisticated spatial relationships
- **Building Construction**: Dynamic building creation based on zoning and demand
- **District Economics**: Per-district budgets and economic tracking
- **Environmental Factors**: Weather, pollution, natural resources

### Extension Points
- **Custom State Fields**: `CityState` can be extended with additional fields
- **New Building Types**: `BuildingType` enum can be extended
- **Additional Invariants**: Register custom invariant checkers with `CityManager`
- **Custom Delta Fields**: Extend `CityDelta` for new tracked metrics

## Related Documentation

- **[Architecture Overview](../architecture/overview.md)**: High-level system design
- **[Class Hierarchy](../architecture/class-hierarchy.md)**: Detailed class relationships
- **[Finance Specification](finance.md)**: Financial subsystem details
- **[Population Specification](population.md)**: Population subsystem details
- **[Traffic Specification](traffic.md)**: Transport subsystem details
- **[Logging Specification](logging.md)**: Log schema including city state fields
- **[Glossary](../guides/glossary.md)**: Term definitions
