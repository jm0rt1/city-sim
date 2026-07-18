# Design White Paper: `devflow` – A Python-Native Project Operations CLI

> **Goal in one sentence:** Replace per-project shell scripts (`publish.sh`, `test.sh`, `build.sh`, etc.) with a single, pip-installable Python CLI (`devflow`) that is configurable, portable, and easy to integrate into your existing Git-based Python projects.

---

## 1. Motivation and Problem Statement

You currently maintain a growing ecosystem of Python projects, each with a scattering of shell scripts at the repository root:

* `publish.sh`
* `upload.sh`
* `test.sh`
* `build.sh`
* `init-venv.sh`
* `download-dependencies.sh`
* `freeze-venv.sh`
* … and more, depending on the project.

Problems:

* **Duplication & Drift**: Almost-identical scripts repeated across repos, subtly diverging.
* **Platform coupling**: Scripts may rely on `bash` semantics, GNU tools, PATH quirks, making them fragile on macOS, Linux, WSL, Git Bash, etc.
* **Cognitive overhead**: Each repo has a different “ritual” (`./build.sh && ./test.sh` vs `./run-tests` vs `./scripts/test.sh`).
* **Dependency management pain**: You want control over how venvs, dependencies, and freezes are handled, but without rewriting glue scripts constantly.

Desired state:

* **One command**, e.g. `devflow`, available everywhere after a pip install.
* **Per-project configuration**, declarative and versioned, ideally in TOML.
* **Rich CLI experience** with discoverable subcommands, help, and tab completion.
* **Python-native logic** (no brittle shell gymnastics) but still integrates smoothly with:

  * Git (hooks, commit workflows, tagging)
  * Packaging (build, upload, publish)
  * Testing and linting
  * Virtualenv management and freeze flows

`devflow` is a Python package you can `pip install git+https://github.com/you/devflow`, which exposes a single console command (`devflow`) that can orchestrate all the operations previously implemented as shell scripts.

---

## 2. High-Level Concept

`devflow` is:

* A **Python CLI “orchestrator”** for project operations (build, test, publish, etc.)
* Configured **per-project** via TOML or similar (`pyproject.toml` or `devflow.toml`).
* **Pluggable and extensible**: high-level commands map to modular Python backends.
* **Portable**: works equivalently under macOS (zsh), Linux (bash), and Git Bash.
* **“Single command” UX**: `devflow <subcommand> [options]`, no `python -m ...`.

It sits *above* your individual projects, but config lives *in* each project. The same `devflow` binary can be invoked in any repo: it discovers the project root, loads config, and runs the defined actions.

---

## 3. Requirements

### 3.1 Functional Requirements

1. **Unified CLI**

   * FR1: Provide a single executable command, `devflow`, installed via console_scripts.
   * FR2: Support subcommands corresponding to existing shell scripts:

     * `devflow build`
     * `devflow test`
     * `devflow publish`
     * `devflow upload`
     * `devflow venv init`
     * `devflow deps sync` / `devflow deps freeze`
     * `devflow ci-check` (composite: lint + test + build)
   * FR3: Allow **custom task definitions** per project (e.g., `devflow docs`, `devflow lint`).

2. **Project configuration**

   * FR4: Discover configuration from:

     * Primary: `[tool.devflow]` section in `pyproject.toml`.
     * Secondary: `devflow.toml` in project root.
   * FR5: Provide a typed configuration schema: tasks, env settings, dependency groups, etc.
   * FR6: Support default configuration that projects can override/extend.

3. **Environment & dependency management**

   * FR7: Support creating and managing a venv: `devflow venv init`.
   * FR8: Support installing dependencies from `requirements.txt` or `pyproject.toml`/`poetry.lock` or `requirements-*.txt`.
   * FR9: Support freezing dependencies to a file: `devflow deps freeze`.
   * FR10: Support “toolchain” configuration: specify which `python` executable or version to use.

