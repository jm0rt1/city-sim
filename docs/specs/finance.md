# Specification: Finance

## Purpose
Define revenue/expense models and budget update rules.

## Interfaces
- `Finance.update(city, context)`: computes revenue and expenses per tick.

## Inputs
- City state and policy parameters.

## Outputs
- Budget delta and metrics for logging.

## Acceptance Criteria
- Budget equation holds within floating‑point tolerance.
- Policies affect revenue/expenses predictably.
