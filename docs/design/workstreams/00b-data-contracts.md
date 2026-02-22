# Pre-Work Workstream 00B: Data Contracts & Delta Aggregation

> **Status**: Pre-work — must be completed before WS-02, WS-03, WS-04, and WS-10 begin
> implementation. Agents for those workstreams must read and accept these contracts before writing
> any code that produces or consumes delta objects.

## Purpose

Lock the data-contract layer: the concrete delta types produced by each subsystem, the rules
`CityManager` uses to aggregate them into `CityDelta`, and the ownership boundaries for
`ServiceManager` and `InfrastructureManager`. Without this workstream, subsystem agents risk
producing incompatible delta structures or silently overwriting each other's state.

All changes in this workstream are **documentation-only**.

---

## Reading Checklist

- [ ] Architecture Overview: [../../architecture/overview.md](../../architecture/overview.md)
- [ ] Class Hierarchy: [../../architecture/class-hierarchy.md](../../architecture/class-hierarchy.md)
- [ ] Interfaces Spec: [../../specs/interfaces.md](../../specs/interfaces.md) ← **read first**
- [ ] City Spec: [../../specs/city.md](../../specs/city.md)
- [ ] Finance Spec: [../../specs/finance.md](../../specs/finance.md)
- [ ] Population Spec: [../../specs/population.md](../../specs/population.md)
- [ ] Traffic Spec: [../../specs/traffic.md](../../specs/traffic.md)
- [ ] Pre-Work WS-00A: [00a-shared-interfaces.md](00a-shared-interfaces.md) ← **prerequisite**
- [ ] Pre-Work WS-00C: [00c-integration-protocols.md](00c-integration-protocols.md) ← read after this workstream (not a prerequisite)

---

## Objectives

1. **Lock `FinanceDelta`** — complete field list, constraints, and serialization contract.
2. **Lock `PopulationDelta`** — complete field list, constraints, and serialization contract.
3. **Lock `TrafficDelta`** — complete field list, constraints, and serialization contract.
4. **Lock `CityDelta`** — aggregation rules and the `__add__` merge semantics.
5. **Define `IServiceManager`** — the write interface for service coverage (owned by WS-02).
6. **Define `IInfrastructureManager`** — the write interface for non-transport infrastructure
   (owned by WS-02; transport portion owned by WS-10).
7. **Clarify ownership table** — which workstream owns each field of `CityState`.

---

## Scope

| File | Action |
|------|--------|
| `docs/specs/interfaces.md` | **Update** — confirm/expand §10–11 (IServiceManager, IInfrastructureManager) |
| `docs/specs/city.md` | **Update** — add ownership table and delta aggregation rules |
| `docs/specs/finance.md` | **Update** — confirm FinanceDelta field list against interfaces.md §2 |
| `docs/specs/population.md` | **Update** — confirm PopulationDelta field list |
| `docs/specs/traffic.md` | **Update** — confirm TrafficDelta field list |

No source code files are in scope for this workstream.

---

## Data Contracts

### FinanceDelta (owned by WS-03)

```python
from dataclasses import dataclass, field
from typing import Any
from .interfaces import SubsystemDelta

@dataclass
class FinanceDelta(SubsystemDelta):
    subsystem_name: str = "finance"

    # Aggregates
    revenue: float = 0.0           # Total revenue generated this tick (>= 0)
    expenses: float = 0.0          # Total expenses incurred this tick (>= 0)
    budget_change: float = 0.0     # Net: revenue - expenses (may be negative)

    # Revenue Breakdown
    revenue_taxes: float = 0.0
    revenue_fees: float = 0.0
    revenue_grants: float = 0.0
    revenue_other: float = 0.0

    # Expense Breakdown
    expense_services: float = 0.0
    expense_infrastructure: float = 0.0
    expense_debt_service: float = 0.0
    expense_operations: float = 0.0
    expense_other: float = 0.0

    # Derived
    is_deficit: bool = False        # True when budget_change < 0

    def to_log_dict(self) -> dict[str, Any]:
        """Keys prefixed with 'finance.'."""
```

**Constraint**: `abs(budget_change - (revenue - expenses)) < 1e-6`

### PopulationDelta (owned by WS-04)

