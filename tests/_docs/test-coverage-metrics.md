# Test Coverage and Quality Metrics

## Purpose
This document defines test coverage standards, quality metrics, and monitoring strategies for the City-Sim project. These metrics ensure that our test suite provides adequate validation of the system.

## Coverage Principles

### Coverage Philosophy
- **Coverage is not quality**: High coverage doesn't guarantee good tests
- **Focus on critical paths**: Prioritize coverage of essential functionality
- **Meaningful tests**: Each test should verify specific behavior
- **Avoid coverage theater**: Don't write tests just to increase coverage numbers

### Coverage Types
1. **Line Coverage**: Percentage of code lines executed by tests
2. **Branch Coverage**: Percentage of decision branches tested
3. **Path Coverage**: Percentage of execution paths tested
4. **Function Coverage**: Percentage of functions called by tests
5. **Integration Coverage**: Percentage of integration points tested

## Coverage Targets

### Module-Level Targets

#### Core Simulation (Tier 1)
**Target: 90%+ coverage**
- `src/simulation/sim.py`: 95%
- `src/simulation/scenario_loader.py`: 90%
- `src/city/city_manager.py`: 95%

**Rationale**: Core simulation logic is critical and must be thoroughly tested

#### City Subsystems (Tier 2)
**Target: 85%+ coverage**
- `src/city/city.py`: 90%
- `src/city/finance.py`: 90%
- `src/city/population/`: 85%
- `src/city/traffic/`: 85%

**Rationale**: Subsystems contain important business logic and state management

#### Utilities and Helpers (Tier 3)
**Target: 80%+ coverage**
- `src/shared/settings.py`: 80%
- `src/shared/utils.py`: 80%
- `src/shared/logging.py`: 85%

**Rationale**: Utilities are important but generally simpler

#### UI/GUI Components (Tier 4)
**Target: 60%+ coverage**
- `src/gui/`: 60%
- `src/cli/`: 70%

**Rationale**: Focus on business logic, not rendering details

### Project-Wide Targets
- **Overall Coverage**: 85%+
- **Critical Path Coverage**: 95%+
- **New Code Coverage**: 90%+ (for new commits)
- **Test-to-Code Ratio**: 1:1 to 2:1 (test LOC : production LOC)

## Measuring Coverage

### Using coverage.py
```bash
# Install coverage
pip install coverage

# Run tests with coverage
coverage run -m unittest discover -s tests

# Generate report
coverage report

# Generate HTML report
coverage html

# View HTML report
open htmlcov/index.html
```

### Configuration
```ini
# .coveragerc
[run]
source = src
omit =
    src/gui/views/generated/*
    src/*/tests/*
    tests/*
    */__pycache__/*

[report]
exclude_lines =
    pragma: no cover
    def __repr__
    raise AssertionError
    raise NotImplementedError
    if __name__ == .__main__.:
    if TYPE_CHECKING:
    @abstract

precision = 2
skip_covered = False
skip_empty = True

[html]
directory = htmlcov
```

### Coverage in CI/CD
```yaml
# .github/workflows/coverage.yml
name: Test Coverage
on: [push, pull_request]
jobs:
  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.12'
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install coverage
      - name: Run tests with coverage
        run: coverage run -m unittest discover
      - name: Generate coverage report
        run: coverage report --fail-under=85
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v2
```

## Quality Metrics

### Test Quality Indicators

#### 1. Test Reliability
**Metric**: Percentage of non-flaky tests
**Target**: 99%+

**Measurement**:
```python
# Track flaky tests
flaky_tests = []  # Tests that fail intermittently
total_tests = 100
reliability = (total_tests - len(flaky_tests)) / total_tests
```

#### 2. Test Speed
**Metric**: Average test execution time
**Targets**:
- Unit tests: < 10ms each
- Integration tests: < 100ms each
- System tests: < 5s each

**Measurement**:
```bash
python -m unittest discover -v | grep -E "^test_.*\(.*\) ... ok" | wc -l
time python -m unittest discover
```

#### 3. Test Determinism
**Metric**: Percentage of deterministic tests
**Target**: 100%

**Validation**:
```bash
# Run tests 3 times, results should be identical
for i in {1..3}; do
    python -m unittest discover > run$i.log
done
diff run1.log run2.log && diff run2.log run3.log
```

#### 4. Test Maintainability
**Metric**: Lines of test code per test case
**Target**: < 50 lines per test method

**Measurement**:
```bash
# Count average lines per test method
find tests -name "*.py" -exec grep -c "def test_" {} \; | \
    awk '{s+=$1}END{print s}'
```

#### 5. Assertion Density
**Metric**: Assertions per test method
**Target**: 1-5 assertions per test

