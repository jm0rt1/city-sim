# Workstream: Roadmap

## Reading Checklist
- **Pre-Work WS-00A** (shared interfaces): [00a-shared-interfaces.md](00a-shared-interfaces.md)
- **Pre-Work WS-00B** (data contracts): [00b-data-contracts.md](00b-data-contracts.md)
- **Pre-Work WS-00C** (integration protocols): [00c-integration-protocols.md](00c-integration-protocols.md)
- **Interfaces Spec**: [../../specs/interfaces.md](../../specs/interfaces.md)
- Architecture Overview: [../../architecture/overview.md](../../architecture/overview.md)
- Class Hierarchy: [../../architecture/class-hierarchy.md](../../architecture/class-hierarchy.md)
- Specs: [../../specs](../../specs) (simulation, city, finance, population, logging, traffic, scenarios)
- ADRs: [../../adr](../../adr)
- Design Guide: [../readme.md](../readme.md)
- Consolidated Prompts: [../prompts.md](../prompts.md)
- Templates: [../templates/](../templates/)
- Guides: [../../guides/](../../guides/)
- Models: [../../models/model.mdj](../../models/model.mdj)

## Objectives
- Plan features and coordinate dependencies across all workstreams.
- Provide clear milestones, realistic timelines, and an explicit cross-workstream dependency map.
- Identify risks and follow-up actions that keep parallel workstreams unblocked.

## Scope
- Documentation only; updates to `docs/design/workstreams/` and `docs/specs/` as needed.

## Inputs
- Requirements and outputs from WS-00A, WS-00B, WS-00C (shared interfaces and contracts).
- Workstream backlogs from WS-01 through WS-11.
- Feature Catalog: [../../FEATURE_CATALOG.md](../../FEATURE_CATALOG.md)
- Project Summary: [../../PROJECT_SUMMARY.md](../../PROJECT_SUMMARY.md)

## Outputs
- This document: milestone list, timelines, dependency map, risk register, and follow-up recommendations.

---

## Milestones

### M0 — Pre-Work: Shared Contracts (Weeks 1–2)

**Goal**: Lock all shared interface definitions so implementation workstreams can proceed in parallel without conflicts.

| Workstream | Key Deliverable |
|---|---|
| WS-00A | `ISubsystem`, `IPolicy`, `Decision`, `PolicyEngine`, `RandomService`, `EventBus`, `MetricsCollector`, `ScenarioLoader`, `TickContext`, `InvariantViolation` defined in `docs/specs/interfaces.md` |
| WS-00B | `FinanceDelta`, `PopulationDelta`, `TrafficDelta`, `CityDelta` aggregation rules; `CityState` ownership table; `IServiceManager`, `IInfrastructureManager` |
| WS-00C | Canonical tick order, state-visibility rule, determinism contracts, error propagation, feedback-loop lags, `EventBus` rules, mandatory metrics, scenario/settings precedence |

**Acceptance Criteria**:
- `docs/specs/interfaces.md` reviewed and accepted by owners of WS-01 through WS-10.
- No open ambiguities in interface contracts.
- All other workstream reading checklists include a WS-00A/B/C review step.

**Depends on**: Nothing — start immediately.

---

### M1 — Alpha: Deterministic Simulation Baseline (Weeks 3–8)

**Goal**: A runnable, deterministic simulation loop with a stable city model, seed-controlled randomness, scenario loading, and structured tick logging.

| Workstream | Key Deliverable |
|---|---|
| WS-01 (Simulation Core) | `SimRunner` + `SimCore` tick loop; `ScenarioLoader` invoked from `sim.py`; tick-duration metric emitted per run |
| WS-02 (City Modeling) | `City`, `CityState`, `CityManager`, `CityDelta`; decision application; invariant enforcement |
| WS-06 (Data & Logging) | JSONL tick log with `run_id`, `tick_index`, `timestamp`; schema validated on write |
| WS-07 (Testing & CI) | Determinism test (same seed → identical logs); unit tests for `City` and `CityManager`; CI pipeline running `./test.sh` |

