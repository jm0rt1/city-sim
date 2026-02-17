# System-Level Test Scenarios

## Purpose
This document defines high-level, end-to-end test scenarios for the City-Sim project. System-level tests validate complete gameplay experiences, ensuring that all subsystems work together to create a cohesive, playable city simulation.

## System Test Philosophy

### What System Tests Validate
1. **Complete User Stories**: Full gameplay scenarios from start to finish
2. **Multi-Subsystem Orchestration**: All subsystems working together harmoniously
3. **Emergent Behavior**: Complex behaviors arising from subsystem interactions
4. **Long-Running Stability**: System behavior over extended simulation runs
5. **Deterministic Gameplay**: Reproducible game experiences with same seeds

### System Test Characteristics
- **Duration**: Tests may run for hundreds or thousands of simulation ticks
- **Complexity**: Tests involve multiple subsystems and complex state
- **Realism**: Tests mirror actual gameplay scenarios
- **Validation**: Tests check game balance, fun factor, and realism
- **Performance**: Tests validate that game remains responsive

## Core System Test Scenarios

### Scenario 1: New City Growth
**Description**: Test the complete lifecycle of a new city from founding to small city status

**Initial Conditions**:
- Starting population: 100
- Starting budget: $10,000
- Empty infrastructure
- Default policies

**Duration**: 365 ticks (1 simulated year)

**Key Checkpoints**:
- Day 30: Population should be 120-150
- Day 30: At least 1 water facility built
- Day 90: Population should be 150-200
- Day 90: At least 1 electricity infrastructure unit
- Day 180: Population should be 250-350
- Day 365: Population should be 400-600
- Day 365: Budget should be positive
- Day 365: Average happiness should be > 60

**Success Criteria**:
```python
def test_new_city_growth_scenario(self):
    """New city should grow steadily over first year."""
    sim = Simulation(seed=42, duration=365)
    sim.load_scenario('new_city')
    
    result = sim.run()
    
    self.assertTrue(result.completed)
    self.assertEqual(result.ticks_executed, 365)
    
    # Validate checkpoints
    self.assertGreaterEqual(result.population_at_tick(30), 120)
    self.assertLessEqual(result.population_at_tick(30), 150)
    
    self.assertGreaterEqual(result.water_facilities_at_tick(30), 1)
    
    self.assertGreaterEqual(result.population_at_tick(365), 400)
    self.assertLessEqual(result.population_at_tick(365), 600)
    
    self.assertGreater(result.final_budget, 0)
    self.assertGreater(result.final_happiness, 60)
```

### Scenario 2: Economic Crisis
**Description**: Test city resilience during economic downturn

**Initial Conditions**:
- Established city: Population 1000
- Starting budget: $5,000
- Moderate infrastructure
- Economic crisis triggered at tick 50

**Duration**: 200 ticks

**Crisis Parameters**:
- Tax revenue reduced by 50%
- Maintenance costs increased by 25%
- Migration increased (unhappy citizens leave faster)

**Key Checkpoints**:
- Tick 50: Crisis begins, budget starts declining
- Tick 100: City makes adjustments (reduce spending, increase taxes)
- Tick 150: Recovery begins (budget stabilizes)
- Tick 200: Partial recovery (population stable, budget growing)

**Success Criteria**:
- City survives crisis (population > 500 at end)
- Budget does not go negative
- Infrastructure maintained (no facility abandonment)
- Happiness recovers to > 50 by end

**Test Implementation**:
```python
def test_economic_crisis_scenario(self):
    """City should survive economic crisis with appropriate policies."""
    sim = Simulation(seed=42, duration=200)
    sim.load_scenario('economic_crisis')
    
    result = sim.run()
    
    # Validate survival
    self.assertGreater(result.final_population, 500)
    self.assertGreaterEqual(result.final_budget, 0)
    
    # Validate infrastructure maintained
    initial_facilities = result.water_facilities_at_tick(0)
    final_facilities = result.water_facilities_at_tick(200)
    self.assertEqual(initial_facilities, final_facilities)
    
    # Validate recovery
    self.assertGreater(result.final_happiness, 50)
```

### Scenario 3: Rapid Expansion
**Description**: Test city systems under rapid growth conditions

**Initial Conditions**:
- Small city: Population 500
- Large budget: $100,000
- Aggressive growth policies
- High immigration rate

**Duration**: 180 ticks

**Growth Parameters**:
- Immigration rate increased by 200%
- Construction costs reduced by 30%
- Infrastructure built proactively

