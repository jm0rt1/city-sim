# City-Sim Expanded Architecture Guide

## Overview

This document expands on the base architecture to describe the comprehensive system design supporting all 40+ subsystems in City-Sim. This guide explains how subsystems interact, data flows between components, and how the architecture enables parallel execution, extensibility, and deterministic simulation.

## Architecture Principles

### 1. Layered Architecture

City-Sim uses a layered architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  (User Interface, Visualization, Reports, Analytics)         │
└─────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│  (Simulation Orchestration, Scenario Management)             │
└─────────────────────────────────────────────────────────────┐
                              ↕
┌─────────────────────────────────────────────────────────────┐
│                    Business Logic Layer                      │
│  (Subsystems, Policy Engine, Decision Making)                │
└─────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│                    Data Layer                                │
│  (City State, Metrics, Logs, Configuration)                  │
└─────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│                    Infrastructure Layer                      │
│  (Logging, Random Services, Threading, File I/O)             │
└─────────────────────────────────────────────────────────────┘
```

### 2. Subsystem Independence

Each subsystem is designed to be as independent as possible:

- **Self-Contained**: Subsystems manage their own state and logic
- **Interface-Based**: Communication through well-defined interfaces
- **Minimal Coupling**: Dependencies only on core interfaces and data structures
- **Testable**: Each subsystem can be tested in isolation
- **Parallel-Safe**: Subsystems can update concurrently where dependencies allow

### 3. Event-Driven Communication

Subsystems communicate through events rather than direct method calls:

```python
# Event publishing
event_bus.publish(DisasterOccurredEvent(disaster=earthquake, severity=7.5))

# Event subscription
emergency_services.subscribe(DisasterOccurredEvent, handle_disaster_response)
healthcare.subscribe(DisasterOccurredEvent, prepare_for_casualties)
```

Benefits:
- **Decoupling**: Publishers don't know about subscribers
- **Extensibility**: New subscribers can be added without modifying publishers
- **Async Support**: Events can be processed asynchronously
- **Replay**: Event streams can be recorded and replayed

### 4. Dependency Injection

All components receive their dependencies through constructors:

```python
class HealthcareSubsystem:
    def __init__(
        self,
        settings: HealthcareSettings,
        random_service: RandomService,
        event_bus: EventBus,
        logger: Logger
    ):
        self.settings = settings
        self.random = random_service
        self.events = event_bus
        self.logger = logger
```

Benefits:
- **Testability**: Easy to inject mock dependencies for testing
- **Flexibility**: Different implementations can be injected
- **Clarity**: Dependencies are explicit and visible
- **No Globals**: Eliminates hidden global state

## Subsystem Interaction Patterns

### Pattern 1: Sequential Dependency Chain

When subsystems must execute in order due to dependencies:

```
Environment → Population → Finance → Transportation → Logging
```

Example: Transportation needs to know population distribution (from Population) and budget for infrastructure (from Finance).

Implementation:
```python
def execute_tick_sequential(city, context):
    env_delta = environment.update(city, context)
    pop_delta = population.update(city, context)  # Uses env_delta
    fin_delta = finance.update(city, context)     # Uses pop_delta
    trans_delta = transport.update(city, context) # Uses all previous
    return aggregate_deltas([env_delta, pop_delta, fin_delta, trans_delta])
```

### Pattern 2: Parallel Execution Groups

When subsystems are independent, they can execute in parallel:

```
        ┌─ Environment ──┐
Parallel│─ Population ───│→ Aggregate → Sequential Phase
        └─ Education ────┘
```

Implementation using free-threaded Python:
```python
def execute_tick_parallel(city, context):
    with ThreadPoolExecutor() as executor:
        # Phase 1: Parallel independent subsystems
        futures = [
            executor.submit(environment.update, city, context),
            executor.submit(population.update, city, context),
            executor.submit(education.update, city, context)
        ]
        deltas = [f.result() for f in futures]
        
        # Phase 2: Sequential dependent subsystems
        finance_delta = finance.update(city, context)
        deltas.append(finance_delta)
        
        return aggregate_deltas(deltas)
```

### Pattern 3: Event-Driven Cascade

When one subsystem's output triggers actions in multiple other subsystems:

```
                    ┌→ Emergency Services
Disaster Occurs → Event Bus ─→ Healthcare
                    └→ Finance (insurance payouts)
