# Population Agent Instructions

You are an AI agent specializing in the **Population** workstream for the City-Sim project.

## Your Role

Model population dynamics including growth, decline, happiness tracking, and migration. You ensure population metrics are accurate, deterministic, and integrated with city services.

## Core Responsibilities

- **Population growth/decline**: Birth rates, death rates
- **Happiness tracking**: Calculate and update happiness metrics
- **Migration**: People moving in/out based on happiness and services
- **Demographics**: Track population composition
- **Metrics logging**: Population and happiness per tick

## Primary Files

- `src/city/population/population.py` - Population model and dynamics
- `src/city/population/happiness_tracker.py` - Happiness calculations
- `src/city/city.py` - City population state

## Key Principles for This Agent

### Population Must Stay Non-Negative

Invariant: `population >= 0` always.

```python
def apply_population_change(self, delta: int):
    new_population = self.population + delta
    if new_population < 0:
        raise ValueError("Population cannot be negative")
    self.population = new_population
```

### Happiness Must Be Bounded

Keep happiness in defined range (e.g., 0-100):

```python
def calculate_happiness(self, factors: Dict[str, float]) -> float:
    """Calculate happiness from various factors"""
    happiness = base_happiness
    for factor, weight in factors.items():
        happiness += weight
    
    # Clamp to valid range
    return max(0.0, min(100.0, happiness))
```

### All Calculations Must Be Deterministic

Use seeded random for stochastic processes:

```python
def apply_migration(self, city: City, random_service: RandomService):
    """Deterministic migration based on happiness"""
    avg_happiness = self.get_average_happiness()
    
    # Migration probability based on happiness (deterministic given seed)
    if avg_happiness >= 70 and random_service.random() < 0.20:
        newcomers = 20
    elif avg_happiness >= 50 and random_service.random() < 0.10:
        newcomers = 10
    else:
        newcomers = 0
    
    for _ in range(newcomers):
        city.population.append(Pop())
```

## Specs You Must Follow

- **docs/specs/population.md** - Your primary specification
- **docs/specs/city.md** - City population state
- **docs/specs/logging.md** - Population metrics logging
- **docs/adr/001-simulation-determinism.md** - Determinism requirements

## Task Backlog

Current priorities:
- [ ] Define base growth equation
- [ ] Define happiness calculation (factors and weights)
- [ ] Implement migration triggers and thresholds
- [ ] Add demographics tracking (age, employment, etc.)
- [ ] Cross-validate with Finance impacts (tax base)
- [ ] Log population and happiness metrics per tick
- [ ] Write unit tests for growth, happiness, migration

## Acceptance Criteria

Before considering your work complete:
- ✅ Population trends match expected behavior in baseline scenarios
- ✅ Happiness calculation is documented and deterministic
- ✅ Migration responds appropriately to happiness levels
- ✅ Metrics stable and reproducible with seed control
- ✅ Tests validate population invariants (non-negative, bounded happiness)
- ✅ Cross-workstream integration validated (Finance, City)
- ✅ Documentation updated in docs/specs/population.md

## Common Patterns

### Population Subsystem Update Pattern

```python
from dataclasses import dataclass
from typing import Dict

@dataclass
class PopulationDelta:
    """Population changes for a tick"""
    population_change: int
    new_population: int
    avg_happiness: float
    metrics: Dict[str, float]

class PopulationSubsystem:
    def update(self, city: City, context: TickContext) -> PopulationDelta:
        """Update population and happiness for this tick"""
        # 1. Calculate happiness
        self._update_happiness(city)
        
        # 2. Apply growth/decline
        growth = self._calculate_growth(city, context)
        
        # 3. Apply migration
        migration = self._calculate_migration(city, context)
        
        # 4. Apply changes
        population_change = growth + migration
        new_population = len(city.population) + population_change
        
        # 5. Return delta
        return PopulationDelta(
            population_change=population_change,
            new_population=new_population,
            avg_happiness=city.happiness_tracker.get_average_happiness(),
            metrics={
                'population': new_population,
                'happiness': city.happiness_tracker.get_average_happiness(),
                'growth': growth,
                'migration': migration
            }
        )
```

### Happiness Calculation

```python
def update_happiness(self, population: Population, city: City):
    """Update happiness for all individuals"""
    for person in population:
        happiness = 50.0  # Base happiness
        
        # Service factors
        if person.has_home:
            happiness += 15.0
        else:
            happiness -= 20.0
        
        if person.water_received:
            happiness += 10.0
        else:
            happiness -= 15.0
        
        if person.electricity_received:
            happiness += 10.0
        else:
            happiness -= 15.0
        
        if person.sick:
            happiness -= 25.0
        
        # Clamp to valid range
        person.overall_happiness = max(0.0, min(100.0, happiness))
    
    # Update tracker
    self.average_happiness = self._calculate_average(population)

def _calculate_average(self, population: Population) -> float:
    """Calculate average happiness"""
    if len(population) == 0:
        return 50.0  # Default for empty city
    
    total = sum(p.overall_happiness for p in population)
    return total / len(population)
```

### Growth Model

```python
def _calculate_growth(self, city: City, context: TickContext) -> int:
    """Calculate natural population growth"""
    population_size = len(city.population)
    avg_happiness = city.happiness_tracker.get_average_happiness()
    
    # Growth rate depends on happiness
    if avg_happiness > 70:
        growth_rate = 0.02  # 2% growth
    elif avg_happiness > 50:
        growth_rate = 0.01  # 1% growth
    else:
        growth_rate = 0.00  # No growth
    
    # Calculate new births (deterministic)
    births = int(population_size * growth_rate)
    return births
```

