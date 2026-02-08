# Workstream: City Modeling

## Objectives
- Clarify `City` state model and transitions.
- Define decision effects and invariants.
- Ensure `CityManager` operations are consistent and testable.

## Scope
- Files: [src/city/city.py](../../src/city/city.py), [src/city/city_manager.py](../../src/city/city_manager.py), [src/city/decisions.py](../../src/city/decisions.py)

## Inputs
- Settings: [src/shared/settings.py](../../src/shared/settings.py)
- Upstream: Simulation tick calls into city updates.

## Outputs
- Updated docs and diagrams (optional).
- Tests validating invariants and transitions.

## Run Steps
```bash
./init-venv.sh && pip install -r requirements.txt
python3 run.py
```

## Task Backlog
- Document core `City` attributes and lifecycle.
- Map decisions to state changes with acceptance criteria.
- Add transition tests for common policies.

## Acceptance Criteria
- Decisions produce expected state deltas under standard scenarios.
- Invariants documented (e.g., non‑negative budgets if required) and tested.

## Checkpoints
- Invariant list merged; baseline tests in place.

## Copy‑Paste Prompt
```
You are an AI coding agent working on City‑Sim, focusing on the City Modeling workstream.

Objectives:
- Clarify City state model and transitions.
- Define decision effects and invariants.
- Ensure CityManager operations are consistent and testable.

Scope & Files:
- Primary: src/city/city.py, src/city/city_manager.py, src/city/decisions.py
- Specs: docs/specs/city.md, docs/architecture/overview.md

Required Outputs:
- Docs clarifying attributes/invariants; code updates if needed.
- Transition tests for common policies.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py
4) ./test.sh

Acceptance Criteria:
- Decisions produce expected state deltas.
- Invariants documented and covered by tests.

Checkpoints:
- Invariant list merged; baseline tests in place.

Deliver:
- Plan + edits
- Validation (tests/logs)
- Follow-up recommendations
```
