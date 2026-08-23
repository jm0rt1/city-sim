# GitHub Copilot Instructions for City-Sim

## Project Overview

City-Sim is a deterministic city-building simulation written in Python 3.13+. The project simulates city dynamics including population growth/decline, happiness tracking, infrastructure management, finance/budgeting, and traffic systems. The simulation operates on a tick-based system where each tick represents a time unit (e.g., a day) in the city's lifecycle.

## Core Principles

### Determinism First
- **All simulation runs must be deterministic**: Given the same seed and configuration, the simulation must produce identical outputs across runs
- Always use seeded random number generators via `RandomService`
- Never use time-based seeds or non-deterministic inputs in core simulation logic
- See ADR-001 (docs/adr/001-simulation-determinism.md) for detailed rationale

### Minimal Public API Changes
- Keep public interfaces stable and well-documented
- Document any breaking changes in relevant spec files
- Prefer extending existing interfaces over creating new ones
- Changes to core contracts must be reflected in docs/specs/

### Separation of Concerns
The architecture follows clear subsystem boundaries:
- **Simulation Core**: Orchestrates the tick loop and scenario execution
- **City Model**: Manages city state and operations via `City` and `CityManager`
- **Finance Subsystem**: Handles budget, revenue, and expenses
- **Population Subsystem**: Manages growth, happiness, and migration
- **Transport Subsystem**: Traffic simulation, pathfinding, and congestion modeling
- **Logging**: Structured outputs for reproducibility and analysis

### Structured Logging
- Use machine-readable formats (JSONL preferred, CSV acceptable)
- Always include run_id, tick_index, timestamp, and key metrics
- Output to output/logs/global/ for global logs, output/logs/ui/ for UI-specific logs
- Never remove or modify existing log fields without updating the logging spec

## Tech Stack & Tooling

### Language & Environment
- **Python 3.13+** with free-threaded mode (no Global Interpreter Lock) for optimal performance
  - See [ADR-002: Free-Threaded Python](docs/adr/002-free-threaded-python.md) for detailed rationale
- Virtual environment managed via `./init-venv.sh` script
- Dependencies in `requirements.txt` (currently minimal)

### Development Environment
- **IDE**: Visual Studio Code with Pylance and Python extensions
- **Type Checking**: Pyright configured via `pyrightconfig.json`
- Ignores: `src/gui/views/generated/main_window.py`, `docs/`

### Testing
- **Framework**: Python unittest (built-in)
- **Test Command**: `./test.sh` (runs unittest discovery)
- Test patterns: `*test*.py` and `*Test*.py`
- Tests located in `tests/` directory

### Entry Points
- `run.py`: Main entry point for running the simulation
- `src/main.py`: Initializes logging and starts the simulation loop
- `src/simulation/sim.py`: Core simulation logic

## Project Structure

```
city-sim/
├── .github/                     # GitHub configuration (this file)
├── .vscode/                     # VS Code settings and launch configs
├── docs/                        # All documentation
│   ├── adr/                     # Architecture Decision Records
│   ├── architecture/            # System architecture docs
│   ├── design/                  # AI development docs and workstreams
│   │   ├── templates/           # Templates for tasks, specs, experiments
│   │   └── workstreams/         # Parallel development workstreams (01-10)
│   ├── guides/                  # Contributing guide, glossary
│   ├── models/                  # UML models (StarUML .mdj)
│   └── specs/                   # Module specifications
├── output/logs/                 # Generated log files (gitignored)
├── src/                         # Source code
│   ├── city/                    # City model and subsystems
│   │   └── population/          # Population and happiness tracking
│   ├── shared/                  # Shared utilities (settings)
│   └── simulation/              # Simulation core
├── tests/                       # Unit and integration tests
├── venv/                        # Virtual environment (gitignored)
├── pyrightconfig.json           # Type checker configuration
├── requirements.txt             # Python dependencies
├── run.py                       # Main entry point
├── setup.py                     # Package setup
└── test.sh                      # Test runner script
```

## Coding Standards

### Python Style
- Follow existing code style in the repository (generally PEP 8)
- Use type hints where they add clarity (see existing code for examples)
- Keep functions focused and single-purpose
- Prefer explicit over implicit behavior

### Documentation
- Update relevant spec files when changing module contracts (docs/specs/)
- Use docstrings for public APIs
- Keep comments minimal but useful
- Document invariants and assumptions clearly

