# Test Automation Patterns and Frameworks

## Purpose
This document describes common test automation patterns, frameworks, and best practices for the City-Sim project. These patterns help create maintainable, efficient, and robust test suites.

## Test Automation Principles

### Automation Goals
1. **Repeatability**: Tests produce consistent results
2. **Speed**: Automated tests run faster than manual tests
3. **Coverage**: Automated tests cover critical functionality
4. **Maintainability**: Tests are easy to understand and update
5. **Reliability**: Tests fail only when code is broken

### When to Automate
✅ **Automate**:
- Regression tests for critical functionality
- Frequently executed test scenarios
- Tests that are time-consuming to run manually
- Tests that require precise timing or setup
- Tests with large data sets

❌ **Don't Automate** (or automate carefully):
- Exploratory testing
- Usability testing
- One-time verification tests
- Tests where automation cost exceeds benefit

## Common Test Patterns

### 1. Arrange-Act-Assert (AAA) Pattern
The foundation of clear, maintainable tests:

```python
def test_city_budget_calculation(self):
    """Test budget calculation using AAA pattern."""
    
    # Arrange: Set up test conditions
    city = City()
    city.budget = 10000
    revenue = 5000
    expenses = 3000
    
    # Act: Execute the operation being tested
    city.process_finances(revenue, expenses)
    
    # Assert: Verify the result
    expected_budget = 10000 + 5000 - 3000
    self.assertEqual(city.budget, expected_budget)
```

### 2. Test Fixture Pattern
Reusable test setup and teardown:

```python
class TestCityWithFixtures(unittest.TestCase):
    """Tests using fixture pattern."""
    
    def setUp(self):
        """Set up test fixtures before each test."""
        self.seed = 42
        self.city = self.create_default_city()
        self.city_manager = CityManager(self.city)
    
    def tearDown(self):
        """Clean up after each test."""
        # Clean up resources
        pass
    
    def create_default_city(self):
        """Factory method for creating test cities."""
        city = City()
        city.budget = 10000
        city.population = Population.from_count(100, seed=self.seed)
        return city
    
    def test_something(self):
        """Test using fixtures."""
        # Fixtures available as self.city, self.city_manager
        pass
```

### 3. Builder Pattern
Fluent API for creating complex test objects:

```python
class CityBuilder:
    """Builder for creating test cities."""
    
    def __init__(self):
        self._city = City()
    
    def with_population(self, count):
        self._city.population = Population.from_count(count)
        return self
    
    def with_budget(self, amount):
        self._city.budget = amount
        return self
    
    def with_infrastructure(self, water=0, electricity=0):
        self._city.water_facilities = water
        self._city.electricity_infrastructure = electricity
        return self
    
    def build(self):
        return self._city

# Usage
def test_with_builder(self):
    city = (CityBuilder()
            .with_population(1000)
            .with_budget(50000)
            .with_infrastructure(water=5, electricity=3)
            .build())
    
    # Test with configured city
```

### 4. Object Mother Pattern
Centralized creation of test objects:

```python
# tests/fixtures/object_mother.py
class CityMother:
    """Factory for creating common test cities."""
    
    @staticmethod
    def small_growing_city():
        """Create a small city in growth phase."""
        city = City()
        city.population = Population.from_count(500)
        city.budget = 25000
        city.water_facilities = 3
        city.happiness_tracker.average_happiness = 75
        return city
    
    @staticmethod
    def large_stable_city():
        """Create a large, stable city."""
        city = City()
        city.population = Population.from_count(5000)
        city.budget = 200000
        city.water_facilities = 20
        city.electricity_infrastructure = 15
        city.happiness_tracker.average_happiness = 80
        return city
    
    @staticmethod
    def struggling_city():
        """Create a city facing challenges."""
        city = City()
        city.population = Population.from_count(1000)
        city.budget = 5000
        city.water_facilities = 1
        city.happiness_tracker.average_happiness = 45
        return city

# Usage
def test_with_object_mother(self):
    city = CityMother.struggling_city()
    # Test struggling city scenario
```

