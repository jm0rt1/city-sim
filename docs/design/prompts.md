# City‑Sim Workstream Prompts

Copy a prompt below and paste into your AI agent to run a focused task. Each prompt includes objectives, scope, outputs, run steps, acceptance criteria, and constraints.

## Global Context Pack
- Architecture Overview: [docs/architecture/overview.md](../architecture/overview.md)
- Class Hierarchy Summary: [docs/architecture/class-hierarchy.md](../architecture/class-hierarchy.md)
- Specs: [docs/specs/simulation.md](../specs/simulation.md), [docs/specs/city.md](../specs/city.md), [docs/specs/finance.md](../specs/finance.md), [docs/specs/population.md](../specs/population.md), [docs/specs/logging.md](../specs/logging.md), [docs/specs/traffic.md](../specs/traffic.md), [docs/specs/scenarios.md](../specs/scenarios.md)
- ADRs: [docs/adr/000-template.md](../adr/000-template.md), [docs/adr/001-simulation-determinism.md](../adr/001-simulation-determinism.md)
- Design Guide: [docs/design/readme.md](readme.md)
- Workstreams Index: [docs/design/workstreams/00-index.md](workstreams/00-index.md)
- Templates: [docs/design/templates/task_card.md](templates/task_card.md), [docs/design/templates/design_spec.md](templates/design_spec.md), [docs/design/templates/experiment_plan.md](templates/experiment_plan.md)
- Guides: [docs/guides/contributing.md](../guides/contributing.md), [docs/guides/glossary.md](../guides/glossary.md)
- Models: [docs/models/model.mdj](../models/model.mdj)
- Entry Points: [run.py](../../run.py), [src/main.py](../../src/main.py)
- Settings: [src/shared/settings.py](../../src/shared/settings.py)
- Logs: [output/logs/global/](../../output/logs/global/), [output/logs/ui/](../../output/logs/ui/)

## Preflight Checklist
- [ ] Read Architecture Overview and Class Hierarchy
- [ ] Review relevant Specs (module + logging + scenarios) and ADRs
- [ ] Confirm `settings` (seed, horizon, policies) and entry points
- [ ] Note required outputs and acceptance criteria for the stream
- [ ] Plan minimal, style-consistent changes and validation steps

## 01 – Simulation Core
```
You are an AI coding agent working on the City‑Sim project. Operate in documentation-first mode: plan precisely, update only relevant files, and validate via quick runs/tests.

Focus: Simulation Core

Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Specs: docs/specs/simulation.md, docs/specs/logging.md, docs/specs/scenarios.md
- ADRs: docs/adr/001-simulation-determinism.md
- Design Guide & Index: docs/design/readme.md, docs/design/workstreams/00-index.md
- Templates & Guides: docs/design/templates/*, docs/guides/*
- Models: docs/models/model.mdj
- Entry: run.py, src/main.py
- Settings: src/shared/settings.py
- Logs: output/logs/global/, output/logs/ui/

Preflight Checklist:
- [ ] Read Architecture Overview, Class Hierarchy, and diagram
- [ ] Review simulation/logging/scenarios specs and ADR
- [ ] Confirm settings (seed, horizon, policies) and entry points
- [ ] Identify required outputs and acceptance criteria
- [ ] Plan minimal, style-consistent changes and validation steps

Objectives:
- Ensure deterministic tick loop and reproducible scenarios.
- Implement/clarify scenario loader and seed control.
- Instrument tick duration and KPIs.

Scope & Files:
- Primary: src/simulation/sim.py, src/shared/settings.py, src/main.py, run.py
- Related: docs/specs/simulation.md, docs/specs/logging.md

Required Outputs:
- Scenario loading and seed management documented (and code hooks if needed).
- Logs with tick_duration_ms and core KPIs each tick.
- Tests (or test plan) validating determinism.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py
4) ./test.sh

Acceptance Criteria:
- Fixed seed yields identical trajectories/logs across runs.
- Tick duration recorded; no >10% regression versus baseline.
- Minimal API changes unless spec requires; updated docs reflect any changes.

Constraints:
- Keep changes minimal and consistent with the codebase style.
- Preserve reproducibility; prefer structured logging.

Deliver:
- Concise plan + exact edits
- Validation notes (run outputs/tests)
- Follow-up recommendations
```

