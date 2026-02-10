# System Architecture Overview

This document describes the planned architecture of the City‑Sim application, focusing on components, data flow, invariants, and design principles to guide implementation. It serves as the primary reference for understanding how the system's major components interact and the rationale behind key architectural decisions.

## Purpose & Scope

City‑Sim is a deterministic city building simulation designed for experimentation, analysis, and AI-driven optimization. The architecture prioritizes:

- **Determinism**: Reproducible outcomes enable rigorous testing and comparative analysis
- **Modularity**: Clear subsystem boundaries allow parallel development and focused testing
- **Extensibility**: Well-defined interfaces support adding new policies, scenarios, and features
- **Observability**: Comprehensive structured logging enables deep analysis of simulation behavior

## Components

The system is organized into loosely-coupled components with clearly defined responsibilities:

### Simulation Core
**Purpose**: Orchestrates the tick loop, scenario execution, and subsystem coordination.

**Key Classes**: `SimRunner`, `SimCore`, `TickScheduler`, `EventBus`, `MetricsCollector`

**Responsibilities**:
- Initialize simulation from settings and scenario configuration
- Execute the tick loop for the configured horizon
- Coordinate subsystem updates in proper order
- Collect and emit metrics and logs
- Produce final `RunReport` with aggregated results

**Implementation**: [src/simulation/sim.py](../../src/simulation/sim.py)

**See Also**: [Simulation Specification](../specs/simulation.md), [ADR-001: Simulation Determinism](../adr/001-simulation-determinism.md)

### City Model
**Purpose**: Represents the complete city state and provides operations for state transitions.

**Key Classes**: `City`, `CityState`, `CityManager`, `CityDelta`, `District`, `Building`

**Responsibilities**:
- Maintain aggregate city state (budget, population, happiness, infrastructure, services)
- Apply decisions and policy effects to modify state
- Enforce invariants (e.g., non-negative population, balanced budget equations)
- Produce delta summaries for logging and analysis
- Manage city geography (districts and buildings)

**Implementation**: [src/city/city.py](../../src/city/city.py), [src/city/city_manager.py](../../src/city/city_manager.py)

**See Also**: [City Specification](../specs/city.md), [Class Hierarchy](class-hierarchy.md)

### Decisions & Policies
**Purpose**: Define and apply rules that modify city state based on conditions and strategies.

**Key Classes**: `PolicyEngine`, `Decision`, `IPolicy`, `IDecisionRule`, policy implementations

**Responsibilities**:
- Evaluate city state and context against configured policies
- Generate executable decision rules
- Apply decisions to produce state changes
- Support policy types: tax, subsidy, zoning, infrastructure investment

**Implementation**: [src/city/decisions.py](../../src/city/decisions.py)

**Example**: A `TaxPolicy` might evaluate city budget and population to decide whether to adjust tax rates, producing a `Decision` that modifies revenue calculations.

### Finance Subsystem
**Purpose**: Model city finances including budget, revenue, expenses, and fiscal policy effects.

**Key Classes**: `FinanceSubsystem`, `Budget`, `RevenueModel`, `ExpenseModel`, `FinanceDelta`

**Responsibilities**:
- Calculate revenue from taxes, fees, and other sources
- Calculate expenses for services, infrastructure, and operations
- Update budget each tick: `new_budget = old_budget + revenue - expenses`
- Apply fiscal policy effects (tax rates, subsidies)
- Enforce budget reconciliation invariant

**Implementation**: [src/city/finance.py](../../src/city/finance.py)

**See Also**: [Finance Specification](../specs/finance.md)

**Example Budget Reconciliation**:
```
Tick N:   budget = 1,000,000
          revenue = 50,000 (taxes + fees)
          expenses = 30,000 (services + infrastructure)
Tick N+1: budget = 1,000,000 + 50,000 - 30,000 = 1,020,000
```

### Population Subsystem
**Purpose**: Model population dynamics including growth, decline, happiness, and migration.

**Key Classes**: `PopulationSubsystem`, `PopulationModel`, `HappinessTracker`, `MigrationModel`, `Demographics`, `PopulationDelta`

**Responsibilities**:
- Calculate population growth/decline based on city conditions
- Update happiness metrics based on services, infrastructure, and economic factors
- Model migration (in/out) influenced by happiness and opportunities
- Maintain demographics data
- Ensure population remains non-negative

**Implementation**: [src/city/population/population.py](../../src/city/population/population.py), [src/city/population/happiness_tracker.py](../../src/city/population/happiness_tracker.py)

**See Also**: [Population Specification](../specs/population.md)

### Transport Subsystem
**Purpose**: Simulate traffic, vehicle routing, signal control, and congestion for city and highway networks.