**Acceptance Criteria**:
- `python run.py` completes without errors.
- Running twice with the same seed produces byte-identical log files.
- Tick-duration metric present in every log entry.
- All existing and new tests pass in CI.

**Depends on**: M0 (WS-00A, 00B, 00C complete).

---

### M2 — Beta Core: Finance and Population Validated (Weeks 9–16)

**Goal**: Working finance and population subsystems, each exercised by scenario runs and validated by automated tests.

| Workstream | Key Deliverable |
|---|---|
| WS-03 (Finance) | `FinanceSubsystem`; budget reconciliation invariant enforced each tick; tax-rate and subsidy policy effects; `FinanceDelta` logged |
| WS-04 (Population) | `PopulationSubsystem`, `HappinessTracker`, `MigrationModel`; happiness bounded [0, 100]; population non-negative; `PopulationDelta` logged |
| WS-06 (Data & Logging) | Log schema extended with `revenue`, `expenses`, `budget`, `population`, `happiness` fields |
| WS-07 (Testing & CI) | Unit tests for budget reconciliation and happiness bounds; integration test running a 100-tick scenario and asserting KPI ranges |

**Acceptance Criteria**:
- Budget equation `budget[t+1] = budget[t] + revenue[t] - expenses[t]` verified within floating-point tolerance (1e-6) for every tick.
- Population never goes negative; happiness always in [0, 100].
- All required log fields present in every tick entry.

**Depends on**: M1.

---

### M3 — Beta UX: User Interface and Richer Logging (Weeks 9–18, parallel with M2)

**Goal**: Improved CLI output and structured logs that support downstream analysis and visualization.

| Workstream | Key Deliverable |
|---|---|
| WS-05 (UI) | CLI progress display (tick counter, key KPIs per tick); run-summary table at end of simulation |
| WS-06 (Data & Logging) | CSV export option alongside JSONL; `RunReportWriter` producing final summary file |

**Acceptance Criteria**:
- CLI shows at least tick index, budget, population, and happiness during a run.
- Final run-summary file written to `output/logs/global/`.
- Log schema documented and unchanged from M2 additions.

**Depends on**: M1 (WS-01 and WS-06 from M1).
*Can run concurrently with M2.*

---

### M4 — Beta Performance: Performance Pass and Expanded Tests (Weeks 17–22)

**Goal**: Identify and address simulation performance bottlenecks; harden the test suite with coverage for all core subsystems.

| Workstream | Key Deliverable |
|---|---|
| WS-08 (Performance) | Profiling baseline established; top-3 hotspots identified and optimized; tick-rate targets documented (see below) |
| WS-07 (Testing & CI) | Integration tests for Finance ↔ Population interaction; scenario suite covering edge cases; static-analysis (Pyright) clean run |

**Tick-Rate Targets** (from [docs/PROJECT_SUMMARY.md](../../PROJECT_SUMMARY.md)):

| City Size | Population | Target Tick Rate |
|---|---|---|
| Small | 10,000 | ≥ 100 ticks/s |
| Medium | 100,000 | ≥ 20 ticks/s |
| Large | 1,000,000 | ≥ 5 ticks/s |
| Metropolis | 10,000,000 | ≥ 1 tick/s |

**Acceptance Criteria**:
- Profiling report committed under `docs/` or a workstream note.
- At least one optimization applied and benchmarked.
- No performance regression > 10% from M1 baseline.
- Pyright type-checker reports zero errors on `src/`.

**Depends on**: M2 and M3 complete.

---

### M5 — Version 1.0: Transport and Traffic Subsystem (Weeks 21–34)

**Goal**: Functional transport subsystem with road network, vehicle routing, signal control, and congestion metrics.

