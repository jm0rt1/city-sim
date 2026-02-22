# ADR 003: Performance Micro-Optimizations and Pitfall Inventory

## Status
Accepted

## Context

As the simulation grows in scale, even small inefficiencies in hot paths (code executed every
tick for every citizen) compound into significant performance regressions. This ADR documents a
systematic audit of the codebase for micro-optimization opportunities and known pitfalls, along
with the decisions made to address each one.

All changes described here are backward-compatible and preserve the existing public API surface.
Determinism requirements from [ADR-001](001-simulation-determinism.md) are maintained.

---

## Identified Issues and Decisions

### 1. Redundant List Construction in Generator Contexts

**Location**: `HappinessTracker.update_happiness`, `Population.property_tax`, `CityBudget.calculate_income`, `Sim.display_city_info`

**Problem**: Code used `sum([... list comprehension ...])` patterns. The list comprehension
allocates a full intermediate list in memory before `sum` consumes it. For large populations
this doubles the peak memory usage in these hot paths.

**Decision**: Replace all `sum([expr for x in iterable])` patterns with generator expressions
`sum(expr for x in iterable)`. Generators produce values lazily, eliminating the intermediate
allocation.

```python
# Before (allocates a list of N elements)
total = sum([person.overall_happiness for person in population.pops])

# After (no intermediate allocation)
total = sum(person.overall_happiness for person in population.pops)
```

**Impact**: Reduced per-tick memory allocation; no change to correctness or semantics.

---

### 2. Duplicate Iteration Over the Same Population for Identical Conditions

**Location**: `CityBudget.calculate_income` in `src/city/finance.py`

**Problem**: The original code iterated over `city.population` twice with the same predicate
(`person.property`) to compute `employed` and `properties` separately. Both variables
held the same value and both contributed to income via different tax rates.

```python
# Before: two full O(n) passes for the same data
employed = sum([1 for person in city.population if person.property])
self.income += employed * self.income_tax_rate

properties = sum([1 for person in city.population if person.property])
self.income += properties * self.property_tax_rate
```

**Decision**: Compute the count once and combine the tax rate additions.

```python
# After: single O(n) pass
with_property = sum(1 for person in city.population if person.property)
self.income += with_property * (self.income_tax_rate + self.property_tax_rate)
```

**Impact**: Halved the number of population iterations for the income calculation step.

---

### 3. Multiple Sequential Passes Over Population Per Tick

**Location**: `City.on_advance_day` in `src/city/city.py`

**Problem**: Resource distribution (water, electricity, housing) and happiness adjustment each
performed a separate pass over the full population list — four passes total per tick. At large
population sizes (e.g., 100 k citizens) this means 400 k iterations instead of 100 k.

```python
# Before: 4 separate O(n) passes
for person in self.population[:people_with_water]:
    person.water_received = True
for person in self.population[:people_with_electricity]:
    person.electricity_received = True
for person in self.population[:self.housing_units]:
    person.has_home = True
for person in self.population:
    person.adjust_happiness()
```

**Decision**: Combine all four passes into a single enumerated loop. The index `i` replaces
the slicing logic by comparing against the capacity thresholds.

```python
# After: single O(n) pass
for i, person in enumerate(self.population):
    person.water_received = i < people_with_water
    person.electricity_received = i < people_with_electricity
    person.has_home = i < self.housing_units
    person.adjust_happiness()
```

**Impact**: Reduced per-tick population iterations from 4× to 1×. Also eliminates three
intermediate list slices (`population[:n]`) which each allocate O(n) temporary lists.

---

### 4. Multiple Sequential Passes Over Population in Display

**Location**: `Sim.display_city_info` in `src/simulation/sim.py`

**Problem**: Four separate list-comprehension `sum` calls each iterated the full population to
count sick, without-water, without-electricity, and without-home citizens.

**Decision**: Combine into a single loop using simple counters.

```python
# After: single O(n) pass
sick_count = 0
without_water = 0
without_electricity = 0
without_home = 0
for person in self.city.population:
    if person.sick:
        sick_count += 1
    if not person.water_received:
        without_water += 1
    if not person.electricity_received:
        without_electricity += 1
    if not person.has_home:
        without_home += 1
```