**Key Classes**: `TransportSubsystem`, `RoadGraph`, `RoutePlanner`, `Vehicle`, `FleetManager`, traffic controllers, `TrafficDelta`

**Responsibilities**:
- Maintain road network graph (intersections, road segments, lanes)
- Plan vehicle routes using A* pathfinding
- Simulate vehicle movement respecting signals and speed limits
- Model traffic flow and congestion
- Control traffic signals and highway ramps
- Provide re-routing under incidents or congestion
- Log traffic metrics (avg speed, congestion index, throughput)

**Implementation**: Future development under `src/transport/` (see workstream 10)

**See Also**: [Traffic Specification](../specs/traffic.md)

### Settings & Configuration
**Purpose**: Provide centralized configuration for simulation parameters, scenarios, and policies.

**Key Classes**: `Settings`, `Scenario`, `PolicySet`, `SeedProvider`

**Responsibilities**:
- Define simulation parameters (seed, tick horizon, profiling options)
- Load and validate scenario configurations
- Manage policy sets for different simulation runs
- Provide deterministic seed management

**Implementation**: [src/shared/settings.py](../../src/shared/settings.py)

**See Also**: [Scenarios Specification](../specs/scenarios.md)

### Entry Points
**Purpose**: Provide command-line and programmatic interfaces to run simulations.

**Key Scripts**: `run.py`, `src/main.py`

**Responsibilities**:
- Parse command-line arguments
- Initialize settings and load scenarios
- Execute simulation runs
- Display results and summaries

**Implementation**: [run.py](../../run.py), [src/main.py](../../src/main.py)

### Logging & Data Export
**Purpose**: Provide structured, machine-readable outputs for analysis and debugging.

**Key Classes**: `Logger`, `JSONLogger`, `CSVLogger`, `LogFormatter`, `LogSchema`, `RunReportWriter`

**Responsibilities**:
- Define log schema with required fields per tick
- Write structured logs in JSONL or CSV format
- Ensure logs are machine-readable and consistent
- Export final run reports
- Support analysis and visualization tools

**Output Locations**: 
- Global logs: [output/logs/global/](../../output/logs/global/)
- UI logs: [output/logs/ui/](../../output/logs/ui/)

**See Also**: [Logging Specification](../specs/logging.md)


## Data Flow

The simulation follows a well-defined data flow pattern that ensures deterministic behavior and clear subsystem interactions:

### Initialization Phase
1. **Configuration Loading**: `run.py` loads settings from configuration files or command-line arguments
2. **Scenario Selection**: `ScenarioLoader` retrieves the specified scenario definition with initial conditions
3. **Seed Initialization**: `RandomService` is initialized with the configured seed for deterministic behavior
4. **City Creation**: Initial `City` state is constructed with starting budget, population, and infrastructure
5. **Subsystem Registration**: All subsystems (Finance, Population, Transport) are initialized and registered

### Execution Phase (Per Tick)
1. **Tick Start**: `SimCore` begins a new tick, creating `TickContext` with current settings and state
2. **Policy Evaluation**: `PolicyEngine` evaluates configured policies against current city state
3. **Decision Generation**: Policies produce `Decision` objects specifying state modifications
4. **Decision Application**: `CityManager.apply_decisions()` applies decisions to city state
5. **Subsystem Updates**: Each subsystem updates in sequence:
   - **Finance**: Calculates revenue and expenses, updates budget
   - **Population**: Applies growth/decline and migration, updates happiness
   - **Transport**: Updates vehicle positions, signals, and traffic metrics
6. **State Validation**: Invariants are checked (e.g., budget reconciliation, non-negative population)
7. **Metrics Collection**: `MetricsCollector` aggregates metrics from all subsystems
8. **Logging**: Structured log entry is written with tick index, timestamp, and all metrics
9. **Tick Completion**: `TickResult` is produced with state deltas and metrics

### Finalization Phase
1. **Loop Completion**: After reaching tick horizon, simulation loop exits
2. **Report Generation**: `RunReport` is created with final state and aggregated KPIs
3. **Output Export**: `RunReportWriter` exports results in human and machine-readable formats
4. **Cleanup**: Resources are released and logs are flushed

### Data Flow Diagram
```
Settings/Scenario → SimRunner → SimCore
                                   ↓
                     ┌─────────────┴─────────────┐
                     ↓                           ↓
               TickContext ──────→ PolicyEngine → Decisions
                     ↓                           ↓
                CityManager ←────────────────────┘
                     ↓
        ┌────────────┼────────────┐
        ↓            ↓            ↓
   Finance    Population    Transport
        ↓            ↓            ↓
        └────────────┼────────────┘
                     ↓
              MetricsCollector
                     ↓
                 Logger → Logs
                     ↓
               TickResult
                     ↓
              (repeat or finalize)
                     ↓
               RunReport
```

