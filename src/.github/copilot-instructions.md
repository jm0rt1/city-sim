# Source Code Guidelines (src/)

## Overview
This directory contains the core implementation of the City-Sim simulation. All code here must maintain determinism and follow the subsystem architecture.

## Module Guidelines

### Simulation Module (src/simulation/)
- **Purpose**: Orchestrate tick loop and scenario execution
- **Key Files**: sim.py
- **Principles**:
  - All random operations must use seeded RandomService
  - Tick execution must be deterministic
  - No I/O operations in core tick logic
  - Profile performance-critical paths
  
### City Module (src/city/)
- **Purpose**: City state management and operations
- **Key Files**: city.py, city_manager.py, decisions.py
- **Principles**:
  - Maintain invariants: budget reconciliation, non-negative population
  - State changes only through CityManager
  - Document all public API contracts
  - Keep City as data container, CityManager for operations

### Population Subsystem (src/city/population/)
- **Purpose**: Population dynamics, happiness, migration
- **Key Files**: population.py, happiness_tracker.py
- **Principles**:
  - Happiness must stay within bounds (0-100 or defined range)
  - All growth/decline calculations must be deterministic
  - Update happiness_tracker every tick
  - Document migration rules clearly

### Finance Subsystem (src/city/finance.py)
- **Purpose**: Budget management, revenue/expense calculation
- **Principles**:
  - Budget equation must balance: prev_budget + revenue - expenses = new_budget
  - Use Decimal for financial calculations if precision matters
  - Document all revenue/expense sources
  - Validate policy effects on budget

### Shared Module (src/shared/)
- **Purpose**: Cross-cutting concerns and configuration
- **Key Files**: settings.py
- **Principles**:
  - GlobalSettings should be immutable during a run
  - Use constants for magic numbers
  - Document all configuration options
  - Keep settings independent of runtime state

## Code Quality Standards

### Type Hints
- Use type hints for all public functions and class methods
- Optional for private methods unless they improve clarity
- Keep types accurate and up-to-date

### Error Handling
- Validate inputs at subsystem boundaries
- Raise ValueError for invalid parameters (e.g., negative values where not allowed)
- Use custom exceptions for domain-specific errors
- Never swallow exceptions silently

### Performance Considerations
- Avoid O(n²) operations in tick loop
- Cache computed values when appropriate
- Profile before optimizing
- Document performance constraints

### Testing Hooks
- Keep functions testable (avoid global state)
- Allow dependency injection where it helps testing
- Provide factory methods for test fixtures
- Document test-only behavior if needed

## Common Patterns

### Subsystem Update Pattern
```python
def update(self, city: City, context: TickContext) -> SubsystemDelta:
    """
    Update subsystem state for current tick.
    
    Args:
        city: Current city state (read-only)
        context: Tick context with settings and metadata
        
    Returns:
        Delta object with changes and metrics
    """
    # 1. Read current state
    # 2. Compute changes (deterministically)
    # 3. Return delta
    pass
```

### State Delta Pattern
```python
@dataclass
class SubsystemDelta:
    """Changes from a subsystem update"""
    field_changes: dict[str, Any]
    metrics: dict[str, float]
    timestamp: datetime
```

### Logging Pattern
```python
# Always include tick context
logger.info("event_type", {
    "run_id": context.run_id,
    "tick_index": context.tick_index,
    "metric_name": value,
    # ... other fields per logging spec
})
```

## Anti-Patterns to Avoid

❌ **Direct random.random() calls**
```python
# WRONG
if random.random() < 0.5:
    do_something()
```
✅ **Use RandomService**
```python
# CORRECT
if random_service.random() < 0.5:
    do_something()
```

❌ **Modifying global state**
```python
# WRONG
GlobalSettings.SOME_VALUE = new_value
```
✅ **Read-only configuration**
```python
# CORRECT
value = GlobalSettings.SOME_VALUE
```

❌ **Breaking invariants**
```python
# WRONG
city.population = -10
```
✅ **Validate constraints**
```python
# CORRECT
if new_population < 0:
    raise ValueError("Population cannot be negative")
city.population = new_population
```

## Integration Points

### Adding New Subsystems
1. Create subsystem module in appropriate directory
2. Implement update(city, context) -> Delta pattern
3. Register in CityManager
4. Add spec file in docs/specs/
5. Add tests with determinism validation

### Modifying Existing Subsystems
1. Check spec file first (docs/specs/)
2. Understand current invariants
3. Run existing tests to establish baseline
4. Make minimal changes
5. Validate no determinism regressions
6. Update spec if API changes

## References
- Architecture: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Specifications: docs/specs/
- Workstreams: docs/design/workstreams/
