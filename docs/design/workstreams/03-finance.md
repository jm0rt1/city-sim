# Workstream: Finance

## Reading Checklist
- Architecture Overview: [../../architecture/overview.md](../../architecture/overview.md)
- Class Hierarchy: [../../architecture/class-hierarchy.md](../../architecture/class-hierarchy.md)
- Architecture Diagram: [../../architecture/city-sim-architecture.puml](../../architecture/city-sim-architecture.puml)
- Specs: [../../specs/finance.md](../../specs/finance.md), [../../specs/logging.md](../../specs/logging.md), [../../specs/scenarios.md](../../specs/scenarios.md)
- ADRs: [../../adr/001-simulation-determinism.md](../../adr/001-simulation-determinism.md)
- Design Guide: [../readme.md](../readme.md)
- Consolidated Prompts: [../prompts.md](../prompts.md)
- Templates: [../templates/](../templates/)
- Guides: [../../guides/](../../guides/)
- Models: [../../models/model.mdj](../../models/model.mdj)

## Objectives
- Model revenue streams, expenses, and policies.
- Ensure budget updates integrate with simulation ticks.

## Scope
- Files: [src/city/finance.py](../../src/city/finance.py), [src/city/city.py](../../src/city/city.py)

## Inputs
- Settings: [src/shared/settings.py](../../src/shared/settings.py)
- Decisions: [src/city/decisions.py](../../src/city/decisions.py)

## Outputs
- Budget update functions with tests.
- Metrics in logs for revenues/expenses per tick.

## Run Steps
```bash
./init-venv.sh && pip install -r requirements.txt
python3 run.py
```

## Task Backlog
- Define base tax and expense models.
- Add policy levers and sensitivity tests.
- Log budget KPIs per scenario.

## Acceptance Criteria
- Budget reconciles correctly each tick.
- Policies produce predictable changes within tolerated bounds.

## Copy‑Paste Prompt
```
You are an AI coding agent working on City‑Sim, focusing on the Finance workstream.

Objectives:
- Model revenue streams, expenses, and policies.
- Ensure budget updates integrate with simulation ticks.

Global Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/finance.md, docs/specs/logging.md, docs/specs/scenarios.md
- ADRs: docs/adr/001-simulation-determinism.md
- Guides: docs/guides/contributing.md, docs/guides/glossary.md
- Workstreams Index: docs/design/workstreams/00-index.md

Scope & Files:
- Primary: src/city/finance.py, src/city/city.py
- Specs: docs/specs/finance.md, docs/architecture/overview.md

Required Outputs:
- Budget update functions with tests.
- Metrics in logs for revenues/expenses per tick.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py
4) ./test.sh

Acceptance Criteria:
- Budget reconciles each tick within tolerance.
- Policies have predictable effects.

Deliver:
- Plan + edits
- Validation (tests/logs)
- Follow-up recommendations
```