**Key Checkpoints**:
- Tick 60: Population doubled (1000)
- Tick 60: Infrastructure keeps pace with growth
- Tick 120: Population tripled (1500)
- Tick 120: Services adequate for population
- Tick 180: Population stabilizes (1800-2000)
- Tick 180: Happiness remains > 65

**Success Criteria**:
- Population grows to 1800-2000
- Infrastructure-to-population ratio maintained
- Happiness never drops below 60
- Traffic congestion remains manageable
- Budget remains positive

**Test Implementation**:
```python
def test_rapid_expansion_scenario(self):
    """City should handle rapid growth with adequate infrastructure."""
    sim = Simulation(seed=42, duration=180)
    sim.load_scenario('rapid_expansion')
    
    result = sim.run()
    
    # Validate growth
    self.assertGreaterEqual(result.final_population, 1800)
    self.assertLessEqual(result.final_population, 2000)
    
    # Validate infrastructure kept pace
    final_facilities_per_capita = (
        result.final_water_facilities / result.final_population
    )
    self.assertGreaterEqual(final_facilities_per_capita, 0.001)
    
    # Validate happiness maintained
    min_happiness = min(result.happiness_history)
    self.assertGreater(min_happiness, 60)
    
    # Validate traffic manageable
    self.assertLess(result.final_traffic_congestion, 0.7)
```

### Scenario 4: Infrastructure Crisis
**Description**: Test city response to infrastructure failure

**Initial Conditions**:
- Medium city: Population 2000
- Aging infrastructure
- Infrastructure failure triggered at tick 100

**Duration**: 300 ticks

**Crisis Parameters**:
- 50% of water facilities fail at tick 100
- 30% of electricity infrastructure fails at tick 110
- Happiness drops sharply
- Services degraded

**Key Checkpoints**:
- Tick 100: Water crisis begins
- Tick 110: Electricity crisis begins
- Tick 120: Emergency construction starts
- Tick 200: Infrastructure restored to 80%
- Tick 300: Full recovery

**Success Criteria**:
- City survives crisis (population > 1000)
- Infrastructure rebuilt by tick 200
- Happiness recovers to > 55
- No complete service collapse

**Test Implementation**:
```python
def test_infrastructure_crisis_scenario(self):
    """City should recover from infrastructure failures."""
    sim = Simulation(seed=42, duration=300)
    sim.load_scenario('infrastructure_crisis')
    
    result = sim.run()
    
    # Validate survival
    self.assertGreater(result.final_population, 1000)
    
    # Validate infrastructure recovery
    initial_facilities = result.water_facilities_at_tick(0)
    facilities_at_crisis = result.water_facilities_at_tick(100)
    facilities_at_recovery = result.water_facilities_at_tick(200)
    
    self.assertLess(facilities_at_crisis, initial_facilities)
    self.assertGreater(facilities_at_recovery, facilities_at_crisis)
    
    # Validate happiness recovery
    self.assertGreater(result.final_happiness, 55)
```

### Scenario 5: Traffic Congestion
**Description**: Test traffic management and mitigation strategies

**Initial Conditions**:
- Large city: Population 5000
- Inadequate road infrastructure
- High traffic volume

**Duration**: 250 ticks

**Traffic Parameters**:
- Roads at 90% capacity
- Traffic grows with population
- Traffic mitigation policies available

**Key Checkpoints**:
- Tick 50: Traffic congestion reaches critical level
- Tick 100: Traffic policies implemented
- Tick 150: New roads constructed
- Tick 200: Congestion reduced to moderate
- Tick 250: Congestion stabilized

**Success Criteria**:
- Congestion never exceeds 95%
- City implements mitigation within 100 ticks
- Final congestion < 70%
- Happiness affected but not catastrophic (> 50)

**Test Implementation**:
```python
def test_traffic_congestion_scenario(self):
    """City should manage traffic congestion effectively."""
    sim = Simulation(seed=42, duration=250)
    sim.load_scenario('traffic_congestion')
    
    result = sim.run()
    
    # Validate congestion managed
    max_congestion = max(result.congestion_history)
    self.assertLess(max_congestion, 0.95)
    
    # Validate mitigation occurred
    congestion_at_50 = result.congestion_at_tick(50)
    congestion_at_200 = result.congestion_at_tick(200)
    self.assertLess(congestion_at_200, congestion_at_50)
    
    # Validate final state
    self.assertLess(result.final_congestion, 0.70)
    self.assertGreater(result.final_happiness, 50)
```

### Scenario 6: Balanced Growth
**Description**: Test optimal city development with balanced policies

**Initial Conditions**:
- Starting city: Population 200
- Moderate budget: $25,000
- Balanced policies (moderate taxes, adequate services)

**Duration**: 500 ticks

