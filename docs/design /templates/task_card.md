# Task Card Template

Use this template to define AI‑executable tasks. Keep scope tight and acceptance criteria clear.

## Title
Concise task name

## Context
- Related modules/files: link to sources, e.g., [src/simulation/sim.py](../../src/simulation/sim.py)
- Brief description of current behavior and desired change

## Objectives
- What should be achieved in this task

## Inputs
- Code files to edit
- Config values (e.g., [src/shared/settings.py](../../src/shared/settings.py))
- Test data or scenarios

## Outputs
- Code changes (list the files)
- Updated docs (if any)
- Tests added/updated

## Run Steps
```bash
# Setup
./init-venv.sh && pip install -r requirements.txt

# Run sim or tests
python3 run.py
./test.sh
```

## Acceptance Criteria
- Deterministic outcome where applicable
- Unit/integration tests pass
- Logs show expected metrics or messages
- Style consistent with the codebase; minimal changes

## Dependencies
- Other tasks/specs this depends on

## Checkpoints
- Small verifiable milestones (commit granularity)

## Risks
- Potential side effects and mitigations
