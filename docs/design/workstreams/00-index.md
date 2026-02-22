# Workstreams Index

Choose a workstream to get started. Each file contains objectives, inputs/outputs, run steps, checkpoints, and acceptance criteria. Workstreams are designed for parallel execution.

## Workstreams
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
- [11-graphics.md](11-graphics.md) – Isometric 2D tile renderer, sprite atlas pipeline, and AI-generated game assets.

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
- Architecture: [../architecture/overview.md](../../architecture/overview.md), [../architecture/class-hierarchy.md](../../architecture/class-hierarchy.md)
- Specs: [../specs](../../specs) including simulation, city, finance, population, logging, traffic, scenarios
- ADRs: [../adr](../../adr)
- Guides: [../guides](../../guides)
- Models: [../models/model.mdj](../../models/model.mdj)