```python
@dataclass
class PopulationDelta(SubsystemDelta):
    subsystem_name: str = "population"

    # Aggregates
    population_change: int = 0     # Net change (births + migration_in - deaths - migration_out)
    happiness_change: float = 0.0  # Net change in happiness

    # Components
    births: int = 0
    deaths: int = 0
    migration_in: int = 0
    migration_out: int = 0

    # Happiness Components
    happiness_from_services: float = 0.0
    happiness_from_infrastructure: float = 0.0
    happiness_from_economy: float = 0.0
    happiness_from_traffic: float = 0.0   # From previous tick's transport_quality

    def to_log_dict(self) -> dict[str, Any]:
        """Keys prefixed with 'population.'."""
```

**Constraint**: `population_change == births + migration_in - deaths - migration_out`

### TrafficDelta (owned by WS-10)

```python
@dataclass
class TrafficDelta(SubsystemDelta):
    subsystem_name: str = "transport"

    # Network Metrics
    avg_speed: float = 0.0             # Average vehicle speed (km/h), >= 0
    congestion_index: float = 0.0      # 0 = free flow, 1 = full gridlock
    throughput: int = 0                # Vehicles that completed routes this tick

    # Incident Tracking
    active_incidents: int = 0
    incidents_resolved: int = 0
    incidents_created: int = 0

    # Quality Output (written to city.state.infrastructure.transport_quality)
    transport_quality_change: float = 0.0  # Delta applied to transport_quality metric

    def to_log_dict(self) -> dict[str, Any]:
        """Keys prefixed with 'transport.'."""
```

**Constraint**: `0.0 <= congestion_index <= 1.0`

---

## CityDelta Aggregation Rules

`CityManager` merges all subsystem deltas into a single `CityDelta` using these rules:

```
CityDelta = aggregate(FinanceDelta, PopulationDelta, TrafficDelta, [additional deltas])
```

| `CityDelta` field | Source | Aggregation |
|-------------------|--------|-------------|
| `budget_change` | `FinanceDelta.budget_change` | direct copy (Finance is sole owner) |
| `revenue` | `FinanceDelta.revenue` | direct copy |
| `expenses` | `FinanceDelta.expenses` | direct copy |
| `population_change` | `PopulationDelta.population_change` | direct copy (Population is sole owner) |
| `births` | `PopulationDelta.births` | direct copy |
| `deaths` | `PopulationDelta.deaths` | direct copy |
| `migration_in` | `PopulationDelta.migration_in` | direct copy |
| `migration_out` | `PopulationDelta.migration_out` | direct copy |
| `happiness_change` | `PopulationDelta.happiness_change` | direct copy (Population is sole owner) |
| `infrastructure_investments` | Decision parameters | dict merge (no key collision allowed) |
| `infrastructure_degradation` | `TrafficDelta` + `CityManager` maintenance | dict merge |
| `service_expansions` | Decision parameters → `IServiceManager` | dict merge |
| `service_reductions` | Decision parameters → `IServiceManager` | dict merge |
| `applied_decisions` | all `SubsystemDelta.applied_decisions` | list concatenation |

**Field Ownership Rule**: If a field appears in only one subsystem delta, that subsystem is the
sole writer; no other subsystem may write it. If a field is derived from multiple subsystems
(e.g., `infrastructure_degradation`), the merge rule is explicit and documented in this table.

---

## Ownership Table: CityState Fields

| Field | Writer | Reader(s) |
|-------|--------|-----------|
| `city.state.budget` | `CityManager` (via `FinanceDelta`) | Finance (previous tick value) |
| `city.state.population` | `CityManager` (via `PopulationDelta`) | Finance, Population |
| `city.state.happiness` | `CityManager` (via `PopulationDelta`) | Population, UI |
| `city.state.infrastructure.transport` | Transport subsystem (WS-10) | Transport, Population |
| `city.state.infrastructure.transport_quality` | `CityManager` (via `TrafficDelta.transport_quality_change`) | Population |
| `city.state.infrastructure.utility_quality` | `CityManager` / `IInfrastructureManager` | Population, Finance |
| `city.state.infrastructure.power_quality` | `CityManager` / `IInfrastructureManager` | Population, Finance |
| `city.state.infrastructure.water_quality` | `CityManager` / `IInfrastructureManager` | Population, Finance |
| `city.state.services.*_coverage` | `CityManager` / `IServiceManager` | Population, Finance, UI |
| `city.current_tick` | `CityManager` | All (read-only) |

