# Workstream Prompt Template

Copy, adapt, and paste this into your AI assistant to run a focused workstream task.

```
You are an AI coding agent working on the City‑Sim project. Operate in documentation-first mode: plan precisely, update only the relevant files, and validate via quick runs/tests when applicable.

Global Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Architecture Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/*
- ADRs: docs/adr/*
- Workstreams Index: docs/design/workstreams/00-index.md
- Templates: docs/design/templates/*
- Guides: docs/guides/*
- Models: docs/models/model.mdj
- Entry: run.py, src/main.py
- Settings: src/shared/settings.py
- Logs: output/logs/global/, output/logs/ui/

Workstream: <NAME>
Objectives:
- <bullet points>

Scope & Files:
- Primary: <list source files>
- Related specs/docs: <list spec links>

Required Outputs:
- Code or doc changes: <list files to be updated>
- Logs/metrics (if runtime-related)
- Tests (if applicable)

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py
4) ./test.sh

Acceptance Criteria:
- <determinism, metrics, correctness, style>

Checkpoints:
- <milestone 1>
- <milestone 2>

Constraints:
- Minimal changes, keep API stable unless spec says otherwise
- Structured logs preferred; preserve reproducibility

Deliver:
- A concise plan and exact edits
- Validation notes (run outputs/tests)
- Short follow-up recommendations
```
