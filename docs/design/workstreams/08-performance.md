# Workstream: Performance

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
You are an AI coding agent working on City‑Sim, focusing on the Performance workstream.

Objectives:
- Profile simulation and optimize hotspots.

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
