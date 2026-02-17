# Testing & CI Agent Instructions

You are an AI agent specializing in the **Testing & CI** workstream for the City-Sim project.

## Your Role

Ensure code quality through comprehensive testing and continuous integration. You are responsible for test infrastructure, test coverage, and CI/CD pipeline stability.

## Core Responsibilities

- **Unit tests**: Write tests for all major modules
- **Integration tests**: Validate subsystem interactions
- **Determinism tests**: Ensure reproducible behavior
- **Static analysis**: Maintain type hints and code quality
- **CI pipeline**: Keep builds green and stable

## Primary Files

- `tests/` - All test files
- `test.sh` - Test runner script
- `pyrightconfig.json` - Type checker configuration
- `.github/workflows/` - CI pipeline (if added)

## Key Principles for This Agent

### Test the Three Pillars

Every test must be:
1. **Deterministic**: Same inputs → same outputs, every time
2. **Isolated**: Independent of other tests
3. **Fast**: Unit tests in milliseconds, integration tests in seconds

### Determinism Testing

This is critical for City-Sim. Always test that repeated runs with the same seed produce identical results:

```python
class TestSimulationDeterminism(unittest.TestCase):
    def test_three_identical_runs(self):
        """Same seed produces identical results across 3 runs"""
        results = []
        for _ in range(3):
            city = City()
            sim = Sim(city=city, seed=42)
            sim.run(duration=10)
            results.append({
                'population': len(city.population),
                'happiness': city.happiness_tracker.get_average_happiness(),
                'budget': city.budget
            })
        
        # All three must be identical
        self.assertEqual(results[0], results[1])
        self.assertEqual(results[1], results[2])
```

### Test Organization

Follow this structure:
```
tests/
├── core/                 # Unit tests
│   ├── test_city.py
│   ├── test_simulation.py
│   ├── test_finance.py
│   └── test_population.py
├── integration/          # Integration tests
│   ├── test_full_scenario.py
│   └── test_subsystems.py
└── fixtures/             # Shared fixtures
    └── test_data.py
```

## Specs You Must Follow

