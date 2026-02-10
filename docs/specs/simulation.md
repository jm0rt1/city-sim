# Specification: Simulation Core

## Purpose
Define the tick loop contract, scenario configuration, expected outputs, and orchestration logic for the City-Sim simulation engine. This specification provides the complete reference for implementing and extending the core simulation loop.

## Overview

The Simulation Core is responsible for:
- Orchestrating the execution of simulation scenarios from start to completion
- Managing the tick loop with precise timing and ordering
- Coordinating subsystems (Finance, Population, Transport) during each tick
- Ensuring deterministic behavior across runs with the same configuration
- Collecting metrics and producing comprehensive logs
- Providing extension points for profiling, custom metrics, and event handling

## Architecture

### Core Components

**SimRunner**: Top-level orchestrator
- Initializes simulation from settings and scenario
- Creates and configures SimCore
- Executes the simulation run
- Produces final RunReport

**SimCore**: Tick engine
- Executes the main tick loop
- Coordinates subsystem updates in defined order
- Manages TickContext for each tick
- Collects metrics via MetricsCollector
- Emits events via EventBus

**Supporting Components**:
- `TickScheduler`: Computes next tick (currently simple increment, future: variable time steps)
- `EventBus`: Publish/subscribe for decoupled component communication
- `MetricsCollector`: Aggregates metrics from subsystems
- `RandomService`: Provides seedable random numbers
- `PolicyEngine`: Evaluates policies and generates decisions
- `CityManager`: Applies decisions and coordinates city state updates

## Interfaces

### SimRunner

```python
class SimRunner:
    """
    Top-level orchestrator for simulation runs.
    """
    
    def __init__(self, settings: Settings):
        """
        Initialize runner with settings.
        
        Args:
            settings: Configuration including seed, horizon, policies, scenario
        """
    
    def run(self) -> RunReport:
        """
        Execute complete simulation run.
        
        Returns:
            RunReport with final state, metrics, and KPIs
            
        Raises:
            ConfigurationError: If settings are invalid
            SimulationError: If simulation fails during execution
        """
```

### SimCore

```python
class SimCore:
    """
    Core tick engine coordinating subsystems.
    """
    
    def __init__(self, city: City, settings: Settings, 
                 city_manager: CityManager,
                 policy_engine: PolicyEngine,
                 metrics_collector: MetricsCollector,
                 random_service: RandomService):
        """Initialize simulation core with dependencies."""
        
    def run(self) -> RunReport:
        """
        Execute tick loop for configured horizon.
        
        Returns:
            RunReport with aggregated results
        """
        
    def tick(self, city: City, context: TickContext) -> TickResult:
        """
        Perform one tick of the simulation.
        
        Execution order (critical for determinism):
        1. Create TickContext with current tick index, settings, random state
        2. PolicyEngine evaluates policies → produces Decisions
        3. CityManager applies decisions → produces initial CityDelta
        4. CityManager updates subsystems:
           a. Finance subsystem → FinanceDelta
           b. Population subsystem → PopulationDelta
           c. Transport subsystem → TrafficDelta (if active)
        5. Validate city invariants
        6. Collect metrics from all subsystems
        7. Emit events via EventBus
        8. Write log entry
        9. Return TickResult
        
        Args:
            city: City state (modified in-place)
            context: Tick context with settings, policies, random service
            
        Returns:
            TickResult containing metrics, deltas, and events
            
        Side Effects:
            - Modifies city state
            - Writes to logs
            - Emits events
            - Updates metrics collector
        """
```

### TickContext

```python
class TickContext:
    """
    Context information for a single tick.
    
    Provides read-only access to simulation configuration and services.
    """
    
    tick_index: int                 # Current tick number (0-based)
    settings: Settings              # Global settings (read-only)
    policy_set: PolicySet           # Active policies for this tick
    random_service: RandomService   # Seedable random number generator
    event_bus: EventBus            # For emitting events
    
    @property
    def is_first_tick(self) -> bool:
        """Check if this is tick 0."""
        return self.tick_index == 0
    
    @property
    def is_last_tick(self) -> bool:
        """Check if this is the final tick."""
        return self.tick_index == self.settings.tick_horizon - 1
```

### TickResult

```python
class TickResult:
    """
    Output from a single tick execution.
    """
    
    tick_index: int                     # Tick number
    city_delta: CityDelta              # Aggregate city changes
    metrics: Dict[str, Any]            # Collected metrics
    events: List[Event]                # Events emitted during tick
    tick_duration_ms: float            # Time to execute tick
    
    # Subsystem-specific results (if available)
    finance_delta: Optional[FinanceDelta]
    population_delta: Optional[PopulationDelta]
    traffic_delta: Optional[TrafficDelta]
    
    def to_log_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for logging."""
```

