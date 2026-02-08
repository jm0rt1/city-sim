# Workstream: Roadmap

## Reading Checklist
- Architecture Overview: [../../architecture/overview.md](../../architecture/overview.md)
- Class Hierarchy: [../../architecture/class-hierarchy.md](../../architecture/class-hierarchy.md)
- Architecture Diagram: [../../architecture/city-sim-architecture.puml](../../architecture/city-sim-architecture.puml)
- Specs: [../../specs](../../specs) (simulation, city, finance, population, logging, traffic, scenarios)
- ADRs: [../../adr](../../adr)
- Design Guide: [../readme.md](../readme.md)
- Consolidated Prompts: [../prompts.md](../prompts.md)
- Templates: [../templates/](../templates/)
- Guides: [../../guides/](../../guides/)
- Models: [../../models/model.mdj](../../models/model.mdj)

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

Global Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/*, docs/specs/scenarios.md
- ADRs: docs/adr/*
- Guides: docs/guides/contributing.md, docs/guides/glossary.md
- Workstreams Index: docs/design/workstreams/00-index.md

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
