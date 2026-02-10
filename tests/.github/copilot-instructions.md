# Test Guidelines (tests/)

## Overview
All tests must be deterministic, isolated, and fast. Follow the patterns established in existing tests.

## Test Organization

### Directory Structure
- `tests/core/`: Unit tests for core modules
- `tests/integration/`: Integration tests (if added)
- `tests/fixtures/`: Shared test fixtures and data

### Naming Conventions
- Files: `test_<module>.py` or `Test<Module>.py`
- Classes: `Test<Feature>` or `<Module>Test`
- Methods: `test_<what>_<when>_<expected_outcome>`

## Test Principles

### Determinism
Every test must produce identical results on repeated runs:
```python
import random

class TestDeterministic(unittest.TestCase):
    def test_simulation_with_fixed_seed(self):
        """Simulation with same seed produces same results"""
        # Set seed explicitly
        random.seed(42)
        result1 = run_simulation(seed=42)
        
        random.seed(42)
        result2 = run_simulation(seed=42)
        
        self.assertEqual(result1, result2)
```

### Isolation
Each test must be independent:
```python
class TestIsolation(unittest.TestCase):
    def setUp(self):
        """Create fresh fixtures for each test"""
        self.city = City()
        self.sim = Sim(city=self.city)
    
    def tearDown(self):
        """Clean up after each test"""
        # Reset any global state if necessary
        pass
```

### Speed
Unit tests should run in milliseconds, not seconds:
- Mock expensive operations (I/O, network, etc.)
- Use small datasets
- Avoid sleeps and delays
- Keep tick counts low in simulation tests

## Test Patterns

### Unit Test Pattern
```python
import unittest
from src.city.city import City

class TestCity(unittest.TestCase):
    """Tests for City class"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.city = City()
    
    def test_add_water_facilities_increases_count(self):
        """Adding water facilities should increase the count"""
        initial = self.city.water_facilities
        self.city.add_water_facilities(5)
        self.assertEqual(self.city.water_facilities, initial + 5)
    
    def test_add_water_facilities_validates_input(self):
        """Adding negative facilities should raise ValueError"""
        with self.assertRaises(ValueError):
            self.city.add_water_facilities(-1)
```

### Determinism Test Pattern
```python
class TestSimulationDeterminism(unittest.TestCase):
    """Verify simulation determinism"""
    
    def test_repeated_runs_identical(self):
        """Same seed produces identical results"""
        results = []
        for _ in range(3):
            city = City()
            sim = Sim(city=city, seed=42)
            sim.run_ticks(10)
            results.append({
                'population': len(city.population),
                'happiness': city.happiness_tracker.get_average_happiness()
            })
        
        # All runs should be identical
        self.assertEqual(results[0], results[1])
        self.assertEqual(results[1], results[2])
```

### Invariant Test Pattern
```python
class TestCityInvariants(unittest.TestCase):
    """Verify city state invariants"""
    
    def test_population_non_negative(self):
        """Population should never go negative"""
        city = City()
        # Perform various operations
        city.advance_day()
        self.assertGreaterEqual(len(city.population), 0)
    
    def test_happiness_bounded(self):
        """Happiness should stay within valid range"""
        city = City()
        city.advance_day()
        happiness = city.happiness_tracker.get_average_happiness()
        self.assertGreaterEqual(happiness, 0)
        self.assertLessEqual(happiness, 100)
```

### Edge Case Test Pattern
```python
class TestEdgeCases(unittest.TestCase):
    """Test boundary conditions and edge cases"""
    
    def test_zero_population(self):
        """Handles zero population gracefully"""
        city = City(population=Population.from_list([]))
        # Should not crash
        city.advance_day()
    
    def test_maximum_capacity(self):
        """Handles capacity limits correctly"""
        city = City()
        city.housing_units = 10
        # Add more population than housing
        for _ in range(20):
            city.population.append(Pop())
        city.advance_day()
        # Verify only 10 have homes
        housed = sum(1 for p in city.population if p.has_home)
        self.assertEqual(housed, 10)
```