4. **Build & test orchestration**

   * FR11: Provide `devflow test` to orchestrate running tests (pytest, unittest, etc.).
   * FR12: Provide `devflow build` to run `python -m build` or `hatchling`, etc., as configured.
   * FR13: Provide `devflow publish` to build and upload artifacts via `twine` or configured backend.

5. **Git integration**

   * FR14: Optionally integrate with git:

     * validate working tree clean before publish,
     * auto-tag releases,
     * run pre-commit checks.
   * FR15: Provide `devflow version` to show project version (e.g., from `setuptools_scm` or config).

6. **Extensibility**

   * FR16: Support a plugin mechanism for custom commands implemented in Python modules.
   * FR17: Allow per-project extra commands via config-defined “task” pipelines (simple “mini makefile”).

---

### 3.2 Non-Functional Requirements

1. **Configurability**

   * NFR1: All behavior should be adjustable via config (paths, commands, options).
   * NFR2: Config should be **declarative**, human-readable, diff-friendly, ideally TOML.

2. **Ease of use**

   * NFR3: `devflow --help` and `devflow <subcommand> --help` provide clear docs and examples.
   * NFR4: Command naming should follow intuitive conventions (no obscure flags when not necessary).
   * NFR5: Provide **sensible defaults** so that many projects “just work” with minimal config.

3. **Portability**

   * NFR6: Must run under:

     * macOS (zsh, bash)
     * Linux (bash, sh)
     * Git Bash / WSL on Windows
   * NFR7: Should not depend on external shells for core logic; use Python’s `subprocess` and stdlib.

4. **Integration with shell environments**

   * NFR8: Provide optional shell completion scripts for bash/zsh.
   * NFR9: Ensure deterministic behavior regardless of shell (no reliance on `.bashrc` or `.zshrc` content).

5. **Robustness & Observability**

   * NFR10: Clear exit codes:

     * 0 = success
     * Non-zero = failure; codes are stable and documented.
   * NFR11: Structured logging with verbosity levels (`-q`, default, `-v`, `-vv`).
   * NFR12: Support a `--dry-run` mode for destructive or remote operations (e.g. publish).

6. **Testability**

   * NFR13: System should be testable via standard Python test frameworks (pytest), in isolation and via integration tests.
   * NFR14: All key features must be verifiable via automated CI across platforms.

---

## 3.3 CLI/UX Requirements

* R-CLI1: Top-level usage:

  ```bash
  devflow [GLOBAL OPTIONS] <command> [COMMAND OPTIONS]
  ```

* R-CLI2: Discoverability:

  * `devflow` with no args displays a summary of available commands and project-specific tasks.

* R-CLI3: Consistent flags:

  * `--dry-run`, `--verbose/-v`, `--config`, `--project-root`, `--version`.

* R-CLI4: Pipeline support:

  * Composite commands (e.g., `devflow ci-check`) run multiple steps in sequence, showing clear phases and failure points.

---

## 4. System Architecture

### 4.1 High-Level Components

1. **CLI Frontend**

   * Built with `argparse`, `click`, or `typer` (typer is a good fit for rich CLI).
   * Responsible for parsing args, dispatching to command handlers.

2. **Core Application Layer**

   * `AppContext` / `Runtime` object:

     * Project root
     * Loaded configuration
     * Environment (venv path, Python executable)
     * Logger and settings.
   * Central “command registry” mapping command names to handlers.

3. **Configuration Subsystem**

   * Loader that:

     * Detects project root (walk up from CWD until finding `pyproject.toml` or `devflow.toml`).
     * Parses config (TOML).
     * Validates schema using pydantic/dataclasses.
     * Merges defaults and project overrides.

4. **Task Execution Engine**

   * Abstraction `Task` object representing a single operation (e.g., run pytest, build package).
   * `Pipeline` for composite tasks (sequences of `Task`s).
   * Central execution service that:

     * Executes tasks in sequence.
     * Handles `--dry-run`, logging, and error propagation.

