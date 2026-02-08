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

## Copy‑Paste Prompt
```
You are an AI coding agent working on City‑Sim, focusing on the Data & Logging workstream.

Objectives:
- Structure logs for reproducibility and analysis.
- Add metrics for key KPIs.

Scope & Files:
- Logs: output/logs/global/, output/logs/ui/
- Instrumentation: simulation and city modules
- Specs: docs/specs/logging.md, docs/architecture/overview.md

Required Outputs:
- Log schema and sample outputs.
- Metrics dashboard (markdown or CSV).

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py

Acceptance Criteria:
- Machine‑readable logs populated for all ticks.

Deliver:
- Plan + edits
- Validation (log samples)
- Follow-up recommendations
```
