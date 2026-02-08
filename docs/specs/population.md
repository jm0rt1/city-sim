# Specification: Population

## Purpose
Define population growth/decline and happiness/migration rules.

## Interfaces
- `Population.update(city, context)`: applies growth and migration changes.
- `HappinessTracker.update(city, context)`: updates happiness metrics.

## Inputs
- City state and finance signals.

## Outputs
- Population and happiness deltas; metrics for logging.

## Acceptance Criteria
- Trends match expected behavior in baseline scenarios.
- Deterministic outcomes with fixed seed.
