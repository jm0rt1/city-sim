# Workstream: Population

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
