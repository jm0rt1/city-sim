# Workstream: Simulation Core

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