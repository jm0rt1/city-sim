# Class Hierarchy Summary

This document summarizes the planned class hierarchy and responsibilities across the City‑Sim system.

## Simulation
- **SimRunner**: orchestrates runs, produces `RunReport`.
- **SimCore**: core tick engine; uses `TickScheduler`, `EventBus`, `MetricsCollector`, `RandomService`, `PolicyEngine`, `CityManager`.
- **TickScheduler**: computes next tick.
- **EventBus/EventQueue/EventHandler/Event**: publish/subscribe infrastructure.
- **TickContext**: per‑tick context (settings, policy set, time index).
- **TickResult**: per‑tick outputs (metrics/state deltas).
- **MetricsCollector**: sink for metrics; flushes to `Logger`.
- **Profiler/ProfileReport**: optional profiling.
- **RandomService**: seedable random provider.
- **ScenarioLoader**: loads scenarios by name.

## Configuration
- **Settings**: global configuration; references `PolicySet`.
- **Scenario**: named scenario with parameters.
- **PolicySet**: collection of `IPolicy`.
- **SeedProvider**: supplies deterministic seeds.

## City
- **City**: aggregate root; owns `CityState` and `District`s.
- **CityState**: budget, population, happiness, `InfrastructureState`, `ServiceState`.
- **CityManager**: applies decisions and updates subsystems; returns `CityDelta`.
- **CityDelta**: summary of state changes.
- **District**: contains `Building`s.
- **Building**: typed (Residential/Commercial/Industrial/Civic) with capacity.
- **InfrastructureState**: transport, utilities, power, water.
- **ServiceState**: health, education, public safety, housing.
- **TransportNetwork/Utilities/PowerGrid/WaterSystem**: infrastructure components.
- **HealthService/EducationService/PublicSafetyService/HousingService**: service components.

## Policy
- **PolicyEngine**: evaluates city/context to produce `IDecisionRule`s.
- **Decision**: executable rule; applies state changes.
- **TaxPolicy/SubsidyPolicy/ZoningPolicy/InfrastructureInvestmentPolicy**: policy primitives.

## Finance
- **FinanceSubsystem**: computes revenue/expenses and budget deltas.
- **FinanceDelta**: per‑tick finance outputs.
- **Budget**: current balance.
- **RevenueModel/ExpenseModel**: calculation strategies.
- **FinanceReport**: summary of finance metrics.

## Population
- **PopulationSubsystem**: updates population, happiness, migration.
- **PopulationDelta**: per‑tick population outputs.
- **PopulationModel**: growth/decline computation.
- **HappinessTracker**: updates happiness.
- **MigrationModel**: migration computation.
- **Demographics**: population composition data.

## Logging
- **Logger**: base logging interface.
- **JSONLogger/CSVLogger**: concrete loggers.
- **LogFormatter/LogSchema**: formatting and field definitions.
- **RunReportWriter**: exports `RunReport`.
- **RunReport**: final run summary (budget, population, happiness, ticks, KPIs).

## Storage
- **DataStore**: abstract storage.
- **FileSystemStore/MemoryStore**: concrete implementations.

## UI
- **CLIService**: runs scenarios and prints summaries.
- **ScenarioReportGenerator**: builds human‑readable reports.

## Transport & Traffic
- **TransportSubsystem**: advances traffic simulation each tick.
- **RoadGraph**: intersections and road segments with lanes.
- **Intersection/RoadSegment/Lane**: network primitives.
- **RoutePlanner/PathfindingService**: A* planning and re‑routing.
- **Vehicle/FleetManager**: vehicle state and route assignment.
- **CityTrafficController/HighwayTrafficController/SignalController**: control logic for signals and highways.
- **TrafficModel/CongestionModel**: flow and congestion computation.
- **TrafficSensor/TrafficReading**: measurements for speed, throughput, occupancy.
- **TrafficDelta**: tick outputs (avg speed, congestion index, throughput).

## Interfaces
- **ISubsystem**: subsystems must implement `update(city, ctx)`.
- **IPolicy**: policy definition.
- **IDecisionRule**: executable rule.
- **ILogger**: logging contract.
- **IMetricSink**: metrics sink.
- **IStorage**: storage contract.
- **IDataExporter**: export outputs.
- **IScenarioLoader**: load scenarios.
- **IProfiler**: profiling interface.

## Relationships (Key)
- **SimRunner → SimCore**: orchestrates core.
- **SimCore → CityManager/PolicyEngine**: updates state and decisions.
- **City → CityState/District**: composition/aggregation.
- **FinanceSubsystem → Budget/RevenueModel/ExpenseModel**: computes deltas.
- **PopulationSubsystem → PopulationModel/HappinessTracker/MigrationModel**: updates population.
- **Logger ← JSONLogger/CSVLogger**: inheritance.
- **DataStore ← FileSystemStore/MemoryStore**: inheritance.

See diagram: [docs/architecture/city-sim-architecture.puml](docs/architecture/city-sim-architecture.puml)
