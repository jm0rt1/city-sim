# Class Hierarchy Reference

## Purpose & Scope

This document provides a comprehensive reference for the City-Sim class hierarchy, detailing the responsibilities, relationships, and design patterns across all major components. It serves as the authoritative guide for:

- Understanding how classes relate to each other (composition, inheritance, dependencies)
- Identifying the responsibilities and key methods of each class
- Locating extension points for adding new features
- Navigating the codebase architecture

This document complements the [Architecture Overview](overview.md) and individual component specifications in [`docs/specs/`](../specs/).

**Target Audience**: Developers implementing features, contributors extending the system, and architects reviewing design decisions.

---

## Contents

1. [Simulation Core](#simulation-core)
2. [Configuration & Settings](#configuration--settings)
3. [City Model](#city-model)
4. [Policy & Decision System](#policy--decision-system)
5. [Finance Subsystem](#finance-subsystem)
6. [Population Subsystem](#population-subsystem)
7. [Transport & Traffic Subsystem](#transport--traffic-subsystem)
8. [Logging & Storage](#logging--storage)
9. [UI & Reporting](#ui--reporting)
10. [Interfaces & Contracts](#interfaces--contracts)
11. [Relationships Summary](#relationships-summary)
12. [Design Patterns](#design-patterns)
13. [Extension Points](#extension-points)

---

## Simulation Core

The Simulation Core orchestrates the tick loop, coordinates subsystems, and manages the simulation lifecycle. These classes form the backbone of the execution engine.

### SimRunner

**Purpose**: Top-level orchestrator for complete simulation runs.

**Responsibilities**:
- Initialize simulation from `Settings` and scenario configuration
- Create and configure `SimCore` instance
- Execute the simulation run from start to completion
- Produce final `RunReport` with aggregated results and KPIs
- Handle top-level error scenarios and reporting

**Key Methods**:
- `__init__(settings: Settings)`: Initialize with configuration
- `run() -> RunReport`: Execute complete simulation and return final report
- `_validate_settings()`: Pre-flight validation of configuration

**Relationships**:
- **Creates**: `SimCore` (composition)
- **Uses**: `Settings`, `ScenarioLoader`
- **Produces**: `RunReport`

**Usage Notes**:
- Entry point for programmatic simulation execution
- Handles initialization and finalization phases
- See [Simulation Specification](../specs/simulation.md#simrunner) for detailed contract

**Example**:
```python
settings = Settings.from_scenario("baseline")
runner = SimRunner(settings)
report = runner.run()
print(f"Final budget: {report.final_budget}")
```

---

### SimCore

**Purpose**: Core tick engine that executes the simulation loop and coordinates all subsystems.

**Responsibilities**:
- Execute the main tick loop for configured horizon
- Create `TickContext` for each tick with current settings and policy set
- Coordinate subsystem updates in defined order (Finance → Population → Transport)
- Collect metrics via `MetricsCollector` after each tick
- Emit events via `EventBus` for decoupled component communication
- Ensure deterministic execution through controlled subsystem ordering

**Key Methods**:
- `__init__(city: City, settings: Settings, ...)`: Initialize with city and dependencies
- `run_tick() -> TickResult`: Execute single tick and return results
- `run_simulation() -> List[TickResult]`: Execute all ticks to horizon
- `_update_subsystems(ctx: TickContext) -> CityDelta`: Coordinate subsystem updates
- `_collect_metrics(delta: CityDelta) -> Dict`: Gather tick metrics

**Key Attributes**:
- `city: City`: The city being simulated
- `tick_scheduler: TickScheduler`: Manages tick progression
- `event_bus: EventBus`: Event publishing system
- `metrics_collector: MetricsCollector`: Aggregates metrics
- `random_service: RandomService`: Deterministic random source
- `policy_engine: PolicyEngine`: Evaluates policies
- `city_manager: CityManager`: Applies state changes

**Relationships**:
- **Aggregates**: `City`, `TickScheduler`, `EventBus`, `MetricsCollector`, `RandomService`, `PolicyEngine`, `CityManager`
- **Creates**: `TickContext` per tick, `TickResult` per tick
- **Used by**: `SimRunner`

**Usage Notes**:
- Central coordinator for all simulation activity
- Maintains strict subsystem update ordering for determinism
- See [Simulation Specification](../specs/simulation.md#simcore) for tick execution details

**Example**:
```python
core = SimCore(city, settings, ...)
for tick in range(settings.tick_horizon):
    result = core.run_tick()
    logger.log_tick(result)
```

---

### TickScheduler

**Purpose**: Computes the next tick index and manages simulation clock progression.

**Responsibilities**:
- Determine next tick index (currently simple increment, future: variable time steps)
- Track current simulation time
- Support potential future features like pause/resume or variable tick rates

**Key Methods**:
- `next_tick() -> int`: Compute and return next tick index
- `current_tick() -> int`: Return current tick index
- `reset()`: Reset scheduler to initial state

**Relationships**:
- **Used by**: `SimCore`
- **Stateless**: No dependencies on other components

**Usage Notes**:
- Currently implements simple increment (tick_n+1)
- Designed for future extensibility (variable time steps, seasons)
- Maintains no state beyond current tick counter

---

### EventBus / EventQueue / EventHandler / Event

**Purpose**: Publish/subscribe infrastructure enabling decoupled communication between components.

**Responsibilities**:
- **EventBus**: Central message broker for publishing and subscribing
- **EventQueue**: FIFO queue for event delivery
- **EventHandler**: Interface for components that react to events
- **Event**: Base class for all event types

**Key Methods**:
- `EventBus.publish(event: Event)`: Publish event to all subscribers
- `EventBus.subscribe(event_type: Type[Event], handler: EventHandler)`: Register handler
- `EventHandler.handle(event: Event)`: Process received event

**Relationships**:
- **Used by**: All subsystems and components that need decoupled communication
- **Contains**: `EventQueue` for buffering events

**Design Pattern**: **Observer Pattern** - Publishers don't know about subscribers

**Usage Notes**:
- Events are processed synchronously within each tick
- Supports multiple handlers per event type
- Useful for cross-cutting concerns (logging, metrics, alerts)

**Example**:
```python
# Subscribe to population changes
event_bus.subscribe(PopulationChangedEvent, population_logger)

# Publish event when population changes
event_bus.publish(PopulationChangedEvent(delta=100, new_total=50000))
```

---

### TickContext

**Purpose**: Encapsulates all contextual information available during a single tick.

**Responsibilities**:
- Provide read-only access to current settings
- Expose active policy set for the tick
- Track current tick index and simulation time
- Provide access to `RandomService` for deterministic randomness

**Key Attributes**:
- `settings: Settings`: Global configuration (read-only)
- `policy_set: PolicySet`: Active policies for this tick
- `tick_index: int`: Current tick number (0-based)
- `random_service: RandomService`: Seeded random source

**Relationships**:
- **Created by**: `SimCore` for each tick
- **Passed to**: All subsystem `update()` methods
- **Provides**: `Settings`, `PolicySet`, `RandomService`

**Usage Notes**:
- Immutable during tick execution
- Ensures subsystems have consistent view of configuration
- Enables deterministic behavior through controlled random access

---

### TickResult

**Purpose**: Contains all outputs produced during a single tick execution.

**Responsibilities**:
- Aggregate metrics from all subsystems
- Contain state delta summaries (`CityDelta`, `FinanceDelta`, `PopulationDelta`, `TrafficDelta`)
- Track events emitted during tick
- Provide structured data for logging

**Key Attributes**:
- `tick_index: int`: Which tick produced this result
- `city_delta: CityDelta`: Summary of city state changes
- `metrics: Dict[str, float]`: Collected metrics (KPIs, performance)
- `events: List[Event]`: Events emitted during tick
- `duration_ms: float`: Tick execution time (for profiling)

**Relationships**:
- **Created by**: `SimCore` after each tick
- **Contains**: `CityDelta` (and nested deltas)
- **Used by**: `Logger`, `MetricsCollector`, `SimRunner`

**Usage Notes**:
- Designed for efficient serialization to logs
- Contains all information needed for tick reconstruction
- See [Logging Specification](../specs/logging.md) for output format

---

### MetricsCollector

**Purpose**: Aggregates metrics from subsystems and flushes to loggers.

**Responsibilities**:
- Collect KPI metrics (budget, population, happiness, congestion)
- Collect performance metrics (tick duration, subsystem timing)
- Buffer metrics for batch flushing
- Format metrics for logger consumption

**Key Methods**:
- `collect_metric(name: str, value: float)`: Record single metric
- `collect_batch(metrics: Dict[str, float])`: Record multiple metrics
- `flush(logger: ILogger)`: Write buffered metrics to logger
- `reset()`: Clear buffers for next tick

**Relationships**:
- **Used by**: `SimCore`
- **Uses**: `ILogger` (interface)
- **Aggregates from**: All subsystems

**Design Pattern**: **Sink Pattern** - Central collection point for metrics

**Usage Notes**:
- Decouples metric production from logging
- Supports multiple logger backends
- See [Logging Specification](../specs/logging.md#metrics-collector)

---

### Profiler / ProfileReport

**Purpose**: Optional performance profiling to identify bottlenecks.

**Responsibilities**:
- **Profiler**: Instrument code paths and measure execution time
- **ProfileReport**: Summarize profiling data with timing breakdowns

**Key Methods**:
- `Profiler.start(label: str)`: Begin timing section
- `Profiler.stop(label: str)`: End timing section
- `Profiler.report() -> ProfileReport`: Generate summary

**Relationships**:
- **Used by**: `SimCore`, subsystems (optional)
- **Produces**: `ProfileReport`

**Usage Notes**:
- Profiling disabled by default (minimal overhead)
- Enable via `Settings.enable_profiling = True`
- Useful for identifying performance regressions

---

### RandomService

**Purpose**: Provides seedable, deterministic random number generation for all subsystems.

**Responsibilities**:
- Initialize from seed value in `Settings`
- Generate random values (uniform, normal, choice)
- Ensure deterministic behavior across runs with same seed
- Provide consistent random state throughout simulation

**Key Methods**:
- `__init__(seed: int)`: Initialize with seed
- `random() -> float`: Random float in [0, 1)
- `randint(a: int, b: int) -> int`: Random integer in [a, b]
- `choice(seq: Sequence) -> Any`: Random element from sequence
- `normal(mu: float, sigma: float) -> float`: Normal distribution sample

**Relationships**:
- **Created by**: `SimRunner` from `Settings.seed`
- **Used by**: All subsystems through `TickContext`

**Design Pattern**: **Service Locator** - Centralized random source

**Determinism Contract**:
- Identical seed → Identical random sequence → Identical simulation output
- See [ADR-001: Simulation Determinism](../adr/001-simulation-determinism.md)

**Usage Notes**:
- All randomness MUST go through `RandomService`
- Never use Python's global `random` module
- Critical for reproducible testing

---

### ScenarioLoader

**Purpose**: Loads predefined scenarios by name and initializes simulation settings.

**Responsibilities**:
- Parse scenario definition files (JSON/YAML)
- Construct `Settings` object with scenario parameters
- Load scenario-specific policies and initial conditions
- Validate scenario definitions

**Key Methods**:
- `load(scenario_name: str) -> Settings`: Load scenario by name
- `list_scenarios() -> List[str]`: List available scenarios
- `validate_scenario(scenario: Dict) -> bool`: Validate scenario definition

**Relationships**:
- **Creates**: `Settings`, `PolicySet`
- **Used by**: `SimRunner`, CLI

**Usage Notes**:
- Scenarios defined in configuration files or programmatically
- See [Scenarios Specification](../specs/scenarios.md) for format

**Example**:
```python
loader = ScenarioLoader()
settings = loader.load("rapid_growth")
runner = SimRunner(settings)
```

---

## Configuration & Settings

Configuration classes manage simulation parameters, scenario definitions, and policy sets. These classes define the "what" and "how" of simulation runs.

### Settings

**Purpose**: Global configuration container for simulation runs.

**Responsibilities**:
- Define tick horizon, seed, logging configuration
- Reference active `PolicySet`
- Store scenario-specific parameters
- Provide validation of configuration values

**Key Attributes**:
- `seed: int`: Random seed for deterministic execution
- `tick_horizon: int`: Number of ticks to simulate
- `policy_set: PolicySet`: Active policies for the run
- `scenario_name: str`: Identifier for the scenario
- `enable_profiling: bool`: Enable performance profiling
- `log_level: str`: Logging verbosity
- `output_directory: str`: Where to write logs and reports

**Key Methods**:
- `from_scenario(name: str) -> Settings`: Create from scenario definition
- `validate() -> bool`: Validate configuration consistency
- `to_dict() -> Dict`: Serialize for logging

**Relationships**:
- **Contains**: `PolicySet`
- **Created by**: `ScenarioLoader`, `SimRunner`
- **Used by**: `SimCore`, all subsystems via `TickContext`

**Usage Notes**:
- Immutable during simulation run
- All subsystems receive copy via `TickContext`
- See [Simulation Specification](../specs/simulation.md#settings)

**Example**:
```python
settings = Settings(
    seed=42,
    tick_horizon=1000,
    policy_set=PolicySet([TaxPolicy(), ZoningPolicy()]),
    scenario_name="baseline"
)
```

---

### Scenario

**Purpose**: Named configuration template with specific parameters and policies.

**Responsibilities**:
- Define scenario-specific parameters (initial budget, population, policies)
- Provide reproducible starting conditions
- Enable comparative analysis between scenarios

**Key Attributes**:
- `name: str`: Scenario identifier
- `description: str`: Human-readable description
- `parameters: Dict`: Scenario-specific values
- `policy_set: PolicySet`: Policies active in this scenario
- `initial_city_state: Dict`: Starting city configuration

**Relationships**:
- **Loaded by**: `ScenarioLoader`
- **Produces**: `Settings` when loaded

**Usage Notes**:
- Scenarios defined as JSON/YAML files or programmatically
- Examples: "baseline", "rapid_growth", "austerity"
- See [Scenarios Specification](../specs/scenarios.md)

---

### PolicySet

**Purpose**: Collection of `IPolicy` instances active during simulation.

**Responsibilities**:
- Maintain ordered list of policies
- Provide policy lookup and iteration
- Support policy addition/removal (for dynamic scenarios)

**Key Attributes**:
- `policies: List[IPolicy]`: Ordered list of active policies

**Key Methods**:
- `add_policy(policy: IPolicy)`: Add policy to set
- `remove_policy(policy_id: str)`: Remove policy by identifier
- `get_policies() -> List[IPolicy]`: Return all policies
- `__iter__()`: Iterate over policies

**Relationships**:
- **Contains**: List of `IPolicy` implementations
- **Contained by**: `Settings`, `TickContext`
- **Used by**: `PolicyEngine`

**Usage Notes**:
- Policies evaluated in order added
- Can be modified between scenarios but not during ticks

---

### SeedProvider

**Purpose**: Supplies deterministic seeds for subsystems and components.

**Responsibilities**:
- Derive child seeds from master seed
- Ensure each subsystem gets unique, deterministic seed
- Support seed hierarchy for reproducibility

**Key Methods**:
- `derive_seed(component: str) -> int`: Generate seed for component
- `get_subsystem_seed(name: str) -> int`: Get seed for subsystem

**Relationships**:
- **Used by**: `RandomService`, `SimCore`
- **Configured from**: `Settings.seed`

**Design Pattern**: **Deterministic Derivation** - One master seed → Many component seeds

**Usage Notes**:
- Enables reproducible parallel subsystem initialization
- Each subsystem can have independent random stream
- See [ADR-001](../adr/001-simulation-determinism.md) for rationale


---

## City Model

The City Model represents the aggregate city state and provides operations for state transitions. These classes form the core data model manipulated during simulation.

### City (Aggregate Root)

**Purpose**: Aggregate root containing all city state and structure.

**Responsibilities**:
- Maintain complete city state (`CityState`)
- Organize geographical structure (districts, buildings)
- Enforce structural integrity (districts contain buildings, etc.)
- Provide read-only access to state for subsystems
- Track city metadata (ID, name, founding tick)

**Key Attributes**:
- `city_id: str`: Unique identifier
- `name: str`: Human-readable name
- `state: CityState`: Current mutable state (budget, population, happiness)
- `districts: List[District]`: Geographical subdivisions
- `founded_tick: int`: Tick when city was created
- `current_tick: int`: Current simulation tick

**Key Methods**:
- `__init__(city_id, name, initial_state, districts)`: Initialize city
- `get_state() -> CityState`: Access current state (read-only)
- `get_district(district_id) -> District`: Look up district by ID
- `get_total_capacity() -> int`: Sum capacity across all buildings

**Relationships**:
- **Contains (composition)**: `CityState`, `List[District]`
- **Modified by**: `CityManager` only (encapsulation)
- **Read by**: All subsystems

**Design Pattern**: **Aggregate Root** - Central access point for all city data

**Invariants**:
- `city_id` and `name` immutable after creation
- `state.population >= 0` at all times
- `state.happiness` in range [0, 100]
- District list can grow but not shrink (cities don't lose districts)

**Usage Notes**:
- All state modifications go through `CityManager`
- Direct state mutation violates encapsulation
- See [City Specification](../specs/city.md#city-aggregate-root)

**Example**:
```python
city = City(
    city_id="city_001",
    name="Springfield",
    initial_state=CityState(budget=1_000_000, population=10_000, ...),
    districts=[downtown, suburbs]
)
```

---

### CityState

**Purpose**: Contains frequently-changing scalar values for city state.

**Responsibilities**:
- Store current budget, population, happiness
- Reference infrastructure and service states
- Track previous values for delta calculations
- Maintain financial reconciliation invariants

**Key Attributes**:
- `budget: float`: Current treasury balance
- `population: int`: Total population count
- `happiness: float`: Aggregate happiness (0-100)
- `infrastructure: InfrastructureState`: Infrastructure component states
- `services: ServiceState`: Service component states
- `previous_budget: Optional[float]`: Budget at previous tick (validation)
- `previous_population: Optional[int]`: Population at previous tick

**Relationships**:
- **Contained by**: `City` (composition)
- **Contains**: `InfrastructureState`, `ServiceState`
- **Modified by**: Subsystems through `CityManager`

**Invariants**:
- `population >= 0` (enforced by `CityManager`)
- `happiness` in [0, 100] (enforced by `HappinessTracker`)
- Budget reconciliation: `new_budget = old_budget + revenue - expenses`

**Usage Notes**:
- Modified each tick by subsystems
- Previous values used for validation and delta calculation
- See [City Specification](../specs/city.md#citystate)

---

### CityManager

**Purpose**: Orchestrates city state updates and enforces invariants.

**Responsibilities**:
- Apply `Decision` objects to modify city state
- Coordinate subsystem updates (Finance, Population, Transport)
- Produce `CityDelta` summaries of changes
- Validate state transitions and enforce invariants
- Handle edge cases (bankruptcy, zero population, capacity limits)

**Key Methods**:
- `__init__(city: City)`: Initialize with city to manage
- `apply_decision(decision: Decision) -> CityDelta`: Execute single decision
- `update(ctx: TickContext) -> CityDelta`: Run tick update (coordinate subsystems)
- `_validate_state()`: Check invariants before committing changes
- `_calculate_delta(old_state, new_state) -> CityDelta`: Compute state delta

**Key Attributes**:
- `city: City`: The city being managed
- `finance_subsystem: FinanceSubsystem`: Finance coordinator
- `population_subsystem: PopulationSubsystem`: Population coordinator
- `transport_subsystem: TransportSubsystem`: Transport coordinator

**Relationships**:
- **Manages**: `City` (exclusive write access)
- **Coordinates**: `FinanceSubsystem`, `PopulationSubsystem`, `TransportSubsystem`
- **Produces**: `CityDelta` after each update
- **Used by**: `SimCore`, `PolicyEngine`

**Design Pattern**: **Facade Pattern** - Simplifies complex subsystem coordination

**Update Order** (deterministic):
1. Apply pending decisions from `PolicyEngine`
2. Update `FinanceSubsystem` → `FinanceDelta`
3. Update `PopulationSubsystem` → `PopulationDelta`
4. Update `TransportSubsystem` → `TrafficDelta`
5. Validate invariants
6. Construct and return `CityDelta`

**Usage Notes**:
- Single point of city state modification
- Ensures atomicity of state changes
- See [City Specification](../specs/city.md#citymanager)

**Example**:
```python
manager = CityManager(city)
delta = manager.update(tick_context)
logger.log(f"Population changed by {delta.population_delta}")
```

---

### CityDelta

**Purpose**: Summary object describing all changes to city state during a tick.

**Responsibilities**:
- Record state changes (population, budget, happiness)
- Aggregate subsystem deltas (FinanceDelta, PopulationDelta, TrafficDelta)
- Provide structured data for logging and analysis

**Key Attributes**:
- `tick_index: int`: When this delta was produced
- `population_delta: int`: Net population change
- `budget_delta: float`: Net budget change
- `happiness_delta: float`: Change in happiness
- `finance_delta: FinanceDelta`: Detailed finance changes
- `population_delta_detail: PopulationDelta`: Detailed population changes
- `traffic_delta: Optional[TrafficDelta]`: Traffic changes (if transport active)

**Relationships**:
- **Created by**: `CityManager` after each tick
- **Contains**: `FinanceDelta`, `PopulationDelta`, `TrafficDelta`
- **Used by**: `Logger`, `MetricsCollector`, `SimCore`

**Usage Notes**:
- Immutable once created
- Designed for efficient serialization
- See [City Specification](../specs/city.md#citydelta)

---

### District

**Purpose**: Geographical subdivision of the city containing buildings.

**Responsibilities**:
- Organize buildings into logical groups
- Track district-level infrastructure connections
- Provide district-level capacity and occupancy

**Key Attributes**:
- `district_id: str`: Unique identifier
- `name: str`: Human-readable name
- `buildings: List[Building]`: Buildings in this district
- `infrastructure_connections: Dict`: Connected infrastructure systems

**Key Methods**:
- `add_building(building: Building)`: Add building to district
- `get_capacity() -> int`: Sum capacity of all buildings
- `get_occupancy() -> int`: Sum occupied units across buildings

**Relationships**:
- **Contained by**: `City` (composition)
- **Contains**: `List[Building]` (composition)

**Usage Notes**:
- Districts rarely change during simulation
- Used for infrastructure routing and planning
- See [City Specification](../specs/city.md#district)

---

### Building

**Purpose**: Represents individual structures with type-specific capacity and state.

**Responsibilities**:
- Store building type (Residential, Commercial, Industrial, Civic)
- Track capacity and occupancy
- Maintain building-specific state (condition, services connected)

**Key Attributes**:
- `building_id: str`: Unique identifier
- `building_type: BuildingType`: RESIDENTIAL | COMMERCIAL | INDUSTRIAL | CIVIC
- `capacity: int`: Maximum occupancy/usage
- `current_occupancy: int`: Current usage
- `condition: float`: Building condition (0-100)
- `services_connected: Set[str]`: Connected services (water, power, etc.)

**Key Methods**:
- `is_at_capacity() -> bool`: Check if building is full
- `add_occupants(count: int)`: Increase occupancy
- `remove_occupants(count: int)`: Decrease occupancy

**Relationships**:
- **Contained by**: `District` (composition)
- **Used by**: `PopulationSubsystem`, `CityManager`

**Invariant**: `0 <= current_occupancy <= capacity`

**Usage Notes**:
- Building types affect revenue and expense calculations
- Condition affects happiness and maintenance costs
- See [City Specification](../specs/city.md#building)

---

### InfrastructureState

**Purpose**: Represents state of city infrastructure systems.

**Responsibilities**:
- Track infrastructure quality and capacity
- Manage transport networks, utilities, power, water systems
- Provide infrastructure metrics for subsystems

**Key Attributes**:
- `transport_network: TransportNetwork`: Road and transit systems
- `utilities: Utilities`: Water, power, waste management
- `power_grid: PowerGrid`: Electricity generation and distribution
- `water_system: WaterSystem`: Water supply and treatment

**Key Methods**:
- `get_quality() -> float`: Average infrastructure quality (0-100)
- `needs_maintenance() -> bool`: Check if maintenance required
- `degrade(amount: float)`: Natural quality degradation
- `upgrade(component: str, quality_delta: float)`: Improve component

**Relationships**:
- **Contained by**: `CityState` (composition)
- **Used by**: `TransportSubsystem`, `PopulationSubsystem`, `FinanceSubsystem`

**Usage Notes**:
- Infrastructure affects service delivery and happiness
- Quality degrades over time without maintenance
- See [City Specification](../specs/city.md#infrastructurestate)

---

### ServiceState

**Purpose**: Represents state of city services.

**Responsibilities**:
- Track service coverage and quality
- Manage health, education, public safety, housing services
- Provide service metrics for happiness calculations

**Key Attributes**:
- `health_service: HealthService`: Healthcare facilities and coverage
- `education_service: EducationService`: Schools and education quality
- `public_safety_service: PublicSafetyService`: Police, fire, emergency
- `housing_service: HousingService`: Housing availability and quality

**Key Methods**:
- `get_coverage(service_type: str) -> float`: Service coverage percentage
- `get_quality(service_type: str) -> float`: Service quality (0-100)
- `update_service(service_type: str, budget_allocation: float)`: Update service based on funding

**Relationships**:
- **Contained by**: `CityState` (composition)
- **Used by**: `PopulationSubsystem`, `HappinessTracker`, `FinanceSubsystem`

**Usage Notes**:
- Services require budget allocation (expenses)
- Service quality directly affects population happiness
- See [City Specification](../specs/city.md#servicestate)

---

## Policy & Decision System

The Policy and Decision system evaluates city conditions and produces executable rules that modify city state. This implements the strategic logic of city management.

### PolicyEngine

**Purpose**: Evaluates policies against current city state to generate decision rules.

**Responsibilities**:
- Iterate over active `PolicySet` each tick
- Evaluate each policy's conditions against `City` and `TickContext`
- Generate executable `Decision` objects when policy conditions met
- Queue decisions for application by `CityManager`
- Track policy evaluation metrics

**Key Methods**:
- `__init__(policy_set: PolicySet)`: Initialize with policies
- `evaluate(city: City, ctx: TickContext) -> List[Decision]`: Evaluate all policies
- `_evaluate_single_policy(policy: IPolicy, ...) -> Optional[Decision]`: Check single policy
- `get_active_policies() -> List[IPolicy]`: Return currently active policies

**Key Attributes**:
- `policy_set: PolicySet`: Policies to evaluate
- `decision_queue: List[Decision]`: Pending decisions

**Relationships**:
- **Uses**: `PolicySet`, `City`, `TickContext`
- **Produces**: `List[Decision]`
- **Used by**: `SimCore`, `CityManager`

**Design Pattern**: **Strategy Pattern** - Policies are interchangeable strategies

**Evaluation Flow**:
1. For each policy in `policy_set`:
2. Check policy conditions against current city state
3. If conditions met, instantiate `Decision` with policy parameters
4. Add decision to queue
5. Return all generated decisions

**Usage Notes**:
- Policies evaluated in order (deterministic)
- Multiple policies can trigger in same tick
- See [Policy Specification (in city.md)](../specs/city.md#policy-integration)

**Example**:
```python
engine = PolicyEngine(policy_set)
decisions = engine.evaluate(city, tick_context)
for decision in decisions:
    city_manager.apply_decision(decision)
```

---

### Decision

**Purpose**: Executable rule that applies specific state changes to city.

**Responsibilities**:
- Encapsulate policy effect as executable command
- Store parameters for state modification
- Provide execution method
- Track decision metadata (source policy, timestamp)

**Key Attributes**:
- `decision_id: str`: Unique identifier
- `policy_id: str`: Source policy that generated this decision
- `decision_type: str`: Type of decision (TAX_CHANGE, SUBSIDY, ZONING, etc.)
- `parameters: Dict`: Decision-specific parameters
- `tick_issued: int`: When decision was generated

**Key Methods**:
- `execute(city: City) -> None`: Apply decision effects to city
- `can_execute(city: City) -> bool`: Check if preconditions met
- `get_description() -> str`: Human-readable description

**Relationships**:
- **Created by**: `PolicyEngine`
- **Executed by**: `CityManager`
- **Implements**: `IDecisionRule` interface

**Design Pattern**: **Command Pattern** - Encapsulates action as object

**Decision Types**:
- `TAX_CHANGE`: Modify tax rates
- `SUBSIDY`: Allocate subsidies to sectors
- `ZONING`: Change zoning regulations
- `INFRASTRUCTURE_INVESTMENT`: Fund infrastructure projects
- `SERVICE_ADJUSTMENT`: Modify service levels

**Usage Notes**:
- Decisions are idempotent (can be safely re-applied with same result)
- Execution may fail if preconditions not met
- See [Decisions Implementation](../../src/city/decisions.py)

**Example**:
```python
decision = Decision(
    decision_id="dec_001",
    policy_id="tax_policy_balanced",
    decision_type="TAX_CHANGE",
    parameters={"new_tax_rate": 0.15, "reason": "budget_deficit"}
)
if decision.can_execute(city):
    decision.execute(city)
```

---

### IPolicy (Interface)

**Purpose**: Interface contract for all policy implementations.

**Responsibilities**:
- Define policy evaluation contract
- Specify parameters and conditions
- Enable plugin-style policy extensions

**Key Methods** (abstract):
- `evaluate(city: City, ctx: TickContext) -> Optional[Decision]`: Policy logic
- `get_policy_id() -> str`: Unique policy identifier
- `get_description() -> str`: Human-readable description

**Relationships**:
- **Implemented by**: `TaxPolicy`, `SubsidyPolicy`, `ZoningPolicy`, etc.
- **Contained in**: `PolicySet`
- **Evaluated by**: `PolicyEngine`

**Design Pattern**: **Strategy Pattern** - Defines family of algorithms

**Usage Notes**:
- Custom policies must implement this interface
- Policies should be stateless (pure functions of city + context)
- See [Extension Points](#extension-points) for adding custom policies

---

### TaxPolicy

**Purpose**: Adjusts tax rates based on city financial and population conditions.

**Responsibilities**:
- Monitor budget levels and population
- Adjust property, income, and business taxes
- Balance revenue needs against happiness impact

**Key Parameters**:
- `min_budget_threshold: float`: Trigger for tax increases
- `max_budget_threshold: float`: Trigger for tax decreases
- `tax_adjustment_rate: float`: How much to adjust taxes (percentage)

**Evaluation Logic**:
- If `budget < min_threshold`: Increase taxes
- If `budget > max_threshold` AND `happiness < target`: Decrease taxes

**Relationships**:
- **Implements**: `IPolicy`
- **Produces**: `Decision` with `TAX_CHANGE` type

**Usage Notes**:
- Affects revenue calculations in `FinanceSubsystem`
- Tax changes impact happiness (inverse relationship)

---

### SubsidyPolicy

**Purpose**: Allocates subsidies to specific sectors (housing, business, etc.).

**Responsibilities**:
- Identify sectors needing support
- Allocate budget to subsidies
- Track subsidy effectiveness

**Key Parameters**:
- `sector: str`: Which sector to subsidize
- `max_subsidy_budget: float`: Maximum subsidy allocation
- `trigger_conditions: Dict`: When to activate subsidy

**Relationships**:
- **Implements**: `IPolicy`
- **Produces**: `Decision` with `SUBSIDY` type

**Usage Notes**:
- Subsidies reduce effective tax burden
- Can stimulate growth in targeted sectors

---

### ZoningPolicy

**Purpose**: Adjusts zoning regulations to control development.

**Responsibilities**:
- Control residential/commercial/industrial mix
- Influence building construction
- Manage city density and sprawl

**Key Parameters**:
- `target_residential_ratio: float`
- `target_commercial_ratio: float`
- `target_industrial_ratio: float`

**Relationships**:
- **Implements**: `IPolicy`
- **Produces**: `Decision` with `ZONING` type

**Usage Notes**:
- Affects building construction rates
- Long-term impact on city composition

---

### InfrastructureInvestmentPolicy

**Purpose**: Allocates budget to infrastructure maintenance and upgrades.

**Responsibilities**:
- Monitor infrastructure quality
- Prioritize infrastructure investments
- Balance maintenance vs. new construction

**Key Parameters**:
- `min_quality_threshold: float`: Trigger for maintenance
- `investment_priorities: List[str]`: Infrastructure priority order
- `max_investment_per_tick: float`: Budget limit

**Relationships**:
- **Implements**: `IPolicy`
- **Produces**: `Decision` with `INFRASTRUCTURE_INVESTMENT` type

**Usage Notes**:
- Infrastructure quality affects happiness and service delivery
- Maintenance costs increase as infrastructure ages


## Finance Subsystem

The Finance Subsystem models city finances including budget, revenue, expenses, and fiscal impacts.

### FinanceSubsystem

**Purpose**: Computes revenue and expenses each tick, updates budget.

**Responsibilities**:
- Calculate revenue from taxes, fees, other sources
- Calculate expenses for services, infrastructure, operations
- Update budget: `new_budget = old_budget + revenue - expenses`
- Apply fiscal policy effects
- Produce `FinanceDelta` summary

**Key Methods**:
- `__init__(city: City)`: Initialize with city
- `update(city: City, ctx: TickContext) -> FinanceDelta`: Compute tick finances
- `calculate_revenue(city: City) -> float`: Total revenue
- `calculate_expenses(city: City) -> float`: Total expenses

**Key Attributes**:
- `revenue_model: RevenueModel`: Revenue calculation strategy
- `expense_model: ExpenseModel`: Expense calculation strategy

**Relationships**:
- **Uses**: `RevenueModel`, `ExpenseModel`, `City`
- **Produces**: `FinanceDelta`
- **Coordinated by**: `CityManager`
- **Implements**: `ISubsystem`

**Update Order**: First subsystem in tick (finances before population/transport)

**Usage Notes**:
- Ensures budget reconciliation invariant
- See [Finance Specification](../specs/finance.md#financesubsystem)

---

### Budget

**Purpose**: Tracks current city treasury balance.

**Responsibilities**:
- Store current balance
- Support transactions (revenue/expense)
- Validate balance changes
- Track historical balance (optional)

**Key Attributes**:
- `balance: float`: Current treasury balance
- `previous_balance: float`: Balance at previous tick

**Key Methods**:
- `add_revenue(amount: float)`: Increase balance
- `add_expense(amount: float)`: Decrease balance
- `can_afford(amount: float) -> bool`: Check affordability

**Relationships**:
- **Contained by**: `CityState`
- **Modified by**: `FinanceSubsystem`

**Invariant**: Balance must reconcile each tick

---

### RevenueModel

**Purpose**: Strategy for calculating city revenue from various sources.

**Responsibilities**:
- Calculate property tax revenue
- Calculate income tax revenue
- Calculate business tax revenue
- Calculate fees and other revenue
- Apply tax policy effects

**Key Methods**:
- `calculate(city: City, ctx: TickContext) -> float`: Total revenue
- `calculate_property_tax(city: City) -> float`: Property tax component
- `calculate_income_tax(city: City) -> float`: Income tax component
- `calculate_business_tax(city: City) -> float`: Business tax component

**Relationships**:
- **Used by**: `FinanceSubsystem`
- **Uses**: `City` (population, buildings, tax rates)

**Design Pattern**: **Strategy Pattern** - Pluggable calculation method

**Revenue Formula**:
```
total_revenue = property_tax + income_tax + business_tax + fees
property_tax = population * avg_property_value * property_tax_rate
income_tax = population * avg_income * income_tax_rate
business_tax = commercial_buildings * revenue_per_building * business_tax_rate
```

**Usage Notes**:
- Tax rates set by `TaxPolicy`
- See [Finance Specification](../specs/finance.md#revenue-sources)

---

### ExpenseModel

**Purpose**: Strategy for calculating city expenses.

**Responsibilities**:
- Calculate service expenses (health, education, safety, housing)
- Calculate infrastructure maintenance
- Calculate operations and administration
- Apply efficiency modifiers

**Key Methods**:
- `calculate(city: City, ctx: TickContext) -> float`: Total expenses
- `calculate_service_expenses(city: City) -> float`: Service costs
- `calculate_maintenance_expenses(city: City) -> float`: Maintenance costs
- `calculate_operations_expenses(city: City) -> float`: Operations costs

**Relationships**:
- **Used by**: `FinanceSubsystem`
- **Uses**: `City` (services, infrastructure, population)

**Design Pattern**: **Strategy Pattern** - Pluggable calculation method

**Expense Formula**:
```
total_expenses = service_expenses + maintenance_expenses + operations
service_expenses = (health + education + safety + housing) * population
maintenance_expenses = infrastructure_quality_deficit * maintenance_rate
operations = base_operations + (population * per_capita_cost)
```

**Usage Notes**:
- Service levels affect expenses
- Infrastructure degradation increases maintenance costs
- See [Finance Specification](../specs/finance.md#expense-categories)

---

### FinanceDelta

**Purpose**: Per-tick financial outputs and summary.

**Responsibilities**:
- Record revenue breakdown
- Record expense breakdown
- Record net budget change
- Track financial metrics

**Key Attributes**:
- `tick_index: int`
- `revenue: float`: Total revenue this tick
- `expenses: float`: Total expenses this tick
- `budget_delta: float`: Net change (revenue - expenses)
- `revenue_breakdown: Dict[str, float]`: Revenue by source
- `expense_breakdown: Dict[str, float]`: Expenses by category

**Relationships**:
- **Created by**: `FinanceSubsystem`
- **Contained by**: `CityDelta`
- **Used by**: `Logger`, `MetricsCollector`

**Usage Notes**:
- Provides detailed financial audit trail
- See [Finance Specification](../specs/finance.md#financedelta)

---

### FinanceReport

**Purpose**: Summary of financial metrics over time.

**Responsibilities**:
- Aggregate financial data across ticks
- Calculate cumulative metrics
- Provide financial analysis

**Key Attributes**:
- `total_revenue: float`
- `total_expenses: float`
- `final_budget: float`
- `average_revenue_per_tick: float`
- `average_expenses_per_tick: float`

**Relationships**:
- **Created by**: `RunReportWriter`
- **Uses**: `FinanceDelta` history

---

## Population Subsystem

The Population Subsystem models population dynamics including growth, happiness, and migration.

### PopulationSubsystem

**Purpose**: Updates population, happiness, and migration each tick.

**Responsibilities**:
- Calculate population growth/decline
- Update happiness based on city conditions
- Model migration (in/out)
- Maintain demographics
- Produce `PopulationDelta`

**Key Methods**:
- `__init__(city: City)`: Initialize subsystem
- `update(city: City, ctx: TickContext) -> PopulationDelta`: Tick update
- `calculate_growth(city: City) -> int`: Natural population change
- `calculate_migration(city: City) -> int`: Migration impact

**Key Attributes**:
- `population_model: PopulationModel`: Growth calculation strategy
- `happiness_tracker: HappinessTracker`: Happiness computation
- `migration_model: MigrationModel`: Migration calculation

**Relationships**:
- **Uses**: `PopulationModel`, `HappinessTracker`, `MigrationModel`
- **Produces**: `PopulationDelta`
- **Coordinated by**: `CityManager`
- **Implements**: `ISubsystem`

**Update Order**: Second subsystem (after Finance)

**Usage Notes**:
- Ensures population >= 0 invariant
- See [Population Specification](../specs/population.md#populationsubsystem)

---

### PopulationModel

**Purpose**: Calculates population growth and decline.

**Responsibilities**:
- Model natural growth rate
- Factor in happiness and services
- Apply capacity constraints
- Calculate births and deaths

**Key Methods**:
- `calculate_growth(city: City, ctx: TickContext) -> int`: Net growth
- `calculate_birth_rate(city: City) -> float`: Birth rate
- `calculate_death_rate(city: City) -> float`: Death rate

**Relationships**:
- **Used by**: `PopulationSubsystem`
- **Uses**: `City` (population, happiness, services)

**Design Pattern**: **Strategy Pattern**

**Growth Formula**:
```
natural_growth = population * (birth_rate - death_rate)
birth_rate = base_birth_rate * happiness_factor * service_factor
death_rate = base_death_rate * (2 - service_factor)
```

**Usage Notes**:
- Growth rate modulated by happiness
- Services improve birth rate, reduce death rate
- See [Population Specification](../specs/population.md#populationmodel)

---

### HappinessTracker

**Purpose**: Computes and tracks city happiness metric.

**Responsibilities**:
- Calculate happiness from multiple factors
- Weight factors appropriately
- Update happiness each tick
- Provide happiness breakdown

**Key Methods**:
- `update_happiness(city: City) -> float`: Calculate current happiness
- `get_average_happiness() -> float`: Return current happiness
- `get_happiness_factors() -> Dict[str, float]`: Breakdown by factor

**Key Attributes**:
- `average_happiness: float`: Current happiness (0-100)
- `factors: HappinessFactors`: Factor breakdown

**Relationships**:
- **Used by**: `PopulationSubsystem`
- **Uses**: `City` (services, infrastructure, budget)

**Happiness Formula**:
```
happiness = weighted_sum([
    employment_factor * 0.25,
    services_factor * 0.25,
    infrastructure_factor * 0.20,
    safety_factor * 0.15,
    housing_factor * 0.15
])
```

**Invariant**: `0 <= happiness <= 100`

**Usage Notes**:
- Happiness affects population growth and migration
- See [Population Specification](../specs/population.md#happinesstracker)

---

### MigrationModel

**Purpose**: Calculates migration into and out of city.

**Responsibilities**:
- Model migration based on happiness
- Factor in external conditions
- Calculate push/pull factors
- Determine net migration

**Key Methods**:
- `calculate_migration(city: City, ctx: TickContext) -> int`: Net migration
- `calculate_immigration(city: City) -> int`: Inflow
- `calculate_emigration(city: City) -> int`: Outflow

**Relationships**:
- **Used by**: `PopulationSubsystem`
- **Uses**: `City` (happiness, employment, housing)

**Migration Formula**:
```
net_migration = immigration - emigration
immigration = base_rate * pull_factors
emigration = population * push_factors
pull_factors = f(happiness, employment, housing_availability)
push_factors = f(unhappiness, unemployment, lack_of_services)
```

**Usage Notes**:
- High happiness attracts migrants
- Low happiness drives emigration
- See [Population Specification](../specs/population.md#migrationmodel)

---

### PopulationDelta

**Purpose**: Per-tick population outputs.

**Responsibilities**:
- Record population changes
- Break down changes (births, deaths, migration)
- Track happiness changes
- Provide demographics updates

**Key Attributes**:
- `tick_index: int`
- `population_delta: int`: Net change
- `births: int`
- `deaths: int`
- `immigration: int`
- `emigration: int`
- `happiness_delta: float`
- `new_happiness: float`

**Relationships**:
- **Created by**: `PopulationSubsystem`
- **Contained by**: `CityDelta`

**Usage Notes**:
- Provides detailed population audit trail
- See [Population Specification](../specs/population.md#populationdelta)

---

### Demographics

**Purpose**: Stores population composition data.

**Responsibilities**:
- Track age distribution
- Track employment status
- Track education levels
- Provide demographic queries

**Key Attributes**:
- `age_distribution: Dict[str, int]`: Population by age group
- `employment_rate: float`
- `education_levels: Dict[str, int]`

**Relationships**:
- **Contained by**: `PopulationState` or `CityState`
- **Updated by**: `PopulationSubsystem`

**Usage Notes**:
- Future feature for more detailed population modeling
- See [Population Specification](../specs/population.md#demographics)

---

## Transport & Traffic Subsystem

The Transport Subsystem manages the transport network, traffic simulation, vehicle routing, and congestion modeling.

### TransportSubsystem

**Purpose**: Advances traffic simulation each tick, coordinates all transport components.

**Responsibilities**:
- Update vehicle positions and routes
- Manage traffic signal controllers
- Calculate congestion metrics
- Handle incidents and re-routing
- Produce `TrafficDelta` summary

**Key Methods**:
- `__init__(city: City, road_graph: RoadGraph)`: Initialize subsystem
- `update(city: City, ctx: TickContext) -> TrafficDelta`: Tick update
- `spawn_vehicles(count: int)`: Add new vehicles to network
- `update_vehicle_positions()`: Move vehicles along routes
- `update_signal_controllers()`: Update traffic signals

**Key Attributes**:
- `road_graph: RoadGraph`: Network topology
- `fleet_manager: FleetManager`: Manages all vehicles
- `route_planner: RoutePlanner`: A* pathfinding
- `traffic_model: TrafficModel`: Flow calculations
- `congestion_model: CongestionModel`: Congestion computation
- `signal_controllers: List[SignalController]`: Traffic signal management

**Relationships**:
- **Uses**: `RoadGraph`, `FleetManager`, `RoutePlanner`, `TrafficModel`, `CongestionModel`
- **Produces**: `TrafficDelta`
- **Coordinated by**: `CityManager`
- **Implements**: `ISubsystem`

**Update Order**: Third subsystem (after Finance, Population)

**Usage Notes**:
- Only active if transport system enabled in settings
- See [Traffic Specification](../specs/traffic.md#transportsubsystem)

---

### RoadGraph

**Purpose**: Represents the road network topology as a directed graph.

**Responsibilities**:
- Store intersections (nodes) and road segments (edges)
- Support pathfinding queries
- Manage network connectivity
- Track infrastructure state per segment

**Key Attributes**:
- `intersections: Dict[str, Intersection]`: Network nodes
- `segments: Dict[str, RoadSegment]`: Network edges
- `adjacency_list: Dict[str, List[str]]`: Graph structure for pathfinding

**Key Methods**:
- `add_intersection(intersection: Intersection)`: Add node
- `add_segment(segment: RoadSegment)`: Add edge
- `get_neighbors(intersection_id: str) -> List[str]`: Adjacent nodes
- `find_path(start: str, end: str) -> List[str]`: Pathfinding (delegates to PathfindingService)

**Relationships**:
- **Contains**: `List[Intersection]`, `List[RoadSegment]`
- **Used by**: `TransportSubsystem`, `RoutePlanner`

**Usage Notes**:
- Graph structure mostly static (rare changes during simulation)
- See [Traffic Specification](../specs/traffic.md#roadgraph)

---

### Intersection / RoadSegment / Lane

**Purpose**: Network primitives representing road structure.

**Intersection**:
- `intersection_id: str`: Unique identifier
- `position: (x, y)`: Geographic location
- `signal_controller: Optional[SignalController]`: Traffic signal if controlled
- `incoming_segments: List[str]`: Segments ending at this intersection
- `outgoing_segments: List[str]`: Segments starting from this intersection

**RoadSegment**:
- `segment_id: str`: Unique identifier
- `from_intersection: str`: Start intersection
- `to_intersection: str`: End intersection
- `lanes: List[Lane]`: Lanes on this segment
- `length: float`: Segment length (meters)
- `road_type: RoadType`: CITY | HIGHWAY | ARTERIAL

**Lane**:
- `lane_id: str`: Unique identifier
- `parent_segment: str`: Containing segment
- `vehicles: List[Vehicle]`: Vehicles currently in lane
- `speed_limit: float`: Maximum speed (m/s)
- `capacity: int`: Maximum vehicles

**Relationships**:
- **RoadGraph** contains **Intersection** and **RoadSegment**
- **RoadSegment** contains **Lane**
- **Lane** contains **Vehicle** references

**Usage Notes**:
- Lanes are the fundamental unit for vehicle movement
- See [Traffic Specification](../specs/traffic.md#network-primitives)

---

### Vehicle / FleetManager

**Purpose**: Represents individual vehicles and manages fleet.

**Vehicle**:
- `vehicle_id: str`: Unique identifier
- `current_position: VehiclePosition`: Current location (lane, offset)
- `route: Route`: Planned path through network
- `speed: float`: Current speed (m/s)
- `destination: str`: Target intersection

**FleetManager**:
- `vehicles: Dict[str, Vehicle]`: All active vehicles
- `spawn_rate: float`: Vehicles per tick to spawn
- **Methods**: `add_vehicle()`, `remove_vehicle()`, `get_vehicle_count()`

**Relationships**:
- **FleetManager** manages all **Vehicle** instances
- **Used by**: `TransportSubsystem`

**Usage Notes**:
- Vehicles removed when reaching destination
- See [Traffic Specification](../specs/traffic.md#vehicle)

---

### RoutePlanner / PathfindingService

**Purpose**: Computes optimal routes through road network using A*.

**RoutePlanner**:
- Handles high-level route requests
- Manages route caching
- Handles re-routing on incidents

**PathfindingService**:
- Implements A* algorithm
- Uses heuristic functions (Euclidean, Manhattan)
- Considers congestion in cost function

**Key Methods**:
- `plan_route(start: str, end: str, graph: RoadGraph) -> Route`: Find path
- `replan_route(vehicle: Vehicle, incident: Incident) -> Route`: Re-route around incident

**Relationships**:
- **Used by**: `TransportSubsystem`, `FleetManager`
- **Uses**: `RoadGraph`

**Design Pattern**: **A* Pathfinding Algorithm**

**Usage Notes**:
- Routes cached for performance
- Re-routing triggered by incidents or congestion
- See [Traffic Specification](../specs/traffic.md#pathfindingservice)

---

### SignalController / CityTrafficController / HighwayTrafficController

**Purpose**: Control logic for traffic signals and highway systems.

**SignalController** (base):
- Manages signal phases at intersections
- Switches between green/yellow/red states
- Tracks phase timing

**CityTrafficController**:
- Adaptive signal control for city intersections
- Responds to traffic demand
- Coordinates nearby signals

**HighwayTrafficController**:
- Ramp metering for highway access
- Speed harmonization
- Incident management

**Relationships**:
- **SignalController** attached to **Intersection**
- **Used by**: `TransportSubsystem`

**Design Pattern**: **State Machine** - Signal phases

**Usage Notes**:
- Fixed-time or adaptive control modes
- See [Traffic Specification](../specs/traffic.md#signal-control)

---

### TrafficModel / CongestionModel

**Purpose**: Compute traffic flow and congestion metrics.

**TrafficModel**:
- Implements Intelligent Driver Model (IDM) for car-following
- Calculates vehicle acceleration and speed adjustments
- Models lane-changing behavior

**CongestionModel**:
- Calculates congestion index per segment
- Identifies bottlenecks
- Computes average speeds

**Formulas**:
```
# IDM acceleration
a = a_max * [1 - (v/v_desired)^4 - (s*/s)^2]

# Congestion index
congestion = vehicles_on_segment / segment_capacity
```

**Relationships**:
- **Used by**: `TransportSubsystem`
- **Uses**: `RoadGraph`, vehicle states

**Usage Notes**:
- Models validated against real-world traffic patterns
- See [Traffic Specification](../specs/traffic.md#traffic-flow-model)

---

### TrafficDelta

**Purpose**: Per-tick traffic simulation outputs.

**Responsibilities**:
- Record average speed across network
- Track congestion index
- Report throughput (vehicles processed)
- Identify bottlenecks

**Key Attributes**:
- `tick_index: int`
- `average_speed: float`: Network-wide average (m/s)
- `congestion_index: float`: Overall congestion (0-1)
- `throughput: int`: Vehicles that reached destination
- `bottlenecks: List[str]`: Congested segment IDs

**Relationships**:
- **Created by**: `TransportSubsystem`
- **Contained by**: `CityDelta`

**Usage Notes**:
- High congestion affects happiness
- See [Traffic Specification](../specs/traffic.md#trafficdelta)

---

## Logging & Storage

Logging and storage components handle persistence of simulation data.

### Logger (Base) / JSONLogger / CSVLogger

**Purpose**: Abstract and concrete implementations for structured logging.

**Logger** (base interface):
- Defines logging contract
- Specifies log format and fields

**JSONLogger**:
- Writes JSON Lines (JSONL) format
- One JSON object per line
- Recommended for structured data

**CSVLogger**:
- Writes CSV format
- Compatible with spreadsheet tools
- Alternative to JSONL

**Key Methods**:
- `log_tick(tick_result: TickResult)`: Log single tick
- `log_summary(run_report: RunReport)`: Log final summary
- `flush()`: Write buffered logs to disk

**Relationships**:
- **Implements**: `ILogger`
- **Used by**: `SimCore`, `MetricsCollector`

**Design Pattern**: **Strategy Pattern** - Pluggable log format

**Usage Notes**:
- JSONL recommended for machine processing
- CSV useful for manual analysis
- See [Logging Specification](../specs/logging.md)

---

### LogFormatter / LogSchema

**Purpose**: Define log format and field schemas.

**LogFormatter**:
- Formats tick data for output
- Handles field selection
- Applies transformations

**LogSchema**:
- Defines required and optional fields
- Specifies data types
- Validates log entries

**Relationships**:
- **Used by**: `JSONLogger`, `CSVLogger`

**Usage Notes**:
- Schema ensures consistent log format
- See [Logging Specification](../specs/logging.md#schema)

---

### RunReportWriter

**Purpose**: Exports final `RunReport` to file.

**Responsibilities**:
- Write summary report
- Include aggregated KPIs
- Format for human readability

**Key Methods**:
- `write(report: RunReport, path: str)`: Export report

**Relationships**:
- **Uses**: `RunReport`
- **Called by**: `SimRunner`

---

### RunReport

**Purpose**: Final simulation run summary.

**Responsibilities**:
- Aggregate final state (budget, population, happiness)
- Track total ticks executed
- Summarize KPIs
- Provide run metadata

**Key Attributes**:
- `scenario_name: str`
- `seed: int`
- `total_ticks: int`
- `final_budget: float`
- `final_population: int`
- `final_happiness: float`
- `kpis: Dict[str, float]`: Key performance indicators

**Relationships**:
- **Created by**: `SimRunner`
- **Used by**: `RunReportWriter`, CLI

**Usage Notes**:
- Immutable once created
- Used for scenario comparison
- See [Simulation Specification](../specs/simulation.md#runreport)

---

### DataStore / FileSystemStore / MemoryStore

**Purpose**: Abstract and concrete storage implementations.

**DataStore** (base interface):
- Defines storage contract
- Supports save/load operations

**FileSystemStore**:
- Persists to local file system
- Default storage backend

**MemoryStore**:
- In-memory storage (no persistence)
- Useful for testing

**Key Methods**:
- `save(key: str, data: Any)`: Store data
- `load(key: str) -> Any`: Retrieve data
- `exists(key: str) -> bool`: Check if key exists

**Relationships**:
- **Implements**: `IStorage`
- **Used by**: `Logger`, `RunReportWriter`

**Design Pattern**: **Strategy Pattern** - Pluggable storage backend

**Usage Notes**:
- FileSystemStore for production
- MemoryStore for unit tests

---

## UI & Reporting

User interface and reporting components.

### CLIService

**Purpose**: Command-line interface for running scenarios.

**Responsibilities**:
- Parse command-line arguments
- Load scenarios
- Execute simulations
- Print summaries

**Key Methods**:
- `run(args: List[str])`: Main entry point
- `_load_scenario(name: str) -> Settings`: Load scenario config
- `_execute_simulation(settings: Settings) -> RunReport`: Run sim
- `_print_report(report: RunReport)`: Display results

**Relationships**:
- **Uses**: `SimRunner`, `ScenarioLoader`, `RunReport`
- **Entry point**: `main.py`

**Usage Notes**:
- Primary way to run simulations
- See CLI usage in README

**Example**:
```bash
python -m city_sim run --scenario baseline --seed 42
```

---

### ScenarioReportGenerator

**Purpose**: Builds human-readable reports from simulation results.

**Responsibilities**:
- Format `RunReport` for display
- Generate charts and tables (future)
- Export to various formats (text, HTML, PDF)

**Key Methods**:
- `generate(report: RunReport) -> str`: Create report text
- `generate_comparison(reports: List[RunReport]) -> str`: Compare scenarios

**Relationships**:
- **Uses**: `RunReport`
- **Used by**: `CLIService`

**Usage Notes**:
- Currently text-based
- Future: graphical visualizations

---

## Interfaces & Contracts

Abstract interfaces defining contracts for extensibility.

### ISubsystem

**Purpose**: Contract for all subsystem implementations.

**Methods** (abstract):
- `update(city: City, ctx: TickContext) -> Delta`: Execute tick update

**Implementations**:
- `FinanceSubsystem`
- `PopulationSubsystem`
- `TransportSubsystem`

**Usage Notes**:
- All subsystems must implement this interface
- Enables polymorphic subsystem handling

---

### IPolicy

**Purpose**: Contract for policy implementations.

**Methods** (abstract):
- `evaluate(city: City, ctx: TickContext) -> Optional[Decision]`: Policy logic
- `get_policy_id() -> str`: Unique identifier

**Implementations**:
- `TaxPolicy`, `SubsidyPolicy`, `ZoningPolicy`, `InfrastructureInvestmentPolicy`

**Design Pattern**: **Strategy Pattern**

---

### IDecisionRule

**Purpose**: Contract for executable decision rules.

**Methods** (abstract):
- `execute(city: City) -> None`: Apply decision
- `can_execute(city: City) -> bool`: Check preconditions

**Implementations**:
- `Decision` (primary implementation)

---

### ILogger / IMetricSink / IStorage / IDataExporter / IProfiler

**Purpose**: Contracts for cross-cutting concerns.

**ILogger**: Logging interface
**IMetricSink**: Metrics collection interface
**IStorage**: Persistence interface
**IDataExporter**: Export interface
**IProfiler**: Profiling interface

**Usage Notes**:
- Enable plugin-style extensibility
- Support dependency injection
- Facilitate testing with mocks

---

## Relationships Summary

This section provides a comprehensive view of how classes relate to each other through various relationship types.

### Composition Relationships (Has-A / Contains)

Strong ownership where the contained object's lifecycle depends on the container.

```
SimCore
├── TickScheduler
├── EventBus
├── MetricsCollector
├── RandomService
├── PolicyEngine
└── CityManager

City
├── CityState
│   ├── InfrastructureState
│   └── ServiceState
└── List[District]
    └── List[Building]

CityManager
├── FinanceSubsystem
│   ├── RevenueModel
│   └── ExpenseModel
├── PopulationSubsystem
│   ├── PopulationModel
│   ├── HappinessTracker
│   └── MigrationModel
└── TransportSubsystem (optional)
    ├── RoadGraph
    │   ├── List[Intersection]
    │   └── List[RoadSegment]
    │       └── List[Lane]
    ├── FleetManager
    ├── RoutePlanner
    ├── TrafficModel
    └── CongestionModel

PolicyEngine
└── PolicySet
    └── List[IPolicy] (TaxPolicy, SubsidyPolicy, etc.)
```

### Inheritance Relationships (Is-A)

Classes implementing interfaces or extending base classes.

```
ILogger
├── JSONLogger
└── CSVLogger

IStorage (DataStore)
├── FileSystemStore
└── MemoryStore

IPolicy
├── TaxPolicy
├── SubsidyPolicy
├── ZoningPolicy
└── InfrastructureInvestmentPolicy

IDecisionRule
└── Decision

ISubsystem
├── FinanceSubsystem
├── PopulationSubsystem
└── TransportSubsystem

SignalController
├── CityTrafficController
└── HighwayTrafficController
```

### Dependency Relationships (Uses)

One class uses another without owning it.

**Simulation Flow**:
- `SimRunner` → uses `Settings`, `ScenarioLoader`, creates `SimCore`
- `SimCore` → uses `City`, produces `TickResult`
- `CityManager` → uses `City`, produces `CityDelta`
- All subsystems → use `City`, `TickContext`

**Policy Evaluation**:
- `PolicyEngine` → uses `City`, `TickContext`, produces `List[Decision]`
- `Decision` → uses `City` for execution

**Logging**:
- `SimCore` → uses `ILogger` to log `TickResult`
- `MetricsCollector` → uses `ILogger` to flush metrics
- `RunReportWriter` → uses `RunReport`, `IStorage`

**Data Flow**:
- `TickContext` → provides `Settings`, `PolicySet`, `RandomService`
- `TickResult` → contains `CityDelta`, metrics, events
- `CityDelta` → contains `FinanceDelta`, `PopulationDelta`, `TrafficDelta`

### Aggregation Relationships

Loose ownership where contained objects can exist independently.

- `Settings` → aggregates `PolicySet` (policies can exist independently)
- `RoadGraph` → aggregates `Intersection` and `RoadSegment` (network components conceptually independent)
- `FleetManager` → aggregates `Vehicle` instances (vehicles can be managed elsewhere)

### Creation Relationships (Factory Pattern)

Classes that create instances of other classes.

- `SimRunner` → creates `SimCore`, produces `RunReport`
- `SimCore` → creates `TickContext`, `TickResult` each tick
- `CityManager` → creates `CityDelta`, coordinates subsystem delta creation
- `PolicyEngine` → creates `Decision` objects
- `ScenarioLoader` → creates `Settings`, `PolicySet`

### Association Diagram (Simplified)

```
┌─────────────┐
│  SimRunner  │
└──────┬──────┘
       │ orchestrates
       ▼
┌─────────────┐      uses      ┌──────────────┐
│   SimCore   │───────────────►│ CityManager  │
└──────┬──────┘                └──────┬───────┘
       │ produces                     │ manages
       ▼                              ▼
┌─────────────┐                ┌─────────────┐
│ TickResult  │                │    City     │
│  contains   │                │  contains   │
│ ┌─────────┐ │                │ ┌─────────┐ │
│ │CityDelta│ │                │ │CityState│ │
│ └─────────┘ │                │ └─────────┘ │
└─────────────┘                └─────────────┘
```

---

## Design Patterns

City-Sim leverages several well-established design patterns to achieve modularity, extensibility, and maintainability.

### Aggregate Root Pattern

**Where**: `City` class

**Purpose**: Provide a single entry point for accessing and modifying city data while maintaining invariants.

**Implementation**:
- `City` is the aggregate root
- All modifications go through `CityManager`
- Internal consistency maintained through controlled access

**Benefits**:
- Encapsulation of complex state
- Centralized invariant enforcement
- Clear ownership and lifecycle management

---

### Strategy Pattern

**Where**: Multiple locations

**Purpose**: Enable runtime selection of algorithms/behaviors.

**Implementations**:

1. **Finance Models**:
   - `RevenueModel` / `ExpenseModel` as strategies
   - Pluggable calculation methods
   - Easy to add new revenue/expense models

2. **Population Models**:
   - `PopulationModel`, `MigrationModel` as strategies
   - Different growth/migration algorithms
   - Scenario-specific customization

3. **Policy System**:
   - `IPolicy` interface with multiple implementations
   - Policies as interchangeable strategies
   - Easy to add new policy types

4. **Logging**:
   - `ILogger` with `JSONLogger`, `CSVLogger`
   - Pluggable log formats
   - Testing with mock loggers

**Benefits**:
- Open/Closed Principle (open for extension, closed for modification)
- Runtime behavior customization
- Easy testing with mocks

---

### Observer Pattern

**Where**: `EventBus` / `EventHandler`

**Purpose**: Enable decoupled communication between components.

**Implementation**:
- `EventBus` as the subject
- Components subscribe to event types
- Publishers don't know about subscribers
- Events delivered synchronously within tick

**Example Events**:
- `PopulationChangedEvent`
- `BudgetThresholdEvent`
- `CongestionAlertEvent`

**Benefits**:
- Loose coupling between components
- Easy to add new event listeners
- Cross-cutting concerns (logging, metrics) without tight coupling

---

### Command Pattern

**Where**: `Decision` class

**Purpose**: Encapsulate policy effects as executable objects.

**Implementation**:
- `Decision` encapsulates action and parameters
- `execute()` method applies state changes
- Decisions queued and executed by `CityManager`
- Decisions are replayable and loggable

**Benefits**:
- Separation of policy evaluation from execution
- Audit trail of decisions
- Potential for undo/redo (future feature)

---

### Facade Pattern

**Where**: `CityManager`

**Purpose**: Simplify complex subsystem coordination.

**Implementation**:
- `CityManager` provides simple interface to complex subsystem interactions
- Hides coordination complexity from `SimCore`
- Enforces update ordering
- Manages state transitions

**Benefits**:
- Reduced coupling between `SimCore` and subsystems
- Single point for state update logic
- Easier to modify subsystem coordination

---

### Singleton Pattern

**Where**: `RandomService` (per-simulation instance)

**Purpose**: Ensure single, consistent source of randomness.

**Implementation**:
- One `RandomService` instance per simulation
- Passed through `TickContext` to all components
- Seeded for determinism

**Benefits**:
- Guarantees determinism
- Centralized random state management
- Easy to control and test

---

### Factory/Builder Pattern

**Where**: `ScenarioLoader`

**Purpose**: Construct complex configuration objects.

**Implementation**:
- `ScenarioLoader` reads scenario definitions
- Constructs `Settings` and `PolicySet`
- Handles defaults and validation

**Benefits**:
- Separation of configuration from business logic
- Reusable scenario definitions
- Validation at construction time

---

## Extension Points

City-Sim is designed for extensibility. This section describes how to add new functionality.

### Adding a New Policy

**Steps**:
1. Create class implementing `IPolicy` interface
2. Implement `evaluate(city, ctx) -> Optional[Decision]`
3. Define policy parameters in `__init__()`
4. Add policy to scenario `PolicySet`

**Example**:
```python
class EnvironmentalPolicy(IPolicy):
    def __init__(self, pollution_threshold: float):
        self.policy_id = "environmental_policy"
        self.threshold = pollution_threshold
    
    def evaluate(self, city: City, ctx: TickContext) -> Optional[Decision]:
        if city.state.pollution > self.threshold:
            return Decision(
                policy_id=self.policy_id,
                decision_type="REDUCE_EMISSIONS",
                parameters={"target_reduction": 0.10}
            )
        return None
```

**Integration**:
- No changes to core simulation code required
- Add to `PolicySet` in scenario definition
- Policy automatically evaluated each tick

---

### Adding a New Subsystem

**Steps**:
1. Create class implementing `ISubsystem` interface
2. Implement `update(city, ctx) -> Delta`
3. Define subsystem-specific models and components
4. Create corresponding `Delta` class for outputs
5. Register subsystem with `CityManager`
6. Update `CityManager` update ordering

**Example**:
```python
class EnvironmentSubsystem(ISubsystem):
    def __init__(self, city: City):
        self.pollution_model = PollutionModel()
    
    def update(self, city: City, ctx: TickContext) -> EnvironmentDelta:
        pollution_change = self.pollution_model.calculate(city)
        city.state.pollution += pollution_change
        
        return EnvironmentDelta(
            tick_index=ctx.tick_index,
            pollution_delta=pollution_change,
            pollution_level=city.state.pollution
        )
```

**Integration**:
- Register in `CityManager.__init__()`
- Add to update sequence in `CityManager.update()`
- Update `CityDelta` to include `EnvironmentDelta`

---

### Adding a New Scenario

**Steps**:
1. Create scenario definition file (JSON/YAML)
2. Specify initial conditions, policies, parameters
3. Place in scenarios directory
4. Load with `ScenarioLoader`

**Example** (scenarios/environmental_focus.json):
```json
{
  "name": "environmental_focus",
  "description": "Scenario focused on environmental sustainability",
  "seed": 12345,
  "tick_horizon": 2000,
  "initial_state": {
    "budget": 1000000,
    "population": 50000,
    "pollution": 30.0
  },
  "policies": [
    {
      "type": "EnvironmentalPolicy",
      "parameters": {
        "pollution_threshold": 50.0
      }
    },
    {
      "type": "TaxPolicy",
      "parameters": {
        "min_budget_threshold": 500000
      }
    }
  ]
}
```

**Usage**:
```bash
python -m city_sim run --scenario environmental_focus
```

---

### Adding a New Logger Format

**Steps**:
1. Create class implementing `ILogger` interface
2. Implement `log_tick()`, `log_summary()`, `flush()`
3. Define format-specific serialization
4. Register logger in configuration

**Example**:
```python
class XMLLogger(ILogger):
    def log_tick(self, tick_result: TickResult):
        xml = f"""
        <tick index="{tick_result.tick_index}">
          <budget>{tick_result.city_delta.budget_delta}</budget>
          <population>{tick_result.city_delta.population_delta}</population>
        </tick>
        """
        self.buffer.append(xml)
    
    def flush(self):
        # Write buffered XML to file
        pass
```

**Integration**:
- Specify in `Settings`: `logger_type = "xml"`
- No changes to simulation code required

---

### Adding Custom Metrics

**Steps**:
1. Define metric calculation function
2. Hook into `MetricsCollector` via `EventBus`
3. Subscribe to relevant events
4. Emit custom metrics

**Example**:
```python
class CustomMetricsCollector(EventHandler):
    def handle(self, event: Event):
        if isinstance(event, PopulationChangedEvent):
            growth_rate = event.delta / event.previous_population
            metrics_collector.collect_metric(
                "population_growth_rate",
                growth_rate
            )
```

**Integration**:
- Register handler with `EventBus`
- Metrics automatically collected and logged

---

### Adding New Decision Types

**Steps**:
1. Define new decision type constant
2. Create decision with type and parameters
3. Handle decision type in `CityManager.apply_decision()`

**Example**:
```python
# In policy
decision = Decision(
    policy_id="env_policy",
    decision_type="GREEN_INFRASTRUCTURE_INVESTMENT",
    parameters={
        "amount": 100000,
        "infrastructure_type": "solar_panels"
    }
)

# In CityManager
def apply_decision(self, decision: Decision):
    if decision.decision_type == "GREEN_INFRASTRUCTURE_INVESTMENT":
        amount = decision.parameters["amount"]
        infra_type = decision.parameters["infrastructure_type"]
        self._invest_green_infrastructure(amount, infra_type)
```

---

## Related Documentation

### Core Specifications

- [Architecture Overview](overview.md) - High-level system architecture
- [Simulation Specification](../specs/simulation.md) - Detailed simulation core contract
- [City Specification](../specs/city.md) - City model and state management
- [Finance Specification](../specs/finance.md) - Finance subsystem details
- [Population Specification](../specs/population.md) - Population dynamics
- [Traffic Specification](../specs/traffic.md) - Transport and traffic simulation
- [Logging Specification](../specs/logging.md) - Structured logging format
- [Scenarios Specification](../specs/scenarios.md) - Scenario definitions

### Design Documentation

- [ADR-001: Simulation Determinism](../adr/001-simulation-determinism.md) - Determinism design decisions
- [Glossary](../guides/glossary.md) - Terminology reference
- [Contributing Guide](../guides/contributing.md) - How to contribute

### Implementation References

- [Simulation Core](../../src/simulation/sim.py) - `Sim`, `SimCore` implementations
- [City Model](../../src/city/city.py) - `City`, `CityState` implementations
- [City Manager](../../src/city/city_manager.py) - `CityManager` implementation
- [Finance](../../src/city/finance.py) - Finance subsystem implementation
- [Population](../../src/city/population/population.py) - Population classes
- [Decisions](../../src/city/decisions.py) - Decision and policy implementations

---

## Revision History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 2.0 | 2025-01-XX | Comprehensive enhancement with detailed class descriptions, relationships, design patterns, and extension points | Enhanced Documentation |
| 1.0 | 2024-XX-XX | Initial class hierarchy summary | Original Author |

---

**End of Class Hierarchy Reference**
