# ADR 001: Simulation Determinism

## Status
Proposed

## Context
We require reproducible runs to evaluate changes and compare scenarios. Determinism also supports robust testing and debugging.

## Decision
Adopt deterministic tick loop behavior: given a fixed seed and configuration, state trajectories and logs must be identical across runs.

## Consequences
- Enables repeatability for tests and experiments.
- Requires careful management of random sources and time‑dependent inputs.
- Slight overhead for seeding and validation.

## References
- Workstream: [Simulation Core](../ai_dev/workstreams/01-simulation-core.md)
- Spec: [Simulation](../specs/simulation.md)