```

Implementation:
```python
class EnvironmentSubsystem:
    def update(self, city, context):
        disasters = self.evaluate_disasters(city)
        for disaster in disasters:
            # Publish event - subscribers will react
            self.events.publish(DisasterOccurredEvent(disaster))
        return EnvironmentDelta(disasters=disasters)

class EmergencyServices:
    def __init__(self, event_bus):
        event_bus.subscribe(DisasterOccurredEvent, self.respond_to_disaster)
    
    def respond_to_disaster(self, event):
        # Automatically triggered when disaster occurs
        self.activate_disaster_response(event.disaster)
```

### Pattern 4: Aggregation and Analysis

Multiple subsystems contribute to city-wide metrics:

```
Environment ─┐
Population ──┤
Finance ─────┼→ Metrics Collector → Happiness Calculator
Education ───┤                    → Performance Reports
Healthcare ──┘
```

Implementation:
```python
class MetricsCollector:
    def collect_metrics(self, deltas: list[SubsystemDelta]) -> CityMetrics:
        metrics = CityMetrics()
        
        for delta in deltas:
            if isinstance(delta, EnvironmentDelta):
                metrics.add_environmental_metrics(delta)
            elif isinstance(delta, PopulationDelta):
                metrics.add_population_metrics(delta)
            # ... etc for all subsystems
        
        metrics.calculate_aggregate_metrics()
        return metrics
```

## Data Flow Architecture

### Tick Execution Data Flow

Detailed flow of data through a single simulation tick:

```
1. Tick Initialization
   ├─ Create TickContext
   │  ├─ tick_index
   │  ├─ timestamp
   │  ├─ random_state
   │  └─ settings
   └─ Clone city state for subsystem updates

2. Policy Evaluation
   ├─ PolicyEngine evaluates all active policies
   ├─ Generates Decision objects
   └─ CityManager applies decisions to city state

3. Subsystem Updates (Parallel where possible)
   ├─ Phase 1: Independent subsystems
   │  ├─ Environment.update() → EnvironmentDelta
   │  ├─ Population.update() → PopulationDelta
   │  └─ Education.update() → EducationDelta
   │
   ├─ Phase 2: Dependent subsystems
   │  ├─ Finance.update() → FinanceDelta
   │  ├─ Healthcare.update() → HealthcareDelta
   │  └─ EmergencyServices.update() → EmergencyServicesDelta
   │
   └─ Phase 3: Final subsystems
      └─ Transportation.update() → TransportDelta

4. Event Processing
   ├─ EventBus delivers queued events
   └─ Subscribers process events

5. Metrics Collection
   ├─ Aggregate all SubsystemDeltas
   ├─ Calculate city-wide metrics
   └─ Compute happiness, performance scores

6. Logging
   ├─ Format metrics for output
   ├─ Write to log files (JSONL/CSV)
   └─ Update visualization data

7. Tick Finalization
   ├─ Create TickResult
   ├─ Update city state
   └─ Return TickResult to simulation core
```

### State Management

City state is managed carefully to support both parallelism and determinism:

```python
class CityState:
    """
    Immutable snapshot of city state at a point in time.
    """
    def __init__(self, data: dict):
        self._data = immutable_dict(data)
    
    def get(self, key: str):
        return self._data[key]
    
    def update(self, changes: dict) -> 'CityState':
        """Create new state with changes applied."""
        new_data = self._data.copy()
        new_data.update(changes)
        return CityState(new_data)

# Usage in parallel execution
def parallel_update(city_state: CityState, context: TickContext):
    # Each subsystem gets read-only access to state
    state_snapshot = city_state.snapshot()
    
    # Parallel updates work on snapshots
    with ThreadPoolExecutor() as executor:
        futures = [
            executor.submit(subsystem.compute_delta, state_snapshot, context)
            for subsystem in subsystems
        ]
        deltas = [f.result() for f in futures]
    
    # Sequential application of deltas to state
    new_state = city_state
    for delta in deltas:
        new_state = new_state.apply_delta(delta)
    
    return new_state
```

## Subsystem Communication Matrix

This matrix shows which subsystems directly interact:

```
                    Env Pop Fin Edu HC  ES  Tra Cul Eco Gov