| Workstream | Key Deliverable |
|---|---|
| WS-10 (Traffic) | `TransportSubsystem`, `RoadGraph`, `RoutePlanner` (A\*), `Vehicle`, `FleetManager`; traffic-signal and highway-ramp controllers; `TrafficDelta` logged per tick |
| WS-06 (Data & Logging) | Log schema extended with `avg_speed`, `congestion_index`, `throughput` |
| WS-07 (Testing & CI) | Vehicle-conservation invariant test; route-validity test; congestion regression test |

**Acceptance Criteria**:
- Traffic subsystem integrates with existing tick loop without breaking determinism.
- Vehicle count conserved between spawn and despawn points each tick.
- Speed never exceeds road-segment limit.
- `TrafficDelta` fields present in every tick log entry.

**Depends on**: M4 (stable core, passing tests).

---

### M6 — Version 1.1: Isometric Graphics Renderer (Weeks 27–40, overlaps late M5)

**Goal**: Decoupled isometric 2D tile renderer consuming simulation state (or logs) without blocking the tick loop.

| Workstream | Key Deliverable |
|---|---|
| WS-11 (Graphics) | `TileRenderer`, `SpriteAtlas`, `IsometricViewport`; AI-generated tile assets pipeline; renderer runs in separate process |
| WS-05 (UI) | UI adapter bridging renderer to simulation `EventBus` or log replay |

**Acceptance Criteria**:
- Renderer never introduces non-determinism in the simulation core.
- Renderer can replay a recorded run from JSONL logs without re-running the simulation.
- Frame rate ≥ 30 frames per second for a small city (10,000 population).

**Depends on**: M1 (EventBus and logging), M5 (traffic state for road rendering).
*Can begin renderer scaffolding once M1 is complete.*

---

### M7 — Version 2.0: Extended Subsystems (Months 7–18)

**Goal**: Add the four major new subsystems documented in `docs/specs/`.

| Subsystem | Spec | Key Features |
|---|---|---|
| Environment / Climate | [environment.md](../../specs/environment.md) | Weather (Markov chains), seasons, 8 disaster types, air quality (6 pollutants), sustainability metrics |
| Education | [education.md](../../specs/education.md) | Preschool through research university, research and innovation, patent transfer, workforce development |
| Healthcare | [healthcare.md](../../specs/healthcare.md) | Hospitals, disease simulation, public health programs, emergency medical services, health outcomes |
| Emergency Services | [emergency_services.md](../../specs/emergency_services.md) | Police, fire, emergency medical services, disaster response, dispatch and resource allocation |

**Suggested sub-milestones within M7**:
- M7a — Environment subsystem (Months 7–9)
- M7b — Healthcare subsystem (Months 10–12)
- M7c — Emergency Services subsystem (Months 13–15)
- M7d — Education subsystem (Months 16–18)

**Acceptance Criteria** (per sub-milestone):
- Subsystem implements `ISubsystem` interface.
- At least one integration test per subsystem verifying determinism.
- All new metrics added to log schema and documented in `docs/specs/logging.md`.

**Depends on**: M4.

---

### M8 — Version 3.0: Economic and Infrastructure Systems (Months 19–24)

**Goal**: Add employment/labor market, business lifecycle, trade, real estate, and physical infrastructure (water, power, telecoms, waste).

Workstreams will be defined as separate documents when M7 is underway. Key categories from [FEATURE_CATALOG.md](../../FEATURE_CATALOG.md):
- Economic Systems: employment, business simulation, trade and commerce, financial institutions, real estate.
- Infrastructure Systems: water supply and sewage, electrical grid, telecommunications, waste management.

**Depends on**: M7 (environment and healthcare feed into infrastructure modeling).

---

### M9 — Version 4.0: Governance, Culture, and Advanced Features (Months 25+)

**Goal**: Political system, comprehensive policy framework, arts and culture, tourism, modding framework, and machine-learning integration.

**Depends on**: M8.

---

## Dependency Map