### RunReport

```python
class RunReport:
    """
    Final summary of a complete simulation run.
    """
    
    run_id: str                        # Unique run identifier
    settings: Settings                 # Settings used for this run
    
    # Final State
    final_city: City                   # City state at end of run
    final_tick: int                    # Last tick executed
    
    # Aggregated Metrics
    total_ticks: int                   # Number of ticks executed
    run_duration_ms: float             # Total wall-clock time
    avg_tick_duration_ms: float        # Mean tick execution time
    
    # KPIs
    kpis: Dict[str, Any]              # Key performance indicators
    # Example KPIs:
    # - final_budget
    # - final_population
    # - avg_happiness
    # - total_revenue
    # - total_expenses
    # - peak_congestion (if transport active)
    
    # Performance Profiling (if enabled)
    profile_report: Optional[ProfileReport]
    
    def to_json(self) -> str:
        """Export as JSON string."""
        
    def to_text_summary(self) -> str:
        """Export as human-readable text summary."""
```

## Inputs

### Settings

Loaded from [src/shared/settings.py](../../src/shared/settings.py):

```python
class Settings:
    """
    Global configuration for simulation.
    """
    
    # Core Simulation Parameters
    seed: int                          # Random seed for reproducibility
    tick_horizon: int                  # Number of ticks to simulate
    
    # Scenario
    scenario_name: str                 # Name of scenario to load
    scenario_params: Dict[str, Any]   # Scenario-specific parameters
    
    # Policies
    policy_set: PolicySet              # Collection of active policies
    
    # Performance
    profiling_enabled: bool            # Enable detailed performance profiling
    
    # Logging
    log_format: str                    # "jsonl" or "csv"
    log_path: str                      # Path to log file
    log_level: str                     # Logging verbosity
    
    # Validation
    strict_mode: bool                  # Raise exceptions on invariant violations
```

### City Model

Initial city state from [src/city/city.py](../../src/city/city.py) and [src/city/city_manager.py](../../src/city/city_manager.py):

- City structure (districts, buildings)
- Initial state (budget, population, happiness)
- Infrastructure and service configurations

### Scenario Definition

Loaded via `ScenarioLoader`:

```python
class Scenario:
    """
    A named configuration for a simulation run.
    """
    
    name: str                          # Scenario identifier
    description: str                   # Human-readable description
    
    # Initial Conditions
    initial_budget: float
    initial_population: int
    initial_happiness: float
    
    # Policies
    policies: List[str]                # Policy IDs to activate
    
    # Parameters
    tick_horizon: int
    parameters: Dict[str, Any]         # Scenario-specific parameters
```

## Outputs

### Structured Logs

Written to `output/logs/global/` per tick:
- All required fields as defined in [Logging Specification](logging.md)
- Metrics from all subsystems
- Policy applications
- Performance data

**Example log entry** (JSONL):
```json
{
  "timestamp": "2024-01-15T10:30:45.123Z",
  "run_id": "run_001",
  "tick_index": 42,
  "budget": 1050000.0,
  "revenue": 52000.0,
  "expenses": 31000.0,
  "population": 10150,
  "happiness": 62.3,
  "policies_applied": ["tax_policy_001"],
  "tick_duration_ms": 8.5
}
```

### Metrics

Collected by `MetricsCollector` each tick:
- **Tick Duration**: Time to execute tick (ms)
- **Event Counts**: Number of events emitted
- **Subsystem Metrics**: From Finance, Population, Transport
- **Invariant Status**: Pass/fail for each invariant check

### Events

Published via `EventBus` during execution:
- Policy application events
- Invariant violation events
- Subsystem milestone events (e.g., "population reached 50,000")
- Performance alerts (e.g., "tick duration exceeded threshold")

### RunReport

Final summary with:
- Final city state
- Aggregated KPIs
- Performance profile (if enabled)
- Success/failure status

## Determinism

**Core Requirement**: Given fixed `seed` and `settings`, simulation produces identical:
- State trajectory (city state at each tick)
- Logs (all fields match exactly)
- Events (same events in same order)
- Metrics (including timing, within measurement error)

### Determinism Guarantees