**Growth Parameters**:
- Natural growth rates
- Balanced infrastructure development
- Responsive policy adjustments

**Key Checkpoints**:
- Tick 100: Population 400-500
- Tick 200: Population 800-1000
- Tick 300: Population 1200-1500
- Tick 400: Population 1600-2000
- Tick 500: Population 2000-2500

**Success Criteria**:
- Steady population growth
- Happiness consistently > 70
- Budget consistently positive
- Infrastructure-to-population ratio optimal
- Traffic manageable throughout

**Test Implementation**:
```python
def test_balanced_growth_scenario(self):
    """City should grow steadily with balanced policies."""
    sim = Simulation(seed=42, duration=500)
    sim.load_scenario('balanced_growth')
    
    result = sim.run()
    
    # Validate growth at checkpoints
    checkpoints = [
        (100, 400, 500),
        (200, 800, 1000),
        (300, 1200, 1500),
        (400, 1600, 2000),
        (500, 2000, 2500),
    ]
    
    for tick, min_pop, max_pop in checkpoints:
        pop = result.population_at_tick(tick)
        self.assertGreaterEqual(pop, min_pop, f"Population too low at tick {tick}")
        self.assertLessEqual(pop, max_pop, f"Population too high at tick {tick}")
    
    # Validate happiness maintained
    min_happiness = min(result.happiness_history)
    self.assertGreater(min_happiness, 70)
    
    # Validate budget positive throughout
    min_budget = min(result.budget_history)
    self.assertGreater(min_budget, 0)
```

## Advanced System Test Scenarios

### Scenario 7: Multi-Crisis Management
**Description**: Test city resilience under multiple simultaneous crises

**Crises**:
1. Economic downturn (tick 50)
2. Infrastructure failure (tick 100)
3. Natural disaster (tick 150)

**Duration**: 400 ticks

**Success Criteria**:
- City survives all crises
- Population > 50% of initial
- Infrastructure restored by end
- Happiness recovers to > 50

### Scenario 8: Seasonal Variations
**Description**: Test city behavior across different seasons and years

**Duration**: 1460 ticks (4 simulated years)

**Seasonal Effects**:
- Winter: Higher heating costs, lower construction
- Spring: Higher construction activity
- Summer: Higher happiness, more tourism
- Fall: Stable period, preparation for winter

**Success Criteria**:
- Seasonal patterns observable in data
- City adapts to seasonal variations
- Multi-year growth trend positive
- Seasonal cycles deterministic

### Scenario 9: Policy Experimentation
**Description**: Test different policy configurations and outcomes

**Policy Sets**:
1. High tax, high services
2. Low tax, low services
3. Moderate tax, moderate services
4. Dynamic policies based on city state

**Duration**: 300 ticks per policy set

**Success Criteria**:
- Different policies produce measurably different outcomes
- All policy sets viable (city survives)
- Trade-offs observable (growth vs. happiness vs. budget)

### Scenario 10: Free-Threaded Performance
**Description**: Test simulation performance with free-threaded Python

**Conditions**:
- Large city (10,000+ population)
- Complex traffic network
- Multiple simultaneous subsystem updates
- Parallel execution enabled

**Duration**: 1000 ticks

**Success Criteria**:
- Determinism maintained in parallel execution
- Performance improvement over single-threaded
- No race conditions or data corruption
- Results identical to single-threaded version

## Test Data and Scenarios

### Scenario Configuration Format
```json
{
  "scenario_name": "new_city_growth",
  "seed": 42,
  "duration": 365,
  "initial_conditions": {
    "population": 100,
    "budget": 10000,
    "water_facilities": 0,
    "electricity_infrastructure": 0,
    "happiness": 70
  },
  "policies": {
    "tax_rate": 0.15,
    "infrastructure_spending": 0.25,
    "migration_enabled": true
  },
  "events": [],
  "checkpoints": [
    {
      "tick": 30,
      "population_min": 120,
      "population_max": 150,
      "water_facilities_min": 1
    }
  ]
}
```

### Scenario Storage
```
tests/data/scenarios/
├── new_city_growth.json
├── economic_crisis.json
├── rapid_expansion.json
├── infrastructure_crisis.json
├── traffic_congestion.json
├── balanced_growth.json
├── multi_crisis.json
├── seasonal_variations.json
├── policy_experimentation.json
└── free_threaded_performance.json
```

## Test Execution Guidelines

### Running System Tests
```bash
# Run all system tests
python -m unittest discover -s tests/system

# Run specific scenario
python -m unittest tests.system.test_scenarios.TestNewCityGrowth

# Run with verbose output
python -m unittest discover -s tests/system -v
```