```
M0 (Shared Contracts)
└── M1 (Alpha: Sim Core + City Model + Logging + CI)
    ├── M2 (Beta Core: Finance + Population)   ─┐
    └── M3 (Beta UX: CLI + Logging)            ─┤ both feed
                                                 ↓
                                          M4 (Performance + Tests)
                                          ├── M5 (v1.0: Traffic)
                                          │   └── M6 (v1.1: Graphics)   ← also needs M1
                                          └── M7 (v2.0: Env/Health/Ed/EmServ)
                                              └── M8 (v3.0: Economic + Infrastructure)
                                                  └── M9 (v4.0: Governance + Culture)
```

### Cross-Workstream Dependency Matrix

| Milestone | Blocking Workstreams | Unblocked By |
|---|---|---|
| M0 | WS-00A, WS-00B, WS-00C | — |
| M1 | WS-01, WS-02, WS-06, WS-07 | M0 |
| M2 | WS-03, WS-04, WS-06, WS-07 | M1 |
| M3 | WS-05, WS-06 | M1 (can run parallel with M2) |
| M4 | WS-07, WS-08 | M2 + M3 |
| M5 | WS-10, WS-06, WS-07 | M4 |
| M6 | WS-11, WS-05 | M1 (scaffold), M5 (traffic rendering) |
| M7 | New subsystem workstreams | M4 |
| M8 | New workstreams (TBD) | M7 |
| M9 | New workstreams (TBD) | M8 |

### Key Interface Dependencies Within Milestones

- **All WS-01–10 implementations** depend on `docs/specs/interfaces.md` (output of M0).
- **WS-03 (Finance)** reads `FinanceDelta` contract from WS-00B before implementing.
- **WS-04 (Population)** reads `PopulationDelta` contract from WS-00B before implementing.
- **WS-10 (Traffic)** reads `TrafficDelta` contract from WS-00B before implementing.
- **WS-05 (UI)** reads the tick-log schema from WS-06 before implementing the CLI display.
- **WS-08 (Performance)** can profile only after WS-01–04 and WS-06 produce real workloads.
- **WS-11 (Graphics)** reads `EventBus` rules from WS-00C to wire up the rendering adapter.

---

## Risk Register

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Interface contracts drift after M0 lock | Medium | High | Treat `docs/specs/interfaces.md` as a locked artifact; require PR review from all workstream owners before any change |
| Determinism broken by parallel subsystem execution | Medium | High | Mandate single-threaded tick execution order (WS-00C); add determinism regression test in CI |
| Finance ↔ Population feedback loop causes instability | Low | Medium | Add safeguard clamps (non-negative population, bounded happiness) enforced in `CityManager`; integration tests covering steady-state scenarios |
| Traffic subsystem complexity delays M5 | High | Medium | Scope M5 to basic road graph + A\* routing first; defer signal optimization and highway-ramp control to a follow-on patch |
| Graphics renderer blocks simulation tick loop | Medium | High | Enforce renderer runs in a separate process; CI test verifying tick timing is unaffected when renderer is active |
| Python 3.13+ free-threaded mode introduces race conditions | Low | High | Follow WS-00C state-visibility rules; run existing determinism tests under free-threaded mode as a gate for each milestone |

---

## Timeline Summary

| Milestone | Duration | Calendar Target | Status |
|---|---|---|---|
| M0 — Shared Contracts | 2 weeks | Weeks 1–2 | Not started |
| M1 — Alpha Baseline | 6 weeks | Weeks 3–8 | Not started |
| M2 — Beta Core | 8 weeks | Weeks 9–16 | Not started |
| M3 — Beta UX | 10 weeks | Weeks 9–18 | Not started |
| M4 — Performance | 6 weeks | Weeks 17–22 | Not started |
| M5 — Traffic (v1.0) | 14 weeks | Weeks 21–34 | Not started |
| M6 — Graphics (v1.1) | 14 weeks | Weeks 27–40 | Not started |
| M7 — Extended Subsystems (v2.0) | Months 7–18 | — | Not started |
| M8 — Economic + Infrastructure (v3.0) | Months 19–24 | — | Not started |
| M9 — Governance + Culture (v4.0) | Months 25+ | — | Not started |

