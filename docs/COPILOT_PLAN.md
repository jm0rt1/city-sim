# Devflow Multi-Agent Implementation Plan

This document packages the design white paper into actionable, parallelizable tracks that can be handed to multiple GitHub Copilot agents. Each track produces mergeable, testable increments that converge into a usable `devflow` CLI. The goal is to preserve as much fidelity to the original design spec as possible while enabling fast, concurrent implementation. **without agents re-implementing each other’s work**.

## Reference Pointers for Agents (Do Not Skip)
- Read the “Design White Paper” (`docs/DESIGN_SPEC.md`); the plan below maps directly to FR/NFR/UX requirements called out there.
- Use Typer for CLI scaffolding, Pydantic (or dataclasses) for config schema, TOML parsing via `tomllib`/`tomli`.
- Preserve the default config surface proposed in the white paper (e.g., `venv_dir`, `default_python`, `build_backend`, `test_runner`, `paths`, `publish`, `deps`, `tasks`).
- Respect global flags everywhere: `--config`, `--project-root`, `--dry-run`, `--verbose/-v`, `--quiet/-q`, `--version`.
- All subprocesses must be executed with explicit arg lists (`shell=False`), and all commands must honor `--dry-run` and verbosity.

## Guardrails to Avoid Overlap
- **Single ownership per shared artifact.** Do not redefine shared types or helpers; extend them or request changes from the owning stream.
- **No parallel rewrites of `AppContext`, config schema, logging, subprocess wrappers, or task engine.** These belong to one stream each (see Ownership Map).
- **Use extension points.** If you need fields or hooks owned by another stream, add a TODO/commented stub and coordinate—do not fork the module.
- **Limit touch surface.** Each stream should change only the directories/files listed for it. Utility changes outside your area must go through the owning stream.
- **Prefer additive PRs.** Avoid refactors that move or rename shared modules while other streams are active.

## Ownership Map (Source of Truth)
- **App bootstrap & config schema:** Workstream A owns `devflow/app.py`, `devflow/config/*`, `devflow/core/logging.py` (if created), and version/flag plumbing. Others import, do not redefine.
- **Command registry & task engine:** Workstream B owns `devflow/commands/base.py`, task/pipeline execution, and registry wiring. Others register commands using provided APIs only.
- **Venv/deps helpers:** Workstream C owns `devflow/commands/venv.py`, `devflow/commands/deps.py`, and any venv/path helpers in `devflow/core/*` they introduce. Others call these helpers instead of reimplementing env handling.
- **Test/build/publish commands:** Workstream D owns `devflow/commands/test.py`, `build.py`, `publish.py`, and upload/build helpers.
- **Git integration:** Workstream E owns `devflow/commands/gitops.py` and any git helper modules.
- **Plugins:** Workstream F owns `devflow/plugins/*` and plugin interfaces.
- **UX/help/completion/docs:** Workstream G owns documentation, help text shape, completion generation, and user-facing messaging. They should not alter core logic.
- **CI/packaging:** Workstream H owns `pyproject.toml`, CI workflows, and release packaging defaults.

## Cross-Stream Traceability Matrix (Design Spec → Workstreams)
- FR1–FR3 (Unified CLI & custom tasks): primarily Workstreams A/B/G.
- FR4–FR6 (Configuration discovery & schema): Workstream A with tests; consumed by all others.
- FR7–FR10 (Venv/deps): Workstream C (depends on A/B helpers).
- FR11–FR13 (Test/build/publish): Workstream D (depends on A/B/C/E where relevant).
- FR14–FR15 (Git integration/versioning): Workstream E (consumed by D/G).
- FR16–FR17 (Plugins/extensibility): Workstream F (consumes A/B).
- NFRs/UX (logging, help, portability, completion): Workstreams B/G with shared helpers from A.
- Evidence strategy & CI matrix: Workstream H.