### Performance Expectations
- Individual system test: < 30 seconds
- Full system test suite: < 5 minutes
- Long-running scenarios (1000+ ticks): < 2 minutes

### Resource Usage
- Memory: < 500 MB per test
- CPU: Single-threaded execution (for now)
- Disk: Minimal (in-memory data structures)

## Determinism Validation

### Ensuring Deterministic System Tests
1. **Fixed Seeds**: All scenarios use explicit, documented seeds
2. **Identical Runs**: Multiple runs with same seed produce identical results
3. **Cross-Platform**: Results consistent across Windows, macOS, Linux
4. **Version Consistency**: Results consistent across Python 3.13+ versions

### Determinism Validation Test
```python
def test_system_determinism(self):
    """System tests should be deterministic across runs."""
    seed = 42
    duration = 100
    
    results = []
    for _ in range(3):
        sim = Simulation(seed=seed, duration=duration)
        sim.load_scenario('new_city_growth')
        result = sim.run()
        results.append({
            'population': result.final_population,
            'budget': result.final_budget,
            'happiness': result.final_happiness,
        })
    
    # All runs should be identical
    self.assertEqual(results[0], results[1])
    self.assertEqual(results[1], results[2])
```

## Success Metrics

### System Test Success Criteria
1. **Completion Rate**: 100% of system tests complete without crashes
2. **Determinism**: 100% reproducibility across runs
3. **Performance**: All tests complete within time limits
4. **Coverage**: All major gameplay scenarios represented
5. **Balance**: Scenarios challenge but are winnable

### Quality Indicators
- **Realism**: Scenarios mirror actual gameplay
- **Fun Factor**: Scenarios are engaging and challenging
- **Educational**: Scenarios teach game mechanics
- **Diversity**: Scenarios cover different playstyles

## Continuous Integration

### CI Pipeline Integration
```yaml
# .github/workflows/system-tests.yml
name: System Tests
on:
  schedule:
    - cron: '0 2 * * *'  # Nightly at 2 AM
  workflow_dispatch:
jobs:
  system-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.12'
      - name: Install dependencies
        run: pip install -r requirements.txt
      - name: Run system tests
        run: python -m unittest discover -s tests/system
        timeout-minutes: 10
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v2
        with:
          name: system-test-results
          path: test-results/
```

## Breadcrumbs for Documentation Reconciliation

**ATTENTION - Top-Level Docs Agent**:
This system test scenario documentation integrates with:
1. Integration test strategy (`integration-test-strategy.md`)
2. Testing workstream (`docs/design/workstreams/07-testing-ci.md`)
3. Scenario specifications (`docs/specs/scenarios.md`)
4. Quality assurance standards

**Key Integration Points**:
- Scenario specifications should align with these test scenarios
- Test scenarios validate gameplay mechanics described in design docs
- Performance benchmarks reference these scenarios
- Release criteria based on system test pass rates

**Open Items**:
1. Complete scenario configuration files for all 10 scenarios
2. Implement scenario loader in simulation core
3. Create test result visualization dashboard
4. Define regression test baseline data
5. Establish performance benchmarks for each scenario
6. Create scenario difficulty ratings
7. Add achievement/goal tracking for scenarios

## Future Enhancements

### Planned Features
1. **Scenario Editor**: GUI tool for creating custom test scenarios
2. **Result Visualization**: Graphs and charts of scenario outcomes
3. **Comparative Analysis**: Compare multiple runs side-by-side
4. **Regression Detection**: Automatic detection of performance regressions
5. **Scenario Variants**: Generate variations of base scenarios
6. **Player vs. AI**: Compare human player results with AI decisions
7. **Leaderboards**: Track best scenario completion times/scores

### Free-Threaded Python Integration
With Python 3.13+ free-threaded execution support (see [ADR-002](../../docs/adr/002-free-threaded-python.md)):
1. Add parallel scenario execution tests
2. Validate determinism in multi-threaded scenarios
3. Performance comparison tests (single vs. multi-threaded)
4. Concurrency stress tests
5. Thread-safety validation scenarios

## References

### Internal Documentation
- Integration Test Strategy: `integration-test-strategy.md`
- Test Automation Patterns: `test-automation-patterns.md`
- Scenario Specifications: `../../docs/specs/scenarios.md`
- Simulation Specifications: `../../docs/specs/simulation.md`

### External Resources
- End-to-End Testing Best Practices
- Game Testing Strategies
- Simulation Validation Techniques

---

**Document Version**: 1.0
**Last Updated**: 2024
**Maintainer**: Testing Team
**Review Cycle**: Quarterly
