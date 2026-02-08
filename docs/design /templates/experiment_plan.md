# Experiment Plan Template

Use to evaluate algorithmic options or parameter tuning.

## Hypothesis
- What you expect to observe and why

## Experimental Setup
- Scenario configuration (link to settings: [src/shared/settings.py](../../src/shared/settings.py))
- Simulation parameters and seeds

## Metrics
- KPIs, counters, and qualitative observations
- Log paths: [output/logs/global/](../../output/logs/global/)

## Procedure
```bash
./init-venv.sh
pip install -r requirements.txt
python3 run.py
```

## Results
- Tables/plots, representative logs

## Analysis
- Interpretation and trade-offs

## Decision
- Adopt, refine, or reject; next steps
