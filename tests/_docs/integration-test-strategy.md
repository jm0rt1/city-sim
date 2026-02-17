# Integration Test Strategy

## Purpose
This document outlines the strategy for integration testing in the City-Sim project. Integration tests verify that multiple subsystems work together correctly, ensuring that interfaces between components are properly implemented and that data flows correctly through the system.

## Scope of Integration Tests

### What Integration Tests Verify
1. **Subsystem Interactions**: How City, Finance, Population, Traffic, and other subsystems communicate
2. **Data Flow**: Correct propagation of state changes across subsystem boundaries
3. **Event Handling**: Proper handling of events that affect multiple subsystems
4. **Contract Compliance**: Adherence to interface contracts between modules
5. **Determinism**: Consistent behavior across subsystem interactions with fixed seeds

### What Integration Tests Do NOT Cover
- Internal implementation details of individual subsystems (covered by unit tests)
- Complete end-to-end scenarios (covered by system tests)
- Performance characteristics (covered by performance tests)
- UI/GUI functionality (covered by UI tests)

## Integration Test Categories

### 1. Finance-City Integration
**Purpose**: Verify that financial operations correctly update city state

**Key Test Scenarios**:
- Budget calculations affect infrastructure development decisions
- Tax policy changes propagate to revenue calculations
- Infrastructure costs are properly deducted from city budget
- Revenue from facilities is correctly added to budget

**Example Test**:
```python
class TestFinanceCityIntegration(unittest.TestCase):
    def test_infrastructure_construction_deducts_budget(self):
        """Building infrastructure should reduce available budget."""
        city = City(initial_budget=10000)
        finance = FinanceManager(city)
        
        initial_budget = city.budget
        construction_cost = 5000
        
        city.build_water_facility(cost=construction_cost)
        finance.process_expenses()
        
        expected_budget = initial_budget - construction_cost
        self.assertEqual(city.budget, expected_budget)
```

### 2. Population-Happiness Integration
**Purpose**: Ensure population dynamics correctly reflect happiness levels

**Key Test Scenarios**:
- Low happiness triggers population migration
- High happiness attracts new residents
- Infrastructure availability affects happiness calculations
- Happiness changes propagate to population growth rates

**Example Test**:
```python
class TestPopulationHappinessIntegration(unittest.TestCase):
    def test_low_happiness_triggers_migration(self):
        """Population should decrease when happiness is low."""
        city = City()
        population = Population(initial_size=1000)
        happiness_tracker = HappinessTracker(city)
        
        # Create unhappy conditions
        city.water_facilities = 0
        city.electricity_infrastructure = 0
        
        happiness_tracker.update()
        initial_happiness = happiness_tracker.get_average_happiness()
        self.assertLess(initial_happiness, 50)
        
        # Advance population with migration enabled
        for _ in range(10):
            population.update(happiness=happiness_tracker.get_average_happiness())
        
        self.assertLess(len(population), 1000)
```

### 3. City-Traffic Integration
**Purpose**: Verify that city development affects traffic patterns

**Key Test Scenarios**:
- Population growth increases traffic demand
- Infrastructure development creates new traffic routes
- Congestion affects city happiness and productivity
- Traffic policy changes affect city metrics

**Example Test**:
```python
class TestCityTrafficIntegration(unittest.TestCase):
    def test_population_growth_increases_traffic(self):
        """Growing population should increase traffic volume."""
        city = City()
        traffic_manager = TrafficManager(city)
        
        city.population = 1000
        traffic_manager.update()
        initial_traffic = traffic_manager.get_traffic_volume()
        
        city.population = 5000
        traffic_manager.update()
        final_traffic = traffic_manager.get_traffic_volume()
        
        self.assertGreater(final_traffic, initial_traffic)
```

### 4. Multi-Subsystem Integration
**Purpose**: Test scenarios involving three or more subsystems

**Key Test Scenarios**:
- City growth cycle: Population → Happiness → Finance → Infrastructure → Traffic
- Policy implementation: Decision → Finance → Population → City state
- Disaster scenarios: Event → Multiple subsystem responses → Recovery
- Seasonal effects: Time → Multiple subsystems adjust

