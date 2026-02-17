# Test Data Management Guidelines

## Purpose
This document provides comprehensive guidelines for managing test data in the City-Sim project, ensuring that tests are reproducible, maintainable, and efficient.

## Principles of Test Data Management

### Core Principles
1. **Determinism**: All test data must produce reproducible results
2. **Minimalism**: Use the smallest dataset that validates the requirement
3. **Realism**: Test data should reflect actual game scenarios
4. **Isolation**: Test data should not depend on external sources
5. **Maintainability**: Test data should be easy to understand and update

### Anti-Patterns to Avoid
❌ **Large Datasets**: Avoid unnecessarily large test datasets
❌ **External Dependencies**: Never rely on external APIs or databases for test data
❌ **Non-Deterministic Data**: Avoid time-based or random test data without seeds
❌ **Production Data**: Never use production data in tests
❌ **Hardcoded Paths**: Avoid absolute file paths in test data

## Test Data Organization

### Directory Structure
```
tests/
├── data/
│   ├── scenarios/              # Complete scenario configurations
│   │   ├── new_city.json
│   │   ├── economic_crisis.json
│   │   └── rapid_expansion.json
│   ├── cities/                 # City state snapshots
│   │   ├── small_city.json
│   │   ├── medium_city.json
│   │   └── large_city.json
│   ├── configurations/         # Policy and configuration files
│   │   ├── high_tax.json
│   │   ├── low_tax.json
│   │   └── aggressive_growth.json
│   ├── expected/               # Expected test outcomes
│   │   ├── new_city_day_30.json
│   │   └── growth_trajectory.json
│   └── fixtures/               # Shared test fixtures
│       ├── base_city.json
│       └── default_settings.json
├── fixtures/                   # Python fixture modules
│   ├── __init__.py
│   ├── city_fixtures.py
│   ├── population_fixtures.py
│   └── finance_fixtures.py
```

## Test Data Formats

### JSON Format (Preferred)
Use JSON for configuration and state data:

```json
{
  "city_name": "Test City",
  "population": 1000,
  "budget": 50000,
  "infrastructure": {
    "water_facilities": 5,
    "electricity_units": 3,
    "roads": 10
  },
  "policies": {
    "tax_rate": 0.15,
    "infrastructure_spending_ratio": 0.25
  },
  "metadata": {
    "seed": 42,
    "created_for_test": "test_city_growth",
    "description": "Baseline city for growth tests"
  }
}
```

### CSV Format (for Tabular Data)
Use CSV for time-series or tabular data:

```csv
tick,population,budget,happiness,water_facilities
0,100,10000,70,0
10,110,9500,72,1
20,125,9800,74,1
30,145,11000,76,2
```

### Python Fixtures (for Complex Objects)
Use Python fixtures for complex object creation:

```python
# tests/fixtures/city_fixtures.py
from src.city.city import City
from src.city.population.population import Population

def create_small_city(seed=42):
    """Create a small test city with basic infrastructure."""
    city = City()
    city.population = Population.from_count(500, seed=seed)
    city.budget = 25000
    city.water_facilities = 3
    city.electricity_infrastructure = 2
    return city

def create_medium_city(seed=42):
    """Create a medium test city with moderate infrastructure."""
    city = City()
    city.population = Population.from_count(2000, seed=seed)
    city.budget = 100000
    city.water_facilities = 10
    city.electricity_infrastructure = 8
    city.roads = 50
    return city
```

## Test Data Lifecycle

### Creation
```python
class TestCityGrowth(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        """One-time data setup for all tests in class."""
        cls.baseline_city_data = load_test_data('cities/small_city.json')
    
    def setUp(self):
        """Per-test data setup."""
        self.city = City.from_dict(self.baseline_city_data.copy())
        self.seed = 42
```

### Usage
```python
def test_city_growth(self):
    """Test city growth using fixture data."""
    # Use immutable test data
    expected_growth = load_test_data('expected/growth_trajectory.json')
    
    # Run simulation
    for _ in range(30):
        self.city.advance_day()
    
    # Compare with expected
    self.assertAlmostEqual(
        len(self.city.population),
        expected_growth['day_30']['population'],
        delta=10  # Allow 10 population variance
    )
```

### Cleanup
```python
def tearDown(self):
    """Clean up test data."""
    # No cleanup needed for immutable data
    pass

@classmethod
def tearDownClass(cls):
    """One-time cleanup after all tests."""
    # Clean up any shared resources
    pass
```

## Test Data Builders

### Builder Pattern for Test Data
Create fluent builders for complex test data:

```python
# tests/fixtures/city_builder.py
class CityBuilder:
    """Builder for creating test cities with fluent interface."""
    
    def __init__(self):
        self._population = 0
        self._budget = 0
        self._water_facilities = 0
        self._seed = 42
    
    def with_population(self, count):
        self._population = count
        return self
    
    def with_budget(self, amount):
        self._budget = amount
        return self
    
    def with_water_facilities(self, count):
        self._water_facilities = count
        return self
    
    def with_seed(self, seed):
        self._seed = seed
        return self
    
    def build(self):
        """Build and return the configured city."""
        city = City()
        city.population = Population.from_count(self._population, seed=self._seed)
        city.budget = self._budget
        city.water_facilities = self._water_facilities
        return city

# Usage in tests
def test_with_builder(self):
    city = (CityBuilder()
            .with_population(1000)
            .with_budget(50000)
            .with_water_facilities(5)
            .with_seed(42)
            .build())
    
    self.assertEqual(len(city.population), 1000)
```