**Golden Rule**: A field listed under "Writer" may only be updated by that component. Any
workstream that needs to influence the field must do so via a `Decision` object, which
`CityManager` processes.

---

## Service & Infrastructure Manager Ownership

- `IServiceManager` is **implemented by `CityManager`** (WS-02) and is the only component that
  writes `ServiceState` coverage fields.
- `IInfrastructureManager` is **implemented by `CityManager`** (WS-02) for non-transport domains.
  Transport infrastructure is managed by `TransportSubsystem` (WS-10).
- Finance and Population subsystems are **read-only** consumers of `ServiceState` and
  `InfrastructureState`.

---

## Inputs

- `docs/specs/interfaces.md` (WS-00A output)
- All existing spec files in `docs/specs/`

---

## Outputs

- Confirmed and fully-expanded delta type definitions (in this document and cross-referenced in
  the relevant subsystem specs).
- Ownership table published in `docs/specs/city.md`.
- Delta aggregation rules referenced in `docs/specs/simulation.md`.

---

## Task Backlog

- [x] Write complete `FinanceDelta` field list with constraints.
- [x] Write complete `PopulationDelta` field list with constraints.
- [x] Write complete `TrafficDelta` field list with constraints.
- [x] Write `CityDelta` aggregation rules table.
- [x] Write `CityState` ownership table.
- [x] Document `IServiceManager` and `IInfrastructureManager` ownership.
- [ ] Cross-check `FinanceDelta` against `docs/specs/finance.md`; resolve any discrepancies.
- [ ] Cross-check `PopulationDelta` against `docs/specs/population.md`; resolve any discrepancies.
- [ ] Cross-check `TrafficDelta` against `docs/specs/traffic.md`; resolve any discrepancies.

---

## Acceptance Criteria

1. Every field of every delta type is named, typed, and has a documented constraint or invariant.
2. No two workstreams write the same `CityState` field (verified by the ownership table).
3. The `CityDelta` aggregation table covers all fields and specifies merge semantics.
4. `IServiceManager` and `IInfrastructureManager` interfaces are consistent with `interfaces.md`.
5. All conflicts identified during cross-check are resolved and documented.

---

## Checkpoints

- [ ] Delta type definitions reviewed and accepted by WS-02, WS-03, WS-04, WS-10 leads.
- [ ] Ownership table added to `docs/specs/city.md`.
- [ ] Aggregation rules added to `docs/specs/simulation.md`.

---

## Copy‑Paste Prompt

```
Preflight Checklist:
- [ ] Read interfaces.md (WS-00A output) in full
- [ ] Read city.md, finance.md, population.md, traffic.md
- [ ] Identify any field naming or type conflicts between specs
- [ ] Review CityDelta aggregation rules in this document

You are an AI agent working on City-Sim, completing Pre-Work Workstream 00B: Data Contracts.

Objectives:
- Confirm and expand the delta type definitions (FinanceDelta, PopulationDelta, TrafficDelta).
- Document CityDelta aggregation rules and CityState ownership in city.md.
- Ensure zero field-name collisions across subsystem deltas.

Global Context Pack:
- Interfaces: docs/specs/interfaces.md
- City: docs/specs/city.md
- Finance: docs/specs/finance.md
- Population: docs/specs/population.md
- Traffic: docs/specs/traffic.md
- Pre-Work: docs/design/workstreams/00a-shared-interfaces.md,
            docs/design/workstreams/00b-data-contracts.md

Scope & Files:
- docs/specs/interfaces.md (update §2 if needed)
- docs/specs/city.md (add ownership table)
- docs/specs/simulation.md (add aggregation rules reference)
- docs/specs/finance.md, population.md, traffic.md (confirm delta fields)

Acceptance Criteria:
- All delta fields named, typed, and constrained.
- No two subsystems write the same CityState field.
- CityDelta merge semantics fully documented.

Deliver:
- Conflict detection notes
- Exact doc edits
- Validation: check that every field in CityDelta traces to exactly one source
```