## Test Coverage Guidelines

### What to Test
✅ **Public APIs**: All public methods and functions
✅ **Invariants**: State constraints that must always hold
✅ **Edge cases**: Boundary conditions, empty inputs, max values
✅ **Error handling**: Invalid inputs, exceptions
✅ **Determinism**: Repeated runs with same seed
✅ **Integration points**: Subsystem interactions

### What Not to Test
❌ **Private implementation details**: Unless they're critical
❌ **Third-party libraries**: Trust the library's tests
❌ **Trivial getters/setters**: Unless they have logic
❌ **Generated code**: Like GUI code in generated/

## Assertions Best Practices

### Be Specific
```python
# WRONG - generic assertion
self.assertTrue(city.population > 0)

# CORRECT - specific assertion
self.assertGreater(len(city.population), 0)
```

### Use Appropriate Assertions
```python
# For equality
self.assertEqual(actual, expected)

# For approximations (floats)
self.assertAlmostEqual(actual, expected, places=2)

# For containers
self.assertIn(item, container)
self.assertListEqual(list1, list2)

# For exceptions
with self.assertRaises(ValueError):
    dangerous_operation()

# For boolean conditions
self.assertTrue(condition)
self.assertFalse(condition)

# For comparisons
self.assertGreater(a, b)
self.assertLess(a, b)
```

### Provide Clear Messages
```python
self.assertEqual(
    actual,
    expected,
    f"Population should be {expected} but got {actual}"
)
```

## Mock and Fixtures

### When to Mock
- External dependencies (file I/O, network)
- Slow operations
- Non-deterministic behavior (system time, unless seeded)

### Example Mocking
```python
from unittest.mock import Mock, patch

class TestWithMocks(unittest.TestCase):
    @patch('src.shared.settings.GlobalSettings.GLOBAL_LOGS_DIR')
    def test_with_mocked_path(self, mock_dir):
        """Test with mocked log directory"""
        mock_dir.return_value = "/tmp/test_logs"
        # Test code here
```

### Fixture Pattern
```python
class TestWithFixtures(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        """One-time setup for all tests in class"""
        cls.large_dataset = load_test_data()
    
    def setUp(self):
        """Per-test setup"""
        self.city = create_test_city()
    
    def tearDown(self):
        """Per-test cleanup"""
        cleanup_test_files()
```

## Running Tests

### Run All Tests
```bash
./test.sh
```

### Run Specific Test File
```bash
python -m unittest tests.core.test_city
```

### Run Specific Test Method
```bash
python -m unittest tests.core.test_city.TestCity.test_add_water_facilities
```

### Verbose Output
```bash
python -m unittest discover -s tests -p '*test*.py' -v
```

## Common Test Anti-Patterns

❌ **Tests depending on each other**
```python
# WRONG
class BadTests(unittest.TestCase):
    def test_1_setup(self):
        self.shared_state = setup()
    
    def test_2_use_state(self):
        # Depends on test_1 running first
        use(self.shared_state)
```

❌ **Non-deterministic assertions**
```python
# WRONG
self.assertTrue(random.random() < 0.5)  # Flaky!
```

❌ **Testing multiple things**
```python
# WRONG - tests multiple unrelated things
def test_everything(self):
    self.test_water()
    self.test_electricity()
    self.test_housing()
```

❌ **Sleeping in tests**
```python
# WRONG
time.sleep(1)  # Makes tests slow
```

## Test Documentation

Document complex test scenarios:
```python
def test_migration_with_low_happiness(self):
    """
    Test migration behavior when happiness drops below threshold.
    
    Scenario:
    1. Start with population of 100
    2. Remove all infrastructure
    3. Advance multiple days
    4. Verify population decreases due to migration
    
    Expected:
    - Population should decrease by ~50% over 10 days
    - Migration should be deterministic with fixed seed
    """
    # Test implementation
```

## References
- Testing Workstream: docs/design/workstreams/07-testing-ci.md
- Contributing Guide: docs/guides/contributing.md
- Main Instructions: ../.github/copilot-instructions.md