**Good Example**:
```python
def test_budget_calculation(self):
    """One focused test with appropriate assertions."""
    city = City(budget=10000)
    city.process_finances(revenue=5000, expenses=3000)
    
    self.assertEqual(city.budget, 12000)
    self.assertEqual(city.revenue_history[-1], 5000)
```

**Bad Example**:
```python
def test_everything(self):
    """Too many assertions in one test."""
    # 20+ assertions testing unrelated things
    self.assertEqual(...)  # x20
```

### Code Quality Metrics

#### 1. Cyclomatic Complexity
**Target**: < 10 per function

**Measurement**:
```bash
pip install radon
radon cc src/ -a -nb
```

#### 2. Code Duplication
**Target**: < 5% duplication

**Measurement**:
```bash
pip install pylint
pylint --disable=all --enable=duplicate-code src/
```

#### 3. Test/Code Ratio
**Target**: 1:1 to 2:1 (test LOC : production LOC)

**Measurement**:
```bash
cloc src/ tests/
```

## Coverage Analysis

### Critical Path Analysis
Identify and ensure coverage of critical paths:

```python
# tests/coverage_analysis.py
def analyze_critical_paths():
    """Analyze coverage of critical code paths."""
    critical_modules = [
        'src/simulation/sim.py',
        'src/city/city_manager.py',
        'src/city/finance.py',
    ]
    
    for module in critical_modules:
        coverage_data = get_coverage_data(module)
        if coverage_data['percent'] < 90:
            print(f"WARNING: {module} has {coverage_data['percent']}% coverage")
            print(f"Missing lines: {coverage_data['missing_lines']}")
```

### Uncovered Code Detection
```python
def find_uncovered_code():
    """Find code that's not covered by any tests."""
    coverage_data = load_coverage_data()
    
    uncovered = []
    for file, data in coverage_data.items():
        if data['missing_lines']:
            uncovered.append({
                'file': file,
                'missing': data['missing_lines'],
                'percent': data['percent_covered']
            })
    
    return sorted(uncovered, key=lambda x: x['percent'])
```

## Coverage Gaps and Mitigation

### Common Coverage Gaps

#### 1. Error Handling Paths
**Gap**: Exception handling code often uncovered
**Solution**: Test error scenarios explicitly

```python
def test_error_handling(self):
    """Test error handling paths."""
    city = City(budget=0)
    
    with self.assertRaises(InsufficientFundsError):
        city.build_water_facility(cost=1000)
    
    # Verify state unchanged after error
    self.assertEqual(city.water_facilities, 0)
```

#### 2. Edge Cases
**Gap**: Boundary conditions not tested
**Solution**: Explicit edge case tests

```python
def test_edge_cases(self):
    """Test boundary conditions."""
    # Zero population
    city = City(population=0)
    city.advance_day()  # Should not crash
    
    # Maximum population
    city = City(population=1000000)
    city.advance_day()  # Should handle gracefully
```

#### 3. Rare Branches
**Gap**: Conditional branches rarely executed
**Solution**: Force branch execution in tests

```python
def test_rare_branch(self):
    """Test rarely executed branch."""
    # Create conditions for rare branch
    city = City()
    city.disaster_mode = True  # Rare condition
    city.advance_day()
    
    # Verify rare branch behavior
    self.assertTrue(city.emergency_measures_active)
```

## Coverage Enforcement

### Pre-Commit Hooks
```bash
#!/bin/bash
# .git/hooks/pre-commit

# Run tests with coverage
coverage run -m unittest discover

# Check coverage threshold
coverage report --fail-under=85

if [ $? -ne 0 ]; then
    echo "Coverage below 85%, commit rejected"
    exit 1
fi
```

### Pull Request Checks
```yaml
# .github/workflows/pr-coverage.yml
name: PR Coverage Check
on: pull_request
jobs:
  check-coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Check coverage diff
        run: |
          coverage run -m unittest discover
          coverage report --fail-under=85
          # Fail if new code has < 90% coverage
          coverage report --include="*${GITHUB_SHA}*" --fail-under=90
```

### Coverage Trends
Track coverage over time:

```python
# scripts/track_coverage.py
import json
from datetime import datetime

def record_coverage():
    """Record current coverage for trend analysis."""
    coverage_data = get_current_coverage()
    
    record = {
        'date': datetime.now().isoformat(),
        'commit': get_current_commit(),
        'overall_coverage': coverage_data['total'],
        'module_coverage': coverage_data['by_module']
    }
    
    with open('coverage_history.json', 'a') as f:
        json.dump(record, f)
        f.write('\n')
```