### Key Data Structures Passed Between Components

- **Settings**: Global configuration (seed, horizon, policies) - read-only
- **TickContext**: Per-tick context (tick_index, settings, policy_set, random_service)
- **City**: Mutable city state updated by `CityManager` and subsystems
- **CityDelta**: Immutable summary of changes during a tick
- **FinanceDelta**: Revenue, expenses, budget change for a tick
- **PopulationDelta**: Population change, migration, happiness updates for a tick
- **TrafficDelta**: Traffic metrics (speed, congestion, throughput) for a tick
- **TickResult**: Complete tick outputs including all deltas and metrics
- **RunReport**: Final run summary with aggregated data

## Invariants

Invariants are conditions that must hold true throughout simulation execution. Violations indicate bugs or configuration errors and should trigger assertions or logging warnings.

### Core Invariants

1. **Deterministic Execution**
   - Given identical seed and settings, two runs produce identical state trajectories and logs
   - Validation: Compare log files or state checksums across runs with same seed
   - Exception: None - determinism is absolute requirement

2. **Budget Reconciliation**
   - Each tick: `budget[t+1] = budget[t] + revenue[t] - expenses[t]`
   - Tolerance: Within floating-point precision (1e-6)
   - Validation: Check equation after each Finance subsystem update
   - Handling: Log warning if violation exceeds tolerance; may indicate calculation bug

3. **Non-Negative Population**
   - At all times: `population >= 0`
   - Validation: Check after Population subsystem update
   - Handling: Clamp to zero and log error if negative (indicates model bug)

4. **Happiness Bounds**
   - At all times: `0 <= happiness <= 100`
   - Validation: Check after HappinessTracker update
   - Handling: Clamp to [0, 100] range and log warning if out of bounds

5. **Tick Ordering**
   - Ticks execute in strictly increasing order: `tick[n] = tick[n-1] + 1`
   - Validation: Assert at start of each tick
   - Exception: None - out-of-order execution would break causality

6. **Subsystem State Consistency**
   - All subsystems operate on the same city state instance during a tick
   - State modifications are sequential, not concurrent
   - Validation: Reference equality checks in subsystem update methods

### Traffic-Specific Invariants (When Transport Subsystem Active)

7. **Vehicle Conservation**
   - Vehicles are neither created nor destroyed during transit (except at defined spawn/despawn points)
   - Validation: Count vehicles at tick start and end

8. **Speed Limits**
   - Vehicle speeds never exceed road segment speed limits
   - Validation: Check after traffic model updates vehicle speeds

9. **Route Validity**
   - Vehicle routes consist of connected road segments
   - Validation: Verify connectivity when route is assigned

### Data Integrity Invariants

10. **Log Completeness**
    - Every tick produces exactly one log entry with all required fields
    - Required fields: timestamp, run_id, tick_index, budget, revenue, expenses, population, happiness
    - Validation: Schema validation on log writes

11. **Metric Consistency**
    - Metrics reported in logs match city state at end of tick
    - Validation: Spot checks comparing logged values to city state

## Design Principles

These principles guide implementation decisions and ensure long-term maintainability:

### 1. Minimal Public API Changes
**Rationale**: Stable interfaces reduce integration friction and allow parallel development

**Application**:
- Define clear contracts in specifications before implementation
- Version interfaces if breaking changes are absolutely necessary
- Prefer extension over modification (open/closed principle)
- Document all public methods, parameters, and return values

**Example**: Adding new policy types should extend `IPolicy` interface, not modify existing policy implementations

### 2. Determinism and Reproducibility First
**Rationale**: Reproducible results enable debugging, testing, and scientific analysis

**Application**:
- All randomness sources through `RandomService` with fixed seed
- No system time dependencies in state calculations (use tick index instead)
- Subsystems update in defined, fixed order
- Avoid floating-point non-determinism (consistent rounding, no parallel aggregation)
- Document any potential sources of non-determinism

**Testing**: Include determinism tests that run same scenario twice and verify identical outputs

### 3. Structured Logging for Machine-Readable Outputs
**Rationale**: Structured data enables automated analysis, visualization, and debugging

**Application**:
- Use JSONL or CSV formats with defined schemas
- Include all relevant metrics in each log entry
- Use consistent field names and types across logs
- Timestamp every entry with ISO 8601 format
- Include run_id to correlate logs from the same run

**Benefits**: Supports analysis tools, dashboards, and AI-driven optimization

### 4. Separation of Concerns
**Rationale**: Loosely-coupled subsystems enable focused development, testing, and optimization

