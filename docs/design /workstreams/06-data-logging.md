# Workstream: Data & Logging

## Objectives
- Structure logs for reproducibility and analysis.
- Add metrics for key KPIs.

## Scope
- Logs: [output/logs/global/](../../output/logs/global/), [output/logs/ui/](../../output/logs/ui/)
- Files: instrumentation points across simulation and city modules

## Inputs
- Settings: [src/shared/settings.py](../../src/shared/settings.py)

## Outputs
- Log schema and sample outputs.
- Metrics dashboard (markdown or simple CSVs).

## Run Steps
```bash
./init-venv.sh && pip install -r requirements.txt
python3 run.py
```

## Task Backlog
- Define structured log format (JSONL or CSV).
- Add KPIs: tick duration, budget, population, happiness.
- Write a README explaining log interpretation.

## Acceptance Criteria
- Logs machine‑readable and consistent across runs.
