# Workstream: Transport & Traffic

## Reading Checklist
- Architecture Overview: [../../architecture/overview.md](../../architecture/overview.md)
- Class Hierarchy: [../../architecture/class-hierarchy.md](../../architecture/class-hierarchy.md)
- Architecture Diagram: [../../architecture/city-sim-architecture.puml](../../architecture/city-sim-architecture.puml)
- Specs: [../../specs/traffic.md](../../specs/traffic.md), [../../specs/logging.md](../../specs/logging.md), [../../specs/scenarios.md](../../specs/scenarios.md)
- ADRs: [../../adr](../../adr)
- Design Guide: [../readme.md](../readme.md)
- Consolidated Prompts: [../prompts.md](../prompts.md)
- Templates: [../templates/](../templates/)
- Guides: [../../guides/](../../guides/)
- Models: [../../models/model.mdj](../../models/model.mdj)

## Objectives
- Implement transport network with intersections, road segments, lanes.
- Add pathfinding (A*) for vehicle routing and re-routing.
- Simulate city and highway traffic with controllers and signals.
- Emit traffic metrics: throughput, avg speed, congestion index.

## Scope
- Files: (new) Transport subsystem; integrate with `InfrastructureState` and `CityManager`.
- Specs: [docs/specs/traffic.md](../../specs/traffic.md), [docs/architecture/overview.md](../../architecture/overview.md)

## Inputs
- Settings: [src/shared/settings.py](../../src/shared/settings.py)
- City infrastructure from [src/city/city.py](../../src/city/city.py)

## Outputs
- Traffic simulation hooks and metrics in logs.
- Tests for pathfinding and signal behavior.

## Run Steps
```bash
./init-venv.sh
pip install -r requirements.txt
python3 run.py
./test.sh
```

## Task Backlog
- Define `RoadGraph`, `Intersection`, `RoadSegment`, `Lane`.
- Implement `RoutePlanner` (A*) and `Vehicle` movement updates.
- Add `SignalController`, `CityTrafficController`, `HighwayTrafficController`.
- Instrument traffic metrics and logging.
- Write unit tests for pathfinding and controller logic.

## Acceptance Criteria
- Vehicles traverse planned routes respecting signals and speed limits.
- A* pathfinding returns feasible routes; re-routes on incidents.
- Deterministic metrics under fixed seed.

## Checkpoints
- Graph + planner implemented; basic vehicle routing works.
- Signals and controllers integrated; metrics logging in place.

## Copy‑Paste Prompt
```
Preflight Checklist:
- [ ] Read Architecture Overview, Class Hierarchy, and diagram
- [ ] Review traffic/logging/scenarios specs and ADRs
- [ ] Confirm settings and entry points
- [ ] Identify required outputs and acceptance criteria
- [ ] Plan minimal, style-consistent changes and validation steps
You are an AI coding agent working on City‑Sim, focusing on the Transport & Traffic workstream.

Objectives:
- Implement a transport network and traffic simulation with A* pathfinding, city/highway controllers, and metrics.

Global Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/traffic.md, docs/specs/logging.md, docs/specs/scenarios.md
- ADRs: docs/adr/*
- Guides: docs/guides/contributing.md, docs/guides/glossary.md
- Workstreams Index: docs/design/workstreams/00-index.md

Scope & Files:
- Integrate with InfrastructureState and CityManager; create Transport subsystem modules.
- Specs: docs/specs/traffic.md; Architecture: docs/architecture/overview.md

Required Outputs:
- Transport subsystem code/docs; logging of throughput, avg_speed, congestion_index.
- Tests for pathfinding and signals.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py
4) ./test.sh

Acceptance Criteria:
- Vehicles respect signals and speed limits and complete routes.
- Pathfinding finds feasible routes; re-routes under blockages.
- Deterministic metrics with fixed seeds.

Deliver:
- Plan + exact edits
- Validation notes (logs/tests)
- Follow-up recommendations
```
