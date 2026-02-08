# AI Coordination Spec — city-sim (early documentation)

Purpose
- Provide a machine-readable, human-friendly spec that instructs multiple specialized AIs what to do and what not to do.
- Act as the canonical source for generating further documentation, tasks, and small implementation units for the Python + pygame city simulation.

Principles
- Small, testable increments.
- Single responsibility per AI role.
- Repeatable, auditable outputs (files, tests, docs).
- Safety: no secrets, no destructive operations on unrelated files, no publishing without review.

How to use this file
- Every generated instruction set must include: title, goal, inputs, outputs, acceptance criteria, files to change, and constraints (what not to do).
- Each AI should produce a one-file or one-PR-sized change with tests and docs whenever possible.

Roles and responsibilities
- AI-Designer
    - Do: produce game design specs (systems, entities, interactions), simulation rules and realism targets.
    - Outputs: markdown design docs, diagrams (optional), lists of required data/assets.
    - Not do: implement code, change codebase directly, presume asset formats beyond those requested.

- AI-Developer
    - Do: implement small, well-documented Python modules, unit tests, and simple pygame prototypes.
    - Outputs: .py files with type hints, docstrings, pytest tests, minimal assets if needed.
    - Not do: write large monolithic features in one PR, commit compiled/binary assets, or bypass code review.

- AI-Artist
    - Do: propose and export placeholder assets (SVG/PNG with source), spritesheets with metadata.
    - Outputs: assets in assets/ with README and licensing notes.
    - Not do: include copyrighted third-party assets or large high-res files.

- AI-Tester
    - Do: design unit/integration tests, playtest checklists, and automated smoke tests for the pygame loop.
    - Outputs: pytest tests, CI job snippets, deterministic test seeds.
    - Not do: create flaky tests or require headful/manual-only verification.

- AI-Integrator
    - Do: create PRs that wire modules, update top-level docs, and ensure CI passes.
    - Outputs: PR descriptions, changelogs, migration notes.
    - Not do: merge to master without passing tests and review.

- AI-DocWriter
    - Do: expand docs from code and design: tutorials, API references, developer guides.
    - Outputs: markdown files under docs/, README updates, doc metadata.
    - Not do: assume undocumented behavior or change code.

Communication protocol
- Each task must be a single markdown file fragment (or a PR) that includes:
    - Title
    - Short goal (1–2 sentences)
    - Inputs (files, data, assets)
    - Outputs (files to add/modify)
    - Acceptance criteria (tests, performance targets)
    - Files/lines to edit (explicit paths)
    - Constraints / do-not-do list
    - Estimated complexity (tiny/small/medium)
- Use branch per task: task/<short-name>.
- Commit messages: "<role>: <short description> (#issue-or-task-id)"
- Create PR with description and link to this spec section.

Coding standards and environment
- Python 3.11+ idioms, type hints, minimal dependencies.
- Use pytest, black, isort, flake8/ruff.
- Pygame usage: structure game loop to allow headless testing (separate update/render).
- Assets under assets/ with README and license info.
- No secrets or external keys in repo.

Testing & acceptance
- Unit tests for logic, smoke tests for game loop (headless or with SDL dummy).
- Acceptance: tests pass, linter OK, basic pygame window can open in local manual test, README updated.

Performance & realism targets (early)
- Deterministic simulation seed for reproducible runs.
- Target: prototype with up to 200 simulated agents at 30 FPS on modern desktop; profile and document bottlenecks.
- Not do: premature optimization. Focus on correct, testable logic first.

Versioning and releases
- Semantic versioning on tagged releases.
- Small iterative releases: each PR that implements a feature increments minor or patch.

How to generate further instructions (meta-instruction template)
- When any AI must ask other AIs to act, produce a markdown file containing:
    - Metadata header: role, author-AI, date, related-task-id.
    - Title and 1-sentence summary.
    - "Do" list: explicit tasks and deliverables (file paths, function names).
    - "Don't" list: explicit forbidden actions.
    - Acceptance criteria: exact tests/outputs that must pass.
    - Dependencies: other tasks or assets required.
    - Suggested branch name and PR title.
    - Example: minimal sample file content or test assertion.
- Example minimal template (must be filled each time):
    - Title: Implement X
    - Goal: ...
    - Inputs: ...
    - Outputs: ...
    - Acceptance: list of pytest asserts or command lines
    - Not: list of forbidden changes
    - Branch: task/<x>
    - PR title: "<Role>: Implement X (#id)"

Review and iteration loop
- Plan (Designer) -> Implement (Developer) -> Test (Tester) -> Doc (DocWriter) -> Integrate (Integrator).
- Each loop ends with a PR and at least one human or AI reviewer.
- If tests fail, produce a focused bug task using the same template.

Safety and repository rules (do not)
- Do not modify unrelated files outside the specified paths.
- Do not push secrets or credentials.
- Do not merge to master without passing CI and approvals.
- Do not generate or include copyrighted third-party content without license.

Next tasks (recommended starters)
- Create task/design-city-entities.md: list core entities (building, road, vehicle, citizen) with properties and behavior.
- Create task/code-init-game-loop.md: prototype headless-friendly pygame loop and tests.
- Create task/doc-development-guidelines.md: expand coding and commit conventions.

Minimal acceptance for this file
- This file must live at docs/ai_dev/readme.md and include the template for future AI-generated instructions.

If uncertain
- Produce the smallest changeable artifact (one markdown file, one test, or one small function) and request review.

End.