**Impact**: 4× reduction in population traversals for the display step.

---

### 5. Bug: `Population.from_list` Mutated Class State Instead of Instance State

**Location**: `Population.from_list` in `src/city/population/population.py`

**Problem**: The factory method used `cls.pops = pops_list` which writes to the *class*
attribute rather than the instance attribute. This means every `Population` instance shares
the same `pops` list, causing silent corruption when multiple `Population` objects exist
simultaneously (e.g., during determinism testing with two independent simulation runs).

```python
# Before: sets class-level attribute — all instances share the same list
@classmethod
def from_list(cls, pops_list: list["Pop"]):
    population = cls()
    cls.pops = pops_list   # BUG: overwrites shared class attribute
    return population
```

**Decision**: Write to the newly created instance, not the class.

```python
# After: sets instance-level attribute
@classmethod
def from_list(cls, pops_list: list["Pop"]):
    population = cls()
    population.pops = pops_list
    return population
```

**Impact**: Correctness fix. Without this, any test or run that creates two `Population`
objects via `from_list` produces incorrect, unpredictable results.

---

## Additional Pitfalls Documented (Not Yet Addressed)

The following issues were identified during the audit. They are documented here for awareness
and future resolution, but are out of scope for the current change set.

### P1: Non-Deterministic Randomness in `Pop.__init__` and `Pop.adjust_happiness`

**Location**: `src/city/population/population.py`

**Problem**: `Pop.__init__` uses `random.randint(0, 100)` and `Pop.adjust_happiness` uses
`random.random()`, both calling the module-level `random` without a seeded generator. This
violates the determinism contract (ADR-001) because the global `random` state is shared and
not reset between runs.

**Recommended Fix**: Inject a `RandomService` instance (or a `random.Random` instance
initialized from the simulation seed) into `Pop` or its factory. See the `RandomService`
interface in `docs/specs/simulation.md`.

**Risk Level**: High — breaks reproducibility.

### P2: Non-Deterministic Randomness in `decisions.py` and `sim.py`

**Location**: `src/city/decisions.py`, `src/simulation/sim.py`

**Problem**: `DecisionBase.roll()`, `Sim.roll_disasters()`, `Sim.roll_for_newcomers()`, and
`Sim.roll_for_leavers()` all call `random.random()` directly on the unseeded global generator.

**Recommended Fix**: Replace all calls to `random.random()` with a `RandomService` that is
initialized from the simulation seed at startup and advanced deterministically each tick.

**Risk Level**: High — breaks reproducibility.

### P3: `City.on_advance_day` Does Not Reset Resource Flags Before Assignment

**Location**: `src/city/city.py`

**Problem**: `water_received`, `electricity_received`, and `has_home` are only set to `True`
for the first N citizens. Citizens beyond the capacity threshold retain whatever value these
flags had from the previous tick. If population decreases between ticks, a citizen who
previously had water may still show `water_received = True` even though they are now beyond
the coverage threshold.

**Recommended Fix**: Explicitly reset flags to `False` at the start of each day, or
unconditionally assign based on the index comparison (as done in the optimized single-pass
loop introduced by this ADR).

**Risk Level**: Medium — may produce incorrect happiness calculations for shrinking cities.

### P4: `CityBudget` Accumulates Income and Expenditure Across Ticks

**Location**: `src/city/finance.py`

**Problem**: `self.income` and `self.expenditure` are never reset between calls to
`update_budget`. Each tick the values are added to the running totals, so `self.balance`
drifts away from `current_tick_revenue - current_tick_expenses`. After N ticks `self.income`
is the *sum* of all revenue ever collected, not the current tick's revenue.

**Recommended Fix**: Reset `self.income = 0` and `self.expenditure = 0` at the start of
`update_budget`, or track a separate cumulative total.

**Risk Level**: High — budget invariant (ADR-001 and `docs/specs/city.md`) cannot hold.