5. **Subsystem Integrations**

   * **Venv Manager**: create, inspect, activate environment for commands.
   * **Dependency Manager**: install/update/freeze.
   * **Build/Publish Manager**: call out to `python -m build`, `twine`, etc.
   * **Git Manager**: run git commands via `subprocess`, parse status, tags, etc.

6. **Plugin System**

   * Minimal plugin interface (e.g., entry points or config-defined Python module path) that allows additional commands to be registered at startup.

---

### 4.2 Package Layout (Proposed)

```text
devflow/
  __init__.py
  cli.py             # entrypoint
  app.py             # AppContext/Runtime
  config/
    __init__.py
    loader.py        # reading pyproject.toml/devflow.toml
    schema.py        # pydantic/dataclasses models
    defaults.py
  commands/
    __init__.py
    base.py          # Command, Task, Pipeline abstractions
    build.py
    test.py
    publish.py
    venv.py
    deps.py
    gitops.py
    custom.py        # generic "run custom task" logic
  core/
    subprocess.py    # robust wrappers for external commands
    logging.py
    paths.py         # project root detection, path helpers
    env.py           # environment variable handling
  plugins/
    __init__.py      # plugin loading mechanisms
  tests/
    ...
pyproject.toml       # packaging, console_scripts entrypoint
```

---

## 5. Configuration Design

### 5.1 Location & Format

* **Preferred**: `pyproject.toml`:

  ```toml
  [tool.devflow]
  default_python = "python3.11"
  venv_dir = ".venv"
  src_dir = "src"
  auto_discover_tasks = true
  ```

* Optional separate file: `devflow.toml` if you want to keep `pyproject.toml` lean:

  ```toml
  [devflow]
  venv_dir = ".venv"
  ```

Priority order:

1. Explicit `--config` path if given.
2. `[tool.devflow]` in `pyproject.toml`.
3. `devflow.toml` in project root.
4. Global defaults (possibly from `~/.config/devflow/config.toml`).

### 5.2 Example Configuration

```toml
[tool.devflow]
venv_dir = ".venv"
default_python = "python3.11"
build_backend = "build"      # "build" vs "hatchling" vs "poetry-build"
test_runner = "pytest"
package_index = "pypi"       # or "testpypi"

[tool.devflow.paths]
dist_dir = "dist"
tests_dir = "tests"
src_dir = "src"

[tool.devflow.publish]
repository = "pypi"
sign = true
tag_on_publish = true
tag_format = "v{version}"

[tool.devflow.deps]
requirements = "requirements.txt"
dev_requirements = "requirements-dev.txt"
freeze_output = "requirements-freeze.txt"

[tool.devflow.tasks.test]
command = "pytest"
args = ["-q"]
use_venv = true

[tool.devflow.tasks.build]
command = "python"
args = ["-m", "build"]
use_venv = true

[tool.devflow.tasks.publish]
steps = ["build", "upload"]

[tool.devflow.tasks.upload]
command = "twine"
args = ["upload", "dist/*"]
use_venv = true

[tool.devflow.tasks.ci-check]
pipeline = ["format", "lint", "test"]

[tool.devflow.tasks.format]
command = "ruff"
args = ["format"]

[tool.devflow.tasks.lint]
command = "ruff"
args = ["check", "."]
```

This provides:

* **Built-in semantic commands** (`test`, `build`, `publish`) with explicit config.
* **Composite tasks** (`ci-check`) built from smaller ones.

---

## 6. Command Design

### 6.1 Top-Level CLI

```text
devflow
  venv       Manage project virtual environment
  deps       Manage dependencies (sync, freeze)
  test       Run tests
  build      Build distribution artifacts
  publish    Build & upload to package index
  git        Git-related helper commands
  task       Run custom tasks defined in config
  ci-check   Opinionated CI pipeline (if configured)
```

**Global flags:**

* `--config PATH`
* `--project-root PATH`
* `-v/--verbose` (can be repeated)
* `-q/--quiet`
* `--dry-run`
* `--version`

### 6.2 Core Subcommands (Minimal Spec)

#### `devflow venv init`

