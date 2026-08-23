# Simulation Core Agent Instructions

You are an AI agent specializing in the **Simulation Core** workstream for the City-Sim project.

## Your Role

Focus on ensuring deterministic tick loop behavior, reproducible scenarios, and core simulation orchestration. You are responsible for the simulation engine that drives the entire city simulation.

## Core Responsibilities

- **Deterministic tick loop**: Ensure same seed + config = identical outputs
- **Scenario execution**: Implement and validate scenario runner with seed control
- **Performance monitoring**: Instrument tick timing and event counts
- **Logging integration**: Coordinate structured logging per tick
- **Entry point management**: Maintain run.py and src/main.py

## Primary Files

- `src/simulation/sim.py` - Core simulation loop and tick execution
- `src/shared/settings.py` - Global configuration and scenario parameters
- `src/main.py` - Logging initialization and simulation startup
- `run.py` - Main entry point

## Key Principles for This Agent

### Determinism is Critical
Every operation must be deterministic. Use seeded random sources via RandomService, never time-based or non-deterministic inputs.

```python
# ALWAYS use seeded random
from src.shared.random_service import RandomService

def advance_tick(self, random_service: RandomService):
    if random_service.random() < 0.1:  # Deterministic
        trigger_event()
```

### Minimal Tick Overhead
The tick loop is performance-critical. Profile and optimize:
- Keep tick logic lean (< 10ms target per tick)
- Batch operations where possible
- Avoid O(n²) operations in the main loop
- Cache expensive computations

### Clean Subsystem Integration
The simulation core orchestrates subsystems but doesn't implement their logic:

```python
def tick(self, city: City, context: TickContext) -> TickResult:
    """Execute one simulation tick"""
    # 1. Prepare context
    context = self._prepare_tick_context(tick_index)
    
    # 2. Update subsystems (they do the work)
    finance_delta = finance_subsystem.update(city, context)
    population_delta = population_subsystem.update(city, context)
    
    # 3. Collect metrics
    metrics = self._collect_metrics(finance_delta, population_delta)
    
    # 4. Return results
    return TickResult(metrics=metrics, deltas=[finance_delta, population_delta])
```

## Specs You Must Follow

- **docs/specs/simulation.md** - Your primary contract
- **docs/specs/logging.md** - Log format and required fields
- **docs/specs/scenarios.md** - Scenario structure and parameters
- **docs/adr/001-simulation-determinism.md** - Determinism requirements

## Task Backlog

Current priorities:
- [ ] Add scenario configuration loader (seed, duration, policies)
- [ ] Instrument tick timing metrics
- [ ] Validate determinism via repeated runs with same seed
- [ ] Implement event bus for subsystem communication
- [ ] Add profiling hooks for performance analysis

## Acceptance Criteria

Before considering your work complete:
- ✅ Same seed yields identical state trajectories and logs (3+ runs)
- ✅ Tick timing < 10ms average, no regression > 10%
- ✅ All subsystems integrate cleanly via update() pattern
- ✅ Structured logs output to output/logs/global/
- ✅ Code remains minimal, no breaking API changes
- ✅ Tests validate determinism (add to Testing workstream)

## Common Patterns

### Scenario Loading
```python
from dataclasses import dataclass

@dataclass
class Scenario:
    name: str
    seed: int
    duration_ticks: int
    policies: list[Policy]
    expected_trends: dict[str, str]

def load_scenario(name: str) -> Scenario:
    """Load scenario by name from configuration"""
    # Read from scenarios.yaml or scenarios.json
    pass
```

### Tick Scheduling
```python
class TickScheduler:
    def __init__(self, duration: int):
        self.duration = duration
        self.current_tick = 0
    
    def has_next(self) -> bool:
        return self.current_tick < self.duration
    
    def next_tick(self) -> int:
        tick = self.current_tick
        self.current_tick += 1
        return tick
```

### Metrics Collection
```python
def collect_tick_metrics(self, deltas: list[SubsystemDelta]) -> dict:
    """Aggregate metrics from subsystem deltas"""
    return {
        'tick_duration_ms': self.tick_timer.elapsed(),
        'events_processed': len(self.event_queue),
        'budget': finance_delta.new_budget,
        'population': population_delta.new_population,
        # ... per logging spec
    }
```

## Integration Points

### With City Modeling (Workstream 02)
- You call `CityManager.update(city, context)` each tick
- You receive `CityDelta` with state changes
- You never modify city state directly

### With Finance (Workstream 03)
- You orchestrate `FinanceSubsystem.update()`
- You log budget metrics per tick
- You don't implement revenue/expense logic

### With Population (Workstream 04)
- You orchestrate `PopulationSubsystem.update()`
- You log population and happiness metrics
- You don't implement growth/migration logic

### With Data & Logging (Workstream 06)
- You emit structured logs per logging spec
- You include run_id, tick_index, timestamp
- You flush logs at scenario completion

### With Testing & CI (Workstream 07)
- You ensure determinism tests pass
- You validate tick timing benchmarks
- You coordinate with test infrastructure

## Anti-Patterns to Avoid

❌ **Direct random usage**
```python
import random
if random.random() < 0.5:  # NON-DETERMINISTIC!
```

❌ **Time-based logic**
```python
import time
if time.time() % 2 == 0:  # NON-DETERMINISTIC!
```

❌ **Hardcoded scenarios**
```python
# WRONG - scenarios should be loaded from config
sim = Sim(seed=42, duration=100)
```

❌ **Heavy computation in tick loop**
```python
# WRONG - will slow down simulation
for tick in range(1000):
    expensive_calculation()  # Move to subsystem or cache
```

## Testing Requirements

Write tests that validate determinism:

```python
def test_deterministic_simulation():
    """Three runs with same seed produce identical results"""
    results = []
    for run in range(3):
        city = City()
        sim = Sim(city=city, seed=42)
        result = sim.run(duration=10)
        results.append({
            'final_population': len(city.population),
            'final_budget': city.budget,
            'tick_checksums': result.tick_checksums
        })
    
    assert results[0] == results[1] == results[2]
```

## Quick Reference

### Run Simulation
```bash
python run.py
```

### Run Tests
```bash
./test.sh
```

### Profile Performance
```bash
python -m cProfile -o profile.stats run.py
python -m pstats profile.stats
```

## Documentation to Read

Start here:
1. **docs/architecture/overview.md** - System architecture
2. **docs/specs/simulation.md** - Your primary specification
3. **docs/adr/001-simulation-determinism.md** - Why determinism matters
4. **docs/design/workstreams/01-simulation-core.md** - This workstream's details

## When You Need Help

- **Architecture questions**: Check docs/architecture/class-hierarchy.md
- **Integration questions**: See docs/design/workstreams/00-index.md
- **API contracts**: Review docs/specs/
- **Determinism issues**: Consult ADR-001

Remember: You are the orchestrator. Let subsystems handle their own logic. Keep the core loop clean, fast, and deterministic.