### Commit Messages
- Use imperative mood: "Add feature" not "Added feature"
- Reference workstreams or specs when relevant: "Implement tick scheduler (WS-01)"
- Keep commits focused and atomic

### Naming Conventions
- Classes: PascalCase (e.g., `City`, `HappinessTracker`)
- Functions/methods: snake_case (e.g., `advance_day`, `get_average_happiness`)
- Constants: UPPER_SNAKE_CASE (e.g., `GLOBAL_LOGS_DIR`)
- Files: snake_case (e.g., `city_manager.py`, `happiness_tracker.py`)

## Development Workflow

### Setup
```bash
# Initialize virtual environment
./init-venv.sh

# Activate virtual environment (if not auto-activated)
source ./venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### Running the Simulation
```bash
# Run via main entry point
python run.py

# Or using Python module syntax
python -m src.main
```

### Testing
```bash
# Run all tests
./test.sh

# Run specific test file
python -m unittest tests.core.test_dummy

# Run tests with verbose output
python -m unittest discover -s tests -p '*test*.py' -v
```

### VS Code Debugging
1. Open Debug sidebar (Ctrl+Shift+D)
2. Select "run.py" configuration
3. Set breakpoints as needed
4. Press F5 or click green arrow to start debugging

## Workstreams & Parallel Development

The project uses a workstream-based development model for parallel work. Each workstream has clear objectives, inputs, outputs, and acceptance criteria.

### Available Workstreams
1. **Simulation Core** (01): Tick loop, determinism, scenario execution
2. **City Modeling** (02): Data structures, state transitions, decisions
3. **Finance** (03): Budget, revenue, expenses, policy effects
4. **Population** (04): Growth, happiness, migration dynamics
5. **UI** (05): CLI/GUI generation and UX
6. **Data & Logging** (06): Structured logging, metrics, experiment tracking
7. **Testing & CI** (07): Unit tests, integration tests, static analysis
8. **Performance** (08): Profiling and optimization
9. **Roadmap** (09): Release planning and dependencies
10. **Traffic** (10): Transport network, pathfinding, traffic simulation

### Using Workstreams
- Read the workstream file in docs/design/workstreams/ before starting work
- Follow the "Reading Checklist" to understand dependencies
- Use task templates from docs/design/templates/ for new work
- Keep changes scoped to the workstream's boundaries where possible
- Coordinate cross-workstream changes via the Roadmap workstream

## Key Files & Modules

### Core Simulation
- `src/simulation/sim.py`: Main simulation loop and tick execution
- `src/shared/settings.py`: Global configuration and settings

### City Management
- `src/city/city.py`: City data model with infrastructure state
- `src/city/city_manager.py`: City state updates and decision application
- `src/city/decisions.py`: Policy decisions and their effects

### Subsystems
- `src/city/finance.py`: Budget, revenue, and expense calculations
- `src/city/population/population.py`: Population model and demographics
- `src/city/population/happiness_tracker.py`: Happiness calculation and tracking

### Entry Points
- `run.py`: Main entry point, sets up and starts simulation
- `src/main.py`: Initializes logging and creates simulation instance

## Testing Guidelines

### Test Organization
- Place unit tests in `tests/core/`
- Follow naming pattern: `test_<module>.py` or `Test<Module>.py`
- Group related tests in test classes
- Use descriptive test method names: `test_<what>_<when>_<expected>`

### Test Principles
- **Determinism**: Tests must be repeatable with fixed seeds
- **Isolation**: Each test should be independent
- **Fast**: Unit tests should run quickly; integration tests can be slower
- **Clear**: Test names and assertions should be self-documenting
- **Coverage**: Aim for meaningful coverage, not just high percentages

### Example Test Structure
```python
import unittest
from src.city.city import City

class TestCity(unittest.TestCase):
    def setUp(self):
        """Set up test fixtures"""
        self.city = City()
    
    def test_add_water_facilities_increases_count(self):
        """Adding water facilities should increase the count"""
        initial = self.city.water_facilities
        self.city.add_water_facilities(5)
        self.assertEqual(self.city.water_facilities, initial + 5)
    
    def test_add_water_facilities_rejects_negative(self):
        """Adding negative facilities should raise ValueError"""
        with self.assertRaises(ValueError):
            self.city.add_water_facilities(-1)