## Operating Principles for All Agents
- Keep logic Python-native—no shell-specific assumptions.
- Prefer Typer for CLI ergonomics (subcommands, help, completion).
- Centralize configuration under `[tool.devflow]` in `pyproject.toml`, with `devflow.toml` fallback.
- Use structured logging with verbosity flags and a `--dry-run` switch respected by every command.
- Ensure task execution uses explicit argument lists for subprocesses (no shell=True).
- Provide unit tests for new modules and integration tests for user-visible flows.
- If you need a change in someone else’s owned module, leave a TODO and a short note in your PR description; do not implement it yourself.

## Workstream A: Project Bootstrap & App Context (Owner: core config/app)
- Create package layout (`devflow/cli.py`, `app.py`, `config/`, `commands/`, `core/`, `plugins/`, `tests/`) matching the proposed tree.
- Implement project-root detection walking upward until `pyproject.toml` or `devflow.toml` is found; expose override via `--project-root`.
- Implement configuration discovery order: explicit `--config`, `[tool.devflow]` in `pyproject.toml`, `devflow.toml`, user-level default (placeholder hook), then built-in defaults.
- Define typed config schema mirroring the sample TOML: `venv_dir`, `default_python`, `build_backend`, `test_runner`, `package_index`, `[paths]`, `[publish]`, `[deps]`, `[tasks.*]`, pipelines vs single tasks, and boolean flags (`auto_discover_tasks`, `tag_on_publish`, `require_clean_working_tree`, etc.).
- Provide config validation tests and root-detection tests; include default-merging tests that show project overrides taking precedence.
- Deliver `AppContext` encapsulating project root, loaded config, logger, verbosity, dry-run flag, and command registry. Ensure the `__version__` flag prints package version per the design.
- Output: runnable `devflow --help` stub listing top-level commands (even if not fully implemented yet) with placeholder handlers.
- **Ownership boundary:** Other streams import `AppContext` and config models; they must not redefine them. Any schema changes should be coordinated here.

## Workstream B: Command Framework & Task Engine (Owner: task/registry)
- Define `Command` base (name/help/run) and registry to map string names to handler classes; integrate with Typer command factory.
- Implement `Task`/`Pipeline` abstractions matching the spec: per-task `use_venv`, env overrides, argument lists, sequencing, and exit code propagation. Support composite `pipeline` tasks and single-command tasks as shown in config examples.
- Provide executor-level logging with phase prefixes (e.g., `[test]`, `[build]`), honor `--dry-run`, verbosity levels (`-q`, `-v`, `-vv`), and consistent non-zero exit code propagation.
- Add `devflow task <name>` to execute custom tasks from config; include clear error messaging for missing tasks and recursive pipeline expansion with cycle detection.
- Output: unit tests covering pipeline expansion, dry-run behavior, env propagation, and exit-code short-circuiting; short “how to define tasks” section in docs.
- **Ownership boundary:** Only this stream defines `Command` base/registry and task execution semantics. Other streams register commands through provided hooks and must not reimplement dispatch or pipeline logic.

## Workstream C: Venv & Dependency Management (Owner: venv/deps helpers)
- Implement `devflow venv init` honoring `default_python`, `venv_dir`, `--python`, and `--recreate`; ensure idempotent creation with clear logs.
- Implement venv-aware command runner helpers (used by other streams) to ensure subprocesses execute inside the configured venv; expose path helpers in `core/paths.py`.
- Implement `devflow deps sync` to install from `requirements.txt`/`pyproject`/`requirements-*.txt` according to config; allow optional extras/groups hooks even if stubbed.
- Implement `devflow deps freeze` writing to configured `freeze_output` path; ensure deterministic ordering and include dry-run preview.
- Output: integration tests with temp projects validating venv creation, sync, freeze output, and path resolution on Linux/macOS/WSL Git Bash where feasible.
- **Ownership boundary:** Other streams call venv/deps helpers rather than spawning their own env logic. Coordinate any needed helper changes with this stream.

