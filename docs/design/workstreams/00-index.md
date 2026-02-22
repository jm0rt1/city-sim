# Workstreams Index

Choose a workstream to get started. Each file contains objectives, inputs/outputs, run steps, checkpoints, and acceptance criteria. Workstreams are designed for parallel execution.

## Pre-Work Workstreams (complete before WS-01 through WS-10)

These workstreams define shared interface contracts and integration protocols. All implementation
workstreams (WS-01 through WS-10) depend on their outputs. Complete these first to prevent
cross-workstream conflicts.

- [00a-shared-interfaces.md](00a-shared-interfaces.md) – **ISubsystem, IPolicy, Decision, PolicyEngine, RandomService, EventBus, MetricsCollector, ScenarioLoader, TickContext, InvariantViolation** — canonical definitions for all shared types.
- [00b-data-contracts.md](00b-data-contracts.md) – **FinanceDelta, PopulationDelta, TrafficDelta, CityDelta aggregation rules, CityState ownership table, IServiceManager, IInfrastructureManager** — data structures that cross subsystem boundaries.
- [00c-integration-protocols.md](00c-integration-protocols.md) – **Canonical tick order, state-visibility rule, determinism contracts, error propagation, feedback-loop lags, EventBus rules, mandatory metrics, scenario/settings precedence** — runtime integration rules.

Primary output: **[docs/specs/interfaces.md](../../specs/interfaces.md)**

## Implementation Workstreams

- [01-simulation-core.md](01-simulation-core.md) – Simulation loop, tick scheduling, determinism, and scenario runs.
- [02-city-modeling.md](02-city-modeling.md) – Data models for `City`, state transitions, and decisions.
- [03-finance.md](03-finance.md) – Budgeting, revenue/expense modeling, and policy levers.
- [04-population.md](04-population.md) – Population growth, happiness, migration dynamics.
- [05-ui.md](05-ui.md) – CLI/UX and UI generation pipeline.
- [06-data-logging.md](06-data-logging.md) – Structured logging, metrics, and experiment tracking.
- [07-testing-ci.md](07-testing-ci.md) – Unit/integration tests, static analysis, and CI.
- [08-performance.md](08-performance.md) – Profiling and optimization plans.
- [09-roadmap.md](09-roadmap.md) – Planning across releases and cross‑workstream dependencies.
- [10-traffic.md](10-traffic.md) – Transport network, pathfinding, and city/highway traffic simulation.

## Source Pointers
- Simulation: [src/simulation/sim.py](../../src/simulation/sim.py)
- City: [src/city/city.py](../../src/city/city.py), [src/city/city_manager.py](../../src/city/city_manager.py)
- Finance: [src/city/finance.py](../../src/city/finance.py)
- Population: [src/city/population/population.py](../../src/city/population/population.py), [src/city/population/happiness_tracker.py](../../src/city/population/happiness_tracker.py)
- Settings: [src/shared/settings.py](../../src/shared/settings.py)
- Decisions: [src/city/decisions.py](../../src/city/decisions.py)

## Prompt Template
- Generic template: [docs/design/templates/workstream_prompt.md](../templates/workstream_prompt.md)
- Each workstream file includes a tailored copy‑paste prompt at the end.
- All prompts consolidated: [docs/design/prompts.md](../prompts.md)

## Context and Reading Order
1. Read **Pre-Work workstreams 00A, 00B, 00C** and their primary output (`docs/specs/interfaces.md`) before any implementation workstream.
2. Architecture: [../architecture/overview.md](../../architecture/overview.md), [../architecture/class-hierarchy.md](../../architecture/class-hierarchy.md)
3. Specs: [../specs](../../specs) including simulation, city, finance, population, logging, traffic, scenarios, **interfaces**
4. ADRs: [../adr](../../adr)
5. Guides: [../guides](../../guides)
6. Models: [../models/model.mdj](../../models/model.mdj)
