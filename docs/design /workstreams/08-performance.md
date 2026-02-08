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