## Workstream D: Test, Build, and Publish Commands (Owner: test/build/publish commands)
- Implement `devflow test` with pass-through args to configured runner (`pytest` default; allow `unittest`, `tox`, etc.) and venv enforcement; expose common flags (`--pattern`, `--marker`, `--cov`) pass-through.
- Implement `devflow build` defaulting to `python -m build` with configurable backend (`hatchling`, `poetry-build`, etc.) and configurable dist directory cleanup behavior.
- Implement `devflow publish` pipeline respecting config flags: require clean working tree (unless `--allow-dirty`), optional pre-tests, build artifacts, upload via `twine` (repository configurable), optional signing, and tag creation following `tag_format`. Add `--dry-run` to show would-be actions.
- Output: integration tests covering happy-path, failing test/build/upload, tag formatting, and dry-run behavior that does not perform network operations.
- **Ownership boundary:** This stream plugs into task engine and venv/git helpers; it must not redefine config models, task execution, or git helpers.

## Workstream E: Git Integration & Safety Rails (Owner: git helpers)
- Implement git helper module for status checks, tag existence/creation, and version reporting (e.g., from `setuptools_scm` or config fallback) aligned with FR14–FR15.
- Support config flags: `require_clean_working_tree`, `tag_on_publish`, `tag_format`, `tag_prefix`, and optional `version_source`. Provide clear error messages when the working tree is dirty.
- Add reusable pre-flight checks for publish and optional CI guardrails; consider `devflow git status`/`devflow version` utility commands if feasible.
- Output: tests using temp git repos to validate blocking behavior, tag formatting, idempotent tagging, and version surfacing.
- **Ownership boundary:** Other streams call git helpers; they should not shell out to git directly or recreate cleanliness checks.

## Workstream F: Plugins & Extensibility (Owner: plugin interfaces)
- Define plugin discovery via entry points (e.g., `devflow.plugins`) and/or config-provided module paths; allow registration of new commands/tasks at startup.
- Specify a minimal plugin interface (e.g., `register(registry: CommandRegistry, app: AppContext)`) and document lifecycle expectations.
- Provide a sample plugin under `tests/fixtures/plugins` that adds a trivial command/task; ensure help text and execution integrate seamlessly with global flags.
- Output: tests verifying plugin discovery, registration, precedence rules, and failure isolation (bad plugin should not crash core).
- **Ownership boundary:** Plugin interface is defined here; other streams should consume it but not change its shape without coordination.

## Workstream G: UX, Completion, and Documentation (Owner: UX/docs)
- Implement `devflow completion <shell>` generation (bash/zsh/fish) and document usage (`eval "$(devflow completion zsh)"`).
- Ensure `devflow` with no args lists available commands and project-specific tasks (discoverable UX per R-CLI2).
- Enrich help text with examples reflecting config patterns from the design (custom tasks, pipelines, publish dry-run, venv init options).
- Maintain a Quickstart section mirroring the sample TOML from the design white paper and a troubleshooting section for portability issues (macOS/Linux/WSL).
- Output: documentation updates plus snapshot/CLI help tests as feasible.
- **Ownership boundary:** This stream edits docs and help/UX strings but should not modify command semantics or core logic.

## Workstream H: CI, Packaging, and Evidence (Owner: CI/packaging)
- Add `pyproject.toml` with console_scripts entry for `devflow`, runtime deps (typer, pydantic, tomli/tomllib backport if needed), and dev extras (pytest, ruff, build, twine for tests).
- Set up CI workflow: lint (ruff), type-check (if enabled), unit + integration tests. Plan matrix for `ubuntu-latest`, `macos-latest`, `windows-latest` (Git Bash/WSL) per portability NFRs.
- Encode acceptance tests mirroring the scenarios in the white paper (venv/test/build/publish dry-run, ci-check pipeline, git cleanliness failure) and capture logs/artifacts for evidence.
- Output: CI config plus baseline badges/README pointers; ensure deterministic exit codes and log snapshots for regressions.
- **Ownership boundary:** This stream owns packaging and CI configuration; others should not modify CI/workflow files without alignment.

## Coordination Checklist
- Establish shared config schema file (`config/schema.py`) and defaults to avoid drift; every workstream consumes the same models.
- Align on logging format, verbosity flags, phase prefixing, and dry-run semantics early; reuse across commands and tests.
- Favor small, mergeable PRs per workstream; keep integration tests green and avoid overlapping edits to schema or core helpers without coordination.
- Cross-reference acceptance scenarios from the design white paper and update this plan as evidence accumulates.

