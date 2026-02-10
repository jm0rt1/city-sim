# Glossary

This glossary defines key terms used throughout the City‑Sim documentation and codebase. Terms are organized alphabetically for easy reference.

## Core Simulation Terms

- **Determinism**: The property that identical inputs (seed, settings, policies) produce identical outputs (state trajectories, logs, metrics) across multiple runs. Critical for testing and reproducibility.

- **KPI (Key Performance Indicator)**: A measurable value demonstrating how effectively the city is achieving key objectives. Examples include budget, population, happiness, traffic throughput, and congestion index.

- **Policy**: A decision or rule that affects city state, such as tax rate changes, zoning adjustments, infrastructure investments, or service level modifications. Policies are evaluated by the `PolicyEngine` and applied via `Decision` objects.

- **Run**: A complete execution of the simulation from initialization through the configured tick horizon, producing logs and a final `RunReport`.

- **Scenario**: A named configuration defining specific parameters, policies, time horizon, and initial conditions for a simulation run. Scenarios enable comparison of different city management strategies.

- **Seed**: An integer value used to initialize the random number generator, ensuring deterministic behavior across runs. Fixed seeds enable reproducible experiments and debugging.

- **Tick**: One discrete iteration of the simulation loop. During each tick, subsystems update city state, policies are evaluated, metrics are collected, and logs are emitted.

- **Tick Context**: The contextual information available during a single tick, including settings, active policy set, current tick index, and random service state.

- **Tick Horizon**: The total number of ticks configured for a simulation run. Defines the length of the simulation period.

## Architecture & Components

- **ADR (Architecture Decision Record)**: A document capturing an important architectural decision, its context, rationale, and consequences. See `docs/adr/` for examples.

- **City**: The aggregate root representing the complete city state, including budget, population, happiness, districts, buildings, infrastructure, and services.

- **CityDelta**: A summary object describing changes to city state during a tick, including population changes, budget adjustments, and happiness modifications.

- **CityManager**: The primary orchestrator for city state updates. Applies decisions, coordinates subsystems (Finance, Population, Transport), and produces `CityDelta` outputs.

- **CityState**: The complete state data for a city, encompassing budget, population, happiness, infrastructure state, and service state.

- **Decision**: An executable rule that applies specific state changes to the city. Produced by the `PolicyEngine` based on evaluated policies.

- **District**: A geographical subdivision of the city containing one or more buildings. Districts help organize city layout and infrastructure.

- **EventBus**: A publish/subscribe infrastructure enabling decoupled communication between simulation components via events.

- **MetricsCollector**: A component that aggregates metrics from various subsystems during each tick and flushes them to loggers for persistence.

- **PolicyEngine**: Evaluates the current city state and context against configured policies to produce decision rules that will be applied to modify city state.

- **ProfileReport**: A summary of performance profiling data, including timing information for critical code paths and subsystems.

- **Profiler**: An optional component that instruments code execution to measure performance characteristics and identify bottlenecks.

- **RandomService**: A seedable random number generator service providing deterministic random values to all subsystems.

- **RunReport**: A comprehensive summary produced at the end of a simulation run, including final state (budget, population, happiness), total ticks executed, and aggregated KPIs.

- **ScenarioLoader**: A component responsible for loading scenario definitions by name and initializing simulation settings appropriately.

- **SimCore**: The core tick engine that orchestrates the simulation loop, coordinates subsystems, and manages the tick lifecycle.

- **SimRunner**: The top-level orchestrator that initializes settings, executes `SimCore`, and produces the final `RunReport`.

- **TickResult**: The output produced by a single tick, containing metrics, state deltas, and any events or alerts generated during the tick.

- **TickScheduler**: A component that computes the next tick timing and manages the simulation clock.

## Subsystems

- **FinanceSubsystem**: Manages city budget, revenue generation, expense calculation, and financial policy effects. Produces `FinanceDelta` outputs per tick.