Environment (Env)   │   ✓   -   -   -   ✓   ✓   -   -   -
Population (Pop)    ✓   │   ✓   ✓   ✓   -   ✓   ✓   ✓   ✓
Finance (Fin)       -   ✓   │   ✓   ✓   ✓   ✓   ✓   ✓   ✓
Education (Edu)     -   ✓   ✓   │   ✓   -   -   ✓   ✓   -
Healthcare (HC)     ✓   ✓   ✓   -   │   ✓   -   -   ✓   -
Emergency (ES)      ✓   ✓   ✓   -   ✓   │   ✓   -   ✓   ✓
Transport (Tra)     ✓   ✓   ✓   -   -   ✓   │   ✓   ✓   -
Culture (Cul)       -   ✓   ✓   ✓   -   -   ✓   │   ✓   ✓
Economy (Eco)       -   ✓   ✓   ✓   ✓   ✓   ✓   ✓   │   ✓
Governance (Gov)    -   ✓   ✓   -   -   ✓   -   ✓   ✓   │

Legend:
│ = Self (diagonal)
✓ = Direct interaction
- = No direct interaction (may interact via events)
```

### Key Interaction Patterns

**Environment → All**: Weather affects energy demand, health, traffic, construction
**Population → All**: Population size affects all service demands
**Finance → All**: Budget constraints affect all subsystem operations
**Transportation → Most**: Traffic affects emergency response, commutes, commerce

## Parallelization Strategy

### Dependency Graph

Visualizing subsystem dependencies for parallelization:

```
Level 0 (No Dependencies):
├─ Environment
├─ Random Events
└─ Time/Calendar

Level 1 (Depends on Level 0):
├─ Population (needs Environment)
├─ Base Infrastructure (independent)
└─ Base Geography (independent)

Level 2 (Depends on Level 0-1):
├─ Education (needs Population)
├─ Healthcare (needs Population, Environment)
├─ Employment (needs Population)
└─ Housing Market (needs Population)

Level 3 (Depends on Level 0-2):
├─ Finance (needs Population, Employment, Infrastructure)
├─ Emergency Services (needs Infrastructure, Population)
├─ Crime (needs Population, Employment, Education)
└─ Culture (needs Population, Education, Finance)

Level 4 (Depends on Level 0-3):
├─ Transportation (needs all others for demand modeling)
└─ Governance (needs all others for policy effects)

Level 5 (Final):
├─ Metrics Aggregation
├─ Happiness Calculation
└─ Logging
```

### Parallel Execution Groups

Groups that can execute simultaneously:

**Group A**: Environment, Random Events, Calendar
**Group B**: Population, Base Infrastructure (wait for A)
**Group C**: Education, Healthcare, Employment, Housing (wait for B)
**Group D**: Finance, Emergency Services, Crime, Culture (wait for C)
**Group E**: Transportation, Governance (wait for D)
**Group F**: Metrics, Happiness, Logging (wait for E)

Expected speedup on 4-core system:
- Sequential: 6 serial steps
- Parallel: ~3-4 parallel steps
- Speedup: ~1.5-2.0× (accounting for synchronization overhead)

## Extensibility Mechanisms

### 1. Plugin Architecture

New subsystems can be added as plugins:

```python
class ISubsystemPlugin:
    """Interface for subsystem plugins."""
    
    def get_name(self) -> str:
        """Unique subsystem name."""
    
    def get_dependencies(self) -> list[str]:
        """List of subsystems this plugin depends on."""
    
    def initialize(self, city: City, settings: Settings):
        """Initialize subsystem."""
    
    def update(self, city: City, context: TickContext) -> SubsystemDelta:
        """Update subsystem for one tick."""
    
    def get_metrics(self) -> dict:
        """Return current metrics."""

# Plugin registration
plugin_registry.register(MyCustomSubsystem())
```

### 2. Policy Extension Points

Custom policies can be injected:

```python
class IPolicy:
    """Interface for custom policies."""
    
    def evaluate(self, city: City, context: TickContext) -> list[Decision]:
        """Evaluate policy and generate decisions."""
    
    def get_cost(self) -> float:
        """Return policy implementation cost."""
    
    def get_effects(self) -> dict:
        """Return expected policy effects."""

# Policy registration
policy_engine.register_policy(CarbonTaxPolicy())
```

### 3. Event Hooks

Custom logic can hook into simulation events:

```python
# Register custom handler
@event_bus.on(TickCompleteEvent)
def custom_analysis(event):
    # Custom per-tick analysis
    city = event.city
    metrics = event.metrics
    analyze_and_report(city, metrics)