## Ready-to-Send Prompts for GitHub Copilot Agents

Use these copy/paste prompts to spin up multiple Copilot agents in parallel. Each prompt already references the in-repo design spec and this plan so agents stay aligned.

### Rapid fan-out options (to avoid prompting one-by-one)
- **One-shot per agent:** Send the combined prompt for each workstream below; it includes the global setup plus the stream scope so you only paste once per agent.
- **Broadcast start + scoped follow-up:** Paste the global setup prompt into multiple agents at once (or your shared channel), then paste only the single-line “scope reminder” bullets per agent. This cuts down on repeated long prompts.
- **Use the scope table as a checklist:** Assign agents A–H, paste the matching combined prompt, and tick the box in your tracker; do not mix scopes between agents.
- **If you need to re-prompt** (agent drift/refresh), resend only the combined prompt for that workstream—skip the global setup unless the agent lost context.

**Global setup prompt (send to every agent before workstream specifics):**
"""
You are implementing the Python CLI tool "devflow." Read docs/DESIGN_SPEC.md and docs/COPILOT_PLAN.md for requirements, scope, and conventions. Honor global flags (`--config`, `--project-root`, `--dry-run`, `--verbose/-v`, `--quiet/-q`, `--version`) and keep all subprocess calls shell=False with explicit arg lists. Favor Typer for CLI, Pydantic/dataclasses for config, tomllib/tomli for TOML parsing. Preserve the config surface in the design spec (venv_dir, default_python, build_backend, test_runner, paths, publish, deps, tasks, pipelines). Use structured logging with verbosity and dry-run support. Write unit/integration tests where described.

Guardrails:
- Do not redefine `AppContext`, config schema, task engine, or logging helpers—import the owner’s implementation.
- Stay within your workstream’s ownership boundaries; if you need changes elsewhere, note a TODO and describe it in your PR instead of implementing it.
- Keep your PR additive and minimal-touch outside owned files. Avoid refactors that move shared code.
"""

**Workstream A (Bootstrap & App Context):**
"""
Implement project bootstrap per docs/COPILOT_PLAN.md Workstream A. Deliver package layout, project-root detection, config discovery/merging order, typed schema matching the sample TOML, and AppContext. Provide tests for root detection, config parsing, and default override behavior. Ensure `devflow --help` shows stub commands.

Ownership reminder: you own config/app/logging primitives. Expose stable APIs for other streams; they must import yours rather than redefining them.
"""

**Workstream B (Command Framework & Task Engine):**
"""
Follow Workstream B in docs/COPILOT_PLAN.md. Build Command base/registry integrated with Typer, Task/Pipeline abstractions with dry-run, verbosity, env propagation, and exit-code short-circuiting. Implement `devflow task <name>` with pipeline expansion and cycle detection. Add unit tests for pipelines, dry-run behavior, and error messaging.

Ownership reminder: you own the registry/task engine. Others must register commands using your hooks; do not edit config schemas or venv/git helpers.
"""

**Workstream C (Venv & Dependency Management):**
"""
Follow Workstream C in docs/COPILOT_PLAN.md. Implement venv helpers and `devflow venv init` honoring default_python, venv_dir, --python, --recreate. Add deps sync/freeze commands honoring config, deterministic freeze output, and dry-run previews. Add integration tests with temp projects for venv creation, sync, and freeze.

Ownership reminder: you own venv/deps helpers. Others should call these helpers; do not modify command registry or config schema beyond consuming it.
"""

**Workstream D (Test, Build, Publish):**
"""
Follow Workstream D in docs/COPILOT_PLAN.md. Implement `devflow test` (pass-through args, venv enforcement), `devflow build` (configurable backend, dist handling), and `devflow publish` (clean working tree check, optional pre-tests, build+upload via twine, signing, tagging per tag_format, --dry-run). Add integration tests for success/failure paths and dry-run behavior.

Ownership reminder: you own these commands only. Reuse registry, config models, venv helpers, and git helpers; do not recreate them.
"""