### 5. Parameterized Test Pattern
Run same test with different inputs:

```python
import unittest
from parameterized import parameterized

class TestPopulationGrowth(unittest.TestCase):
    """Parameterized population growth tests."""
    
    @parameterized.expand([
        ("small_city", 100, 0.02),
        ("medium_city", 1000, 0.015),
        ("large_city", 5000, 0.01),
    ])
    def test_growth_rate_scales_with_size(self, name, initial_pop, expected_rate):
        """Growth rate should scale with city size."""
        city = City()
        city.population = Population.from_count(initial_pop)
        
        growth_rate = city.calculate_growth_rate()
        
        self.assertAlmostEqual(growth_rate, expected_rate, places=3)
```

### 6. Mock Object Pattern
Isolate units under test:

```python
from unittest.mock import Mock, patch, MagicMock

class TestWithMocks(unittest.TestCase):
    """Tests using mock objects."""
    
    def test_city_manager_delegates_to_finance(self):
        """CityManager should delegate finance operations."""
        # Create mock finance manager
        mock_finance = Mock()
        mock_finance.calculate_revenue.return_value = 5000
        
        city_manager = CityManager(City())
        city_manager.finance_manager = mock_finance
        
        # Perform action
        city_manager.update()
        
        # Verify mock was called
        mock_finance.calculate_revenue.assert_called_once()
    
    @patch('src.city.city_manager.FinanceManager')
    def test_with_patched_dependency(self, mock_finance_class):
        """Test with patched dependency."""
        mock_finance_class.return_value = Mock()
        
        city_manager = CityManager(City())
        # Test with mocked FinanceManager
```

### 7. Test Double Pattern
Various types of test doubles:

```python
class StubRandomService:
    """Stub for RandomService that returns fixed values."""
    
    def randint(self, a, b):
        return (a + b) // 2  # Always return midpoint
    
    def uniform(self, a, b):
        return (a + b) / 2  # Always return midpoint

class FakeDatabase:
    """Fake database for testing without real DB."""
    
    def __init__(self):
        self.data = {}
    
    def save(self, key, value):
        self.data[key] = value
    
    def load(self, key):
        return self.data.get(key)

# Usage
def test_with_stub(self):
    stub_random = StubRandomService()
    city = City(random_service=stub_random)
    # Test with predictable random behavior
```

### 8. Page Object Pattern (for GUI Testing)
Encapsulate UI structure:

```python
class CityViewPage:
    """Page object for city view."""
    
    def __init__(self, driver):
        self.driver = driver
    
    @property
    def population_display(self):
        return self.driver.find_element_by_id('population')
    
    @property
    def budget_display(self):
        return self.driver.find_element_by_id('budget')
    
    def click_build_water_facility(self):
        button = self.driver.find_element_by_id('build_water')
        button.click()
    
    def get_population(self):
        return int(self.population_display.text)

# Usage
def test_gui_with_page_object(self):
    page = CityViewPage(self.driver)
    
    initial_population = page.get_population()
    page.click_build_water_facility()
    # Verify UI updated
```

## Test Organization Patterns

### 1. Test Class per Class Pattern
One test class per production class:

```python
# src/city/city.py
class City:
    pass

# tests/city/test_city.py
class TestCity(unittest.TestCase):
    """Tests for City class."""
    pass
```

### 2. Test Class per Feature Pattern
Group tests by feature:

```python
class TestCityGrowth(unittest.TestCase):
    """Tests for city growth features."""
    pass

class TestCityFinance(unittest.TestCase):
    """Tests for city finance features."""
    pass

class TestCityInfrastructure(unittest.TestCase):
    """Tests for city infrastructure features."""
    pass
```

### 3. Test Suite Pattern
Organize related tests into suites:

```python
def city_test_suite():
    """Create suite of all city tests."""
    suite = unittest.TestSuite()
    suite.addTests(unittest.TestLoader().loadTestsFromTestCase(TestCity))
    suite.addTests(unittest.TestLoader().loadTestsFromTestCase(TestCityGrowth))
    suite.addTests(unittest.TestLoader().loadTestsFromTestCase(TestCityFinance))
    return suite

def run_city_tests():
    """Run all city tests."""
    runner = unittest.TextTestRunner(verbosity=2)
    runner.run(city_test_suite())
```

## Data-Driven Testing

### CSV Data-Driven Tests
```python
import csv

class TestDataDriven(unittest.TestCase):
    """Data-driven tests from CSV."""
    
    def test_growth_scenarios_from_csv(self):
        """Test multiple growth scenarios from CSV data."""
        with open('tests/data/growth_scenarios.csv', 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                with self.subTest(scenario=row['scenario']):
                    initial_pop = int(row['initial_population'])
                    expected_pop = int(row['expected_population'])
                    
                    city = City()
                    city.population = Population.from_count(initial_pop)
                    
                    for _ in range(30):
                        city.advance_day()
                    
                    self.assertAlmostEqual(
                        len(city.population),
                        expected_pop,
                        delta=10
                    )
```

### JSON Data-Driven Tests
```python
import json

class TestJsonDataDriven(unittest.TestCase):
    """Data-driven tests from JSON."""
    
    def test_scenarios_from_json(self):
        """Test scenarios defined in JSON."""
        with open('tests/data/test_scenarios.json', 'r') as f:
            scenarios = json.load(f)
        
        for scenario in scenarios:
            with self.subTest(name=scenario['name']):
                city = City.from_dict(scenario['initial_state'])
                
                # Run scenario
                for _ in range(scenario['duration']):
                    city.advance_day()
                
                # Verify expected outcome
                for key, expected in scenario['expected'].items():
                    actual = getattr(city, key)
                    self.assertEqual(actual, expected)
```

## Test Helpers and Utilities

### Custom Assertions
```python
class CityTestCase(unittest.TestCase):
    """Base test case with custom city assertions."""
    
    def assertPopulationInRange(self, city, min_pop, max_pop, msg=None):
        """Assert population is within expected range."""
        actual = len(city.population)
        if not (min_pop <= actual <= max_pop):
            msg = msg or f"Population {actual} not in range [{min_pop}, {max_pop}]"
            raise AssertionError(msg)
    
    def assertBudgetPositive(self, city, msg=None):
        """Assert city budget is positive."""
        if city.budget <= 0:
            msg = msg or f"Budget {city.budget} is not positive"
            raise AssertionError(msg)
    
    def assertHappinessAbove(self, city, threshold, msg=None):
        """Assert happiness is above threshold."""
        happiness = city.happiness_tracker.get_average_happiness()
        if happiness <= threshold:
            msg = msg or f"Happiness {happiness} not above {threshold}"
            raise AssertionError(msg)

# Usage
class TestCity(CityTestCase):
    def test_growth(self):
        city = City()
        # Use custom assertions
        self.assertPopulationInRange(city, 90, 110)
        self.assertBudgetPositive(city)
```

### Test Utilities
```python
# tests/utils/test_helpers.py

def run_simulation_for_ticks(city_manager, ticks, seed=42):
    """Helper to run simulation for specified ticks."""
    random.seed(seed)
    for _ in range(ticks):
        city_manager.update()

def assert_budget_reconciles(test_case, city, prev_budget, revenue, expenses):
    """Helper to assert budget reconciliation."""
    expected = prev_budget + revenue - expenses
    test_case.assertAlmostEqual(city.budget, expected, places=2)

def create_city_snapshot(city):
    """Create snapshot of city state for comparison."""
    return {
        'population': len(city.population),
        'budget': city.budget,
        'water_facilities': city.water_facilities,
        'happiness': city.happiness_tracker.get_average_happiness()
    }

def compare_city_snapshots(test_case, snapshot1, snapshot2):
    """Compare two city snapshots."""
    for key in snapshot1:
        test_case.assertEqual(
            snapshot1[key],
            snapshot2[key],
            f"Mismatch in {key}"
        )
```

