# Pre-Work Workstream 00C: Integration Protocols

> **Status**: Pre-work — must be completed before WS-01, WS-02, WS-03, WS-04, WS-06, and WS-10
> begin implementation. Agents for those workstreams must read and accept these protocols before
> writing any code that crosses subsystem boundaries.

## Purpose

Define the runtime integration rules that govern *how* subsystems interact during each tick:
the fixed update order, determinism contracts, cross-subsystem feedback loops, error propagation,
and event-bus usage. Without this workstream, independently-developed subsystems may make
incompatible assumptions about execution order or state visibility, leading to non-deterministic
or inconsistent simulations.

All changes in this workstream are **documentation-only**.

---

## Reading Checklist

- [ ] Architecture Overview: [../../architecture/overview.md](../../architecture/overview.md)
- [ ] Class Hierarchy: [../../architecture/class-hierarchy.md](../../architecture/class-hierarchy.md)
- [ ] Interfaces Spec: [../../specs/interfaces.md](../../specs/interfaces.md) ← **read first**
- [ ] Data Contracts WS-00B: [00b-data-contracts.md](00b-data-contracts.md) ← **prerequisite**
- [ ] Simulation Spec: [../../specs/simulation.md](../../specs/simulation.md)
- [ ] City Spec: [../../specs/city.md](../../specs/city.md)
- [ ] ADR-001 Determinism: [../../adr/001-simulation-determinism.md](../../adr/001-simulation-determinism.md)
- [ ] Pre-Work WS-00A: [00a-shared-interfaces.md](00a-shared-interfaces.md)

---

## Objectives

1. **Define the canonical tick execution order** — no workstream may deviate from it.
2. **Define the state-visibility rule** — subsystems see start-of-tick state; they cannot read
   each other's within-tick outputs.
3. **Define determinism contracts** — all sources of non-determinism are enumerated and
   explicitly forbidden or controlled.
4. **Define error propagation rules** — how exceptions in one subsystem affect others.
5. **Define feedback loop contracts** — the one-tick lag rule for cross-subsystem dependencies.
6. **Define EventBus usage rules** — what events are required, how handlers must behave.
7. **Define MetricsCollector usage rules** — which metrics are mandatory each tick.
8. **Define the scenario ↔ settings relationship** — what takes precedence.

---

## 1. Canonical Tick Execution Order

The following order is **fixed**. `SimCore` (WS-01) and `CityManager` (WS-02) must implement this
exactly. No subsystem, policy, or event handler may reorder steps.

```
Tick N begins
│
├─ Step 1:  SimCore creates TickContext(tick_index=N, random_service, event_bus, policy_set)
│
├─ Step 2:  PolicyEngine.evaluate(city, context) → List[Decision]
│           • Policies observe start-of-tick city state (read-only)
│           • Decisions are sorted by (priority ASC, registration_order ASC)
│
├─ Step 3:  CityManager.apply_decisions(city, decisions, context) → partial CityDelta
│           • Tax rates, service expansions, infrastructure investments recorded
│           • No subsystem deltas produced here
│           • City state is NOT yet modified; changes are staged in the partial delta
│
├─ Step 4:  Subsystem updates (run in this fixed order, each with start-of-tick city state):
│   ├─ 4a: FinanceSubsystem.update(city, context)   → FinanceDelta
│   ├─ 4b: PopulationSubsystem.update(city, context) → PopulationDelta
│   └─ 4c: TransportSubsystem.update(city, context)  → TrafficDelta
│           • Each subsystem receives the SAME city state (as it was at step start)
│           • Subsystems MUST NOT read each other's within-tick deltas
│
├─ Step 5:  CityManager aggregates deltas:
│           • Merges partial CityDelta (step 3) + FinanceDelta + PopulationDelta + TrafficDelta
│           • Applies aggregated CityDelta to city state (single atomic commit)
│           • Updates city.current_tick = N
│
├─ Step 6:  CityManager.validate_invariants(city) → List[InvariantViolation]
│           • In strict_mode: raise SimulationError on any violation
│           • Otherwise: log violations as warnings; clamp invalid values
│
├─ Step 7:  MetricsCollector.record_dict(tick_metrics, tick_index=N)
│           • Mandatory metrics listed in §7
│
├─ Step 8:  EventBus processes deferred events from steps 2–6 (if any)
│           • Events are processed FIFO
│           • Handlers may NOT modify city state or emit new events
│
├─ Step 9:  Logger writes structured log entry (JSONL or CSV)
│           • Includes all fields from Logging Specification
│
└─ Step 10: SimCore checks termination conditions (tick_horizon reached, etc.)

Tick N complete
```