## Fixture Management

### Shared Fixtures
Define shared fixtures for common test scenarios:

```python
# tests/fixtures/__init__.py
import json
from pathlib import Path

FIXTURES_DIR = Path(__file__).parent.parent / 'data'

def load_fixture(filename):
    """Load a test fixture from JSON file."""
    filepath = FIXTURES_DIR / filename
    with open(filepath, 'r') as f:
        return json.load(f)

def save_fixture(data, filename):
    """Save test data as a fixture for future use."""
    filepath = FIXTURES_DIR / filename
    filepath.parent.mkdir(parents=True, exist_ok=True)
    with open(filepath, 'w') as f:
        json.dump(data, f, indent=2)

# Common fixtures
def get_default_city():
    """Get default city configuration."""
    return load_fixture('cities/small_city.json')

def get_default_scenario():
    """Get default scenario configuration."""
    return load_fixture('scenarios/new_city.json')
```

### Fixture Inheritance
Create fixture hierarchies for related tests:

```python
class CityTestBase(unittest.TestCase):
    """Base class with common fixtures for city tests."""
    
    def setUp(self):
        """Set up common city test fixtures."""
        self.seed = 42
        self.default_budget = 10000
        self.default_population = 100
        
        self.city = self.create_test_city()
    
    def create_test_city(self, **overrides):
        """Create a test city with optional parameter overrides."""
        city = City()
        city.budget = overrides.get('budget', self.default_budget)
        city.population = Population.from_count(
            overrides.get('population', self.default_population),
            seed=self.seed
        )
        return city

class TestCityGrowth(CityTestBase):
    """Growth tests inherit common city fixtures."""
    
    def test_growth_increases_population(self):
        """Test that growth increases population."""
        initial_pop = len(self.city.population)
        # Test implementation
```

## Deterministic Test Data

### Seeded Random Data
Always use seeds for random test data:

```python
def generate_test_population(count, seed=42):
    """Generate deterministic test population."""
    random.seed(seed)
    population = []
    
    for i in range(count):
        person = {
            'id': i,
            'age': random.randint(18, 80),
            'happiness': random.uniform(50, 100),
            'income': random.randint(20000, 100000)
        }
        population.append(person)
    
    return population

# Usage
def test_with_seeded_data(self):
    # This will always produce the same population
    pop1 = generate_test_population(100, seed=42)
    pop2 = generate_test_population(100, seed=42)
    
    self.assertEqual(pop1, pop2)
```

### Reproducible Sequences
Create reproducible sequences for time-based tests:

```python
def generate_revenue_sequence(length, seed=42):
    """Generate deterministic revenue sequence."""
    random.seed(seed)
    base_revenue = 10000
    
    revenues = []
    for _ in range(length):
        variance = random.uniform(-0.1, 0.1)
        revenue = base_revenue * (1 + variance)
        revenues.append(revenue)
    
    return revenues
```

## Test Data Validation

### Schema Validation
Validate test data against schemas:

```python
import jsonschema

CITY_SCHEMA = {
    "type": "object",
    "required": ["population", "budget"],
    "properties": {
        "population": {"type": "integer", "minimum": 0},
        "budget": {"type": "number"},
        "infrastructure": {
            "type": "object",
            "properties": {
                "water_facilities": {"type": "integer", "minimum": 0},
                "electricity_units": {"type": "integer", "minimum": 0}
            }
        }
    }
}

def validate_city_data(city_data):
    """Validate city test data against schema."""
    try:
        jsonschema.validate(instance=city_data, schema=CITY_SCHEMA)
        return True
    except jsonschema.ValidationError as e:
        print(f"Invalid city data: {e.message}")
        return False

# Use in tests
def test_with_validation(self):
    city_data = load_fixture('cities/small_city.json')
    self.assertTrue(validate_city_data(city_data))
```

### Data Integrity Checks
Verify test data integrity:

```python
def verify_test_data_integrity():
    """Verify all test data files are valid and complete."""
    fixtures_dir = Path('tests/data')
    
    for json_file in fixtures_dir.rglob('*.json'):
        try:
            with open(json_file, 'r') as f:
                data = json.load(f)
            print(f"✓ {json_file.name} is valid JSON")
        except json.JSONDecodeError as e:
            print(f"✗ {json_file.name} is invalid: {e}")
            return False
    
    return True
```

## Performance Considerations

### Data Size Guidelines
- **Unit Tests**: < 100 entities per dataset
- **Integration Tests**: < 1000 entities per dataset
- **System Tests**: < 10,000 entities per dataset
- **Performance Tests**: Variable, but measure impact

### Lazy Loading
Load test data only when needed:

```python
class TestWithLazyData(unittest.TestCase):
    @property
    def large_city_data(self):
        """Lazy-load large city data only when accessed."""
        if not hasattr(self, '_large_city_data'):
            self._large_city_data = load_fixture('cities/large_city.json')
        return self._large_city_data
    
    def test_something(self):
        # Data loaded only if this test runs
        city = City.from_dict(self.large_city_data)
```

### Caching Test Data
Cache expensive test data generation:

```python
from functools import lru_cache

@lru_cache(maxsize=10)
def get_test_scenario(scenario_name):
    """Get test scenario with caching."""
    return load_fixture(f'scenarios/{scenario_name}.json')
```

## Test Data Maintenance

### Versioning Test Data
Version test data files for compatibility:

```json
{
  "_version": "1.0",
  "_created": "2024-01-01",
  "_description": "Small city baseline for growth tests",
  "city_name": "Test City",
  "population": 100
}
```

### Updating Test Data
Process for updating test data:

1. **Identify Need**: Determine why data needs updating
2. **Version Check**: Verify current data version
3. **Create Backup**: Copy current data before modifying
4. **Update Data**: Make necessary changes
5. **Validate**: Run validation checks
6. **Test**: Run affected tests
7. **Document**: Update changelog and version

### Migration Scripts
Create scripts for test data migrations:

```python
def migrate_city_data_v1_to_v2(old_data):
    """Migrate city data from v1 to v2 format."""
    new_data = old_data.copy()
    new_data['_version'] = '2.0'
    
    # Add new required fields
    if 'traffic' not in new_data:
        new_data['traffic'] = {
            'roads': 0,
            'congestion': 0.0
        }
    
    return new_data
```

## Best Practices

### DO
✅ Use descriptive names for test data files
✅ Include metadata in test data (version, description, purpose)
✅ Keep test data minimal and focused
✅ Validate test data in CI/CD pipeline
✅ Document test data structure and purpose
✅ Use builders for complex test data
✅ Version test data files
✅ Cache expensive test data operations

### DO NOT
❌ Commit large binary files as test data
❌ Use production data in tests
❌ Hardcode file paths
❌ Create circular dependencies in test data
❌ Generate random data without seeds
❌ Rely on external data sources
❌ Duplicate test data unnecessarily
❌ Leave obsolete test data files

## Test Data Examples

### Minimal City Fixture
```json
{
  "_version": "1.0",
  "_description": "Minimal city for basic tests",
  "population": 100,
  "budget": 10000,
  "water_facilities": 0,
  "happiness": 70
}
```

### Complete Scenario Fixture
```json
{
  "_version": "1.0",
  "_description": "New city growth scenario",
  "scenario_name": "new_city_growth",
  "seed": 42,
  "duration": 365,
  "initial_conditions": {
    "city": {
      "population": 100,
      "budget": 10000,
      "infrastructure": {
        "water_facilities": 0,
        "electricity_units": 0,
        "roads": 0
      }
    }
  },
  "policies": {
    "tax_rate": 0.15,
    "infrastructure_spending": 0.25
  },
  "events": [],
  "checkpoints": [
    {
      "tick": 30,
      "assertions": {
        "population_min": 120,
        "population_max": 150,
        "water_facilities_min": 1
      }
    }
  ]
}
```

## Tools and Utilities

### Test Data Generator
```python
# tests/fixtures/data_generator.py
def generate_test_city(
    size='small',
    seed=42,
    budget_multiplier=1.0
):
    """Generate test city based on size category."""
    
    sizes = {
        'small': {'population': 100, 'budget': 10000},
        'medium': {'population': 1000, 'budget': 50000},
        'large': {'population': 5000, 'budget': 200000}
    }
    
    config = sizes[size]
    
    return {
        'population': config['population'],
        'budget': config['budget'] * budget_multiplier,
        'seed': seed,
        'metadata': {
            'size': size,
            'generated_by': 'data_generator.generate_test_city'
        }
    }
```

### Test Data Validator
```bash
#!/bin/bash
# validate_test_data.sh
python -m tests.fixtures.validate_data
```

## Breadcrumbs for Documentation Reconciliation

**ATTENTION - Top-Level Docs Agent**:
This test data management documentation should align with:
1. Overall data management strategy
2. File format standards
3. Version control practices
4. CI/CD pipeline data handling

**Key Integration Points**:
- Data serialization formats in core system
- File structure conventions
- Version migration strategies
- Backup and recovery procedures

**Open Items**:
1. Establish test data size limits and enforcement
2. Create automated test data validation in CI/CD
3. Implement test data versioning strategy
4. Define test data backup procedures
5. Create test data generation tools
6. Establish test data review process

## References

### Internal Documentation
- Integration Test Strategy: `integration-test-strategy.md`
- System Test Scenarios: `system-test-scenarios.md`
- Test Copilot Instructions: `../.github/copilot-instructions.md`

### External Resources
- JSON Schema: https://json-schema.org/
- Test Data Best Practices
- Fixture Management Patterns

---

**Document Version**: 1.0
**Last Updated**: 2024
**Maintainer**: Testing Team
**Review Cycle**: Quarterly