* Create `.venv` (or configured `venv_dir`) using configured Python.
* Install base dependencies if configured.

Options:

* `--python PATH_OR_VERSION` to override default.
* `--recreate` to delete and recreate venv.

#### `devflow deps sync`

* Ensure venv has dependencies consistent with `requirements.txt` or `pyproject.toml`.
* Possibly integrate with `pip-compile` / `pip-tools` if configured.

#### `devflow deps freeze`

* Freeze installed packages to configured `freeze_output` file.

#### `devflow test`

* Execute configured test runner under the venv.
* Supports `--pattern`, `--marker`, `--cov`, etc., passed through to the test runner.

#### `devflow build`

* Run configured build backend in the venv:

  * e.g. `python -m build`.
* Ensure `dist/` is cleaned or versioned properly.

#### `devflow publish`

* Sequence:

  1. Ensure working tree clean (unless `--allow-dirty`).
  2. Run tests (optional, `--skip-tests`).
  3. Run build.
  4. Run upload (`twine upload`).
  5. Create git tag (if configured).
* Support `--repository`, `--dry-run`.

#### `devflow task <name>`

* Run any custom task defined in `[tool.devflow.tasks.<name>]`.

---

## 7. Implementation Design Details

### 7.1 Command Abstraction & Registry

* `Command` base class:

  ```python
  class Command(ABC):
      name: str
      help: str

      def __init__(self, app: AppContext) -> None:
          self.app = app

      @abstractmethod
      def run(self, **kwargs) -> int:
          ...
  ```

* `CommandRegistry`:

  ```python
  class CommandRegistry:
      def __init__(self) -> None:
          self._commands: dict[str, type[Command]] = {}

      def register(self, cmd_cls: type[Command]) -> None:
          self._commands[cmd_cls.name] = cmd_cls

      def get(self, name: str) -> type[Command] | None:
          return self._commands.get(name)
  ```

* CLI binds subcommands to registry entries; config-defined tasks are mapped to a `CustomTaskCommand`.

### 7.2 Task & Pipeline Execution

* `Task` abstraction:

  ```python
  @dataclass
  class Task:
      name: str
      command: list[str]  # executable + args
      use_venv: bool = True
      env: dict[str, str] | None = None
  ```

* `Pipeline`:

  ```python
  @dataclass
  class Pipeline:
      name: str
      tasks: list[Task]
  ```

* Execution logic respects `--dry-run` (log commands but don’t run) and collects results to provide clear feedback.

### 7.3 Project Root & Config Loading

* Project root detection:

  ```python
  def find_project_root(start: Path) -> Path:
      current = start
      while current != current.parent:
          if (current / "pyproject.toml").exists() or (current / "devflow.toml").exists():
              return current
          current = current.parent
      raise RuntimeError("Project root not found")
  ```

* Config loader:

  * Parses TOML.
  * Validates with schema.
  * Builds `AppConfig` object.

### 7.4 Shell Integration & Completion

* Provide `devflow completion <shell>` to output completion script.
* User can add:

  ```bash
  eval "$(devflow completion zsh)"
  ```

to `~/.zshrc` or similar.

### 7.5 Observability

* Logging categories:

  * `INFO`: high-level steps (e.g. “Running tests with pytest”).
  * `DEBUG`: actual commands, environment details.
  * `ERROR`: failure messages and suggestions.
* Output structure:

  * Prefixed phases: `[venv] Creating venv`, `[test] Running pytest`, `[publish] Uploading wheels`.

---

## 8. Test Scenarios & Evidence Strategy

We want to **prove** the design meets the requirements using tests and prototyping.

### 8.1 Acceptance Criteria Overview

For each requirement, define measurable acceptance tests.

Examples:

* **Configurability**:

  * Changing `test_runner` in config changes the executed command.
  * Adding custom tasks makes `devflow task <name>` available.

* **Ease of use**:

  * `devflow` with no args lists commands.
  * `devflow test --help` is informative.