**Why this order?**
- Finance runs before Population so that Population can observe the *committed* budget from the
  previous tick (the one-tick lag rule — see §5).
- Transport runs after Population so that traffic incidents do not retroactively affect population
  calculations within the same tick.
- Invariant validation runs after all deltas are committed so that it sees final state.
- MetricsCollector and Logger run after invariant validation so that metrics reflect clamped state.

---

## 2. State-Visibility Rule

> **Rule**: During steps 4a–4c, every subsystem observes the city state as it existed at the
> **end of the previous tick** (i.e., step 5 of tick N-1). No subsystem may read a delta produced
> by another subsystem during the current tick.

Consequences:
- Finance calculating revenue uses `city.state.population` from tick N-1.
- Population calculating happiness uses `city.state.budget` from tick N-1.
- Transport updating road quality uses `city.state.infrastructure.transport` from tick N-1
  (with its own within-tick modifications, since Transport owns that field).

This rule is enforced architecturally: subsystems receive the `city` object which has not yet been
modified when they are called (step 4). The commit happens in step 5.

---

## 3. Determinism Contracts

All of the following are **prohibited** in subsystem, policy, or event-handler code:

| Prohibited | Reason | Permitted Alternative |
|------------|--------|-----------------------|
| `random.random()` (stdlib) | Non-deterministic without explicit seed | `context.random_service.random()` |
| `numpy.random.*` (unseeded) | Non-deterministic | `context.random_service.*` |
| `time.time()` | Non-deterministic | `context.tick_index` for temporal logic |
| `datetime.now()` | Non-deterministic | `context.tick_index` |
| `os.urandom()` | Non-deterministic | `context.random_service.*` |
| `uuid.uuid4()` | Non-deterministic | `f"{context.tick_index}_{sequential_counter}"` |
| `set` iteration | Non-deterministic order | `sorted(my_set)` |
| `dict` key iteration without explicit ordering | Subtle order dependence in aggregations | Use `sorted(d.items())` when order matters |
| Parallel execution with shared mutable state | Race conditions | Serialize updates or use locks |
| External I/O (database reads, HTTP) during tick | Latency variance breaks timing | Pre-load before tick loop |
| Floating-point order dependence | Results vary with summation order | Use `math.fsum()` or documented order |

**Determinism test**: Run the same scenario twice with the same seed. Compare logs byte-for-byte.
Any difference is a determinism bug.

---

## 4. Error Propagation Rules

| Error Type | Where Raised | Propagation Rule |
|------------|-------------|-----------------|
| `ConfigurationError` | Before tick loop | Fatal — halt simulation before tick 0 |
| `ScenarioNotFoundError` | `ScenarioLoader.load()` | Fatal — halt simulation |
| `InvariantError` (strict_mode) | Step 6 | Fatal — halt simulation, log full context |
| `InvariantViolation` (non-strict) | Step 6 | Log warning; clamp values; continue |
| Subsystem exception (unexpected) | Steps 4a–4c | Log error + full stack trace; re-raise as `SimulationError` |
| `PolicyConflictError` | Step 2 | Fatal — halt simulation |
| Event handler exception | Step 8 | Log error; continue (handlers must not be critical path) |
| Logger/metrics exception | Steps 7, 9 | Log error to stderr; continue (never halt for logging failure) |

**Fail-fast philosophy**: Correctness errors (invariant violations in strict mode, configuration
errors, policy conflicts) halt immediately to prevent silent corruption. Observability errors
(logging, metrics) never halt the simulation.

---