## Reporting and Visualization

### Coverage Reports

#### Console Report
```bash
coverage report --sort=cover
```

Output:
```
Name                           Stmts   Miss  Cover
--------------------------------------------------
src/simulation/sim.py            150      5    97%
src/city/city_manager.py         200     15    92%
src/city/finance.py              120     12    90%
--------------------------------------------------
TOTAL                           1500    150    90%
```

#### HTML Report
```bash
coverage html
open htmlcov/index.html
```

Features:
- Visual coverage indicators
- Click-through to source code
- Missing lines highlighted
- Branch coverage details

#### Badge Generation
```yaml
# .github/workflows/coverage-badge.yml
- name: Coverage Badge
  uses: cicirello/jacoco-badge-generator@v2
  with:
    jacoco-csv-file: coverage.xml
    badges-directory: badges
    generate-branches-badge: true
```

### Dashboard Integration
```python
# Upload to coverage service
import codecov

codecov.upload({
    'coverage': coverage_percentage,
    'commit': commit_sha,
    'branch': branch_name
})
```

## Best Practices

### DO
✅ Write tests before or alongside code (TDD)
✅ Focus on meaningful coverage, not just high numbers
✅ Test critical paths thoroughly
✅ Cover edge cases and error conditions
✅ Review coverage reports regularly
✅ Set coverage targets per module importance
✅ Track coverage trends over time
✅ Fail builds on coverage regression

### DO NOT
❌ Write tests just to increase coverage
❌ Ignore uncovered critical code
❌ Accept decreasing coverage without justification
❌ Test trivial code (getters/setters) excessively
❌ Aim for 100% coverage without considering cost
❌ Use coverage as sole quality metric
❌ Game the coverage system

## Advanced Coverage Techniques

### Mutation Testing
Validate test quality through mutation testing:

```bash
# Install mutmut
pip install mutmut

# Run mutation testing
mutmut run

# View results
mutmut results
```

### Branch Coverage Analysis
```python
# Ensure both branches tested
def test_conditional_branches(self):
    """Test both branches of condition."""
    
    # Test true branch
    city = City(budget=10000)
    city.can_afford_construction(5000)
    self.assertTrue(city.last_check_passed)
    
    # Test false branch
    city = City(budget=1000)
    city.can_afford_construction(5000)
    self.assertFalse(city.last_check_passed)
```

### Path Coverage
```python
def test_all_execution_paths(self):
    """Test all possible execution paths."""
    
    # Path 1: A -> B -> C
    result1 = function(condition1=True, condition2=True)
    
    # Path 2: A -> B -> D
    result2 = function(condition1=True, condition2=False)
    
    # Path 3: A -> E
    result3 = function(condition1=False, condition2=True)
    
    # Verify each path
    self.assertEqual(result1, expected1)
    self.assertEqual(result2, expected2)
    self.assertEqual(result3, expected3)
```

## Coverage for Free-Threaded Python

### Thread-Safety Coverage
```python
def test_thread_safe_operations(self):
    """Ensure operations are thread-safe."""
    import concurrent.futures
    
    city = City()
    
    def read_population():
        return len(city.population)
    
    # Execute in parallel
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(read_population) for _ in range(100)]
        results = [f.result() for f in futures]
    
    # All should return same value (thread-safe reads)
    self.assertEqual(len(set(results)), 1)
```

## Breadcrumbs for Documentation Reconciliation

**ATTENTION - Top-Level Docs Agent**:
Coverage and metrics documentation should align with:
1. CI/CD quality gates
2. Code review standards
3. Definition of done
4. Release criteria

**Key Integration Points**:
- Coverage enforcement in CI/CD
- Quality dashboards
- Team metrics and KPIs
- Technical debt tracking

**Open Items**:
1. Set up coverage tracking dashboard
2. Integrate mutation testing in CI/CD
3. Define coverage regression policies
4. Create coverage improvement plans
5. Establish metrics review cadence
6. Document coverage exemption process

## References

### Internal Documentation
- Test Copilot Instructions: `../.github/copilot-instructions.md`
- Integration Test Strategy: `integration-test-strategy.md`
- Test Automation Patterns: `test-automation-patterns.md`

### External Resources
- coverage.py documentation: https://coverage.readthedocs.io/
- Mutation Testing: https://mutmut.readthedocs.io/
- Code Coverage Best Practices

### Tools
- `coverage.py`: Python coverage measurement
- `mutmut`: Mutation testing
- `radon`: Cyclomatic complexity
- `codecov`: Coverage reporting service

---

**Document Version**: 1.0
**Last Updated**: 2024
**Maintainer**: Testing Team
**Review Cycle**: Quarterly
