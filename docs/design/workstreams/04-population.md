# Workstream: Population

## Reading Checklist
- Architecture Overview: [../../architecture/overview.md](../../architecture/overview.md)
- Class Hierarchy: [../../architecture/class-hierarchy.md](../../architecture/class-hierarchy.md)
- Architecture Diagram: [../../architecture/city-sim-architecture.puml](../../architecture/city-sim-architecture.puml)
- Specs: [../../specs/population.md](../../specs/population.md), [../../specs/logging.md](../../specs/logging.md), [../../specs/scenarios.md](../../specs/scenarios.md)
- ADRs: [../../adr/001-simulation-determinism.md](../../adr/001-simulation-determinism.md)
- Design Guide: [../readme.md](../readme.md)
- Consolidated Prompts: [../prompts.md](../prompts.md)
- Templates: [../templates/](../templates/)
- Guides: [../../guides/](../../guides/)
- Models: [../../models/model.mdj](../../models/model.mdj)

## Objectives
- Implement population growth/decline models.
- Track happiness and migration dynamics.

## Scope
- Files: [src/city/population/population.py](../../src/city/population/population.py), [src/city/population/happiness_tracker.py](../../src/city/population/happiness_tracker.py)

## Inputs
- Settings: [src/shared/settings.py](../../src/shared/settings.py)
- Finance/policy signals from other workstreams.

## Outputs
- Population and happiness metrics logged per tick.
- Tests validating trends under scenarios.

## Run Steps
```bash
./init-venv.sh && pip install -r requirements.txt
python3 run.py
```

## Task Backlog
- Define base growth and happiness equations.
- Add migration triggers and thresholds.
- Cross‑validate with Finance impacts.

## Acceptance Criteria
- Metrics stable and reproducible with seed control.
- Expected trends under synthetic scenarios confirmed.

## Copy‑Paste Prompt
```
You are an AI coding agent working on City‑Sim, focusing on the Population workstream.

Objectives:
- Implement population growth/decline models.
- Track happiness and migration dynamics.

Global Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/population.md, docs/specs/logging.md, docs/specs/scenarios.md
- ADRs: docs/adr/001-simulation-determinism.md
- Guides: docs/guides/contributing.md, docs/guides/glossary.md
- Workstreams Index: docs/design/workstreams/00-index.md

Scope & Files:
- Primary: src/city/population/population.py, src/city/population/happiness_tracker.py
- Specs: docs/specs/population.md, docs/architecture/overview.md

Required Outputs:
- Population and happiness metrics logged per tick.
- Tests validating trends under scenarios.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py
4) ./test.sh

Acceptance Criteria:
- Metrics stable/reproducible with fixed seed.
- Expected trends confirmed in baseline scenarios.

Deliver:
- Plan + edits
- Validation (tests/logs)
- Follow-up recommendations
```
