# Workstream: Roadmap

## Objectives
- Plan features and coordinate dependencies.

## Scope
- All modules; milestone planning across workstreams

## Inputs
- Requirements and feedback from other workstreams

## Outputs
- Milestone list and timelines

## Backlog (Initial)
- M1: Deterministic simulation and baseline metrics
- M2: Finance + Population models validated
- M3: UI improvements and richer logging
- M4: Performance pass and expanded tests

## Acceptance Criteria
- Clear, achievable milestones with defined dependencies.

## Copy‑Paste Prompt
```
You are an AI coding agent working on City‑Sim, focusing on the Roadmap workstream.

Objectives:
- Plan features and coordinate dependencies across workstreams.

Scope & Files:
- All modules; docs in docs/specs/* and docs/architecture/*

Required Outputs:
- Milestone list and timelines; cross‑workstream dependencies.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py (optional, for validation context)

Acceptance Criteria:
- Clear, achievable milestones with defined dependencies.

Deliver:
- Plan + milestones
- Dependencies map
- Follow-up recommendations
```
