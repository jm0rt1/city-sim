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

## Copy‑Paste Prompt
```
You are an AI coding agent working on City‑Sim, focusing on the Finance workstream.

Objectives:
- Model revenue streams, expenses, and policies.
- Ensure budget updates integrate with simulation ticks.

Scope & Files:
- Primary: src/city/finance.py, src/city/city.py
- Specs: docs/specs/finance.md, docs/architecture/overview.md

Required Outputs:
- Budget update functions with tests.
- Metrics in logs for revenues/expenses per tick.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py
4) ./test.sh

Acceptance Criteria:
- Budget reconciles each tick within tolerance.
- Policies have predictable effects.

Deliver:
- Plan + edits
- Validation (tests/logs)
- Follow-up recommendations
```
