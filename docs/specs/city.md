# Specification: City Model

## Purpose
Define `City` data structures, invariants, and update rules via `CityManager`.

## Data Model
- `City`:
  - `budget: float`
  - `population: int`
  - `happiness: float` (0..100)
  - Additional attributes: infrastructure, services, etc.

## Operations
- `CityManager.apply_decisions(city, decisions)`: returns state deltas.
- `CityManager.update(city, context)`: applies subsystem updates per tick.

## Invariants
- Budget reconciliation holds each tick.
- Population non‑negative; happiness bounded.

## Acceptance Criteria
- Standard decisions produce expected deltas.
- Transitions validated under baseline scenarios.
