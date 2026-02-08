# Workstream: Finance

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
