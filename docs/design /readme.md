# City‑Sim AI Development Guide

This guide provides an AI‑followable documentation tree to coordinate parallel workstreams for the city building simulation. It defines clear inputs, outputs, run steps, checkpoints, and acceptance criteria so human and AI collaborators can execute tasks safely and consistently.

## How To Use
- Start at the Workstreams Index: see [docs/ai_dev/workstreams/00-index.md](docs/ai_dev/workstreams/00-index.md).
- Pick a workstream and open its file; each has an Objectives section, Task Backlog, and Run Steps that reference source files like [src/simulation/sim.py](src/simulation/sim.py) and [src/city/city_manager.py](src/city/city_manager.py).
- Author new tasks using the template in [docs/ai_dev/templates/task_card.md](docs/ai_dev/templates/task_card.md). Larger efforts should use [design_spec.md](docs/ai_dev/templates/design_spec.md) or [experiment_plan.md](docs/ai_dev/templates/experiment_plan.md).
- Keep changes minimal and consistent with the existing codebase style.

## Context
- Code entry points: [run.py](run.py), [src/main.py](src/main.py).
- Core modules: [src/simulation/sim.py](src/simulation/sim.py), [src/city/city.py](src/city/city.py), [src/city/city_manager.py](src/city/city_manager.py), [src/city/finance.py](src/city/finance.py), [src/city/population/population.py](src/city/population/population.py), [src/city/population/happiness_tracker.py](src/city/population/happiness_tracker.py), [src/shared/settings.py](src/shared/settings.py), [src/city/decisions.py](src/city/decisions.py).
- Logs: [output/logs/global/](output/logs/global/) for global runs; UI logs in [output/logs/ui/](output/logs/ui/).
- Tests: [tests/core/test_dummy.py](tests/core/test_dummy.py) (expand in Testing workstream).

## Parallel Workstreams
Workstreams are designed to run independently where possible:
1. Simulation Core – algorithm correctness and tick loop performance.
2. City Modeling – data structures and state transitions.
3. Finance – budget, revenue/expenses, policy effects.
4. Population – growth, happiness, migration.
5. UI – CLI or future GUI generation and UX.
6. Data & Logging – metrics, structured logs, and reproducibility.
7. Testing & CI – unit/integration tests and static analysis.
8. Performance – profiling and optimization.
9. Roadmap – release planning and cross‑workstream dependencies.

See the index at [docs/ai_dev/workstreams/00-index.md](docs/ai_dev/workstreams/00-index.md) for details and links.

## Quick Run
Use the following commands to run and test locally on macOS:

```bash
# Create and activate venv (if needed)
./init-venv.sh

# Install dependencies
pip install -r requirements.txt

# Run the simulation
python3 run.py

# Run tests
./test.sh
```

## Initial Documentation
For historical notes and original scoping, see [docs/ai_dev/initial_documentation.md](docs/ai_dev/initial_documentation.md).