## 5. Feedback Loop Contracts (One-Tick Lag)

The following cross-subsystem dependencies are intentional and introduce exactly one tick of lag.
This is the only acceptable form of cross-subsystem data dependency.

| Dependency | Producer | Consumer | Lag |
|------------|----------|----------|-----|
| Population count affects tax revenue | Population (tick N) | Finance (tick N+1) | 1 tick |
| Budget affects migration decisions | Finance (tick N) | Population (tick N+1) | 1 tick |
| Service coverage affects happiness | CityManager (tick N) | Population (tick N+1) | 1 tick |
| Infrastructure quality affects happiness | CityManager (tick N) | Population (tick N+1) | 1 tick |
| Traffic congestion affects happiness | Transport (tick N) | Population (tick N+1) via `transport_quality` | 1 tick |
| Happiness affects migration rate | Population (tick N) | Population (tick N+1) | 1 tick (internal) |

**Zero-lag dependencies are forbidden** between different subsystems to prevent evaluation-order
sensitivity.

---

## 6. EventBus Usage Rules

| Rule | Detail |
|------|--------|
| Event types must be registered | Call `event_bus.subscribe()` before tick loop starts |
| Event types must be namespaced | Format: `"<subsystem>.<event_name>"` (see namespace table in interfaces.md §16) |
| Handlers are read-only | Handlers MUST NOT modify `city` state or call `event_bus.publish()` |
| Handler exceptions | Logged and re-raised; do NOT swallow exceptions silently |
| Events do not carry over | Events from tick N are discarded after step 8 of tick N |

**Required events** (every subsystem must publish these at minimum):

| Event Type | Publisher | Trigger Condition |
|------------|-----------|-------------------|
| `finance.budget_updated` | Finance | Every tick |
| `finance.deficit_detected` | Finance | When `budget_change < 0` |
| `population.population_updated` | Population | Every tick |
| `population.happiness_updated` | Population | Every tick |
| `transport.metrics_updated` | Transport | Every tick (if active) |
| `sim.tick_complete` | SimCore | End of every tick (step 10) |
| `sim.invariant_violation` | CityManager | When violations found in step 6 |

---

## 7. Mandatory Metrics (MetricsCollector)

The following metrics MUST be recorded every tick via `MetricsCollector.record_dict()`:

```python
mandatory_metrics = {
    "sim.tick_duration_ms":             float,  # Measured by SimCore
    "finance.budget":                   float,  # city.state.budget after commit
    "finance.revenue":                  float,  # FinanceDelta.revenue
    "finance.expenses":                 float,  # FinanceDelta.expenses
    "population.count":                 int,    # city.state.population after commit
    "population.happiness":             float,  # city.state.happiness after commit
    "population.births":                int,    # PopulationDelta.births
    "population.deaths":                int,    # PopulationDelta.deaths
    "population.migration_in":          int,    # PopulationDelta.migration_in
    "population.migration_out":         int,    # PopulationDelta.migration_out
    "services.health_coverage":         float,  # city.state.services.health_coverage
    "services.education_coverage":      float,  # city.state.services.education_coverage
    "infra.transport_quality":          float,  # city.state.infrastructure.transport_quality
}

# Optional (recorded only when Transport subsystem is active)
optional_transport_metrics = {
    "transport.avg_speed":              float,
    "transport.congestion_index":       float,
    "transport.throughput":             int,
    "transport.active_incidents":       int,
}
```

All metric keys follow the namespace conventions in `interfaces.md §16`.

---

## 8. Scenario ↔ Settings Precedence

When both `Scenario` and `Settings` specify the same parameter, **`Scenario` takes precedence** for
simulation parameters (seed, tick_horizon, initial conditions) and **`Settings` takes precedence**
for infrastructure parameters (log_format, log_path, profiling_enabled, strict_mode).

