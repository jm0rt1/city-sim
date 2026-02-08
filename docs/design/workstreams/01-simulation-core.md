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

## Copy‑Paste Prompt
```
You are an AI coding agent working on City‑Sim, focusing on the Simulation Core workstream.

Objectives:
- Ensure deterministic tick loop and reproducible scenarios.
- Establish scenario runner with seed control and logging.
- Validate update cycle performance and correctness.

Scope & Files:
- Primary: src/simulation/sim.py, src/shared/settings.py, src/main.py, run.py
- Specs: docs/specs/simulation.md, docs/architecture/overview.md

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