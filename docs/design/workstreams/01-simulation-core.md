# Workstream: Simulation Core

## Reading Checklist
- Architecture Overview: [../../architecture/overview.md](../../architecture/overview.md)
- Class Hierarchy: [../../architecture/class-hierarchy.md](../../architecture/class-hierarchy.md)
- Architecture Diagram: [../../architecture/city-sim-architecture.puml](../../architecture/city-sim-architecture.puml)
- Specs: [../../specs/simulation.md](../../specs/simulation.md), [../../specs/logging.md](../../specs/logging.md), [../../specs/scenarios.md](../../specs/scenarios.md)
- ADRs: [../../adr/001-simulation-determinism.md](../../adr/001-simulation-determinism.md)
- Design Guide: [../readme.md](../readme.md)
- Consolidated Prompts: [../prompts.md](../prompts.md)
- Templates: [../templates/](../templates/)
- Guides: [../../guides/](../../guides/)
- Models: [../../models/model.mdj](../../models/model.mdj)

## Objectives
- Ensure deterministic tick loop and reproducible scenarios.
- Establish scenario runner with seed control and logging.
- Validate core update cycle performance and correctness.

## Scope
- Files: [src/simulation/sim.py](../../src/simulation/sim.py), [src/shared/settings.py](../../src/shared/settings.py), [src/main.py](../../src/main.py), [run.py](../../run.py)
- Outputs: stable simulation loop behavior, metrics for tick duration, and scenario logs.

## Inputs
- Settings: [src/shared/settings.py](../../src/shared/settings.py)
- Entry points: [run.py](../../run.py), [src/main.py](../../src/main.py)

## Outputs
- Logs: [output/logs/global/](../../output/logs/global/)
- Updated docs and potential unit tests in [tests/](../../tests/)

## Run Steps
```bash
./init-venv.sh && pip install -r requirements.txt
python3 run.py
```

## Task Backlog
- Add scenario configuration loader (seed, duration, policies).
- Instrument tick timing and event counts.
- Validate determinism via repeated runs with same seed.

## Acceptance Criteria
- Same seed yields identical state trajectories and logs.
- Tick timing metric recorded per run; no regression >10%.
- Code remains minimal; public APIs unchanged unless specified.

## Checkpoints
- Scenario loader implemented and referenced by `sim.py`.
- Determinism test covers repeatability (add to Testing workstream).

## Copy‑Paste Prompt
```
Preflight Checklist:
- [ ] Read Architecture Overview, Class Hierarchy, and diagram
- [ ] Review simulation/city/logging specs and ADR
- [ ] Confirm settings and entry points
- [ ] Identify required outputs and acceptance criteria
- [ ] Plan minimal, style-consistent changes and validation steps
You are an AI coding agent working on City‑Sim, focusing on the Simulation Core workstream.

Objectives:
- Ensure deterministic tick loop and reproducible scenarios.
- Establish scenario runner with seed control and logging.
- Validate update cycle performance and correctness.

Global Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/simulation.md, docs/specs/logging.md, docs/specs/scenarios.md
- ADRs: docs/adr/001-simulation-determinism.md
- Guides: docs/guides/contributing.md, docs/guides/glossary.md
- Workstreams Index: docs/design/workstreams/00-index.md

Scope & Files:
- Primary: src/simulation/sim.py, src/shared/settings.py, src/main.py, run.py
- Related: docs/specs/simulation.md, docs/specs/logging.md

Required Outputs:
- Code/doc changes to implement/clarify scenario loader, determinism controls, and tick metrics.
- Logs in output/logs/global/ with tick_duration_ms and KPIs.
- Tests (if applicable) to verify determinism.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py
4) ./test.sh

Acceptance Criteria:
- Same seed yields identical trajectories/logs.
- Tick timing recorded; no >10% performance regression.
- Minimal API changes unless spec requires.

Checkpoints:
- Scenario loader invoked by sim.py
- Determinism test updated under tests/

Deliver:
- Concise plan + exact edits
- Validation notes (run outputs/tests)
- Follow-up recommendations
```