| Parameter | Precedence | Reason |
|-----------|-----------|--------|
| `seed` | `Scenario` | Scenarios are self-contained reproducible experiments |
| `tick_horizon` | `Scenario` | Scenario defines its own duration |
| `initial_budget` | `Scenario` | Scenario defines initial conditions |
| `initial_population` | `Scenario` | Scenario defines initial conditions |
| `initial_happiness` | `Scenario` | Scenario defines initial conditions |
| `policy_ids` | `Scenario` merged with `Settings.policy_set` | Both sources contribute policies |
| `log_format` | `Settings` | Deployment concern, not scenario concern |
| `log_path` | `Settings` | Deployment concern |
| `profiling_enabled` | `Settings` | Deployment concern |
| `strict_mode` | `Settings` | Deployment concern |

`SimRunner` applies this precedence table when merging `Scenario` into `Settings`.

---

## Inputs

- `docs/specs/interfaces.md` (WS-00A output)
- `docs/design/workstreams/00b-data-contracts.md` (WS-00B output)
- `docs/specs/simulation.md`
- `docs/adr/001-simulation-determinism.md`

---

## Outputs

- This document (`00c-integration-protocols.md`) is the primary deliverable.
- `docs/specs/simulation.md` — update §Determinism to reference the prohibited-list table from §3.
- `docs/specs/city.md` — update §Operations to reference the canonical tick order from §1.

---

## Task Backlog

- [x] Define canonical tick execution order (§1).
- [x] Define state-visibility rule (§2).
- [x] Define determinism contracts with prohibited-list table (§3).
- [x] Define error propagation rules table (§4).
- [x] Define feedback loop contracts / one-tick lag table (§5).
- [x] Define EventBus usage rules and required events table (§6).
- [x] Define mandatory metrics list (§7).
- [x] Define scenario ↔ settings precedence table (§8).
- [ ] Update `docs/specs/simulation.md` to cross-reference §1 and §3.
- [ ] Update `docs/specs/city.md` to cross-reference §1 and §2.

---

## Acceptance Criteria

1. The canonical tick order in §1 matches the order described in `simulation.md` and `city.md`.
2. Every source of non-determinism in §3 is covered and every workaround is documented.
3. The one-tick-lag table in §5 covers all cross-subsystem dependencies identified in WS-00B.
4. Required events in §6 are referenced in each subsystem's workstream.
5. Mandatory metrics in §7 are a superset of all `required` fields in `logging.md`.

---

## Checkpoints

- [ ] Tick order reviewed and accepted by WS-01 (SimCore), WS-02 (CityManager) leads.
- [ ] Determinism prohibited list reviewed by WS-07 (Testing & CI) for test coverage.
- [ ] Feedback loop table verified against WS-03 (Finance) and WS-04 (Population) implementations.

---

## Copy‑Paste Prompt

```
Preflight Checklist:
- [ ] Read interfaces.md (WS-00A output) in full
- [ ] Read 00b-data-contracts.md (WS-00B output) in full
- [ ] Read simulation.md and city.md
- [ ] Read ADR-001 on determinism

You are an AI agent working on City-Sim, completing Pre-Work Workstream 00C: Integration Protocols.

Objectives:
- Confirm the canonical tick order matches simulation.md and city.md.
- Verify no subsystem violates the state-visibility rule.
- Ensure all non-determinism sources are enumerated and handled.
- Cross-reference mandatory metrics against logging.md required fields.

Global Context Pack:
- Interfaces: docs/specs/interfaces.md
- Data Contracts: docs/design/workstreams/00b-data-contracts.md
- Simulation: docs/specs/simulation.md
- City: docs/specs/city.md
- Logging: docs/specs/logging.md
- ADR-001: docs/adr/001-simulation-determinism.md

Scope & Files:
- docs/design/workstreams/00c-integration-protocols.md (confirm/expand)
- docs/specs/simulation.md (add cross-reference to §1 and §3 of this doc)
- docs/specs/city.md (add cross-reference to §1 and §2 of this doc)

Acceptance Criteria:
- Tick order consistent across all docs.
- Determinism prohibited list comprehensive.
- All cross-subsystem dependencies in the one-tick-lag table.
- Mandatory metrics superset of logging.md required fields.

Deliver:
- Conflict and gap notes
- Exact doc edits
- Validation: confirm each mandatory metric maps to a field in logging.md
```