- **InfrastructureState**: Represents the state of city infrastructure including transport networks, utilities, power grids, and water systems.

- **PopulationSubsystem**: Manages population dynamics including growth, decline, happiness tracking, and migration. Produces `PopulationDelta` outputs per tick.

- **ServiceState**: Represents the state of city services including health, education, public safety, and housing services.

- **TransportSubsystem**: Manages the transport network, traffic simulation, vehicle routing, signal control, and congestion modeling. Produces `TrafficDelta` outputs per tick.

## Finance Terms

- **Budget**: The current financial balance of the city, updated each tick based on revenue and expenses.

- **ExpenseModel**: A strategy or calculation method for determining city expenses based on service levels, infrastructure maintenance, and policy decisions.

- **FinanceDelta**: Per-tick financial outputs including revenue generated, expenses incurred, and resulting budget change.

- **FinanceReport**: A summary of financial metrics over a run or time period, useful for analysis and reporting.

- **RevenueModel**: A strategy or calculation method for determining city revenue from taxes, fees, and other income sources.

## Population Terms

- **Demographics**: Statistical data describing the composition of the city's population, potentially including age distribution, employment, and other characteristics.

- **HappinessTracker**: A component that computes and updates the city's happiness metric based on various factors such as services, infrastructure quality, and economic conditions.

- **Migration**: The movement of population into or out of the city, influenced by happiness, economic opportunities, and external factors.

- **MigrationModel**: A calculation strategy determining population migration rates based on city conditions and neighboring regions.

- **PopulationDelta**: Per-tick population outputs including population changes, happiness updates, and migration statistics.

- **PopulationModel**: A calculation strategy for population growth and decline based on birth rates, death rates, and city conditions.

## Transport & Traffic Terms

- **A\* (A-star)**: A graph search algorithm used for pathfinding. Finds optimal routes by combining actual distance traveled with a heuristic estimate of remaining distance.

- **CityTrafficController**: A controller managing traffic signals, flow control, and coordination for city streets and intersections.

- **CongestionModel**: A model calculating traffic congestion levels based on vehicle density, speeds, and road capacity.

- **FleetManager**: A component managing the collection of vehicles in the simulation, including route assignment and state updates.

- **HighwayTrafficController**: A controller managing highway traffic including ramp metering, speed harmonization, and incident response.

- **Intersection**: A node in the road network where two or more road segments meet. May include traffic signals or other control mechanisms.

- **Lane**: A single traffic lane within a road segment, with specific length and allowed vehicle types.

- **PathfindingService**: A service providing route planning capabilities using graph search algorithms like A*.

- **RoadGraph**: The graph structure representing the transport network with intersections as nodes and road segments as edges.

- **RoadSegment**: An edge in the road network connecting two intersections, containing multiple lanes with speed limits and capacity constraints.

- **Route**: A sequence of road segments defining a path from origin to destination for a vehicle.

- **RoutePlanner**: A component that computes vehicle routes using pathfinding algorithms and network state.

- **SignalController**: A component managing traffic signal timing and coordination at intersections.

- **TrafficDelta**: Per-tick traffic outputs including average speed, congestion index, throughput, and incident flags.

- **TrafficModel**: A model simulating traffic flow, vehicle movement, and speed adjustments based on network conditions.

- **TrafficReading**: A measurement from a traffic sensor, including speed, count, and occupancy data.

- **TrafficSensor**: A virtual sensor placed in the network to measure traffic conditions at specific locations.

- **Vehicle**: An entity representing a single vehicle in the simulation with type, route, current position, and speed.

## Data & Logging Terms

- **CSV (Comma-Separated Values)**: A simple tabular data format suitable for structured logging and easy import into analysis tools.

- **DataStore**: An abstract storage interface with concrete implementations like `FileSystemStore` and `MemoryStore`.

- **FileSystemStore**: A storage implementation persisting data to the local file system.

- **ILogger**: The logging contract interface that concrete loggers must implement.