*Weeks are relative to project start. M2 and M3 run in parallel. M5 and M6 overlap in their final weeks.*

---

## Follow-Up Recommendations

1. **Lock `docs/specs/interfaces.md` before any implementation work starts.**
   The WS-00A/B/C pre-work is the single most important gating step. Every implementation workstream blocks on it. Schedule a synchronous review meeting (or async PR review) with all workstream leads before Week 3.

2. **Add a determinism smoke test to CI immediately (M1).**
   Run the simulation twice with the same seed in every CI build and diff the output logs. This catches non-determinism regressions before they accumulate.

3. **Define the `TrafficDelta` data contract early (WS-00B).**
   The transport subsystem is the largest and most complex (WS-10, ~69KB spec). Locking its delta contract in M0 prevents the most expensive rework.

4. **Create separate workstream documents for each M7 subsystem.**
   Environment, Education, Healthcare, and Emergency Services each warrant their own workstream file (e.g., `12-environment.md`, `13-education.md`) following the existing template to keep parallel teams unblocked.

5. **Establish performance benchmarks at M1, not M4.**
   Record a tick-rate baseline for a 10,000-population city at M1. This gives WS-08 a meaningful target and catches early regressions before the codebase is large.

6. **Scope M5 (Traffic) to a minimal viable network first.**
   Start with a fixed road graph, A\* routing, and basic congestion metrics. Defer adaptive signal control and highway on-ramp metering to a v1.0 patch. This reduces the risk of M5 slipping and delaying M6.

7. **Treat the graphics renderer (WS-11) as strictly read-only.**
   The renderer must never write to shared simulation state. Enforce this with an architectural boundary in code (read-only city-state snapshots or log-only replay) and test it in CI.

8. **Draft ADRs for each major M7 subsystem decision.**
   Following the pattern of ADR-001 and ADR-002, capture the rationale for key design choices (e.g., Markov-chain weather, disease simulation model) before implementation begins.

---

## Acceptance Criteria
- Clear, achievable milestones with defined dependencies (covered above).
- Every milestone has an explicit dependency list and acceptance criteria.
- The dependency map is kept up to date as workstreams complete.
- Timeline summary updated after each milestone is closed.

## Copy‑Paste Prompt
```
Preflight Checklist:
- [ ] Read Architecture Overview, Class Hierarchy, and diagram
- [ ] Review specs, scenarios, and ADRs
- [ ] Confirm settings and entry points
- [ ] Identify required outputs and acceptance criteria
- [ ] Plan minimal, style-consistent changes and validation steps
You are an AI coding agent working on City‑Sim, focusing on the Roadmap workstream.

Objectives:
- Plan features and coordinate dependencies across workstreams.

Global Context Pack:
- Architecture Overview: docs/architecture/overview.md
- Class Hierarchy: docs/architecture/class-hierarchy.md
- Diagram: docs/architecture/city-sim-architecture.puml
- Specs: docs/specs/*, docs/specs/scenarios.md
- ADRs: docs/adr/*
- Guides: docs/guides/contributing.md, docs/guides/glossary.md
- Workstreams Index: docs/design/workstreams/00-index.md

Scope & Files:
- All modules; docs in docs/specs/* and docs/architecture/*

Required Outputs:
- Milestone list and timelines; cross‑workstream dependencies.

Run Steps:
1) ./init-venv.sh
2) pip install -r requirements.txt
3) python3 run.py (optional, for validation context)

Acceptance Criteria:
- Clear, achievable milestones with defined dependencies.

Deliver:
- Plan + milestones
- Dependencies map
- Follow-up recommendations
```