# Register for multiple events
@event_bus.on([DisasterOccurredEvent, CrimeIncidentEvent])
def emergency_analyzer(event):
    # Analyze emergency patterns
    track_emergency_trends(event)
```

### 4. Data Export Adapters

Custom output formats can be added:

```python
class ILogAdapter:
    """Interface for custom log output formats."""
    
    def write_tick(self, tick_result: TickResult):
        """Write tick results in custom format."""
    
    def finalize(self, run_report: RunReport):
        """Write final run report."""

# Adapter registration
logger.add_adapter(DatabaseLogAdapter(connection_string))
logger.add_adapter(ElasticsearchAdapter(es_client))
```

## Performance Optimization Strategies

### 1. Caching and Memoization

Expensive calculations are cached:

```python
class TransportationSubsystem:
    def __init__(self):
        self._route_cache = {}  # Cache calculated routes
        self._distance_matrix = None  # Cache distance calculations
    
    @memoize(max_size=1000)
    def calculate_route(self, start, end):
        """Cached route calculation."""
        # Expensive A* pathfinding
        return find_shortest_path(start, end)
    
    def invalidate_caches(self):
        """Clear caches when road network changes."""
        self._route_cache.clear()
```

### 2. Level of Detail

Distant or less important subsystems can use simplified models:

```python
class DetailLevel(Enum):
    FULL = "full"           # Full simulation
    MEDIUM = "medium"       # Simplified simulation
    LIGHT = "light"         # Statistical approximation
    DISABLED = "disabled"   # Subsystem disabled

# Configuration
settings = SimulationSettings(
    detail_levels={
        "environment": DetailLevel.FULL,
        "population": DetailLevel.FULL,
        "traffic": DetailLevel.MEDIUM,    # Simplified traffic
        "cultural_events": DetailLevel.LIGHT,  # Statistics only
        "minor_services": DetailLevel.DISABLED
    }
)
```

### 3. Incremental Updates

Only update changed data:

```python
class PopulationSubsystem:
    def update(self, city, context):
        # Only recalculate for changed districts
        changed_districts = city.get_changed_districts()
        
        for district in changed_districts:
            district.population = self.calculate_population(district)
        
        # Other districts keep cached values
        return PopulationDelta(changed_districts=changed_districts)
```

### 4. Batch Processing

Process similar operations in batches:

```python
def process_citizens_batch(citizens, batch_size=1000):
    """Process citizens in batches for efficiency."""
    for i in range(0, len(citizens), batch_size):
        batch = citizens[i:i+batch_size]
        # Process entire batch with vectorized operations
        batch_results = vectorized_happiness_calculation(batch)
        yield from batch_results
```

## Error Handling and Recovery

### Error Handling Strategy

```python
class SubsystemError(Exception):
    """Base exception for subsystem errors."""
    pass

class SubsystemUpdateError(SubsystemError):
    """Error during subsystem update."""
    pass

class SubsystemInitializationError(SubsystemError):
    """Error during subsystem initialization."""
    pass

# Error handling in simulation core
def execute_tick(city, context):
    results = {}
    errors = []
    
    for subsystem in subsystems:
        try:
            result = subsystem.update(city, context)
            results[subsystem.name] = result
        except SubsystemError as e:
            # Log error and continue with other subsystems
            logger.error(f"Subsystem {subsystem.name} failed: {e}")
            errors.append((subsystem.name, e))
            # Use default/fallback result
            results[subsystem.name] = subsystem.get_fallback_result()
    
    if errors:
        # Record tick completed with errors
        return TickResult(results, errors=errors, status=TickStatus.PARTIAL)
    else:
        return TickResult(results, status=TickStatus.SUCCESS)
```

### Recovery Mechanisms

1. **Fallback Values**: Use last known good values when subsystem fails
2. **Graceful Degradation**: Continue with reduced functionality
3. **State Snapshots**: Periodic state snapshots for recovery
4. **Error Isolation**: Prevent one subsystem failure from cascading

## Testing Strategy

### Unit Testing

Each subsystem has comprehensive unit tests:

```python
class TestHealthcareSubsystem(unittest.TestCase):
    def setUp(self):
        self.settings = HealthcareSettings.defaults()
        self.random = RandomService(seed=42)
        self.healthcare = HealthcareSubsystem(self.settings, self.random)
    
    def test_disease_transmission_deterministic(self):
        """Disease transmission is deterministic with same seed."""
        city = self.create_test_city()
        context = self.create_test_context(seed=42)
        
        result1 = self.healthcare.simulate_disease_transmission(city, context)
        result2 = self.healthcare.simulate_disease_transmission(city, context)
        
        self.assertEqual(result1.new_infections, result2.new_infections)