## 02 – City Modeling
```
You are an AI coding agent working on City‑Sim.

Focus: City Modeling

Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Architecture Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/city.md, docs/specs/logging.md
- ADRs: docs/adr/001-simulation-determinism.md
- Design Guide & Index: docs/design/readme.md, docs/design/workstreams/00-index.md
- Templates & Guides: docs/design/templates/*, docs/guides/*
- Models: docs/models/model.mdj
- Entry: run.py, src/main.py
- Settings: src/shared/settings.py
- Logs: output/logs/global/, output/logs/ui/

Preflight Checklist:
- [ ] Read Architecture Overview, Class Hierarchy, and diagram
- [ ] Review city/logging specs and ADRs
- [ ] Confirm settings and entry points
- [ ] Identify required outputs and acceptance criteria
- [ ] Plan minimal, style-consistent changes and validation steps

Objectives:
- Clarify City state, invariants, and transitions.
- Define decision effects and coverage.
- Ensure CityManager operations are consistent and testable.

Scope & Files:
- Primary: src/city/city.py, src/city/city_manager.py, src/city/decisions.py
- Related: docs/specs/city.md

Required Outputs:
- Updated docs describing attributes & invariants.
- Transition tests for common policies.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py
4) ./test.sh

Acceptance Criteria:
- Decisions produce expected deltas under baseline scenarios.
- Invariants documented and covered by tests.

Constraints:
- Minimal, style-consistent changes; stable public contracts.

Deliver:
- Plan + edits
- Validation (tests/logs)
- Follow-up recommendations
```

## 03 – Finance
```
You are an AI coding agent working on City‑Sim.

Focus: Finance

Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Architecture Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/finance.md, docs/specs/logging.md, docs/specs/scenarios.md
- ADRs: docs/adr/001-simulation-determinism.md
- Design Guide & Index: docs/design/readme.md, docs/design/workstreams/00-index.md
- Templates & Guides: docs/design/templates/*, docs/guides/*
- Models: docs/models/model.mdj
- Entry: run.py, src/main.py
- Settings: src/shared/settings.py
- Logs: output/logs/global/, output/logs/ui/

Preflight Checklist:
- [ ] Read Architecture Overview, Class Hierarchy, and diagram
- [ ] Review finance/logging/scenarios specs and ADRs
- [ ] Confirm settings and entry points
- [ ] Identify required outputs and acceptance criteria
- [ ] Plan minimal, style-consistent changes and validation steps

Objectives:
- Model revenue, expenses, and policy effects.
- Integrate budget updates with simulation ticks.

Scope & Files:
- Primary: src/city/finance.py, src/city/city.py
- Related: docs/specs/finance.md, docs/specs/logging.md

Required Outputs:
- Budget update functions + tests.
- Log revenue/expenses per tick.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py
4) ./test.sh

Acceptance Criteria:
- Budget equation holds within floating‑point tolerance.
- Policies affect revenue/expenses predictably.

Deliver:
- Plan + edits
- Validation (tests/logs)
- Follow-up recommendations
```

## 04 – Population
```
You are an AI coding agent working on City‑Sim.

Focus: Population

Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Architecture Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/population.md, docs/specs/logging.md, docs/specs/scenarios.md
- ADRs: docs/adr/001-simulation-determinism.md
- Design Guide & Index: docs/design/readme.md, docs/design/workstreams/00-index.md
- Templates & Guides: docs/design/templates/*, docs/guides/*
- Models: docs/models/model.mdj
- Entry: run.py, src/main.py
- Settings: src/shared/settings.py
- Logs: output/logs/global/, output/logs/ui/

Preflight Checklist:
- [ ] Read Architecture Overview, Class Hierarchy, and diagram
- [ ] Review population/logging/scenarios specs and ADRs
- [ ] Confirm settings and entry points
- [ ] Identify required outputs and acceptance criteria
- [ ] Plan minimal, style-consistent changes and validation steps

Objectives:
- Implement population growth/decline and happiness/migration.
- Produce stable, deterministic metrics.

Scope & Files:
- Primary: population + happiness tracker modules
- Related: docs/specs/population.md, docs/specs/logging.md

Required Outputs:
- Logged population/happiness metrics per tick.
- Tests validating baseline trends.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py
4) ./test.sh

Acceptance Criteria:
- Metrics deterministic with fixed seed.
- Expected trends confirmed in scenarios.

Deliver:
- Plan + edits
- Validation (tests/logs)
- Follow-up recommendations
```

