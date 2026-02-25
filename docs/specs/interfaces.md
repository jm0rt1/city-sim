# Specification: Shared Interfaces & Contracts

## Purpose

Define all cross-cutting interface contracts that are consumed by more than one workstream. Every
agent or developer working on any subsystem **must** read this document before writing code. These
contracts are the single source of truth; no workstream may redefine them locally.

This file is intentionally free of business logic. Its only goal is to eliminate ambiguity so that
independently-developed subsystems can be composed without conflicts.

---

## 1. ISubsystem — Base Subsystem Interface

Every simulation subsystem (Finance, Population, Transport, …) must implement this protocol.

```python
from __future__ import annotations
from typing import Protocol

class ISubsystem(Protocol):
    """
    Minimum contract every subsystem must satisfy.

    CityManager iterates registered subsystems in the defined update order
    and calls update() exactly once per tick.
    """

    @property
    def name(self) -> str:
        """
        Machine-readable subsystem identifier (e.g. "finance", "population").
        Used in log keys and metrics namespacing.
        Must be stable across releases.
        """
        ...

    def update(self, city: "City", context: "TickContext") -> "SubsystemDelta":
        """
        Perform one tick of subsystem logic.

        Contract:
        - MUST NOT modify city state directly; return a SubsystemDelta instead.
          CityManager is solely responsible for committing deltas.
        - MUST be deterministic: same city + same context → same delta.
        - MUST NOT raise unless configuration is invalid (raise ConfigurationError).
        - MUST complete within the subsystem's registered tick budget.

        Args:
            city:    Read-only view of current city state.
            context: Per-tick metadata including random_service and policy_set.

        Returns:
            SubsystemDelta describing every change this subsystem wants to make.
        """
        ...

    def validate(self, city: "City") -> list["InvariantViolation"]:
        """
        Check subsystem-specific invariants without modifying state.

        Returns:
            Empty list when all invariants hold; list of violations otherwise.
        """
        ...
```

**Rules**:
- Subsystems are instantiated once and reused across all ticks.
- Subsystems must be stateless between ticks (all mutable state lives in `City`).
- The update-order is owned by `CityManager` (see §6).

---

## 2. SubsystemDelta — Generic Delta Base

Each subsystem returns a concrete subclass. `CityManager` aggregates them into `CityDelta`.

```python
from dataclasses import dataclass, field
from typing import Any

@dataclass
class SubsystemDelta:
    """
    Base class for all per-tick subsystem output.

    Fields common to every delta type are defined here.
    Subsystem-specific fields are added in concrete subclasses
    (FinanceDelta, PopulationDelta, TrafficDelta).
    """

    subsystem_name: str                  # Matches ISubsystem.name
    tick_index: int                      # Tick number that produced this delta
    applied_decisions: list[str] = field(default_factory=list)
    # IDs of Decision objects that influenced this delta

    def to_log_dict(self) -> dict[str, Any]:
        """
        Serialize to a flat dictionary suitable for structured logging.
        Keys must be namespaced: "<subsystem_name>.<field_name>".
        """
        raise NotImplementedError
```

**Aggregation rules** (enforced by `CityManager`):
1. Numeric fields are **summed** across all deltas for the same field name.
2. List fields are **concatenated**.
3. In case of field collision between subsystems, the **last writer wins** is *forbidden*;
   fields must use the subsystem namespace prefix to avoid collisions.

---

## 3. IPolicy — Policy Interface

Policies are stateless evaluators. They observe city state and return `Decision` objects.

```python
from typing import Protocol

class IPolicy(Protocol):
    """
    Stateless policy evaluator.

    Policies are registered with PolicyEngine and evaluated in registration order
    every tick (order is deterministic because PolicyEngine maintains a list, not a set).
    """

    @property
    def policy_id(self) -> str:
        """Stable, unique policy identifier (e.g. "tax_policy_v1")."""
        ...

    def evaluate(
        self,
        city: "City",
        context: "TickContext",
    ) -> list["Decision"]:
        """
        Observe city state and return zero or more decisions.

        Contract:
        - MUST be deterministic.
        - MUST NOT modify city or context.
        - MUST use context.random_service for any randomness.
        - MUST return an empty list (not None) when no action is taken.

        Args:
            city:    Read-only snapshot of city state.
            context: Tick context providing random_service and settings.

        Returns:
            List of Decision objects (may be empty).
        """
        ...
```

---

## 4. Decision — Policy Output