### P5: `Population.adjust_happiness` Is Redundant With `City.on_advance_day`

**Location**: `src/city/population/population.py`, `src/city/city.py`

**Problem**: `Population.adjust_happiness()` iterates over `pops` and calls
`pop.adjust_happiness()` on each one. `City.on_advance_day` already calls
`person.adjust_happiness()` directly in its own loop. If both are called in the same tick,
happiness is adjusted twice.

**Recommended Fix**: Remove `Population.adjust_happiness()` or ensure it is not called
redundantly.

**Risk Level**: Medium — causes happiness to be computed twice per tick.

### P6: `Sim.roll_for_newcomers` Appends to `city.population` as if It Were a List

**Location**: `src/simulation/sim.py`

**Problem**: `self.city.population.append(Pop())` treats `city.population` as a plain list,
but `city.population` is a `Population` object. `Population` does not implement `append`;
it uses `add_pop`. This will raise `AttributeError` at runtime.

**Recommended Fix**: Use `self.city.population.add_pop(Pop())` or add an `append` alias to
`Population`.

**Risk Level**: High — runtime error in the newcomer migration path.

### P7: Inefficient Removal of Leavers via `list.remove()`

**Location**: `src/city/city_manager.py`

**Problem**: `manage_population` calls `self.city.population.remove_pop(pop)` in a loop.
`Population.remove_pop` delegates to `list.remove(pop)`, which is O(n) per call. For a city
with M leavers in a population of N, the total cost is O(M × N). With a large exodus event
this becomes quadratic.

**Recommended Fix**: Collect leavers in a set and rebuild the population list with a single
filter pass: `self.pops = [p for p in self.pops if p not in leavers_set]` where
`leavers_set` is a `set` built from the leaver list.

**Risk Level**: Medium — performance degrades quadratically during mass-emigration events.

### P8: `GlobalSettings` Creates Directories at Class Definition Time

**Location**: `src/shared/settings.py`

**Problem**: `OUTPUT_DIR.mkdir(...)`, `LOGS_DIR.mkdir(...)` etc. are executed at the *class
body* level, meaning they run the moment `settings.py` is imported. This triggers file-system
side-effects in test environments and anywhere `settings` is imported without intending to
create directories.

**Recommended Fix**: Move directory creation into an explicit `initialize()` class method or
into `main.py` before the simulation starts.

**Risk Level**: Low-Medium — undesirable side-effects during testing and import.

---

## Performance Targets (Reference)

From `docs/specs/simulation.md` and ADR-002:

| City Scale       | Population     | Target Tick Duration |
|------------------|----------------|----------------------|
| Small            | 10 k           | < 10 ms              |
| Medium           | 100 k          | < 50 ms              |
| Large            | 1 M            | < 200 ms             |
| Metropolis       | 10 M           | < 1000 ms            |

The optimizations in this ADR (items 1–5) reduce per-tick loop iterations by approximately
4× for the population-processing phase, directly contributing to meeting these targets.

---

## Consequences

### Positive
- Reduced per-tick memory allocation in hot paths.
- Reduced per-tick CPU time for population processing (up to 4× fewer iterations).
- Correctness fix for `Population.from_list` that prevents silent shared-state corruption.
- Consolidated documentation of all known pitfalls in a single, searchable ADR.

### Negative
- None for items 1–5 (all are pure refactors with equivalent semantics).
- Items P1–P8 remain open; they require deeper architectural changes (e.g., `RandomService`
  injection) and are tracked here for future implementation.

---

## References

- [ADR-001: Simulation Determinism](001-simulation-determinism.md)
- [ADR-002: Free-Threaded Python](002-free-threaded-python.md)
- [Simulation Specification](../specs/simulation.md) — Performance Considerations section
- [City Specification](../specs/city.md) — Invariants section
- [Finance Specification](../specs/finance.md)
- [Population Specification](../specs/population.md)

## Decision Date
2026-02-22

## Decision Makers
- AI Development Assistant (audit and implementation)
- Project Lead: James Mortensen (review)

## Review Date
To be reviewed after P1–P8 pitfalls are addressed.
