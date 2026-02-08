# Workstream: Testing & CI

## Objectives
- Add unit/integration tests and static analysis.
- Ensure stable CI pipeline.

## Scope
- Tests: [tests/](../../tests/)
- Config: [pyrightconfig.json](../../pyrightconfig.json)

## Inputs
- Existing minimal tests: [tests/core/test_dummy.py](../../tests/core/test_dummy.py)

## Outputs
- Test suites for major modules.
- CI instructions (optional).

## Run Steps
```bash
./init-venv.sh && pip install -r requirements.txt
./test.sh
```

## Task Backlog
- Unit tests for `sim.py`, `city.py`, `finance.py`, population.
- Static analysis improvements and type hints.

## Acceptance Criteria
- Tests green; meaningful coverage metrics.