- **JSON (JavaScript Object Notation)**: A structured data format suitable for logging complex nested data structures.

- **JSONL (JSON Lines)**: A format where each line is a complete JSON object. Preferred for structured logging due to ease of parsing and ability to handle nested structures.

- **LogFormatter**: A component responsible for formatting log data according to defined schemas.

- **Logger**: A component that writes structured log data to persistent storage for later analysis.

- **LogSchema**: The definition of required and optional fields for log entries, ensuring consistency across the system.

- **MemoryStore**: A storage implementation keeping data in memory, useful for testing and temporary data.

- **RunReportWriter**: A component that exports the final `RunReport` in various formats for human or machine consumption.

## Building & Infrastructure Terms

- **Building**: A structure within a district with a specific type (Residential, Commercial, Industrial, Civic) and capacity.

- **Civic Building**: A building dedicated to public services such as schools, hospitals, or government offices.

- **Commercial Building**: A building used for business, retail, or office purposes.

- **EducationService**: A service component providing educational facilities and programs to the population.

- **HealthService**: A service component providing healthcare facilities and services to the population.

- **HousingService**: A service component managing residential capacity and housing availability.

- **Industrial Building**: A building used for manufacturing, production, or industrial purposes.

- **PowerGrid**: An infrastructure component managing electricity generation and distribution.

- **PublicSafetyService**: A service component providing police, fire, and emergency services.

- **Residential Building**: A building providing housing for the city's population.

- **TransportNetwork**: The complete infrastructure for movement including roads, intersections, and transit systems.

- **Utilities**: Infrastructure components providing essential services like power, water, and waste management.

- **WaterSystem**: An infrastructure component managing water supply and distribution.

## Policy & Decision Terms

- **IDecisionRule**: An interface defining the contract for executable decision rules.

- **IPolicy**: An interface defining the contract for policy definitions that can be evaluated by the `PolicyEngine`.

- **InfrastructureInvestmentPolicy**: A policy type focused on decisions about infrastructure improvements and maintenance.

- **SubsidyPolicy**: A policy type managing financial subsidies to businesses, services, or populations.

- **TaxPolicy**: A policy type managing tax rates, structures, and collection rules.

- **ZoningPolicy**: A policy type managing land use designations and building restrictions.

## Interface & Contract Terms

- **IDataExporter**: An interface for components that export data in various formats.

- **IMetricSink**: An interface for components that receive and process metrics.

- **IProfiler**: An interface for profiling components.

- **IScenarioLoader**: An interface for components that load scenario definitions.

- **IStorage**: An interface defining the contract for storage implementations.

- **ISubsystem**: An interface that all subsystems must implement, requiring an `update(city, ctx)` method.

## Testing & Quality Terms

- **Acceptance Criteria**: Specific, measurable conditions that must be met for a feature or component to be considered complete and correct.

- **Baseline Scenario**: A reference scenario with known expected outcomes, used for validating system behavior and detecting regressions.

- **Integration Test**: A test validating the interaction between multiple components or subsystems.

- **Invariant**: A condition that must always hold true throughout execution, such as "population is non-negative" or "budget equation balances each tick."

- **Unit Test**: A test validating the behavior of a single component in isolation.

## File & Directory References

- **docs/adr/**: Directory containing Architecture Decision Records.
- **docs/architecture/**: Directory containing high-level system architecture documentation.
- **docs/design/**: Directory containing design guides, workstreams, and templates.
- **docs/guides/**: Directory containing user and contributor guides.
- **docs/models/**: Directory containing UML and other model files.
- **docs/specs/**: Directory containing detailed specifications for subsystems and components.
- **output/logs/global/**: Directory for global simulation run logs.
- **output/logs/ui/**: Directory for UI-specific logs.
- **src/city/**: Directory containing city model implementation.
- **src/shared/**: Directory containing shared utilities and settings.
- **src/simulation/**: Directory containing simulation core implementation.