**Example Test**:
```python
class TestMultiSubsystemIntegration(unittest.TestCase):
    def test_complete_city_growth_cycle(self):
        """Complete growth cycle should propagate through all subsystems."""
        city = City(initial_budget=100000, initial_population=500)
        city_manager = CityManager(city)
        
        # Run multiple ticks
        for _ in range(50):
            city_manager.update()
        
        # Verify integrated state changes
        self.assertGreater(len(city.population), 500, "Population should grow")
        self.assertGreater(city.water_facilities, 0, "Infrastructure should develop")
        self.assertNotEqual(city.budget, 100000, "Budget should change")
        self.assertIsNotNone(city.traffic_state, "Traffic should be tracked")
```

## Test Data Management

### Fixture Strategy
1. **Minimal Fixtures**: Use smallest data sets that demonstrate integration
2. **Realistic Scenarios**: Base fixtures on actual game scenarios
3. **Deterministic Data**: All test data must be reproducible
4. **Shared Fixtures**: Reuse common setups across related tests

### Fixture Organization
```
tests/fixtures/
├── cities/
│   ├── small_city.json          # Minimal city for basic tests
│   ├── medium_city.json         # Mid-sized city for growth tests
│   └── large_city.json          # Large city for stress tests
├── scenarios/
│   ├── growth_scenario.json     # Rapid growth conditions
│   ├── decline_scenario.json    # City decline conditions
│   └── stable_scenario.json     # Steady-state conditions
└── configurations/
    ├── high_revenue.json        # High tax/revenue config
    ├── low_happiness.json       # Low happiness conditions
    └── traffic_congestion.json  # High traffic scenario
```

## Test Execution Strategy

### Test Ordering
1. **Independent Execution**: Each test must run independently
2. **No Shared State**: Tests must not depend on execution order
3. **Clean Slate**: Each test starts with fresh fixtures

### Test Isolation
```python
class TestIntegrationBase(unittest.TestCase):
    """Base class for integration tests with proper isolation."""
    
    def setUp(self):
        """Create fresh instances for each test."""
        self.city = City()
        self.city_manager = CityManager(self.city)
        # Initialize other subsystems
    
    def tearDown(self):
        """Clean up after each test."""
        # Release resources
        # Reset any global state
        pass
```

### Performance Considerations
- Integration tests may take longer than unit tests (acceptable)
- Target: Each integration test < 1 second
- Complex multi-tick scenarios: < 5 seconds
- Mark slow tests with `@unittest.skipIf` for quick runs

## Determinism Requirements

### Seeding Strategy
All integration tests must use explicit seeds:
```python
def test_with_deterministic_behavior(self):
    """Test must be reproducible."""
    seed = 42
    
    # First run
    city1 = City()
    city_manager1 = CityManager(city1, seed=seed)
    for _ in range(10):
        city_manager1.update()
    result1 = city1.population
    
    # Second run
    city2 = City()
    city_manager2 = CityManager(city2, seed=seed)
    for _ in range(10):
        city_manager2.update()
    result2 = city2.population
    
    self.assertEqual(result1, result2)
```

### Avoiding Non-Deterministic Behavior
❌ **Avoid**:
- `time.time()` or `datetime.now()` without mocking
- Uncontrolled random number generation
- File system operations with timestamps
- Network calls
- System-dependent behavior

✅ **Use**:
- Fixed seeds for random number generation
- Mocked time sources
- Deterministic file operations
- In-memory data structures
- Platform-independent code

## Error Handling and Edge Cases

### Integration Test Edge Cases
1. **Boundary Conditions**: Test limits of subsystem interactions
2. **Null/Empty States**: Handle missing or zero-value data
3. **Overflow Scenarios**: Test extreme values and overflow conditions
4. **Cascade Failures**: Verify graceful degradation
5. **Recovery Scenarios**: Test system recovery from errors

### Example Edge Case Test
```python
def test_zero_budget_prevents_construction(self):
    """City with zero budget should not be able to build."""
    city = City(initial_budget=0)
    city_manager = CityManager(city)
    
    initial_facilities = city.water_facilities
    
    # Attempt construction
    try:
        city_manager.build_infrastructure('water')
    except InsufficientFundsError:
        pass  # Expected
    
    # Verify no construction occurred
    self.assertEqual(city.water_facilities, initial_facilities)
```

## Test Coverage Goals