```python
from dataclasses import dataclass, field
from enum import Enum
from typing import Any

class DecisionType(Enum):
    # Finance
    TAX_RATE_CHANGE          = "tax_rate_change"
    BUDGET_ALLOCATION        = "budget_allocation"
    INFRASTRUCTURE_INVESTMENT = "infrastructure_investment"
    SERVICE_EXPANSION        = "service_expansion"
    SERVICE_REDUCTION        = "service_reduction"
    DEBT_ISSUANCE            = "debt_issuance"

    # Population / Happiness
    HAPPINESS_INTERVENTION   = "happiness_intervention"
    HOUSING_POLICY           = "housing_policy"
    MIGRATION_INCENTIVE      = "migration_incentive"

    # Transport
    SIGNAL_TIMING_CHANGE     = "signal_timing_change"
    SPEED_LIMIT_CHANGE       = "speed_limit_change"
    ROAD_CLOSURE             = "road_closure"

    # Generic / Extension
    CUSTOM                   = "custom"

@dataclass
class Decision:
    """
    An atomic, reversible instruction produced by a Policy.

    CityManager applies decisions in the order they are returned by PolicyEngine.
    Decisions affecting the same field are applied sequentially (no batching).
    """

    decision_id: str                     # Unique per-tick identifier
    policy_id: str                       # ID of the IPolicy that produced this
    type: DecisionType
    parameters: dict[str, Any] = field(default_factory=dict)
    priority: int = 0
    # Lower value = applied first. Ties broken by registration order of originating policy.

    reason: str = ""                     # Human-readable explanation for logging
```

---

## 5. PolicyEngine

```python
class PolicyEngine:
    """
    Evaluates all registered policies and collects their decisions.

    Evaluation order is deterministic: policies are evaluated in the order
    they were registered (first-registered, first-evaluated).
    """

    def __init__(self) -> None:
        self._policies: list[IPolicy] = []

    def register(self, policy: IPolicy) -> None:
        """
        Register a policy for evaluation each tick.

        Policies must be registered before the simulation starts.
        Registration order determines evaluation order.
        """

    def evaluate(
        self,
        city: "City",
        context: "TickContext",
    ) -> list[Decision]:
        """
        Evaluate all registered policies.

        Returns decisions sorted by (priority ASC, registration_order ASC).
        Two policies must not produce decisions with the same decision_id within
        a single tick; PolicyEngine raises ValueError if a collision is detected.

        Returns:
            Ordered list of Decision objects.
        """
```

---

## 6. RandomService

```python
import random

class RandomService:
    """
    Seedable random number generator.

    All simulation randomness MUST flow through this service.
    No subsystem or policy may use the stdlib random module, numpy.random,
    or any other random source directly.

    Thread-safety: NOT thread-safe. Do not share across threads without locking.
    """

    def __init__(self, seed: int) -> None:
        """
        Initialize with a fixed seed.

        Args:
            seed: Integer seed. Must be provided; no default.
        """
        self._rng = random.Random(seed)
        self._seed = seed

    # --- Core API ---

    def random(self) -> float:
        """Return a float in [0.0, 1.0)."""

    def randint(self, a: int, b: int) -> int:
        """Return a random integer N such that a <= N <= b."""

    def choice(self, seq: "collections.abc.Sequence") -> Any:
        """Choose a random element from a non-empty sequence."""

    def shuffle(self, seq: list) -> None:
        """Shuffle list in-place."""

    def gauss(self, mu: float, sigma: float) -> float:
        """Return a Gaussian-distributed float."""

    # --- Reproducibility ---

    @property
    def seed(self) -> int:
        """The seed used to initialize this service."""

    def get_state(self) -> object:
        """
        Return opaque state that can be passed to set_state() to replay a sequence.
        Use for checkpointing.
        """

    def set_state(self, state: object) -> None:
        """Restore state from a previous get_state() call."""
```

**Determinism guarantee**: Given the same `seed` and the same sequence of calls, `RandomService`
produces the same sequence of values across Python versions that keep the same `random.Random`
implementation (CPython 3.x).

---

## 7. EventBus

```python
from typing import Callable, Any
from dataclasses import dataclass

@dataclass
class Event:
    """
    An immutable event emitted during simulation.
    """
    event_type: str          # Namespaced: "<subsystem>.<event_name>"  e.g. "finance.bankruptcy"
    tick_index: int
    payload: dict[str, Any]  # Serializable key-value data


# Handler type alias
EventHandler = Callable[[Event], None]

class EventBus:
    """
    Simple synchronous publish/subscribe bus.

    Determinism guarantee: handlers are invoked in subscription order (FIFO).
    No async dispatch; all handlers complete before the next event is published.

    Events emitted during tick N are processed within tick N before the tick completes.
    Events do NOT carry over to the next tick.
    """

    def subscribe(self, event_type: str, handler: EventHandler) -> None:
        """
        Register a handler for a specific event type.

        Wildcard "*" subscribes to all event types.
        Handlers are invoked in registration order.
        """

    def publish(self, event: Event) -> None:
        """
        Publish an event and invoke all matching handlers synchronously.

        Raises:
            RuntimeError: If a handler raises an exception
                          (the exception is re-raised after logging context).
        """

    def get_events(self, tick_index: int) -> list[Event]:
        """
        Return all events emitted during a given tick (for logging/testing).
        """
```