1. **Random Number Generation**: All randomness through `RandomService` with fixed seed
2. **Subsystem Ordering**: Fixed update order (Finance → Population → Transport)
3. **No External State**: No dependencies on system time, file system state, or external services (except configuration)
4. **Floating-Point Consistency**: Consistent rounding and no parallel floating-point aggregation
5. **Event Ordering**: Events processed in deterministic order (FIFO queue)

### Testing Determinism

```python
def test_determinism():
    """Verify identical runs produce identical outputs."""
    
    settings = Settings(seed=12345, tick_horizon=100, ...)
    
    # Run 1
    runner1 = SimRunner(settings)
    report1 = runner1.run()
    
    # Run 2 (same settings)
    runner2 = SimRunner(settings)
    report2 = runner2.run()
    
    # Verify identical results
    assert report1.final_city.state.budget == report2.final_city.state.budget
    assert report1.final_city.state.population == report2.final_city.state.population
    assert report1.kpis == report2.kpis
    
    # Verify logs are identical
    assert compare_log_files("run1.jsonl", "run2.jsonl") == True
```

## Configuration

### Seed Management

```python
class SeedProvider:
    """
    Manages deterministic seed generation.
    """
    
    @staticmethod
    def from_settings(settings: Settings) -> int:
        """Extract seed from settings."""
        return settings.seed
    
    @staticmethod
    def generate_unique() -> int:
        """Generate unique seed from timestamp."""
        import time
        return int(time.time() * 1000) % (2**31)
```

### Scenario Loading

```python
class ScenarioLoader:
    """
    Loads scenario definitions from files or database.
    """
    
    def load(self, scenario_name: str) -> Scenario:
        """
        Load scenario by name.
        
        Args:
            scenario_name: Identifier for scenario
            
        Returns:
            Scenario object with configuration
            
        Raises:
            ScenarioNotFoundError: If scenario doesn't exist
        """
```

### Policy Configuration

```python
class PolicySet:
    """
    Collection of policies for a simulation run.
    """
    
    policies: List[IPolicy]            # Active policies
    
    def add(self, policy: IPolicy):
        """Add a policy to the set."""
        
    def evaluate(self, city: City, context: TickContext) -> List[Decision]:
        """Evaluate all policies and collect decisions."""
```

## Usage Examples

### Example 1: Basic Simulation Run

```python
# Configure settings
settings = Settings(
    seed=12345,
    tick_horizon=1000,
    scenario_name="baseline",
    log_format="jsonl",
    log_path="output/logs/global/run_001.jsonl"
)

# Create and execute runner
runner = SimRunner(settings)
report = runner.run()

# Display results
print(f"Simulation completed: {report.total_ticks} ticks")
print(f"Final budget: ${report.kpis['final_budget']:,.2f}")
print(f"Final population: {report.kpis['final_population']:,}")
print(f"Average happiness: {report.kpis['avg_happiness']:.1f}")
```

### Example 2: Custom Scenario with Policies

```python
# Load custom scenario
scenario = ScenarioLoader().load("aggressive_growth")

# Configure policies
policy_set = PolicySet()
policy_set.add(TaxPolicy(rate=0.08))  # Low taxes to encourage growth
policy_set.add(InfrastructureInvestmentPolicy(budget_fraction=0.25))  # Heavy investment

# Create settings with custom scenario
settings = Settings(
    seed=67890,
    tick_horizon=500,
    scenario_name=scenario.name,
    policy_set=policy_set,
    profiling_enabled=True
)

runner = SimRunner(settings)
report = runner.run()

# Analyze results
if report.kpis['final_population'] > scenario.initial_population * 1.5:
    print("✓ Achieved 50% population growth target")
else:
    print("✗ Did not meet growth target")
```

### Example 3: Profiling and Performance Analysis

```python
settings = Settings(
    seed=11111,
    tick_horizon=100,
    profiling_enabled=True
)

runner = SimRunner(settings)
report = runner.run()

# Analyze performance
profile = report.profile_report
print(f"Average tick duration: {report.avg_tick_duration_ms:.2f} ms")
print(f"Finance subsystem: {profile.avg_finance_ms:.2f} ms")
print(f"Population subsystem: {profile.avg_population_ms:.2f} ms")
print(f"Transport subsystem: {profile.avg_transport_ms:.2f} ms")

# Identify bottlenecks
if profile.avg_transport_ms > profile.avg_finance_ms * 2:
    print("⚠ Transport subsystem is bottleneck (2x slower than Finance)")
```

## Performance Considerations

### Tick Duration Targets