### Integration Test Coverage
- **Subsystem Interfaces**: 100% of public interfaces between subsystems
- **Data Flow Paths**: All critical data transformation paths
- **Event Handlers**: All cross-subsystem event handling
- **Common Scenarios**: Top 20 most common gameplay scenarios

### Coverage Metrics
```bash
# Run integration tests with coverage
coverage run -m unittest discover -s tests/integration
coverage report --include="src/city/*,src/simulation/*"
coverage html
```

## Continuous Integration

### CI Pipeline Integration
Integration tests should run:
1. On every pull request
2. Before merging to main branch
3. Nightly for full regression suite
4. On release candidates

### CI Configuration Example
```yaml
# .github/workflows/integration-tests.yml
name: Integration Tests
on: [pull_request, push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.12'
      - name: Install dependencies
        run: pip install -r requirements.txt
      - name: Run integration tests
        run: python -m unittest discover -s tests/integration
```

## Test Maintenance

### Keeping Tests Healthy
1. **Regular Review**: Review and update tests quarterly
2. **Refactor with Code**: Update tests when refactoring production code
3. **Remove Obsolete Tests**: Delete tests for removed features
4. **Update Fixtures**: Keep test data current with schema changes

### Test Smells to Avoid
- Tests that take too long (> 5 seconds)
- Tests with unclear purpose or names
- Tests that fail intermittently
- Tests with complex setup or teardown
- Tests that test too much at once

## Future Enhancements

### Planned Improvements
1. **Test Data Builder Pattern**: Fluent API for creating test scenarios
2. **Integration Test DSL**: Domain-specific language for scenario description
3. **Visual Test Reports**: Graphical representation of integration paths
4. **Automated Test Generation**: Generate tests from interface specifications
5. **Parallel Execution**: Run independent integration tests concurrently

### Free-Threaded Python Considerations
When Python 3.13+ with free-threaded execution is adopted:
1. Add concurrency integration tests
2. Verify thread-safety of subsystem interactions
3. Test race conditions and synchronization
4. Validate determinism in parallel execution
5. Performance test multi-threaded scenarios

## Examples and Templates

### Integration Test Template
```python
"""
Integration tests for [Subsystem A] and [Subsystem B].

This module tests the interactions between [Subsystem A] and [Subsystem B],
ensuring that [key integration requirement].
"""
import unittest
from src.city.city import City
# Import other required modules

class Test[SubsystemA][SubsystemB]Integration(unittest.TestCase):
    """Test [SubsystemA] and [SubsystemB] integration."""
    
    def setUp(self):
        """Set up test fixtures for integration testing."""
        self.seed = 42
        self.city = City()
        # Initialize subsystems
    
    def tearDown(self):
        """Clean up after tests."""
        pass
    
    def test_[scenario]_[expected_outcome](self):
        """
        Test that [scenario description].
        
        Given: [initial state]
        When: [action or event]
        Then: [expected result]
        """
        # Arrange
        # Act
        # Assert
        pass

if __name__ == '__main__':
    unittest.main()
```

## References and Resources

### Internal Documentation
- System Architecture: `../../docs/architecture/overview.md`
- Module Specifications: `../../docs/specs/`
- Testing Workstream: `../../docs/design/workstreams/07-testing-ci.md`
- Unit Test Guidelines: `../.github/copilot-instructions.md`

### External Resources
- Python unittest documentation: https://docs.python.org/3/library/unittest.html
- Martin Fowler on Integration Testing: https://martinfowler.com/articles/integration-test.html
- Test Pyramid concept: https://martinfowler.com/bliki/TestPyramid.html

## Breadcrumbs for Top-Level Documentation

**ATTENTION - Docs Reconciliation Agent**:
This integration test strategy should be aligned with:
1. Overall testing strategy in main docs
2. CI/CD pipeline configuration
3. Quality gates and release criteria
4. Development workflow documentation

**Key Integration Points**:
- Testing Workstream (WS-07): Implementation of integration test framework
- CI/CD Setup: Automated execution of integration tests
- Code Review Process: Integration test requirements for new features
- Release Checklist: Integration test pass requirement

**Open Items**:
1. Define integration test coverage thresholds
2. Establish integration test execution time limits
3. Create integration test data generation tools
4. Set up integration test result visualization
5. Define integration test failure triage process
