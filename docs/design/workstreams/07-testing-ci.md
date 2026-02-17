# Workstream: Testing & CI

## Reading Checklist
- Architecture Overview: [../../architecture/overview.md](../../architecture/overview.md)
- Class Hierarchy: [../../architecture/class-hierarchy.md](../../architecture/class-hierarchy.md)
- Specs: [../../specs/simulation.md](../../specs/simulation.md), [../../specs/city.md](../../specs/city.md), [../../specs/finance.md](../../specs/finance.md), [../../specs/population.md](../../specs/population.md), [../../specs/traffic.md](../../specs/traffic.md), [../../specs/logging.md](../../specs/logging.md)
- ADRs: [../../adr/001-simulation-determinism.md](../../adr/001-simulation-determinism.md)
- Design Guide: [../readme.md](../readme.md)
- Consolidated Prompts: [../prompts.md](../prompts.md)
- Templates: [../templates/](../templates/)
- Guides: [../../guides/](../../guides/)
- Models: [../../models/model.mdj](../../models/model.mdj)

## Objectives
- Add unit/integration tests and static analysis.
- Ensure stable CI pipeline.

## Scope
- Tests: [tests/](../../tests/)
- Config: [pyrightconfig.json](../../pyrightconfig.json)

## Inputs
- Existing minimal tests: [tests/core/test_dummy.py](../../tests/core/test_dummy.py)

## Outputs
- Test suites for major modules.
- CI instructions (optional).

## Run Steps
```bash
./init-venv.sh && pip install -r requirements.txt
./test.sh
```

## Task Backlog
- Unit tests for `sim.py`, `city.py`, `finance.py`, population.
- Static analysis improvements and type hints.

## Acceptance Criteria
- Tests green; meaningful coverage metrics.

## Copy‑Paste Prompt
```
Preflight Checklist:
- [ ] Read Architecture Overview, Class Hierarchy, and diagram
- [ ] Review relevant specs and ADRs
- [ ] Confirm settings and entry points
- [ ] Identify required outputs and acceptance criteria
- [ ] Plan minimal, style-consistent changes and validation steps
You are an AI coding agent working on City‑Sim, focusing on the Testing & CI workstream.

Objectives:
- Add unit/integration tests and static analysis.
- Ensure stable CI pipeline.

Global Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/*
- ADRs: docs/adr/001-simulation-determinism.md
- Guides: docs/guides/contributing.md, docs/guides/glossary.md
- Workstreams Index: docs/design/workstreams/00-index.md

Scope & Files:
- Tests: tests/
- Config: pyrightconfig.json
- Specs: docs/specs/*, docs/architecture/overview.md

Required Outputs:
- Test suites for major modules.
- CI instructions (optional).

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) ./test.sh

Acceptance Criteria:
- Tests green; meaningful coverage metrics.

Deliver:
- Plan + edits
- Validation (test results)
- Follow-up recommendations
```