## 05 – UI
```
You are an AI coding agent working on City‑Sim.

Focus: UI

Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Architecture Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/logging.md, docs/specs/scenarios.md
- ADRs: docs/adr/001-simulation-determinism.md
- Design Guide & Index: docs/design/readme.md, docs/design/workstreams/00-index.md
- Templates & Guides: docs/design/templates/*, docs/guides/*
- Models: docs/models/model.mdj
- Entry: run.py, src/main.py
- Settings: src/shared/settings.py
- Logs: output/logs/global/, output/logs/ui/

Preflight Checklist:
- [ ] Read Architecture Overview, Class Hierarchy, and diagram
- [ ] Review logging/specs as relevant
- [ ] Confirm settings and entry points
- [ ] Identify required outputs and acceptance criteria
- [ ] Plan minimal, style-consistent changes and validation steps

Objectives:
- Improve CLI output and run summaries.
- Prepare future UI generation pipeline.

Scope & Files:
- Primary: run.py, src/main.py
- Related: docs/architecture/overview.md

Required Outputs:
- Clear CLI messages; scenario reports.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py

Acceptance Criteria:
- Users can run scenarios and see summarized results.

Deliver:
- Plan + edits
- Validation (CLI outputs)
- Follow-up recommendations
```

## 06 – Data & Logging
```
You are an AI coding agent working on City‑Sim.

Focus: Data & Logging

Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Architecture Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/logging.md, docs/specs/scenarios.md
- ADRs: docs/adr/001-simulation-determinism.md
- Design Guide & Index: docs/design/readme.md, docs/design/workstreams/00-index.md
- Templates & Guides: docs/design/templates/*, docs/guides/*
- Models: docs/models/model.mdj
- Entry: run.py, src/main.py
- Settings: src/shared/settings.py
- Logs: output/logs/global/, output/logs/ui/

Preflight Checklist:
- [ ] Read Architecture Overview, Class Hierarchy, and diagram
- [ ] Review logging/specs and ADRs
- [ ] Confirm settings and entry points
- [ ] Identify required outputs and acceptance criteria
- [ ] Plan minimal, style-consistent changes and validation steps

Objectives:
- Define structured logs and KPIs.
- Ensure reproducible, machine‑readable outputs.

Scope & Files:
- Instrumentation points across simulation and city modules.
- Schema per docs/specs/logging.md

Required Outputs:
- Log schema, samples, and optional dashboard (markdown/CSV).

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py

Acceptance Criteria:
- Consistent, machine‑readable logs with required fields.

Deliver:
- Plan + edits
- Validation (log samples)
- Follow-up recommendations
```

## 07 – Testing & CI
```
You are an AI coding agent working on City‑Sim.

Focus: Testing & CI

Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Architecture Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/*
- ADRs: docs/adr/*
- Design Guide & Index: docs/design/readme.md, docs/design/workstreams/00-index.md
- Templates & Guides: docs/design/templates/*, docs/guides/*
- Models: docs/models/model.mdj
- Entry: run.py, src/main.py
- Settings: src/shared/settings.py
- Logs: output/logs/global/, output/logs/ui/
- Tests & Config: tests/, pyrightconfig.json

Preflight Checklist:
- [ ] Read Architecture Overview, Class Hierarchy, and diagram
- [ ] Review relevant specs and ADRs
- [ ] Confirm settings and entry points
- [ ] Identify required outputs and acceptance criteria
- [ ] Plan minimal, style-consistent changes and validation steps

Objectives:
- Add unit/integration tests; improve static analysis.
- Ensure stable CI pipeline.

Scope & Files:
- Primary: tests/
- Related: key modules under src/

Required Outputs:
- Test suites for sim/city/finance/population/transport.
- Optional CI instructions.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) ./test.sh

Acceptance Criteria:
- Tests green with meaningful coverage.

Deliver:
- Plan + edits
- Validation (test results)
- Follow-up recommendations
```

