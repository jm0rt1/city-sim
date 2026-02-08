# System Architecture Overview

This document describes the planned architecture of the City‑Sim application, focusing on components, data flow, invariants, and design principles to guide implementation.

## Components
- Simulation Core: orchestrates tick loop and scenario execution — see [src/simulation/sim.py](../../src/simulation/sim.py)
- City Model: core state (`City`) and operations (`CityManager`) — see [src/city/city.py](../../src/city/city.py), [src/city/city_manager.py](../../src/city/city_manager.py)
- Decisions/Policies: effects applied to city state — see [src/city/decisions.py](../../src/city/decisions.py)
- Finance: budget, revenue, expenses — see [src/city/finance.py](../../src/city/finance.py)
- Population: growth, happiness, migration — see [src/city/population/population.py](../../src/city/population/population.py), [src/city/population/happiness_tracker.py](../../src/city/population/happiness_tracker.py)
- Settings: configuration and scenario parameters — see [src/shared/settings.py](../../src/shared/settings.py)
- Entry Points: runtime scripts — see [run.py](../../run.py), [src/main.py](../../src/main.py)
- Logging: structured outputs for analysis — see [output/logs/global](../../output/logs/global), [output/logs/ui](../../output/logs/ui)

## Data Flow
1. `run.py` initializes settings and seeds the simulation.
2. Simulation Core executes ticks, calling `CityManager` to update `City` state.
3. Decisions and policies are evaluated; Finance and Population subsystems update.
4. Metrics and logs are emitted per tick to `output/logs/*`.
5. UI/CLI surfaces summaries and scenario reports.

## Invariants (Examples)
- Deterministic runs under fixed seed and configuration.
- Budget reconciliation: previous_budget + revenue − expenses = current_budget.
- Population values non‑negative; rates within defined bounds.
- Happiness normalized to an agreed range (e.g., 0..100).

## Design Principles
- Minimal public API changes; clear contracts documented in specs.
- Determinism and reproducibility prioritized for testing and analysis.
- Structured logging for machine‑readable outputs.
- Separation of concerns: Simulation, City Model, Finance, Population.

## Extension Points
- Scenario loader: configurable parameters, policies, time horizon.
- Plug‑in hooks for metrics and profiling.
- Future UI adapters for richer visualization.