---

## 8. MetricsCollector

```python
from typing import Any

class MetricsCollector:
    """
    Accumulates numeric metrics across ticks for aggregation and reporting.

    Keys use the subsystem-namespace pattern: "<subsystem>.<metric_name>".
    """

    def record(self, key: str, value: float, tick_index: int) -> None:
        """
        Record a single numeric metric value for the given tick.

        Multiple calls for the same (key, tick_index) are averaged.
        """

    def record_dict(self, metrics: dict[str, float], tick_index: int) -> None:
        """
        Record multiple metrics at once (convenience wrapper around record()).
        """

    def get(self, key: str) -> list[float]:
        """Return the ordered time-series for a metric key."""

    def get_average(self, key: str) -> float:
        """Return mean value across all recorded ticks."""

    def to_summary_dict(self) -> dict[str, Any]:
        """
        Return a flat dict suitable for inclusion in RunReport.kpis.
        Keys: metric key; Values: summary statistics (min, max, mean, last).
        """
```

---

## 9. ScenarioLoader

```python
from dataclasses import dataclass, field
from typing import Any

@dataclass
class Scenario:
    """
    Named configuration for a simulation run.

    ScenarioLoader.load() returns this object. SimRunner consumes it.
    """

    name: str
    description: str = ""

    # Initial Conditions
    initial_budget: float = 1_000_000.0
    initial_population: int = 10_000
    initial_happiness: float = 60.0

    # Run Parameters
    tick_horizon: int = 1000
    seed: int = 0

    # Policies
    policy_ids: list[str] = field(default_factory=list)
    # Resolved to IPolicy instances by PolicyEngine at startup

    # Subsystem-Specific Parameters (namespaced)
    parameters: dict[str, Any] = field(default_factory=dict)
    # Key convention: "<subsystem>.<param_name>" e.g. "finance.base_tax_rate"


class ScenarioLoader:
    """
    Loads Scenario definitions from files or built-in defaults.
    """

    def load(self, scenario_name: str) -> Scenario:
        """
        Load a scenario by name.

        Args:
            scenario_name: Unique scenario identifier.

        Returns:
            Scenario object.

        Raises:
            ScenarioNotFoundError: If no scenario with that name exists.
            ScenarioValidationError: If the scenario definition is malformed.
        """

    def list_scenarios(self) -> list[str]:
        """Return names of all available scenarios."""
```

---

## 10. InfrastructureManager

Ownership split:
- **Transport** (`WS-10`) owns `InfrastructureState.transport` and all `TransportNetwork`
  sub-objects.
- **CityManager** (`WS-02`) owns all other infrastructure fields (`utilities`, `power`, `water`,
  quality metrics).

```python
class IInfrastructureManager(Protocol):
    """
    Interface for the portion of infrastructure management owned by CityManager.
    Transport infrastructure is handled by TransportSubsystem (ISubsystem).
    """

    def apply_investment(
        self,
        city: "City",
        domain: str,           # "utilities" | "power" | "water"
        amount: float,
        context: "TickContext",
    ) -> float:
        """
        Apply a capital investment to a non-transport infrastructure domain.

        Returns:
            Actual quality increase applied (may be less than requested if capped at 100).
        """

    def apply_degradation(
        self,
        city: "City",
        domain: str,
        amount: float,
        context: "TickContext",
    ) -> float:
        """
        Apply degradation to a non-transport infrastructure domain.

        Returns:
            Actual quality decrease applied (may be less than requested if floored at 0).
        """
```

---

## 11. ServiceManager

The Service subsystem has no dedicated workstream; ownership is assigned to `WS-02` (City
Modeling). The interface below prevents conflicts with `WS-03` (Finance) and `WS-04` (Population)
which read service coverage values.

```python
class IServiceManager(Protocol):
    """
    Manages city service capacity and coverage.
    Owned by CityManager (WS-02).
    Finance and Population subsystems read coverage; only CityManager writes it.
    """

    def expand_service(
        self,
        city: "City",
        domain: str,           # "health" | "education" | "public_safety" | "housing"
        capacity_delta: float,
        context: "TickContext",
    ) -> float:
        """
        Increase service capacity for a domain.

        Returns:
            Actual coverage increase (clamped to [0, 100]).
        """

    def reduce_service(
        self,
        city: "City",
        domain: str,
        capacity_delta: float,
        context: "TickContext",
    ) -> float:
        """
        Decrease service capacity for a domain.

        Returns:
            Actual coverage decrease (clamped to [0, 100]).
        """

    def compute_coverage(
        self,
        city: "City",
        domain: str,
    ) -> float:
        """
        Compute current coverage for a domain without modifying state.

        Returns:
            Coverage value in [0, 100].
        """
```