**Application**:
- Clear boundaries between Simulation, City Model, Finance, Population, Transport
- Subsystems communicate through well-defined interfaces (`ISubsystem`)
- Avoid cross-subsystem dependencies; use events for decoupled communication
- Each subsystem manages its own state and logic

**Example**: Finance subsystem knows nothing about traffic - it receives city state and produces financial deltas

### 5. Testability by Design
**Rationale**: Comprehensive testing ensures correctness and prevents regressions

**Application**:
- Design for dependency injection (pass dependencies, don't create them)
- Provide test doubles (mocks, stubs) for external dependencies
- Keep functions pure where possible (same inputs → same outputs)
- Write tests alongside implementation, not as afterthought

**Example**: `CityManager` accepts `City` and `TickContext` as parameters rather than accessing global state

### 6. Documentation as Code
**Rationale**: Up-to-date documentation is essential for collaboration and long-term maintenance

**Application**:
- Specifications in `docs/specs/` define contracts before implementation
- Architecture Decision Records (ADRs) capture rationale for major decisions
- Code comments explain "why", not "what"
- Keep specs and code synchronized through regular reviews

## Extension Points

The architecture provides several mechanisms for extending functionality without modifying core code:

### 1. Scenario Loader
**Purpose**: Enable loading custom scenarios with varied initial conditions and parameters

**Extension Method**: 
- Implement `IScenarioLoader` interface
- Register new loader with `SimRunner`
- Store scenario definitions in standard format (YAML, JSON, etc.)

**Use Cases**: 
- Load scenarios from database
- Generate procedural scenarios
- Import scenarios from external tools

### 2. Policy Plugins
**Purpose**: Add new policy types without modifying `PolicyEngine`

**Extension Method**:
- Implement `IPolicy` interface
- Register policy with `PolicySet` in settings
- Policy is automatically evaluated each tick

**Use Cases**:
- Experiment with novel tax strategies
- Test infrastructure investment algorithms
- Implement custom zoning rules

### 3. Metrics and Profiling Hooks
**Purpose**: Collect custom metrics and performance data

**Extension Method**:
- Implement `IMetricSink` for custom metrics
- Implement `IProfiler` for custom profiling
- Register with `SimCore` during initialization

**Use Cases**:
- Export metrics to monitoring systems
- Profile specific subsystems
- Collect data for machine learning models

### 4. Custom Subsystems
**Purpose**: Add entirely new simulation aspects

**Extension Method**:
- Implement `ISubsystem` interface
- Register with `SimCore` for tick updates
- Add state to `CityState` as needed

**Use Cases**:
- Add weather simulation
- Implement crime modeling
- Simulate environmental factors

### 5. UI Adapters for Visualization
**Purpose**: Support different visualization and interaction modes

**Extension Method**:
- Implement UI adapter consuming logs or `RunReport`
- Can run live (reading logs as produced) or post-hoc (analyzing completed runs)
- No modification to simulation core required

**Use Cases**:
- Web-based dashboards
- 3D city visualization
- Real-time monitoring displays

## Future UI Architecture Considerations

While current implementation focuses on CLI and log-based outputs, the architecture is designed to support rich UI in the future:

- **Event-Driven Updates**: `EventBus` can stream events to UI for real-time display
- **State Snapshots**: `City` state can be serialized for UI rendering at any point
- **Decoupled Rendering**: UI runs in separate process, consuming logs or events
- **Replay Capability**: UI can replay simulation from logs without re-running simulation

## Related Documentation

- **[Class Hierarchy](class-hierarchy.md)**: Detailed breakdown of classes and their relationships
- **[Specifications](../specs/)**: Detailed contracts for each subsystem
- **[ADRs](../adr/)**: Architecture Decision Records capturing key design choices
- **[Workstreams](../design/workstreams/00-index.md)**: Parallel development tracks
- **[UML Models](../models/model.mdj)**: Visual class diagrams and relationships
- **[Contributing Guide](../guides/contributing.md)**: How to contribute to the codebase
- **[Glossary](../guides/glossary.md)**: Definitions of key terms

## Validation & Testing Strategy

To ensure the architecture is correctly implemented:

1. **Invariant Tests**: Automated tests verifying each invariant holds across tick execution
2. **Determinism Tests**: Run same scenario multiple times, verify identical outputs
3. **Integration Tests**: Verify subsystems interact correctly through defined interfaces
4. **Performance Benchmarks**: Track tick duration and identify regressions
5. **Schema Validation**: Verify log outputs match defined schemas
6. **Scenario Suites**: Maintain library of scenarios covering edge cases and typical usage

See [Testing Workstream](../design/workstreams/07-testing-ci.md) for detailed testing approach.