## 08 – Performance
```
You are an AI coding agent working on City‑Sim.

Focus: Performance

Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Architecture Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/simulation.md, docs/specs/city.md, docs/specs/logging.md
- ADRs: docs/adr/001-simulation-determinism.md
- Design Guide & Index: docs/design/readme.md, docs/design/workstreams/00-index.md
- Templates & Guides: docs/design/templates/*, docs/guides/*
- Models: docs/models/model.mdj
- Entry: run.py, src/main.py
- Settings: src/shared/settings.py
- Logs: output/logs/global/, output/logs/ui/

Preflight Checklist:
- [ ] Read Architecture Overview, Class Hierarchy, and diagram
- [ ] Review simulation/city/logging specs and ADR
- [ ] Confirm settings and entry points
- [ ] Identify required outputs and acceptance criteria
- [ ] Plan minimal, style-consistent changes and validation steps

Objectives:
- Profile and optimize hotspots without breaking determinism.

Scope & Files:
- Primary: simulation core; targeted city modules

Required Outputs:
- Profiling reports; optimization notes; minimal code changes.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py

Acceptance Criteria:
- Demonstrated latency improvements; no correctness regressions.

Deliver:
- Plan + edits
- Validation (profiling data)
- Follow-up recommendations
```

## 09 – Roadmap
```
You are an AI coding agent working on City‑Sim.

Focus: Roadmap

Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Architecture Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/*, docs/specs/scenarios.md
- ADRs: docs/adr/*
- Design Guide & Index: docs/design/readme.md, docs/design/workstreams/00-index.md
- Templates & Guides: docs/design/templates/*, docs/guides/*
- Models: docs/models/model.mdj
- Entry: run.py, src/main.py
- Settings: src/shared/settings.py
- Logs: output/logs/global/, output/logs/ui/

Preflight Checklist:
- [ ] Read Architecture Overview, Class Hierarchy, and diagram
- [ ] Review specs, scenarios, and ADRs
- [ ] Confirm settings and entry points
- [ ] Identify required outputs and acceptance criteria
- [ ] Plan minimal, style-consistent changes and validation steps

Objectives:
- Plan features and dependencies across workstreams.

Scope & Files:
- Documentation only; update design/workstreams and specs if needed

Required Outputs:
- Milestone list, timelines, dependency mapping.

Acceptance Criteria:
- Clear, achievable milestones with defined dependencies.

Deliver:
- Plan + milestones
- Dependencies map
- Follow-up recommendations
```

## 10 – Transport & Traffic
```
You are an AI coding agent working on City‑Sim.

Focus: Transport & Traffic

Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Architecture Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/traffic.md, docs/specs/logging.md, docs/specs/scenarios.md
- ADRs: docs/adr/*
- Design Guide & Index: docs/design/readme.md, docs/design/workstreams/00-index.md
- Templates & Guides: docs/design/templates/*, docs/guides/*
- Models: docs/models/model.mdj
- Entry: run.py, src/main.py
- Settings: src/shared/settings.py
- Logs: output/logs/global/, output/logs/ui/

Preflight Checklist:
- [ ] Read Architecture Overview, Class Hierarchy, and diagram
- [ ] Review traffic/logging/scenarios specs and ADRs
- [ ] Confirm settings and entry points
- [ ] Identify required outputs and acceptance criteria
- [ ] Plan minimal, style-consistent changes and validation steps

Objectives:
- Implement transport network primitives and A* pathfinding.
- Simulate city & highway traffic (signals, ramp metering, controllers).
- Log traffic metrics: avg_speed, congestion_index, throughput.

Scope & Files:
- New Transport subsystem modules under src/
- Integrate with City infrastructure state and simulation core

Required Outputs:
- Transport subsystem code/docs; tests for pathfinding/signals.
- Logs populated with traffic fields.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py
4) ./test.sh

Acceptance Criteria:
- Vehicles respect signals & speed limits and complete routes.
- A* finds feasible routes; re-routes under blockages/incidents.
- Deterministic metrics under fixed seeds.

Deliver:
- Plan + exact edits
- Validation notes (logs/tests)
- Follow-up recommendations
```