- **Target**: < 100ms per tick on standard hardware (for 1000-tick runs to complete in ~2 minutes)
- **Measurement**: Include `tick_duration_ms` in logs
- **Tolerance**: ±10% variability across runs is acceptable
- **Regression Detection**: Alert if average tick duration increases > 10% between versions

### Optimization Guidelines

1. **Profile Before Optimizing**: Use `profiling_enabled=True` to identify actual bottlenecks
2. **Subsystem Isolation**: Optimize slowest subsystem first
3. **Avoid Premature Optimization**: Correctness and determinism > speed
4. **Cache Computation**: Cache expensive calculations that don't change within a tick
5. **Efficient Data Structures**: Use appropriate data structures (e.g., sets for membership tests)

### Scalability Targets

- **Small Runs**: 100 ticks, < 1 second
- **Medium Runs**: 1,000 ticks, < 2 minutes
- **Large Runs**: 10,000 ticks, < 20 minutes
- **Very Large Runs**: 100,000 ticks, < 3 hours

## Acceptance Criteria

A compliant Simulation Core implementation must satisfy:

1. **Repeatable Outputs with Same Seed**
   - Two runs with identical settings produce identical logs
   - Verified by byte-for-byte log comparison or checksum

2. **Tick Duration Performance**
   - No more than 10% variability in average tick duration across runs
   - Average tick duration meets targets for scenario scale

3. **Complete Metric Collection**
   - All required metrics collected and logged each tick
   - No missing or null values for required fields

4. **Proper Event Handling**
   - Events emitted and handled in deterministic order
   - Event handlers don't break determinism

5. **Invariant Enforcement**
   - All city invariants checked each tick
   - Violations logged or raise exceptions as configured

6. **Graceful Error Handling**
   - Configuration errors detected before execution
   - Runtime errors logged with context
   - Simulation can be stopped cleanly

## Testing Strategy

### Unit Tests
- Test individual components (TickScheduler, MetricsCollector, etc.)
- Mock dependencies to isolate behavior
- Verify correct metric collection and event emission

### Integration Tests
- Test full tick loop with real subsystems
- Verify subsystem coordination and ordering
- Check data flow from settings → logs → report

### Determinism Tests
- Run same scenario multiple times
- Compare logs byte-for-byte or via checksums
- Test with various seeds and configurations

### Performance Tests
- Measure tick duration distributions
- Verify performance targets
- Detect regressions in performance

### Scenario Tests
- Run predefined scenarios with known expected outcomes
- Verify KPIs match expectations
- Test edge cases (empty city, bankruptcy, etc.)

## Error Handling

### Configuration Errors

```python
class ConfigurationError(Exception):
    """Raised when settings are invalid."""
    pass

# Example checks
if settings.tick_horizon <= 0:
    raise ConfigurationError("tick_horizon must be positive")

if settings.seed is None:
    raise ConfigurationError("seed is required for determinism")
```

### Runtime Errors

```python
class SimulationError(Exception):
    """Raised when simulation fails during execution."""
    pass

# Example handling
try:
    delta = city_manager.update(city, context)
except Exception as e:
    logger.error(f"Simulation failed at tick {context.tick_index}: {e}")
    raise SimulationError(f"Failed at tick {context.tick_index}") from e
```

### Invariant Violations

```python
# In strict mode
if settings.strict_mode:
    violations = city_manager.validate_invariants(city)
    if violations:
        raise SimulationError(f"Invariant violations: {violations}")

# In normal mode
violations = city_manager.validate_invariants(city)
if violations:
    logger.warning(f"Invariant violations at tick {context.tick_index}: {violations}")
    # Continue execution
```

## Future Enhancements

### Planned Features
- **Variable Time Steps**: Support non-uniform tick intervals
- **Pause/Resume**: Save simulation state and resume later
- **Parallel Subsystems**: Execute independent subsystems in parallel (with determinism guarantees)
- **Checkpointing**: Save state at intervals for recovery
- **Live Monitoring**: Real-time metrics streaming to dashboard
- **Distributed Execution**: Run large scenarios across multiple machines

## Related Documentation

- **[Architecture Overview](../architecture/overview.md)**: System architecture and component interactions
- **[Class Hierarchy](../architecture/class-hierarchy.md)**: Detailed class relationships
- **[City Specification](city.md)**: City state and operations
- **[Logging Specification](logging.md)**: Log format and fields
- **[ADR-001: Simulation Determinism](../adr/001-simulation-determinism.md)**: Determinism design decisions
- **[Scenarios Specification](scenarios.md)**: Scenario definition and loading
- **[Glossary](../guides/glossary.md)**: Term definitions