```

### Integration Testing

Test interactions between subsystems:

```python
class TestEmergencyHealthcareIntegration(unittest.TestCase):
    def test_disaster_triggers_medical_response(self):
        """Disaster should trigger both emergency services and healthcare."""
        # Setup
        city = self.create_city_with_disaster()
        
        # Execute tick
        result = execute_tick(city, context)
        
        # Verify emergency services activated
        self.assertTrue(result.emergency_services.disaster_response_active)
        
        # Verify healthcare prepared for casualties
        self.assertGreater(result.healthcare.emergency_capacity_activated, 0)
```

### Determinism Testing

Verify identical results with same seed:

```python
class TestDeterminism(unittest.TestCase):
    def test_full_simulation_deterministic(self):
        """Complete simulation produces identical results with same seed."""
        seed = 12345
        ticks = 1000
        
        run1 = run_simulation(seed=seed, ticks=ticks)
        run2 = run_simulation(seed=seed, ticks=ticks)
        
        # Compare all metrics
        for tick in range(ticks):
            self.assertEqual(run1.metrics[tick], run2.metrics[tick])
```

### Performance Testing

Benchmark performance targets:

```python
class TestPerformance(unittest.TestCase):
    def test_large_city_performance(self):
        """Large city simulation meets performance targets."""
        city = self.create_large_city(population=1_000_000)
        
        start_time = time.time()
        for _ in range(100):  # 100 ticks
            execute_tick(city, context)
        elapsed = time.time() - start_time
        
        ticks_per_second = 100 / elapsed
        self.assertGreater(ticks_per_second, 5)  # Target: 5+ ticks/sec
```

## Deployment Architecture

### Single-Machine Deployment

For standalone simulation:

```
┌─────────────────────────────────────┐
│   City-Sim Process                  │
│   ┌──────────────────────────────┐  │
│   │  Simulation Core              │  │
│   │  ├─ Subsystems (parallel)    │  │
│   │  ├─ Event Bus                │  │
│   │  └─ Logging                  │  │
│   └──────────────────────────────┘  │
│              ↓                       │
│   ┌──────────────────────────────┐  │
│   │  File System                  │  │
│   │  ├─ Logs (JSONL/CSV)         │  │
│   │  ├─ Configuration             │  │
│   │  └─ Checkpoints              │  │
│   └──────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Distributed Deployment (Future)

For massive simulations or multiplayer:

```
┌────────────────┐       ┌────────────────┐
│  Web Frontend  │◄─────►│  API Gateway   │
└────────────────┘       └────────────────┘
                                │
                         ┌──────┴───────┐
                         │              │
                ┌────────▼────┐  ┌──────▼──────┐
                │ Simulation  │  │  Database   │
                │   Cluster   │  │  (State)    │
                │             │  │             │
                │ ┌─────────┐ │  └─────────────┘
                │ │ Node 1  │ │
                │ │ Node 2  │ │
                │ │ Node N  │ │
                │ └─────────┘ │
                └─────────────┘
```

## Conclusion

This architecture provides:

- **Scalability**: Parallel execution leveraging modern multi-core processors
- **Extensibility**: Clean interfaces for adding new features
- **Maintainability**: Clear separation of concerns and well-defined contracts
- **Performance**: Optimizations at multiple levels from caching to parallelization
- **Reliability**: Comprehensive error handling and recovery mechanisms
- **Testability**: Each component can be tested independently

The architecture supports the ambitious goal of simulating every aspect of city life while maintaining code quality, performance, and deterministic behavior. As the simulation grows, this architecture can scale both vertically (more powerful hardware) and horizontally (distributed execution).

## Related Documentation

- [Architecture Overview](overview.md): High-level architecture description
- [Class Hierarchy](class-hierarchy.md): Detailed class relationships
- [Feature Catalog](../FEATURE_CATALOG.md): Complete feature list
- [ADR-002: Free-Threaded Python](../adr/002-free-threaded-python.md): Parallelization strategy
- [Performance Guide](../guides/performance.md): Performance optimization techniques
- [Contributing Guide](../guides/contributing.md): How to extend the architecture