---

## 12. TickContext

This type is provided by `SimCore` and passed to every subsystem and policy. It is read-only from
the perspective of subsystems; only `SimCore` constructs it.

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class TickContext:
    """
    Immutable context for a single tick.
    Constructed by SimCore; passed to CityManager, subsystems, and policies.
    """

    tick_index: int
    settings: "Settings"
    policy_set: "PolicySet"
    random_service: RandomService  # NOT frozen — callers may advance its state
    event_bus: EventBus

    @property
    def is_first_tick(self) -> bool:
        return self.tick_index == 0

    @property
    def is_last_tick(self) -> bool:
        return self.tick_index == self.settings.tick_horizon - 1
```

---

## 13. InvariantViolation

```python
from dataclasses import dataclass
from enum import Enum

class Severity(Enum):
    WARNING  = "warning"   # Log and continue
    ERROR    = "error"     # Log and clamp, mark run as degraded
    CRITICAL = "critical"  # Raise SimulationError in strict_mode

@dataclass
class InvariantViolation:
    """
    Describes a failed invariant check.
    Returned by ISubsystem.validate() and CityManager.validate_invariants().
    """

    invariant_name: str        # e.g. "population_non_negative"
    message: str               # Human-readable description
    severity: Severity
    subsystem: str             # Which subsystem owns this invariant
    tick_index: int
    actual_value: object       # The value that violated the invariant
    expected: str              # Description of the valid range/condition
```

---

## 14. Cross-Subsystem Feedback Contracts

The following contracts govern how subsystems read each other's outputs. Reading a value produced
by another subsystem in the **same tick** is forbidden — subsystems only read the city state as it
existed at the **start** of the tick.

| Reader Subsystem | Value Read | Source Field | Update Rule |
|-----------------|-----------|-------------|-------------|
| Finance | Population | `city.state.population` | Set at end of **previous** tick |
| Finance | Service coverage | `city.state.services.*_coverage` | Set at end of **previous** tick |
| Population | Budget | `city.state.budget` | Set at end of **previous** tick |
| Population | Service coverage | `city.state.services.*_coverage` | Set at end of **previous** tick |
| Population | Infrastructure quality | `city.state.infrastructure.*_quality` | Set at end of **previous** tick |
| Transport | Infrastructure state | `city.state.infrastructure.transport` | Read and write within same tick |
| Happiness | Traffic congestion | `city.state.infrastructure.transport_quality` | Set at end of **previous** tick |

---

## 15. Errors & Exceptions

```python
class CitySimError(Exception):
    """Base class for all city-sim errors."""

class ConfigurationError(CitySimError):
    """Invalid settings or scenario configuration."""

class SimulationError(CitySimError):
    """Unrecoverable error during simulation execution."""

class ScenarioNotFoundError(CitySimError):
    """Requested scenario does not exist."""

class ScenarioValidationError(CitySimError):
    """Scenario definition is structurally invalid."""

class InvariantError(CitySimError):
    """Invariant violated in strict_mode."""

class PolicyConflictError(CitySimError):
    """Two policies produced decisions with the same decision_id in a single tick."""
```

---

## 16. Namespace Conventions

All keys used in log dictionaries, metrics, and parameters must follow these conventions to avoid
collision:

| Domain | Prefix | Example |
|--------|--------|---------|
| Finance | `finance.` | `finance.revenue`, `finance.tax_rate` |
| Population | `population.` | `population.births`, `population.happiness` |
| Transport | `transport.` | `transport.avg_speed`, `transport.congestion_index` |
| Infrastructure | `infra.` | `infra.power_quality`, `infra.water_quality` |
| Services | `services.` | `services.health_coverage`, `services.education_coverage` |
| Simulation Core | `sim.` | `sim.tick_duration_ms`, `sim.run_id` |
| Scenario | `scenario.` | `scenario.name`, `scenario.seed` |

---

## Related Documentation

- [Architecture Overview](../architecture/overview.md)
- [Class Hierarchy](../architecture/class-hierarchy.md)
- [Simulation Specification](simulation.md)
- [City Specification](city.md)
- [Finance Specification](finance.md)
- [Population Specification](population.md)
- [Traffic Specification](traffic.md)
- [Logging Specification](logging.md)
- [Pre-Work WS-00A: Shared Interfaces](../design/workstreams/00a-shared-interfaces.md)
- [Pre-Work WS-00B: Data Contracts](../design/workstreams/00b-data-contracts.md)
- [Pre-Work WS-00C: Integration Protocols](../design/workstreams/00c-integration-protocols.md)
