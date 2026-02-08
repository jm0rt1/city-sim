# Specification: Simulation Core

## Purpose
Define the tick loop contract, scenario configuration, and expected outputs.

## Interfaces
- `Sim.run(settings)`: executes the simulation for the configured horizon.
- `Sim.tick(city, context)`: performs one tick, returning updated state and metrics.

## Inputs
- Settings: [src/shared/settings.py](../../src/shared/settings.py) — seed, horizon, policies.
- City model: [src/city/city.py](../../src/city/city.py), [src/city/city_manager.py](../../src/city/city_manager.py).

## Outputs
- Logs: structured per tick; summary report at end.
- Metrics: tick duration, event counts, key KPIs.

## Determinism
- Given fixed `seed` and settings, identical state trajectory and logs.

## Configuration
- `seed: int`
- `tick_horizon: int`
- `policies: list`
- `profiling_enabled: bool`

## Acceptance Criteria
- Repeatable outputs with same seed.
- No more than 10% variability in tick duration across runs.