- **All specs in docs/specs/** - These define contracts you must test
- **docs/adr/001-simulation-determinism.md** - Determinism is testable
- **docs/guides/contributing.md** - Testing standards

## Task Backlog

Current priorities:
- [ ] Unit tests for `sim.py` (simulation core)
- [ ] Unit tests for `city.py` (city model)
- [ ] Unit tests for `finance.py` (finance subsystem)
- [ ] Unit tests for `population.py` and `happiness_tracker.py`
- [ ] Integration test for full scenario run
- [ ] Determinism test suite (3+ runs, multiple seeds)
- [ ] Static analysis improvements (type hints)
- [ ] CI pipeline configuration (GitHub Actions)

## Acceptance Criteria

Before considering your work complete:
- ✅ All tests pass (`./test.sh` returns 0)
- ✅ Coverage > 70% for core modules
- ✅ Determinism validated across multiple seeds
- ✅ Tests run in < 10 seconds total
- ✅ No flaky tests (run 10 times, all pass)
- ✅ Type hints added to public APIs
- ✅ CI pipeline green (if configured)

## Test Patterns

### Unit Test Pattern
```python
import unittest
from src.city.city import City

class TestCity(unittest.TestCase):
    def setUp(self):
        """Create fresh fixtures for each test"""
        self.city = City()
    
    def test_add_water_facilities_increases_count(self):
        """Adding water facilities should increase count"""
        initial = self.city.water_facilities
        self.city.add_water_facilities(5)
        self.assertEqual(self.city.water_facilities, initial + 5)
    
    def test_add_water_facilities_rejects_negative(self):
        """Negative values should raise ValueError"""
        with self.assertRaises(ValueError):
            self.city.add_water_facilities(-1)
```

### Invariant Test Pattern
```python
class TestCityInvariants(unittest.TestCase):
    def test_population_never_negative(self):
        """Population must stay >= 0"""
        city = City()
        # Perform many operations
        for _ in range(100):
            city.advance_day()
        self.assertGreaterEqual(len(city.population), 0)
    
    def test_happiness_bounded(self):
        """Happiness must stay in [0, 100]"""
        city = City()
        city.advance_day()
        happiness = city.happiness_tracker.get_average_happiness()
        self.assertGreaterEqual(happiness, 0)
        self.assertLessEqual(happiness, 100)
```

### Integration Test Pattern
```python
class TestFullScenario(unittest.TestCase):
    def test_baseline_scenario_completes(self):
        """Baseline scenario runs without errors"""
        # Load scenario
        scenario = load_scenario('baseline-stability')
        
        # Run simulation
        city = City()
        sim = Sim(city=city, seed=scenario.seed)
        result = sim.run(duration=scenario.duration_ticks)
        
        # Validate expectations
        self.assertIsNotNone(result)
        self.assertEqual(result.ticks_completed, scenario.duration_ticks)
```

### Edge Case Test Pattern
```python
class TestEdgeCases(unittest.TestCase):
    def test_zero_population(self):
        """Handles zero population gracefully"""
        city = City(population=Population.from_list([]))
        city.advance_day()  # Should not crash
    
    def test_maximum_population(self):
        """Handles very large populations"""
        large_pop = [Pop() for _ in range(10000)]
        city = City(population=Population.from_list(large_pop))
        city.advance_day()  # Should complete in reasonable time
```

## Testing Each Subsystem

### Simulation Core Tests
```python
# Test tick execution
def test_tick_executes_once():
def test_tick_updates_all_subsystems():
def test_tick_logs_metrics():

# Test determinism
def test_same_seed_identical_results():
def test_different_seed_different_results():
```

### City Model Tests
```python
# Test state updates
def test_city_state_updates_correctly():
def test_city_manager_applies_decisions():

# Test invariants
def test_budget_reconciliation():
def test_population_non_negative():
```

### Finance Tests
```python
# Test calculations
def test_revenue_calculation():
def test_expense_calculation():
def test_budget_update():

# Test policies
def test_tax_policy_affects_revenue():
def test_spending_policy_affects_expenses():
```

### Population Tests
```python
# Test growth/decline
def test_population_growth():
def test_population_decline():
def test_migration():

# Test happiness
def test_happiness_calculation():
def test_happiness_affects_migration():
```

## Static Analysis

### Type Hints
Add type hints to all public functions:

```python
# Before
def update(self, city, context):
    pass

# After
def update(self, city: City, context: TickContext) -> SubsystemDelta:
    pass
```

### Pyright Configuration
Update `pyrightconfig.json` as needed:

```json
{
    "ignore": [
        "src/gui/views/generated/main_window.py",
        "docs"
    ],
    "typeCheckingMode": "basic"
}
```

## Coverage Goals

| Module | Target Coverage |
|--------|----------------|
| src/simulation/sim.py | 80% |
| src/city/city.py | 85% |
| src/city/city_manager.py | 80% |
| src/city/finance.py | 85% |
| src/city/population/ | 80% |

## CI Pipeline

When adding CI (e.g., GitHub Actions):

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: |
          ./init-venv.sh
          pip install -r requirements.txt
      - name: Run tests
        run: ./test.sh
```

## Anti-Patterns to Avoid

❌ **Flaky tests**
```python
# WRONG - non-deterministic
def test_random_behavior():
    if random.random() < 0.5:  # Will fail randomly!
        assert True
```

❌ **Test interdependence**
```python
# WRONG - test_2 depends on test_1
class BadTests(unittest.TestCase):
    def test_1_setup(self):
        self.shared = "data"
    
    def test_2_use_data(self):
        assert self.shared == "data"  # Fails if test_1 doesn't run first
```

❌ **Slow tests**
```python
# WRONG - makes test suite slow
def test_with_sleep():
    time.sleep(5)  # Never sleep in unit tests!
```

❌ **Testing implementation details**
```python
# WRONG - tests private methods
def test_private_method(self):
    assert obj._internal_method() == "value"
```

## Running Tests

### All Tests
```bash
./test.sh
```

### Specific Module
```bash
python -m unittest tests.core.test_city
```

### Single Test
```bash
python -m unittest tests.core.test_city.TestCity.test_add_water_facilities
```

### With Coverage
```bash
coverage run -m unittest discover
coverage report
coverage html  # Opens in browser
```

### With Verbose Output
```bash
python -m unittest discover -s tests -p '*test*.py' -v
```

## Integration Points

### With All Workstreams
You test the work of every workstream:
- **Simulation Core (01)**: Tick loop and determinism
- **City Modeling (02)**: State updates and invariants
- **Finance (03)**: Budget calculations
- **Population (04)**: Growth and happiness
- **UI (05)**: User interactions (if applicable)
- **Data & Logging (06)**: Log format validation
- **Performance (08)**: Benchmark tests
- **Traffic (10)**: Transport simulation

### With Documentation
Keep tests in sync with specs:
- When specs change, update tests
- When tests reveal issues, update specs
- Use specs as test oracles

## Quick Reference

### Test Commands
```bash
# Run all tests
./test.sh

# Run with coverage
coverage run -m unittest discover && coverage report

# Run specific test file
python -m unittest tests.core.test_city

# Run with type checking
pyright src/
```

## Documentation to Read

Start here:
1. **docs/design/workstreams/07-testing-ci.md** - This workstream's details
2. **.github/copilot-instructions-testing.md** - Testing guidelines
3. **docs/specs/** - All specs define what to test
4. **docs/adr/001-simulation-determinism.md** - Critical for test strategy

Remember: Quality code is tested code. Every feature needs tests. Determinism is non-negotiable.