```

## Architecture & Design Patterns

### Data Flow
1. `run.py` initializes settings and seeds the simulation
2. Simulation Core executes ticks, calling `CityManager` to update `City` state
3. Decisions and policies are evaluated per tick
4. Finance and Population subsystems compute deltas
5. Metrics and logs are emitted to output/logs/*
6. UI/CLI surfaces summaries and reports

### Key Invariants
- **Budget reconciliation**: previous_budget + revenue - expenses = current_budget
- **Population non-negative**: Population values must be ≥ 0
- **Happiness bounded**: Happiness normalized to agreed range (e.g., 0-100)
- **Determinism**: Fixed seed + fixed config = identical outputs

### Extension Points
- Scenario loader: Configurable parameters, policies, time horizon
- Plug-in hooks for metrics and profiling
- Policy engine for custom decision rules
- Logger adapters for different output formats

## Common Tasks

### Adding a New Subsystem
1. Read docs/architecture/class-hierarchy.md for subsystem patterns
2. Create module in appropriate src/ subdirectory
3. Implement ISubsystem interface (update method)
4. Add spec file in docs/specs/
5. Register subsystem in CityManager
6. Add tests in tests/
7. Update architecture docs if needed

### Adding a New Policy
1. Review docs/specs/city.md for decision framework
2. Create policy class in src/city/decisions.py
3. Implement policy evaluation and state effects
4. Add policy to scenario configuration
5. Add tests for policy effects
6. Document in relevant workstream

### Adding a New Metric
1. Review docs/specs/logging.md for schema
2. Add metric field to log output
3. Update Logger/MetricsCollector
4. Add metric to scenario reports
5. Update logging spec documentation

### Adding a New Scenario
1. Review docs/specs/scenarios.md
2. Define scenario parameters (seed, duration, policies)
3. Document expected trends and outcomes
4. Add scenario to scenario loader
5. Run and validate scenario outputs
6. Add scenario tests

## Important Constraints

### What to Keep in Mind
- **No breaking changes** to existing public APIs without documentation
- **Always run tests** before committing changes
- **Maintain determinism** in all simulation logic
- **Update specs** when changing module contracts
- **Keep changes minimal** and focused on specific objectives
- **Follow existing patterns** rather than introducing new ones

### What to Avoid
- Time-based randomness or non-deterministic inputs
- Removing or modifying working code unnecessarily
- Adding dependencies without strong justification
- Changing log schemas without updating documentation
- Breaking test suites for unrelated functionality
- Creating helper scripts or workarounds (use standard tools)

## Glossary

- **Tick**: One iteration of the simulation loop (e.g., one day)
- **Scenario**: A configured run with specific parameters and policies
- **Determinism**: Identical outputs given the same inputs and seed
- **KPI**: Key Performance Indicator (e.g., budget, population, happiness)
- **Policy**: Decision affecting city state (e.g., tax rate change)
- **Delta**: State change output from a subsystem update
- **Subsystem**: Independent module handling specific domain (Finance, Population, etc.)
- **RunReport**: Final summary of simulation run with KPIs

## Additional Resources

### Documentation Reading Order
1. Start with README.md for basic setup
2. Read docs/architecture/overview.md for system design
3. Review docs/architecture/class-hierarchy.md for component details
4. Check docs/design/readme.md for development workflow
5. Browse docs/specs/ for detailed module specifications
6. Review docs/adr/ for architectural decisions
7. Consult docs/guides/contributing.md for workflow

### Key Documentation
- **Architecture**: docs/architecture/overview.md, docs/architecture/class-hierarchy.md
- **Specifications**: docs/specs/ (simulation, city, finance, population, traffic, logging, scenarios)
- **Workstreams**: docs/design/workstreams/00-index.md
- **Templates**: docs/design/templates/ (task_card, design_spec, experiment_plan)
- **ADRs**: docs/adr/ (001-simulation-determinism)
- **Guides**: docs/guides/contributing.md, docs/guides/glossary.md

## Questions or Issues?

When encountering issues:
1. Check relevant spec file in docs/specs/
2. Review workstream documentation in docs/design/workstreams/
3. Look for similar patterns in existing code
4. Consult ADRs for architectural decisions
5. Keep changes minimal and well-tested
6. Document any assumptions or limitations

## Path-Specific Guidelines

See additional path-specific instructions below for targeted guidance on specific areas of the codebase.