## Performance Testing Patterns

### Timing Tests
```python
import time

class TestPerformance(unittest.TestCase):
    """Performance tests."""
    
    def test_tick_performance(self):
        """Tick should complete within time limit."""
        city_manager = CityManager(CityMother.large_stable_city())
        
        start = time.perf_counter()
        city_manager.update()
        elapsed = time.perf_counter() - start
        
        self.assertLess(elapsed, 0.1, f"Tick took {elapsed:.3f}s")
    
    def test_batch_performance(self):
        """Batch of 100 ticks should complete within time limit."""
        city_manager = CityManager(City())
        
        start = time.perf_counter()
        for _ in range(100):
            city_manager.update()
        elapsed = time.perf_counter() - start
        
        self.assertLess(elapsed, 5.0, f"100 ticks took {elapsed:.3f}s")
```

### Memory Tests
```python
import tracemalloc

class TestMemory(unittest.TestCase):
    """Memory usage tests."""
    
    def test_memory_usage_stable(self):
        """Memory usage should not grow unbounded."""
        city_manager = CityManager(City())
        
        tracemalloc.start()
        initial = tracemalloc.get_traced_memory()[0]
        
        # Run many ticks
        for _ in range(1000):
            city_manager.update()
        
        current, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        
        growth = (current - initial) / initial
        self.assertLess(growth, 0.1, f"Memory grew by {growth:.1%}")
```

## Continuous Integration Patterns

### Test Tags and Categories
```python
import unittest

class TestFast(unittest.TestCase):
    """Fast-running tests for quick feedback."""
    pass

class TestSlow(unittest.TestCase):
    """Slow-running tests for comprehensive validation."""
    
    @unittest.skipIf(os.getenv('QUICK_TEST'), 'Skipping slow test')
    def test_long_simulation(self):
        """Long-running simulation test."""
        pass

class TestNightly(unittest.TestCase):
    """Nightly regression tests."""
    
    @unittest.skipUnless(os.getenv('NIGHTLY_BUILD'), 'Nightly test only')
    def test_comprehensive_scenario(self):
        """Comprehensive test for nightly builds."""
        pass
```

### Test Retry Pattern
```python
from functools import wraps

def retry_on_failure(retries=3):
    """Decorator to retry flaky tests."""
    def decorator(test_func):
        @wraps(test_func)
        def wrapper(*args, **kwargs):
            for attempt in range(retries):
                try:
                    return test_func(*args, **kwargs)
                except AssertionError:
                    if attempt == retries - 1:
                        raise
                    print(f"Test failed, retrying ({attempt + 1}/{retries})")
            return None
        return wrapper
    return decorator

# Usage (use sparingly!)
class TestWithRetry(unittest.TestCase):
    @retry_on_failure(retries=3)
    def test_potentially_flaky(self):
        """Test that might be flaky."""
        pass
```

## Breadcrumbs for Documentation Reconciliation

**ATTENTION - Top-Level Docs Agent**:
These test automation patterns integrate with:
1. Main testing guidelines
2. CI/CD pipeline configuration
3. Code quality standards
4. Development workflow

**Key Integration Points**:
- Pattern adoption in test codebase
- CI/CD test execution strategy
- Code review checklist for tests
- Team training on patterns

**Open Items**:
1. Establish standard patterns for team adoption
2. Create pattern templates and examples
3. Document anti-patterns to avoid
4. Set up pattern linting/enforcement
5. Create pattern migration guides
6. Develop pattern selection guidelines

## References

### Internal Documentation
- Test Copilot Instructions: `../.github/copilot-instructions.md`
- Integration Test Strategy: `integration-test-strategy.md`
- Test Data Management: `test-data-management.md`

### External Resources
- xUnit Test Patterns: http://xunitpatterns.com/
- Martin Fowler's Test Patterns
- Python unittest documentation

---

**Document Version**: 1.0
**Last Updated**: 2024
**Maintainer**: Testing Team
**Review Cycle**: Quarterly