* **Portability**:

  * CI matrix: `ubuntu-latest`, `macos-latest`, `windows-latest` (Git Bash/WSL) all run core commands successfully.

* **Shell integration**:

  * Completion scripts generated correctly and load without errors in zsh/bash.

### 8.2 Test Matrix

**Dimensions:**

* OS: macOS / Linux / Git Bash
* Project type:

  * Simple package (src layout).
  * Multi-package monorepo.
* Dependency style:

  * `requirements.txt` only.
  * `pyproject.toml` with `build-system`.
* Operations:

  * `venv init`
  * `deps sync`
  * `test`
  * `build`
  * `publish` (dry-run to test index)

**Example matrix slice:**

| Test ID | OS      | Project Type | Operation           | Expected Result                            |
| ------: | ------- | ------------ | ------------------- | ------------------------------------------ |
|    T-01 | macOS   | simple       | `venv init`         | `.venv` created; python usable             |
|    T-02 | Linux   | simple       | `deps sync`         | installs from `requirements.txt`           |
|    T-03 | Linux   | simple       | `test`              | pytest runs, exit code matches test result |
|    T-04 | macOS   | simple       | `build`             | `dist/` contains wheel and sdist           |
|    T-05 | Linux   | simple       | `publish --dry-run` | No network calls; logs “would upload..”    |
|    T-06 | GitBash | simple       | `test`              | same as Linux, no shell errors             |

### 8.3 Detailed Test Scenarios

#### Scenario 1: Replace `test.sh` with `devflow test`

**Given:**

* A project with `pyproject.toml` configured:

  ```toml
  [tool.devflow.tasks.test]
  command = "pytest"
  args = ["-q"]
  use_venv = true
  ```

**When:**

* User runs:

  ```bash
  devflow venv init
  devflow deps sync
  devflow test
  ```

**Then:**

* A venv is created.
* Dependencies are installed.
* `pytest -q` is executed via venv.
* Exit code matches pytest’s exit code.
* Logs show the sequence of operations.

**Evidence collection:**

* Capture command output and exit code in CI.
* Use snapshot tests on logs to verify clarity and phases.
* Use `pytest` to assert `subprocess.run` was called with correct args in unit tests.

---

#### Scenario 2: Portable build & publish

**Given:**

* `pyproject.toml` with `[build-system]` and `[tool.devflow]`.
* `devflow` configured for `python -m build` and `twine upload`.

**When:**

* On macOS and Linux:

  ```bash
  devflow build
  devflow publish --dry-run
  ```

**Then:**

* Build step produces identical artifact structure on both OSes.
* Publish dry-run logs show which files would be uploaded, to which repository.
* No shell-specific errors occur.

**Evidence:**

* CI job collects the artifact list (e.g. `ls dist/`).
* Snapshot of `devflow publish --dry-run` output.
* Check `devflow` exit codes.

---

#### Scenario 3: Custom pipeline (`ci-check`)

**Given:**

```toml
[tool.devflow.tasks.ci-check]
pipeline = ["format", "lint", "test"]

[tool.devflow.tasks.format]
command = "ruff"
args = ["format"]

[tool.devflow.tasks.lint]
command = "ruff"
args = ["check", "."]

[tool.devflow.tasks.test]
command = "pytest"
args = ["-q"]
```

**When:**

```bash
devflow ci-check
```

**Then:**

* Commands run in order: `ruff format`, `ruff check .`, `pytest -q`.
* If `ruff check` fails, `pytest` is not run, and `devflow` exit code matches `ruff`’s.
* Logs clearly delineate each task.

**Evidence:**

* Controlled test repo where `ruff` deliberately fails.
* CI logs verifying that `pytest` is skipped when `lint` fails.

---

#### Scenario 4: Configurability & Overrides

**Given:**

* Global config says `test_runner = "pytest"`.
* A project overrides test command to `python -m unittest`.

**When:**

```bash
devflow test
```

**Then:**

* `unittest` executes in that project, not pytest.
* Another project without override still uses pytest.