**Workstream E (Git Integration):**
"""
Implement Workstream E from docs/COPILOT_PLAN.md. Build git helpers for status checks, tag formatting/creation, version surfacing (setuptools_scm or config fallback). Wire require_clean_working_tree, tag_on_publish, tag_format/tag_prefix, version_source flags. Add tests using temp git repos for dirty-tree blocking and idempotent tagging.

Ownership reminder: you own git helpers only. Expose callable helpers for other commands; do not alter config schemas or task engine internals.
"""

**Workstream F (Plugins & Extensibility):**
"""
Implement Workstream F per docs/COPILOT_PLAN.md. Define plugin discovery via entry points/config module paths, plugin interface (e.g., register(registry, app)), and a sample plugin fixture adding a command/task. Ensure bad plugins fail gracefully. Add tests for discovery, registration, precedence, and isolation.

Ownership reminder: you own plugin interface/loader. Do not change core registry or config schema; build on what Workstreams A/B provide.
"""

**Workstream G (UX, Completion, Docs):**
"""
Implement Workstream G per docs/COPILOT_PLAN.md. Add `devflow completion <shell>` for bash/zsh/fish, ensure `devflow` with no args lists commands and project tasks, enrich help text with examples from the design spec, and maintain Quickstart/troubleshooting docs. Add snapshot/help tests where practical.

Ownership reminder: you own UX/docs/help strings. Do not modify core logic, registry, or config schema; reference existing commands and helpers instead.
"""

**Workstream H (CI, Packaging, Evidence):**
"""
Implement Workstream H per docs/COPILOT_PLAN.md. Create pyproject.toml with console_scripts entry, runtime/dev deps. Add CI workflow covering lint/type-check/tests; plan matrix for ubuntu/macos/windows Git Bash per portability NFRs. Encode acceptance scenarios (venv/test/build/publish dry-run, ci-check pipeline, dirty git blocking) and capture logs/artifacts for evidence.

Ownership reminder: you own packaging/CI. Avoid touching core logic unless required for packaging hooks; coordinate any such change explicitly.
"""

### Combined one-shot prompts (global setup + workstream scope in a single paste)
Copy the relevant block and send it once to the agent; no separate global prompt needed. These are intentionally compact but still include the guardrails.

**Workstream A (Bootstrap & App Context) – single message:**
"""
You are implementing the Python CLI tool "devflow." Read docs/DESIGN_SPEC.md and docs/COPILOT_PLAN.md. Honor global flags, shell=False subprocesses, Typer CLI, Pydantic/dataclasses config, tomllib/tomli parsing, and structured logging with verbosity + dry-run. Preserve the config surface (venv_dir, default_python, build_backend, test_runner, paths, publish, deps, tasks, pipelines). Guardrails: do not redefine AppContext/config/task engine/logging helpers; stay within your scope; additive changes only.

Task: Execute Workstream A. Deliver package layout, project-root detection with --project-root override, config discovery/merging order, typed schema matching sample TOML, AppContext with version/flags, and tests for root detection + config parsing/overrides. `devflow --help` should list stub commands. You own config/app/logging primitives; expose stable APIs for others.
"""

**Workstream B (Command Framework & Task Engine) – single message:**
"""
You are implementing the Python CLI tool "devflow." Read docs/DESIGN_SPEC.md and docs/COPILOT_PLAN.md. Honor global flags, shell=False subprocesses, Typer CLI, structured logging with verbosity + dry-run. Guardrails: import AppContext/config/logging from Workstream A; do not redefine them. Additive changes only.

Task: Execute Workstream B. Build Command base/registry integrated with Typer, Task/Pipeline abstractions with dry-run, verbosity, env propagation, exit-code short-circuiting. Implement `devflow task <name>` with pipeline expansion and cycle detection. Add unit tests for pipelines, dry-run, error messaging. You own registry/task engine semantics; others register commands via your hooks.
"""

