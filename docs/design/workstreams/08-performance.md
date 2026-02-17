# Workstream: Performance

## Reading Checklist
- Architecture Overview: [../../architecture/overview.md](../../architecture/overview.md)
- Class Hierarchy: [../../architecture/class-hierarchy.md](../../architecture/class-hierarchy.md)
- Specs: [../../specs/simulation.md](../../specs/simulation.md), [../../specs/city.md](../../specs/city.md), [../../specs/logging.md](../../specs/logging.md)
- ADRs: [../../adr/001-simulation-determinism.md](../../adr/001-simulation-determinism.md)
- Design Guide: [../readme.md](../readme.md)
- Consolidated Prompts: [../prompts.md](../prompts.md)
- Templates: [../templates/](../templates/)
- Guides: [../../guides/](../../guides/)
- Models: [../../models/model.mdj](../../models/model.mdj)

## Objectives
- Profile simulation and optimize hotspots.

## Scope
- Files: [src/simulation/sim.py](../../src/simulation/sim.py), city modules as needed

## Inputs
- Scenarios and seeds for repeatable profiling.

## Outputs
- Profiling reports and optimization notes.

## Run Steps
```bash
./init-venv.sh && pip install -r requirements.txt
python3 run.py
```

## Task Backlog
- Add basic profiling hooks (cProfile).
- Reduce tick latency under default scenario.

## Acceptance Criteria
- Demonstrated latency improvements without correctness regressions.

## Copy‑Paste Prompt
```
Preflight Checklist:
- [ ] Read Architecture Overview, Class Hierarchy, and diagram
- [ ] Review specs, scenarios, and ADRs
- [ ] Confirm settings and entry points
- [ ] Identify required outputs and acceptance criteria
- [ ] Plan minimal, style-consistent changes and validation steps
You are an AI coding agent working on City‑Sim, focusing on the Performance workstream.

Objectives:
- Profile simulation and optimize hotspots.

Global Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/simulation.md, docs/specs/city.md
- ADRs: docs/adr/001-simulation-determinism.md
- Guides: docs/guides/contributing.md, docs/guides/glossary.md
- Workstreams Index: docs/design/workstreams/00-index.md

Scope & Files:
- Primary: src/simulation/sim.py, city modules as needed
- Specs: docs/architecture/overview.md

Required Outputs:
- Profiling reports and optimization notes.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py

Acceptance Criteria:
- Latency improvements without correctness regressions.

Deliver:
- Plan + edits
- Validation (profiling reports)
- Follow-up recommendations
```