**Evidence:**

* Two fixture repos within the tests, each with their own config.
* Integration tests assert that different commands were executed.

---

#### Scenario 5: Git integration & safety

**Given:**

* A project config:

  ```toml
  [tool.devflow.publish]
  tag_on_publish = true
  tag_format = "v{version}"
  require_clean_working_tree = true
  ```

**When:**

* User runs `devflow publish` with uncommitted changes.

**Then:**

* `devflow` checks git status.
* Fails before build/publish.
* Prints clear message: “Working tree not clean; commit or stash before publish.”

**Evidence:**

* Integration test initializes a git repo, creates a dirty file, runs command, and asserts:

  * exit code != 0
  * no build artifacts created
  * no tag created

---

### 8.4 Prototype Strategy

1. **Vertical Slice Prototype (Phase 1)**

   * Implement:

     * Config loader (limited subset)
     * Project root detection
     * `venv init`
     * `deps sync` (simple `pip install -r requirements.txt`)
     * `test` as “run pytest”
   * Use it in one of your existing projects by “shadowing” current scripts:

     * keep `test.sh`, make it call `devflow test` internally.
   * Evidence:

     * Validate repeated runs behave the same.
     * Compare logs to shell script output.

2. **Extend to Build & Publish (Phase 2)**

   * Add `build` and `publish` commands.
   * Support `--dry-run` for publish.
   * Hook into one package you actually upload to TestPyPI.

3. **Hardening & Portability (Phase 3)**

   * Add CI matrix with macOS/Linux + Git Bash.
   * Run full test matrix on each push.
   * Incorporate collected evidence (logs, artifacts, exit codes) as gating conditions.

---

## 9. Evidence of Meeting Requirements

We can capture evidence in three layers:

1. **Unit Test Evidence**

   * Confirm that:

     * Config is parsed correctly.
     * Commands are resolved correctly from config.
     * Task pipelines expand correctly.
   * Metrics:

     * High coverage for config loader and task executor.

2. **Integration Test Evidence**

   * Use temporary directories with fixture repos.
   * Run `devflow` commands via `subprocess.run`.
   * Assert on:

     * Exit codes.
     * Created files (venvs, dist artifacts, freeze files).
     * Content of logs (with normalized paths).

3. **Real-world Dogfooding Evidence**

   * Replace shell scripts in one of your real repos by symlinking or delegating to `devflow`.
   * Track:

     * Number of times `devflow` is used vs legacy scripts over time.
     * Incidents of script failure vs `devflow` failure (should go down).
   * Optionally, log anonymized usage telemetry into a file (only locally) to understand which commands and flows you actually use.

---

## 10. Risks and Mitigations

1. **Risk: Over-engineering for early stages**

   * Mitigation: Start with a minimal vertical slice (just venv + test) but design with extensibility in mind.

2. **Risk: Tight coupling to one packaging style**

   * Mitigation: Configurable backends for build and publish; default to `python -m build` and `twine` but allow alternatives.

3. **Risk: Platform quirks**

   * Mitigation:

     * Avoid shell-specific features.
     * Use Python’s `subprocess` with explicit lists instead of strings.
     * CI on multiple OS/shell combos.

4. **Risk: Config complexity**

   * Mitigation:

     * Provide simple defaults.
     * Offer minimal config examples for the common case.
     * Keep advanced options in docs, not mandatory templates.

---

## 11. Summary

`devflow` is a Python-native “UV-like” command for **project operations orchestration**:

* **Replaces** ad-hoc shell scripts (`build.sh`, `test.sh`, etc.).
* **Unifies** project flows under one consistent CLI.
* **Centralizes** configuration in TOML, versioned with your code.
* **Ensures** portability across macOS, Linux, and Git Bash.
* **Backed** by a robust test and evidence strategy that makes it believable this can pass real-world usage and regression tests.

If you’d like, the next step can be a **concrete initial `pyproject.toml` + minimal `devflow` package skeleton**, ready to paste into a repo and iterate on.