**Workstream C (Venv & Dependency Management) – single message:**
"""
You are implementing the Python CLI tool "devflow." Read docs/DESIGN_SPEC.md and docs/COPILOT_PLAN.md. Honor global flags, shell=False subprocesses, Typer CLI, structured logging with verbosity + dry-run. Guardrails: use config/AppContext/registry from owners; do not reimplement them. Additive changes only.

Task: Execute Workstream C. Implement `devflow venv init` honoring default_python, venv_dir, --python, --recreate; add venv-aware command runner helpers and path helpers; implement `devflow deps sync` and `devflow deps freeze` with deterministic output and dry-run previews. Provide integration tests with temp projects. You own venv/deps helpers; others call them.
"""

**Workstream D (Test, Build, Publish) – single message:**
"""
You are implementing the Python CLI tool "devflow." Read docs/DESIGN_SPEC.md and docs/COPILOT_PLAN.md. Honor global flags, shell=False subprocesses, Typer CLI, structured logging with verbosity + dry-run. Guardrails: reuse config/AppContext/registry/venv/git helpers; do not recreate them. Additive changes only.

Task: Execute Workstream D. Implement `devflow test` (pass-through args, venv enforcement), `devflow build` (configurable backend, dist handling), `devflow publish` (clean working tree check, optional pre-tests, build+upload via twine, signing, tagging per tag_format, --dry-run). Add integration tests for success/failure and dry-run behavior. You own only these commands.
"""

**Workstream E (Git Integration) – single message:**
"""
You are implementing the Python CLI tool "devflow." Read docs/DESIGN_SPEC.md and docs/COPILOT_PLAN.md. Honor global flags, shell=False subprocesses, Typer CLI, structured logging with verbosity + dry-run. Guardrails: reuse config/AppContext/registry; do not redefine task engine. Additive changes only.

Task: Execute Workstream E. Build git helpers for status checks, tag formatting/creation, version sourcing (setuptools_scm or config fallback). Wire require_clean_working_tree, tag_on_publish, tag_format/tag_prefix, version_source flags. Add tests with temp git repos for dirty-tree blocking and idempotent tagging. Expose callable helpers for other commands.
"""

**Workstream F (Plugins & Extensibility) – single message:**
"""
You are implementing the Python CLI tool "devflow." Read docs/DESIGN_SPEC.md and docs/COPILOT_PLAN.md. Honor global flags, shell=False subprocesses, Typer CLI, structured logging with verbosity + dry-run. Guardrails: use registry/config from owners; do not change them. Additive changes only.

Task: Execute Workstream F. Define plugin discovery via entry points/config module paths, plugin interface (e.g., register(registry, app)), and a sample plugin fixture adding a command/task. Ensure bad plugins fail gracefully. Add tests for discovery, registration, precedence, and isolation. You own plugin loader/interface only.
"""

**Workstream G (UX, Completion, Docs) – single message:**
"""
You are implementing the Python CLI tool "devflow." Read docs/DESIGN_SPEC.md and docs/COPILOT_PLAN.md. Honor global flags, shell=False subprocesses, Typer CLI, structured logging with verbosity + dry-run. Guardrails: reuse registry/config/helpers; do not alter core semantics. Additive changes only.

Task: Execute Workstream G. Add `devflow completion <shell>`, ensure `devflow` with no args lists commands and project tasks, enrich help text with design-spec examples, maintain Quickstart/troubleshooting docs, add snapshot/help tests where practical. You own UX/docs/help strings only.
"""

**Workstream H (CI, Packaging, Evidence) – single message:**
"""
You are implementing the Python CLI tool "devflow." Read docs/DESIGN_SPEC.md and docs/COPILOT_PLAN.md. Honor global flags, shell=False subprocesses, Typer CLI, structured logging with verbosity + dry-run. Guardrails: do not modify core logic beyond packaging hooks; coordinate if needed. Additive changes only.

Task: Execute Workstream H. Create pyproject.toml with console_scripts entry and deps; add CI workflow covering lint/type-check/tests with ubuntu/macos/windows Git Bash matrix; encode acceptance scenarios (venv/test/build/publish dry-run, ci-check pipeline, dirty git blocking) and capture logs/artifacts for evidence. You own packaging/CI.
"""
