# Contributing Guide

Welcome to the City-Sim project! This guide will help you contribute effectively to the codebase, whether you're fixing bugs, adding features, or improving documentation.

## Table of Contents
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation Standards](#documentation-standards)
- [Commit Message Format](#commit-message-format)
- [Pull Request Process](#pull-request-process)
- [Code Review Guidelines](#code-review-guidelines)
- [Communication](#communication)

## Getting Started

### Prerequisites
- Python 3.13 or later with free-threaded mode (no Global Interpreter Lock)
  - Download from: https://www.python.org/downloads/
  - Free-threading installation guide: https://py-free-threading.github.io/installing_cpython/
  - See [ADR-002](../adr/002-free-threaded-python.md) for rationale
- Git
- Visual Studio Code (recommended) with Python and Pylance extensions
- Familiarity with the [Architecture Overview](../architecture/overview.md) and [Class Hierarchy](../architecture/class-hierarchy.md)

### Setting Up Your Development Environment

1. **Fork and Clone the Repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/city-sim.git
   cd city-sim
   ```

2. **Create and Activate Virtual Environment**
   ```bash
   ./init-venv.sh
   source ./venv/bin/activate  # On Windows: .\venv\Scripts\activate
   ```

3. **Install Dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Verify Setup**
   ```bash
   # Run tests to ensure everything works
   ./test.sh
   
   # Run a simple simulation
   python3 run.py
   ```

### Understanding the Codebase

Before contributing, familiarize yourself with:
- **[Architecture Overview](../architecture/overview.md)**: System design and component interactions
- **[Specifications](../specs/)**: Detailed subsystem contracts
- **[Workstreams](../design/workstreams/00-index.md)**: Organized development tracks
- **[Glossary](glossary.md)**: Key terms and definitions
- **[ADRs](../adr/)**: Architecture decisions and rationale

## Development Workflow

### 1. Create a Feature Branch

```bash
# Sync with main branch
git checkout main
git pull origin main

# Create a descriptive branch
git checkout -b feature/add-weather-system
# or
git checkout -b fix/budget-reconciliation-bug
# or
git checkout -b docs/improve-population-spec
```

**Branch Naming Convention**:
- `feature/`: New features or enhancements
- `fix/`: Bug fixes
- `docs/`: Documentation updates
- `refactor/`: Code refactoring
- `test/`: Test additions or improvements
- `perf/`: Performance optimizations

### 2. Make Focused, Minimal Changes

**Best Practices**:
- Keep pull requests small and focused on a single concern
- Make incremental commits as you work
- Test frequently during development
- Update documentation alongside code changes

**Example Workflow**:
```bash
# Make changes to code
vim src/city/finance.py

# Test your changes
./test.sh

# Run simulation to verify behavior
python3 run.py

# Stage and commit
git add src/city/finance.py
git commit -m "Add subsidy calculation to finance model"
```

### 3. Write or Update Documentation

**Documentation Requirements**:
- Update relevant specification files in `docs/specs/`
- Add docstrings to new functions and classes
- Update `docs/guides/glossary.md` for new terms
- Include usage examples for new features
- Document edge cases and limitations

**Example Docstring**:
```python
def calculate_happiness(city: City, context: TickContext) -> float:
    """
    Calculate aggregate city happiness based on multiple factors.
    
    Happiness is computed as a weighted sum of:
    - Service quality (30% weight)
    - Economic prosperity (25% weight)
    - Infrastructure quality (20% weight)
    - Environmental quality (15% weight)
    - Safety (10% weight)
    
    Args:
        city: Current city state
        context: Tick context with settings and policies
        
    Returns:
        Happiness value in range [0, 100]
        
    Raises:
        ValueError: If city state is invalid
        
    Example:
        >>> city = City(population=10000, budget=1000000, ...)
        >>> context = TickContext(tick_index=42, ...)
        >>> happiness = calculate_happiness(city, context)
        >>> print(f"City happiness: {happiness:.1f}")
        City happiness: 62.5
    """
```

### 4. Run Tests Locally

**Always run tests before committing**:
```bash
# Run all tests
./test.sh

# Run specific test file
python3 -m pytest tests/city/test_finance.py

# Run with coverage
python3 -m pytest --cov=src tests/

# Run specific test
python3 -m pytest tests/city/test_finance.py::test_budget_reconciliation
```

### 5. Commit Your Changes

Follow the [Commit Message Format](#commit-message-format) described below.

## Coding Standards

### Python Style

**Follow PEP 8** with these specifics:
- **Line Length**: 100 characters (not 79)
- **Indentation**: 4 spaces (no tabs)
- **Imports**: Organized (standard library, third-party, local)
- **Naming**:
  - `snake_case` for functions, variables, modules
  - `PascalCase` for classes
  - `UPPER_CASE` for constants
  - Private methods start with `_`

**Example**:
```python
from typing import List, Optional
import numpy as np

from src.city.city import City
from src.shared.settings import Settings

ANNUAL_INTEREST_RATE = 0.05  # Constant


class FinanceSubsystem:
    """Finance subsystem managing budget and transactions."""
    
    def __init__(self, revenue_model: RevenueModel):
        self._revenue_model = revenue_model
        
    def calculate_revenue(self, city: City) -> float:
        """Calculate total revenue for this tick."""
        return self._revenue_model.calculate(city)
```

### Type Hints

**Use type hints for all function signatures**:
```python
from typing import List, Dict, Optional, Tuple

def update_population(city: City, 
                      context: TickContext) -> PopulationDelta:
    """Update population with type hints."""
    pass

def get_buildings_by_type(city: City, 
                          building_type: BuildingType) -> List[Building]:
    """Return buildings of specified type."""
    pass
```

### Determinism Requirements

**Critical**: All code must be deterministic:
- Use `RandomService` for all randomness (with seed)
- No dependencies on system time for calculations
- Fixed subsystem update order
- No non-deterministic data structures (e.g., set iteration order)
- Consistent floating-point operations

**Example**:
```python
# ✓ Good: Use RandomService
population_change = context.random_service.randint(-10, 10)

# ✗ Bad: Use standard library random
import random
population_change = random.randint(-10, 10)  # NOT DETERMINISTIC
```

### Structured Logging

**Always use structured logging**:
```python
# ✓ Good: Structured log with all required fields
logger.log({
    "timestamp": datetime.utcnow().isoformat() + "Z",
    "run_id": context.run_id,
    "tick_index": context.tick_index,
    "budget": city.state.budget,
    "revenue": delta.revenue,
    "expenses": delta.expenses,
    ...
})

# ✗ Bad: Unstructured print statement
print(f"Budget: {city.state.budget}")
```

### Error Handling

**Handle errors gracefully with context**:
```python
try:
    delta = subsystem.update(city, context)
except SubsystemError as e:
    logger.error(f"Subsystem failed at tick {context.tick_index}: {e}")
    raise SimulationError(f"Failed at tick {context.tick_index}") from e
```

## Testing Guidelines

### Test Organization

```
tests/
├── city/
│   ├── test_city.py
│   ├── test_city_manager.py
│   └── test_finance.py
├── population/
│   ├── test_population.py
│   └── test_happiness.py
├── simulation/
│   └── test_sim.py
└── integration/
    └── test_full_simulation.py
```

### Writing Tests

**Unit Tests**: Test individual functions/classes in isolation
```python
def test_budget_reconciliation():
    """Verify budget equation holds."""
    city = create_test_city(budget=1000000)
    delta = FinanceDelta(revenue=50000, expenses=30000)
    
    finance.apply_delta(city, delta)
    
    expected = 1000000 + 50000 - 30000
    assert abs(city.state.budget - expected) < 1e-6
```

**Integration Tests**: Test component interactions
```python
def test_full_tick_updates_all_subsystems():
    """Verify tick updates finance, population, and transport."""
    city = create_test_city()
    context = create_test_context()
    
    result = sim_core.tick(city, context)
    
    assert result.finance_delta is not None
    assert result.population_delta is not None
    assert result.city_delta.budget_change != 0
```

**Determinism Tests**: Verify reproducibility
```python
def test_determinism_same_seed():
    """Same seed produces identical results."""
    settings1 = Settings(seed=12345, tick_horizon=10)
    settings2 = Settings(seed=12345, tick_horizon=10)
    
    report1 = SimRunner(settings1).run()
    report2 = SimRunner(settings2).run()
    
    assert report1.final_city.state.budget == report2.final_city.state.budget
    assert report1.kpis == report2.kpis
```

## Documentation Standards

### Specification Format

All subsystems must have a specification in `docs/specs/`:
- **Purpose**: What the subsystem does
- **Data Models**: Complete class/struct definitions
- **Interfaces**: Method signatures with docstrings
- **Examples**: Usage examples with code
- **Edge Cases**: Document unusual scenarios
- **Acceptance Criteria**: Testable requirements

See [City Specification](../specs/city.md) as a reference example.

### README Updates

Update relevant READMEs when:
- Adding new subsystems or components
- Changing build/run procedures
- Adding new dependencies
- Changing configuration options

## Commit Message Format

Use the imperative mood and follow this format:

```
<type>: <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `perf`: Performance improvement
- `chore`: Maintenance tasks

**Examples**:
```
feat: Add weather subsystem with temperature and precipitation

Implements basic weather simulation affecting happiness and traffic.
Includes weather model, data structures, and integration with city state.

Refs: #123
```

```
fix: Correct budget reconciliation floating-point error

Budget equation was failing due to floating-point rounding.
Increased tolerance to 1e-6 and added validation test.

Fixes: #456
```

```
docs: Enhance population specification with growth formulas

Added detailed formulas for birth rate, death rate, and migration.
Included edge cases and integration examples.
```

## Pull Request Process

### Before Submitting

**Checklist**:
- [ ] Code follows coding standards
- [ ] All tests pass locally
- [ ] New tests added for new functionality
- [ ] Documentation updated (specs, docstrings, README)
- [ ] No unnecessary debug code or comments
- [ ] Determinism maintained (if applicable)
- [ ] Glossary updated with new terms

### Submitting the PR

1. **Push your branch**:
   ```bash
   git push origin feature/add-weather-system
   ```

2. **Create Pull Request** on GitHub with:
   - **Title**: Clear, concise description
   - **Description**: What, why, and how
   - **Linked Issues**: Reference related issues
   - **Testing**: How you tested the changes
   - **Screenshots**: For UI changes

**Example PR Description**:
```markdown
## Summary
Adds weather subsystem to simulate temperature and precipitation effects.

## Changes
- New WeatherSubsystem class with temperature and precipitation models
- Integration with City infrastructure state
- Weather effects on traffic and happiness
- Tests for weather calculations and edge cases
- Updated population spec to include weather effects

## Testing
- Added 15 unit tests for weather calculations
- Ran determinism tests (passed)
- Ran 1000-tick simulation to verify integration

## Related Issues
Closes #123
Refs #124
```

### PR Review Response

**When reviewers request changes**:
- Address all comments
- Add commits for each change (don't force-push during review)
- Respond to comments explaining your changes
- Mark conversations as resolved when addressed

## Code Review Guidelines

### As a Reviewer

**Check for**:
- Correctness and logic errors
- Adherence to coding standards
- Test coverage and quality
- Documentation completeness
- Performance implications
- Determinism maintenance
- Edge case handling

**Provide**:
- Constructive feedback
- Specific suggestions
- Praise for good work
- Context for requested changes

### As a Contributor

**Expectations**:
- Reviews may take 1-3 days
- Be responsive to feedback
- Ask questions if unclear
- Don't take feedback personally

## Communication

### Getting Help

- **GitHub Issues**: Report bugs or request features
- **GitHub Discussions**: Ask questions or discuss ideas
- **Documentation**: Check docs first before asking

### Reporting Bugs

**Include**:
- Description of the issue
- Steps to reproduce
- Expected vs actual behavior
- System information (OS, Python version)
- Relevant logs or error messages
- Minimal reproducible example

**Template**:
```markdown
**Description**: Budget reconciliation fails after 100 ticks

**Steps to Reproduce**:
1. Run baseline scenario with seed 12345
2. Execute for 100 ticks
3. Observe budget reconciliation error in logs

**Expected**: Budget equation holds within tolerance
**Actual**: Budget difference = 0.005 (exceeds 1e-6)

**Environment**:
- OS: macOS 14.0
- Python: 3.11.2
- City-Sim: main branch (commit abc123)

**Logs**:
```
ERROR: Budget reconciliation failed at tick 100
Expected: 1234567.89, Got: 1234567.90, Diff: 0.005
```
```

## Acknowledgments

Thank you for contributing to City-Sim! Your efforts help make this project better for everyone.