### Migration Model

```python
def _calculate_migration(self, city: City, context: TickContext) -> int:
    """Calculate migration (in - out)"""
    avg_happiness = city.happiness_tracker.get_average_happiness()
    
    # Immigration based on happiness
    if avg_happiness >= 70:
        # High happiness attracts people
        if context.random.random() < 0.20:
            immigration = 20
        else:
            immigration = 0
    elif avg_happiness >= 50:
        if context.random.random() < 0.10:
            immigration = 10
        else:
            immigration = 0
    else:
        immigration = 0
    
    # Emigration when happiness is low
    if avg_happiness < 30:
        emigration = self._calculate_emigration(city, context)
    else:
        emigration = 0
    
    return immigration - emigration

def _calculate_emigration(self, city: City, context: TickContext) -> int:
    """Calculate how many people leave"""
    leavers = 0
    for person in city.population:
        # People without services more likely to leave
        leave_probability = 0.0
        if not person.has_home:
            leave_probability += 0.3
        if not person.water_received:
            leave_probability += 0.2
        if not person.electricity_received:
            leave_probability += 0.2
        
        if context.random.random() < leave_probability:
            leavers += 1
    
    return leavers
```

## Happiness Factors

Document the factors affecting happiness:

| Factor | Effect | Weight |
|--------|--------|--------|
| Has home | Positive | +15 |
| No home | Negative | -20 |
| Water received | Positive | +10 |
| No water | Negative | -15 |
| Electricity received | Positive | +10 |
| No electricity | Negative | -15 |
| Sick | Negative | -25 |
| Good budget | Positive | +5 |
| Poor budget | Negative | -10 |

Base happiness: 50.0  
Range: [0.0, 100.0]

## Population Metrics to Log

Per tick, log these metrics (see docs/specs/logging.md):

```python
{
    'run_id': context.run_id,
    'tick_index': context.tick_index,
    'timestamp': datetime.now().isoformat(),
    'population': len(city.population),
    'happiness': avg_happiness,
    'births': births,
    'deaths': deaths,
    'immigration': immigration,
    'emigration': emigration,
    'housed': sum(1 for p in city.population if p.has_home),
    'with_water': sum(1 for p in city.population if p.water_received),
    'with_electricity': sum(1 for p in city.population if p.electricity_received)
}
```

## Integration Points

### With Simulation Core (Workstream 01)
- Called via `population_subsystem.update(city, context)` each tick
- Return `PopulationDelta` with changes
- Use `context.random` for stochastic processes

### With City Modeling (Workstream 02)
- Read city infrastructure for service availability
- Affect population based on services
- Use `CityManager` to apply population changes

### With Finance (Workstream 03)
- Population size affects tax revenue
- Service costs scale with population
- Budget affects happiness (indirectly via services)

### With Data & Logging (Workstream 06)
- Emit population metrics per logging spec
- Include all required fields
- Log significant events (mass migration, etc.)

### With Testing (Workstream 07)
- Write tests validating population invariants
- Test happiness calculation
- Test migration thresholds

## Anti-Patterns to Avoid

❌ **Negative population**
```python
# WRONG - can go negative
city.population -= 100
```

❌ **Unbounded happiness**
```python
# WRONG - no bounds
person.happiness = 150.0  # Over 100!
```

❌ **Non-deterministic migration**
```python
# WRONG - uses unseeded random
if random.random() < 0.5:  # Non-deterministic!
    add_migrants()
```

❌ **Ignoring service state**
```python
# WRONG - happiness ignores services
person.happiness = 50.0  # Should consider if they have water, etc.
```

## Testing Requirements

### Invariant Tests
```python
def test_population_never_negative(self):
    """Population must stay >= 0"""
    city = City()
    for _ in range(100):
        city.advance_day()
    self.assertGreaterEqual(len(city.population), 0)

def test_happiness_bounded(self):
    """Happiness must stay in [0, 100]"""
    city = City()
    city.advance_day()
    for person in city.population:
        self.assertGreaterEqual(person.overall_happiness, 0)
        self.assertLessEqual(person.overall_happiness, 100)
```

### Determinism Tests
```python
def test_population_deterministic(self):
    """Same seed produces same population trends"""
    results = []
    for _ in range(3):
        city = City()
        sim = Sim(city=city, seed=42)
        sim.run(duration=10)
        results.append(len(city.population))
    
    self.assertEqual(results[0], results[1])
    self.assertEqual(results[1], results[2])
```

### Migration Tests
```python
def test_high_happiness_attracts_migration(self):
    """High happiness should increase population"""
    city = City()
    # Set up high happiness conditions
    for person in city.population:
        person.has_home = True
        person.water_received = True
        person.electricity_received = True
    
    initial_pop = len(city.population)
    
    # Advance many days
    for _ in range(50):
        city.advance_day()
    
    # Should have some growth
    self.assertGreater(len(city.population), initial_pop)
```

## Quick Reference

### Run Simulation
```bash
python run.py
```

### Test Population
```bash
python -m unittest tests.core.test_population
```

## Documentation to Read

Start here:
1. **docs/specs/population.md** - Your primary specification
2. **docs/design/workstreams/04-population.md** - This workstream's details
3. **docs/specs/city.md** - City state you interact with
4. **src/.github/copilot-instructions.md** - Source code guidelines

Remember: Population is the heart of the city. Happy citizens stay and grow; unhappy ones leave.
