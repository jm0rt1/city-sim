# City-Sim Comprehensive Development Guide

## Welcome Developers!

This guide provides everything you need to contribute to City-Sim, from setting up your development environment to implementing new features and subsystems. City-Sim is a complex, feature-rich city simulation that aims to model every aspect of urban life with scientific accuracy and engaging gameplay.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Development Environment Setup](#development-environment-setup)
3. [Project Structure](#project-structure)
4. [Core Concepts](#core-concepts)
5. [Implementing New Features](#implementing-new-features)
6. [Code Style and Standards](#code-style-and-standards)
7. [Testing Guidelines](#testing-guidelines)
8. [Documentation Requirements](#documentation-requirements)
9. [Submitting Contributions](#submitting-contributions)
10. [Advanced Topics](#advanced-topics)

## Getting Started

### Prerequisites

- **Python 3.13 or later** with free-threaded mode (no Global Interpreter Lock)
  - Download from: https://www.python.org/downloads/
  - Free-threading installation guide: https://py-free-threading.github.io/installing_cpython/
- **Git** for version control
- **Visual Studio Code** (recommended) with Python extensions
- **Understanding of**:
  - Object-oriented programming in Python
  - Type hints and type checking
  - Unit testing with unittest
  - Basic simulation and modeling concepts

### Quick Start

```bash
# Clone the repository
git clone https://github.com/jm0rt1/city-sim.git
cd city-sim

# Initialize virtual environment (creates venv with Python 3.13+)
./init-venv.sh

# Activate virtual environment
source ./venv/bin/activate  # On macOS/Linux
# or
./venv/Scripts/activate  # On Windows

# Install dependencies (if any)
pip install -r requirements.txt

# Run tests to verify setup
./test.sh

# Run the simulation
python run.py
```

## Development Environment Setup

### Visual Studio Code Setup

1. **Install Extensions**:
   - Python (Microsoft)
   - Pylance (Microsoft)
   - GitLens (optional but recommended)
   - Python Test Explorer (optional)

2. **Configure Settings** (.vscode/settings.json):
```json
{
  "python.defaultInterpreterPath": "./venv/bin/python",
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": false,
  "python.linting.pycodestyleEnabled": false,
  "python.formatting.provider": "none",
  "python.analysis.typeCheckingMode": "basic",
  "editor.rulers": [100],
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true
}
```

3. **Debug Configuration** (.vscode/launch.json):
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Run Simulation",
      "type": "python",
      "request": "launch",
      "program": "${workspaceFolder}/run.py",
      "console": "integratedTerminal",
      "justMyCode": true
    },
    {
      "name": "Run Tests",
      "type": "python",
      "request": "launch",
      "module": "unittest",
      "args": ["discover", "-s", "tests", "-p", "*test*.py"],
      "console": "integratedTerminal",
      "justMyCode": true
    }
  ]
}
```

### Type Checking Configuration

Pyright is configured via `pyrightconfig.json`:

```json
{
  "include": ["src"],
  "exclude": ["src/gui/views/generated/main_window.py", "docs/**"],
  "typeCheckingMode": "basic",
  "reportMissingImports": true,
  "reportMissingTypeStubs": false
}
```

Run type checking:
```bash
pyright src/
```

## Project Structure

```
city-sim/
├── src/                          # Source code
│   ├── city/                     # City model and subsystems
│   │   ├── city.py              # Core city data model
│   │   ├── city_manager.py      # City state management
│   │   ├── decisions.py         # Policy and decision system
│   │   ├── finance.py           # Finance subsystem
│   │   ├── population/          # Population subsystem
│   │   │   ├── population.py
│   │   │   └── happiness_tracker.py
│   │   └── [future subsystems]  # Environment, Education, Healthcare, etc.
│   ├── simulation/              # Simulation core
│   │   └── sim.py               # Main simulation loop
│   ├── shared/                  # Shared utilities
│   │   └── settings.py          # Configuration management
│   └── main.py                  # Application entry point
│
├── tests/                        # Test suite
│   ├── core/                    # Core functionality tests
│   └── integration/             # Integration tests
│
├── docs/                         # Documentation
│   ├── specs/                   # Technical specifications
│   │   ├── city.md
│   │   ├── environment.md
│   │   ├── education.md
│   │   ├── healthcare.md
│   │   ├── emergency_services.md
│   │   ├── finance.md
│   │   ├── population.md
│   │   ├── traffic.md
│   │   ├── logging.md
│   │   └── scenarios.md
│   ├── architecture/            # Architecture documentation
│   │   ├── overview.md
│   │   ├── class-hierarchy.md
│   │   └── expanded_architecture.md
│   ├── adr/                     # Architecture Decision Records
│   │   ├── 001-simulation-determinism.md
│   │   └── 002-free-threaded-python.md
│   ├── guides/                  # User and developer guides
│   │   ├── contributing.md
│   │   ├── glossary.md
│   │   └── [this file]
│   ├── design/                  # Design documents
│   │   ├── workstreams/         # Parallel development tracks
│   │   └── templates/           # Document templates
│   └── FEATURE_CATALOG.md      # Complete feature listing
│
├── output/                       # Generated outputs (gitignored)
│   └── logs/                    # Simulation logs
│       ├── global/              # Main simulation logs
│       └── ui/                  # UI-specific logs
│
├── run.py                       # Main entry point
├── test.sh                      # Test runner script
├── init-venv.sh                 # Virtual environment setup
├── requirements.txt             # Python dependencies
├── pyrightconfig.json           # Type checker configuration
└── README.md                    # Project overview
```

### Key Directories

- **src/city/**: All subsystems modeling city aspects (population, finance, environment, etc.)
- **src/simulation/**: Core simulation engine and tick loop
- **src/shared/**: Utilities used across subsystems (settings, logging, random services)
- **tests/**: Comprehensive test suite ensuring quality and determinism
- **docs/specs/**: Detailed specifications defining subsystem contracts and behaviors
- **docs/architecture/**: System design and component relationships

## Core Concepts

### 1. Deterministic Simulation

**Critical**: All simulation runs with the same seed must produce identical results.

**Requirements**:
- Use `RandomService` with seeded random number generator, never `random` module directly
- No system time dependencies in state calculations (use tick index instead)
- Fixed execution order for all operations
- No floating-point non-determinism (careful with parallel sums)

**Example**:
```python
from src.shared.random_service import RandomService

class MySubsystem:
    def __init__(self, random_service: RandomService):
        self.random = random_service  # Use injected random service
    
    def update(self, city, context):
        # CORRECT: Using injected seeded random
        random_value = self.random.random()
        
        # WRONG: Using system random (non-deterministic!)
        # random_value = random.random()  # Never do this!
        
        # WRONG: Using system time (non-deterministic!)
        # current_time = time.time()  # Never do this!
        
        # CORRECT: Using tick index instead of time
        current_tick = context.tick_index
```

### 2. Subsystem Pattern

All subsystems follow the `ISubsystem` interface:

```python
from typing import Protocol
from src.city.city import City
from src.simulation.tick_context import TickContext

class ISubsystem(Protocol):
    """Interface that all subsystems must implement."""
    
    def update(self, city: City, context: TickContext) -> SubsystemDelta:
        """
        Update subsystem for one simulation tick.
        
        Arguments:
            city: Current city state (read and potentially modify)
            context: Tick context with tick_index, settings, random_service
            
        Returns:
            SubsystemDelta with summary of changes made
        """
        ...

# Example implementation
class EnvironmentSubsystem:
    def __init__(self, settings: EnvironmentSettings, random_service: RandomService):
        self.settings = settings
        self.random = random_service
    
    def update(self, city: City, context: TickContext) -> EnvironmentDelta:
        # 1. Calculate new state
        weather = self.simulate_weather(city, context)
        disasters = self.check_disasters(city, context)
        
        # 2. Apply changes to city
        city.current_weather = weather
        city.active_disasters = disasters
        
        # 3. Return summary of changes
        return EnvironmentDelta(
            weather=weather,
            new_disasters=disasters,
            temperature_energy_modifier=self.calculate_energy_modifier(weather)
        )
```

### 3. Data Structures: City, Context, and Deltas

**City**: Mutable object holding all city state
```python
class City:
    def __init__(self):
        # Infrastructure
        self.water_facilities = 0
        self.electricity_facilities = 0
        self.housing_units = 0
        
        # Population
        self.population = Population()
        
        # Budget
        self.budget = 1_000_000.0
        
        # More state as subsystems are added...
```

**TickContext**: Read-only context for each tick
```python
@dataclass
class TickContext:
    tick_index: int                      # Current tick number
    timestamp: str                       # ISO 8601 timestamp
    settings: Settings                   # Global settings
    random_service: RandomService        # Seeded RNG
    policy_set: PolicySet               # Active policies
```

**SubsystemDelta**: Summary of changes made by subsystem
```python
@dataclass
class EnvironmentDelta:
    """Changes made by environment subsystem in one tick."""
    weather: WeatherState
    new_disasters: list[Disaster]
    temperature_energy_modifier: float
    air_quality_index: float
    # ... more delta fields
```

### 4. Policy System

Policies modify city behavior:

```python
class IPolicy:
    """Interface for policies."""
    
    def evaluate(self, city: City, context: TickContext) -> list[Decision]:
        """
        Evaluate policy and generate decisions.
        
        Returns:
            List of decisions to apply to city state
        """
        ...

# Example policy
class TaxRatePolicy:
    def __init__(self, target_tax_rate: float):
        self.target_tax_rate = target_tax_rate
    
    def evaluate(self, city, context):
        if city.budget < 100_000:  # Low budget
            # Increase taxes
            return [Decision(
                type=DecisionType.SET_TAX_RATE,
                value=self.target_tax_rate * 1.1
            )]
        return []  # No change needed
```

### 5. Logging and Metrics

All subsystems emit metrics for analysis:

```python
class Logger:
    def log_tick(self, tick_index: int, metrics: dict):
        """Log metrics for one tick."""
        log_entry = {
            "tick_index": tick_index,
            "timestamp": datetime.now().isoformat(),
            **metrics  # Merge all subsystem metrics
        }
        self.write_jsonl(log_entry)

# Subsystem provides metrics
class MySubsystem:
    def update(self, city, context):
        # ... update logic ...
        
        return MySubsystemDelta(
            # State changes
            new_value=42,
            
            # Metrics for logging
            metrics={
                "my_subsystem_metric1": value1,
                "my_subsystem_metric2": value2
            }
        )
```

## Implementing New Features

### Adding a New Subsystem

Follow this step-by-step process:

#### Step 1: Write Specification

Create `docs/specs/my_subsystem.md`:

```markdown
# Specification: My Subsystem

## Purpose
Define what this subsystem models and why it's important.

## Core Concepts
Key concepts and terminology.

## Architecture
Component structure and relationships.

## Interfaces
Detailed interface definitions with type signatures.

## Data Structures
Classes and data structures used.

## Behavioral Specifications
How the subsystem behaves under different conditions.

## Integration with Other Subsystems
How this subsystem interacts with others.

## Metrics and Logging
What metrics are tracked and logged.

## Testing Strategy
How to test this subsystem.
```

#### Step 2: Define Data Structures

Create `src/city/my_subsystem.py`:

```python
from dataclasses import dataclass
from typing import List, Optional

@dataclass
class MySubsystemState:
    """State for my subsystem."""
    value1: int
    value2: float
    items: List[str]

@dataclass
class MySubsystemDelta:
    """Changes made by subsystem in one tick."""
    previous_state: MySubsystemState
    current_state: MySubsystemState
    metrics: dict
```

#### Step 3: Implement Subsystem

```python
from src.shared.random_service import RandomService
from src.city.city import City
from src.simulation.tick_context import TickContext

class MySubsystem:
    """Implements my feature subsystem."""
    
    def __init__(self, settings: MySubsystemSettings, random_service: RandomService):
        """
        Initialize subsystem.
        
        Arguments:
            settings: Configuration for this subsystem
            random_service: Seeded random number generator
        """
        self.settings = settings
        self.random = random_service
        self.state = MySubsystemState(value1=0, value2=0.0, items=[])
    
    def update(self, city: City, context: TickContext) -> MySubsystemDelta:
        """
        Update subsystem for one tick.
        
        Arguments:
            city: Current city state
            context: Tick context
            
        Returns:
            MySubsystemDelta with changes made
        """
        previous_state = self.state
        
        # 1. Read current city state
        population = len(city.population)
        budget = city.budget
        
        # 2. Perform calculations
        new_value1 = self.calculate_value1(population)
        new_value2 = self.calculate_value2(budget)
        
        # 3. Apply changes to city
        self.state = MySubsystemState(
            value1=new_value1,
            value2=new_value2,
            items=self.state.items + ["new_item"]
        )
        
        # 4. Update city state
        city.my_subsystem_state = self.state
        
        # 5. Return delta with metrics
        return MySubsystemDelta(
            previous_state=previous_state,
            current_state=self.state,
            metrics={
                "my_value1": new_value1,
                "my_value2": new_value2,
                "item_count": len(self.state.items)
            }
        )
    
    def calculate_value1(self, population: int) -> int:
        """Calculate value1 based on population."""
        return population // 100  # Example calculation
    
    def calculate_value2(self, budget: float) -> float:
        """Calculate value2 based on budget."""
        return budget * 0.01  # Example calculation
```

#### Step 4: Add to City Model

Update `src/city/city.py`:

```python
class City:
    def __init__(self):
        # ... existing fields ...
        
        # Add new subsystem state
        self.my_subsystem_state: Optional[MySubsystemState] = None
```

#### Step 5: Register with Simulation

Update `src/simulation/sim.py`:

```python
from src.city.my_subsystem import MySubsystem, MySubsystemSettings

class Sim:
    def __init__(self, city: City):
        self.city = city
        
        # Initialize new subsystem
        my_settings = MySubsystemSettings()
        self.my_subsystem = MySubsystem(my_settings, random_service)
    
    def advance_day(self):
        # ... existing subsystem updates ...
        
        # Update new subsystem
        my_delta = self.my_subsystem.update(self.city, context)
        
        # ... rest of tick processing ...
```

#### Step 6: Write Tests

Create `tests/core/test_my_subsystem.py`:

```python
import unittest
from src.city.city import City
from src.city.my_subsystem import MySubsystem, MySubsystemSettings
from src.shared.random_service import RandomService
from src.simulation.tick_context import TickContext

class TestMySubsystem(unittest.TestCase):
    def setUp(self):
        """Set up test fixtures."""
        self.settings = MySubsystemSettings()
        self.random = RandomService(seed=42)
        self.subsystem = MySubsystem(self.settings, self.random)
        self.city = City()
        self.context = TickContext(
            tick_index=0,
            timestamp="2024-01-01T00:00:00",
            settings=Settings(),
            random_service=self.random,
            policy_set=PolicySet()
        )
    
    def test_update_produces_delta(self):
        """Update should return delta with metrics."""
        delta = self.subsystem.update(self.city, self.context)
        
        self.assertIsNotNone(delta)
        self.assertIsInstance(delta.metrics, dict)
        self.assertIn("my_value1", delta.metrics)
    
    def test_deterministic_behavior(self):
        """Same inputs should produce same outputs."""
        # Reset for determinism test
        self.setUp()
        
        delta1 = self.subsystem.update(self.city, self.context)
        
        # Reset again with same seed
        self.setUp()
        
        delta2 = self.subsystem.update(self.city, self.context)
        
        self.assertEqual(delta1.current_state, delta2.current_state)
    
    def test_population_affects_value1(self):
        """Value1 should change with population."""
        # Small population
        self.city.population = [1, 2, 3]  # 3 people
        delta1 = self.subsystem.update(self.city, self.context)
        
        # Large population
        self.setUp()  # Reset subsystem
        self.city.population = [i for i in range(1000)]  # 1000 people
        delta2 = self.subsystem.update(self.city, self.context)
        
        self.assertNotEqual(
            delta1.current_state.value1,
            delta2.current_state.value1
        )

if __name__ == '__main__':
    unittest.main()
```

#### Step 7: Update Documentation

1. Add subsystem to Feature Catalog (`docs/FEATURE_CATALOG.md`)
2. Add entry to Architecture documentation
3. Update README if user-facing feature
4. Add to relevant workstream documents

### Adding a New Policy

Policies are simpler than subsystems:

```python
from src.city.decisions import IPolicy, Decision, DecisionType

class MyCustomPolicy(IPolicy):
    """Custom policy implementation."""
    
    def __init__(self, threshold: float):
        self.threshold = threshold
    
    def evaluate(self, city: City, context: TickContext) -> List[Decision]:
        """
        Evaluate policy and generate decisions.
        
        Returns:
            List of decisions to apply
        """
        decisions = []
        
        if city.budget < self.threshold:
            # Take action when budget low
            decisions.append(Decision(
                type=DecisionType.REDUCE_SPENDING,
                amount=1000.0,
                reason="Budget below threshold"
            ))
        
        return decisions

# Register policy
policy_engine.register_policy(MyCustomPolicy(threshold=50_000))
```

## Code Style and Standards

### Python Style Guidelines

1. **Follow existing code style** in the repository (generally PEP 8)
2. **Use type hints** for function signatures:
   ```python
   def calculate_happiness(population: Population, services: Services) -> float:
       """Calculate average happiness score."""
       pass
   ```

3. **Write docstrings** for public functions and classes:
   ```python
   def process_data(data: list[int]) -> dict:
       """
       Process input data and generate summary.
       
       Arguments:
           data: List of integer values to process
           
       Returns:
           Dictionary with summary statistics
           
       Raises:
           ValueError: If data list is empty
       """
       pass
   ```

4. **Keep functions focused** - one function, one purpose
5. **Avoid abbreviations** - use full descriptive names
6. **Use constants** for magic numbers:
   ```python
   # Good
   WATER_PER_FACILITY = 20
   people_with_water = water_facilities * WATER_PER_FACILITY
   
   # Bad
   people_with_water = water_facilities * 20  # What does 20 mean?
   ```

### Naming Conventions

- **Classes**: `PascalCase` (e.g., `City`, `HappinessTracker`, `WeatherSimulator`)
- **Functions/Methods**: `snake_case` (e.g., `advance_day()`, `get_average_happiness()`)
- **Constants**: `UPPER_SNAKE_CASE` (e.g., `GLOBAL_LOGS_DIR`, `MAX_POPULATION`)
- **Private Members**: Prefix with `_` (e.g., `_internal_state`, `_calculate_hidden()`)
- **Files**: `snake_case` (e.g., `city_manager.py`, `happiness_tracker.py`)

### Import Organization

Group imports in this order:

```python
# 1. Standard library imports
import random
from typing import List, Optional
from dataclasses import dataclass

# 2. Third-party imports
import numpy as np  # If using third-party libraries

# 3. Local application imports
from src.city.city import City
from src.shared.settings import Settings
from src.simulation.tick_context import TickContext
```

## Testing Guidelines

### Test Organization

- Place unit tests in `tests/core/`
- Place integration tests in `tests/integration/`
- Name test files: `test_<module>.py` or `Test<Module>.py`
- Name test classes: `Test<FeatureName>`
- Name test methods: `test_<what>_<when>_<expected>`

### Test Structure

```python
class TestFeature(unittest.TestCase):
    def setUp(self):
        """Set up test fixtures before each test."""
        self.city = City()
        self.random = RandomService(seed=42)
    
    def tearDown(self):
        """Clean up after each test."""
        pass  # Usually not needed
    
    def test_feature_behavior_when_condition_then_result(self):
        """Descriptive docstring explaining what this tests."""
        # Arrange: Set up test data
        self.city.population = [Person() for _ in range(100)]
        
        # Act: Perform the operation
        result = self.city.calculate_something()
        
        # Assert: Verify results
        self.assertEqual(result, expected_value)
        self.assertGreater(result, 0)
```

### Testing Principles

1. **Test Determinism**: Verify identical results with same seed
   ```python
   def test_deterministic_behavior(self):
       result1 = run_with_seed(42)
       result2 = run_with_seed(42)
       self.assertEqual(result1, result2)
   ```

2. **Test Isolation**: Each test should be independent
   ```python
   # Good - each test independent
   def test_feature_a(self):
       city = create_fresh_city()
       # test feature A
   
   def test_feature_b(self):
       city = create_fresh_city()
       # test feature B
   
   # Bad - tests depend on each other
   def test_sequence_part1(self):
       self.city.do_something()
   
   def test_sequence_part2(self):  # Depends on part1!
       self.city.do_something_else()
   ```

3. **Test Edge Cases**: Test boundary conditions
   ```python
   def test_empty_list(self):
       result = process([])
       self.assertEqual(result, [])
   
   def test_single_item(self):
       result = process([1])
       self.assertEqual(len(result), 1)
   
   def test_large_list(self):
       result = process([i for i in range(10000)])
       self.assertEqual(len(result), 10000)
   ```

4. **Test Failure Cases**: Test error handling
   ```python
   def test_invalid_input_raises_error(self):
       with self.assertRaises(ValueError):
           process_data(invalid_input)
   ```

### Running Tests

```bash
# Run all tests
./test.sh

# Run specific test file
python -m unittest tests.core.test_my_subsystem

# Run specific test class
python -m unittest tests.core.test_my_subsystem.TestMySubsystem

# Run specific test method
python -m unittest tests.core.test_my_subsystem.TestMySubsystem.test_specific_behavior

# Run with verbose output
python -m unittest discover -s tests -p '*test*.py' -v
```

## Documentation Requirements

### Required Documentation

Every new feature must include:

1. **Specification** (`docs/specs/`):
   - Purpose and overview
   - Core concepts and terminology
   - Architecture and component structure
   - Interface definitions with type signatures
   - Data structures
   - Behavioral specifications
   - Integration points with other subsystems
   - Metrics and logging
   - Testing strategy

2. **Code Documentation**:
   - Module docstring at top of file
   - Class docstrings
   - Method docstrings (especially public methods)
   - Complex algorithm explanations

3. **Feature Catalog Update**:
   - Add feature to `docs/FEATURE_CATALOG.md`
   - Include in appropriate category
   - List key capabilities

4. **Architecture Update**:
   - Update architecture diagrams if needed
   - Document new subsystem interactions
   - Add to subsystem communication matrix

### Documentation Style

Use clear, descriptive language:

```python
# Good docstring
def calculate_tax_revenue(tax_rate: float, income: float) -> float:
    """
    Calculate total tax revenue from income.
    
    Applies the tax rate to income to determine total tax collected.
    Tax revenue is capped at income (cannot exceed 100%).
    
    Arguments:
        tax_rate: Tax rate as decimal (0.0 to 1.0)
        income: Total income subject to taxation
        
    Returns:
        Total tax revenue collected
        
    Raises:
        ValueError: If tax_rate is negative or greater than 1.0
        
    Example:
        >>> calculate_tax_revenue(0.25, 100000)
        25000.0
    """
    if tax_rate < 0 or tax_rate > 1.0:
        raise ValueError("Tax rate must be between 0.0 and 1.0")
    return min(tax_rate * income, income)

# Bad docstring
def calc_tax(t: float, i: float) -> float:
    """Calculates tax."""  # Too brief, unclear
    return t * i
```

## Submitting Contributions

### Before Submitting

1. **Run Tests**: Ensure all tests pass
   ```bash
   ./test.sh
   ```

2. **Type Check**: Run Pyright type checker
   ```bash
   pyright src/
   ```

3. **Review Changes**: Check what you're submitting
   ```bash
   git status
   git diff
   ```

4. **Write Good Commit Messages**:
   ```
   Add environment subsystem with weather simulation
   
   - Implements weather patterns using Markov chains
   - Adds seasonal cycle system
   - Includes disaster simulation
   - Comprehensive test coverage
   ```

### Pull Request Process

1. **Create Branch**:
   ```bash
   git checkout -b feature/my-new-feature
   ```

2. **Make Changes**: Implement feature with tests and docs

3. **Commit Changes**:
   ```bash
   git add .
   git commit -m "Descriptive commit message"
   ```

4. **Push to Repository**:
   ```bash
   git push origin feature/my-new-feature
   ```

5. **Create Pull Request**: On GitHub, create PR with:
   - Clear title describing feature
   - Description of what changed and why
   - Link to related issues
   - Screenshots if UI changes
   - Checklist of completed items

6. **Address Feedback**: Respond to code review comments

## Advanced Topics

### Parallel Execution

For subsystems that can run in parallel:

```python
from concurrent.futures import ThreadPoolExecutor

def execute_parallel_subsystems(subsystems, city, context):
    """Execute independent subsystems in parallel."""
    with ThreadPoolExecutor() as executor:
        futures = [
            executor.submit(subsystem.update, city, context)
            for subsystem in subsystems
        ]
        deltas = [future.result() for future in futures]
    return deltas
```

**Requirements for parallel execution**:
- No shared mutable state between subsystems
- Read-only access to city state (or use copy-on-write)
- Deterministic ordering when aggregating results
- Proper use of seeded RNGs

### Performance Optimization

Techniques for improving performance:

1. **Caching**: Cache expensive calculations
   ```python
   from functools import lru_cache
   
   @lru_cache(maxsize=1000)
   def expensive_calculation(param1, param2):
       # Complex calculation
       return result
   ```

2. **Vectorization**: Use NumPy for bulk operations
   ```python
   import numpy as np
   
   # Instead of:
   results = [process(x) for x in data]
   
   # Use vectorized operations:
   results = np.vectorize(process)(np.array(data))
   ```

3. **Lazy Evaluation**: Compute only when needed
   ```python
   class CityMetrics:
       def __init__(self, city):
           self.city = city
           self._average_happiness = None  # Computed on demand
       
       @property
       def average_happiness(self):
           if self._average_happiness is None:
               self._average_happiness = self._compute_happiness()
           return self._average_happiness
   ```

### Debugging Tips

1. **Use Logging**: Add logging to trace execution
   ```python
   import logging
   
   logger = logging.getLogger(__name__)
   
   def my_function():
       logger.debug("Starting my_function")
       # ... code ...
       logger.debug(f"Intermediate result: {value}")
       # ... more code ...
   ```

2. **Breakpoint Debugging**: Use Visual Studio Code debugger or pdb
   ```python
   def problematic_function():
       x = some_calculation()
       breakpoint()  # Execution pauses here
       y = another_calculation(x)
   ```

3. **Assertions for Invariants**: Check assumptions
   ```python
   def update_budget(budget, revenue, expenses):
       new_budget = budget + revenue - expenses
       assert new_budget >= 0, "Budget cannot be negative"
       return new_budget
   ```

## Getting Help

- **Documentation**: Check `docs/` for specifications and guides
- **Code Examples**: Look at existing subsystems for patterns
- **Issue Tracker**: Search for similar issues or questions
- **Community**: Reach out to maintainers and community

## Summary Checklist

When implementing a new feature:

- [ ] Write specification document
- [ ] Implement data structures
- [ ] Implement subsystem with deterministic behavior
- [ ] Add to City model and simulation loop
- [ ] Write comprehensive unit tests
- [ ] Write integration tests
- [ ] Update Feature Catalog
- [ ] Update architecture docs
- [ ] Run all tests successfully
- [ ] Run type checker
- [ ] Create pull request with good description
- [ ] Respond to code review feedback

Welcome to the City-Sim development community! We're excited to see your contributions to making this the most comprehensive city simulation ever created.
