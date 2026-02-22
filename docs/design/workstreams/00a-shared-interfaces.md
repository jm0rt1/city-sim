# Pre-Work Workstream 00A: Shared Interfaces

> **Status**: Pre-work — must be completed before any implementation workstream (WS-01 through
> WS-10) begins writing code. Agents for WS-01–10 must read and accept these definitions before
> starting.

## Purpose

Define, document, and lock the shared interface contracts that multiple workstreams depend on.
Completing this workstream eliminates the most common source of cross-workstream conflicts:
ambiguous or duplicate interface definitions.

All changes in this workstream are **documentation-only** (spec files and workstream documents).
No production code is written here; production code that *implements* these interfaces is written
by the owning workstreams.

---

## Reading Checklist

- [ ] Architecture Overview: [../../architecture/overview.md](../../architecture/overview.md)
- [ ] Class Hierarchy: [../../architecture/class-hierarchy.md](../../architecture/class-hierarchy.md)
- [ ] Simulation Spec: [../../specs/simulation.md](../../specs/simulation.md)
- [ ] City Spec: [../../specs/city.md](../../specs/city.md)
- [ ] Interfaces Spec: [../../specs/interfaces.md](../../specs/interfaces.md) ← **primary output**
- [ ] ADR-001: [../../adr/001-simulation-determinism.md](../../adr/001-simulation-determinism.md)
- [ ] Design Guide: [../readme.md](../readme.md)
- [ ] Pre-Work WS-00B: [00b-data-contracts.md](00b-data-contracts.md)
- [ ] Pre-Work WS-00C: [00c-integration-protocols.md](00c-integration-protocols.md)

---

## Objectives

1. **Define `ISubsystem`** — the base protocol every simulation subsystem must implement.
2. **Define `IPolicy` and `Decision`** — the contract policies use to communicate with
   `CityManager`.
3. **Define `PolicyEngine`** — deterministic policy evaluation order.
4. **Define `RandomService`** — the single permitted source of randomness, with determinism
   guarantees.
5. **Define `EventBus` and `Event`** — synchronous publish/subscribe with FIFO ordering.
6. **Define `MetricsCollector`** — namespaced metric accumulation API.
7. **Define `ScenarioLoader` and `Scenario`** — scenario loading contract.
8. **Define `TickContext`** — the immutable per-tick context object.
9. **Define `InvariantViolation`** — structured invariant-failure reporting.
10. **Establish namespace conventions** for all log/metric/parameter keys.

---

## Scope

| File | Action |
|------|--------|
| `docs/specs/interfaces.md` | **Create** (primary deliverable) |
| `docs/design/workstreams/00-index.md` | **Update** — add pre-work workstreams |
| `docs/design/workstreams/01-*.md` through `10-*.md` | **Update** — add WS-00A/B/C to Reading Checklists |

No source code files are in scope for this workstream.

---

## Inputs

- All existing spec files in `docs/specs/`
- Architecture documents in `docs/architecture/`
- ADRs in `docs/adr/`

---

## Outputs

- `docs/specs/interfaces.md` containing complete, unambiguous definitions for all 13 shared types
  listed under Objectives.
- Updated workstream index and reading checklists.

---

## Task Backlog

- [x] Write `ISubsystem` protocol with `name`, `update()`, and `validate()` methods.
- [x] Write `IPolicy` and `Decision` with `DecisionType` enumeration.
- [x] Write `PolicyEngine` with deterministic evaluation order guarantee.
- [x] Write `RandomService` with seed management and state checkpointing.
- [x] Write `EventBus` / `Event` with synchronous FIFO dispatch.
- [x] Write `MetricsCollector` with namespaced keys.
- [x] Write `ScenarioLoader` / `Scenario` with validation error types.
- [x] Write `TickContext` (frozen dataclass).
- [x] Write `InvariantViolation` with severity levels.
- [x] Document namespace conventions table.
- [x] Add cross-reference links in all affected workstream/spec files.

---

## Acceptance Criteria

1. `docs/specs/interfaces.md` exists and defines all 13 types listed above without ambiguity.
2. Every type name used in any other spec file resolves to exactly one definition in
   `interfaces.md`, `simulation.md`, `city.md`, `finance.md`, `population.md`, or `traffic.md`.
3. No two spec files define a type with the same name differently.
4. Namespace conventions table is complete and consistent with all log/metric examples in other
   specs.
5. WS-00A, WS-00B, WS-00C are listed as prerequisites in `00-index.md`.
6. All main workstream reading checklists reference the interfaces spec.

---

## Checkpoints

- [ ] `interfaces.md` written and cross-reviewed against all existing specs for conflicts.
- [ ] `00-index.md` updated with pre-work section.
- [ ] All main workstream files updated.

---

## Copy‑Paste Prompt

```
Preflight Checklist:
- [ ] Read Architecture Overview and Class Hierarchy
- [ ] Read ALL existing specs (simulation, city, finance, population, traffic, logging)
- [ ] Read interfaces.md (this workstream's primary output)
- [ ] Read pre-work workstreams 00B and 00C
- [ ] Identify any type conflicts or gaps in the existing definitions

You are an AI agent working on City-Sim, completing Pre-Work Workstream 00A: Shared Interfaces.

Objectives:
- Finalize and lock the shared interface contracts in docs/specs/interfaces.md.
- Ensure every type referenced in any spec has a canonical definition.
- Update 00-index.md and all workstream reading checklists.

Global Context Pack:
- Architecture: docs/architecture/overview.md, docs/architecture/class-hierarchy.md
- Specs: docs/specs/interfaces.md (primary), docs/specs/simulation.md, docs/specs/city.md,
         docs/specs/finance.md, docs/specs/population.md, docs/specs/traffic.md,
         docs/specs/logging.md
- ADRs: docs/adr/001-simulation-determinism.md
- Workstreams: docs/design/workstreams/00-index.md, 00a-shared-interfaces.md,
               00b-data-contracts.md, 00c-integration-protocols.md

Scope & Files:
- docs/specs/interfaces.md
- docs/design/workstreams/00-index.md
- docs/design/workstreams/01-*.md through 10-*.md (reading checklists only)

Required Outputs:
- Complete interfaces.md with all 13 shared type definitions.
- Updated index and reading checklists.

Acceptance Criteria:
- No ambiguous or duplicate type definitions across specs.
- All namespace keys follow the established conventions.
- All main workstreams reference interfaces.md in their reading checklists.

Deliver:
- Concise plan + exact edits
- Conflict detection notes (any types that were ambiguous before this workstream)
- Follow-up recommendations for WS-00B and WS-00C
```
