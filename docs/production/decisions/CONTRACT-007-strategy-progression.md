# CONTRACT-007: Durable strategy progression and urgency truth

**Status:** Approved with required adjustments

**Date:** July 21, 2026

**Proposer:** PLAY-013 gameplay loop after the PLAY-051 next-wave audit

**Audit authority:** `docs/production/evidence/PLAY-051/NEXT_WAVE_SIMULATION_AUDIT_2026-07-21.md`

## Player outcome

A player who takes time to read the HUD or recover from an invalid placement cannot permanently miss the authored strategy story. The chosen route advances once, in order, survives save/load/undo, and supplies one authoritative urgency value to the HUD.

## Approved persisted shape

1. Extend the existing optional `CityProgressionState` with `strategy: CityStrategyProgression?`.
2. `CityStrategyProgression` is `Codable`, `Equatable`, and `Sendable` and contains only:
   - `committedStrategy`;
   - `currentPhase`;
   - `nextScheduledTick: Int?`, expressed as an absolute daily-boundary tick.
3. Do not persist a commitment day, countdown, history ledger, UI state, panel state, or renderer state.
4. Missing `strategy` decodes as `nil`. `nil` means awaiting a valid strategy choice, including for legacy saves. Loading never commits or mutates strategy.

## Scheduling semantics

1. A valid Commercial or Industrial commitment occurs once at a daily boundary after the first successful eligible placement. Invalid or rejected placement changes no progression state.
2. Later tile-count changes, construction, or demolition cannot silently switch the committed route.
3. Phase transitions use `state.tick >= nextScheduledTick`, never exact tick equality.
4. Each transition applies exactly once, then persists the next phase and next boundary. One evaluation cannot cascade multiple missed phases.
5. A legacy session beyond the old Day 25 boundary may commit on its next eligible daily boundary and schedules forward from there. It does not replay expired consequences.
6. Every setback retains a deterministic minimum actionable warning interval. Delayed commitment does not freeze ordinary economy, demand, happiness, utility, or treasury consequences.
7. Existing Town Charter daily-boundary and one-time award semantics remain unchanged.

## Presentation boundary

Gameplay analytics derive awaiting-choice status, committed strategy, current phase, and days until the next consequence from authoritative state. UI/input consumes those values and must not infer a countdown from `tick`, message titles, or prose. `CityPresentationSnapshot` needs no parallel strategy field because it already carries the authoritative state and derived analytics.

Existing message titles should remain stable where possible. Resolved or expired opening guidance must retire or become visibly historical within one daily evaluation so current pressure remains prominent.

## Persistence and fingerprint decision

- Save schema remains version 1 because the nested field is additive and optional.
- Fingerprint version remains 1 under the existing sorted-JSON, full-state algorithm.
- Frozen legacy nil-strategy bytes and digests must remain unchanged. Active strategy fixtures legitimately receive new digests because the authoritative state changes.
- If an authentic pre-change schema-1 envelope fails digest validation after decoding, stop and add version-aware fingerprint validation before considering schema 2.
- Undo restores the exact whole progression state. Save/load, backup recovery, replay, and grouped-speed execution preserve phase and scheduling exactly.

## Mandatory evidence

- Frozen schema-0 and pre-change schema-1 files decode and validate without regeneration.
- Missing strategy remains nil through load and normalizes only at the defined daily boundary.
- The retained PLAY-051 route crosses Day 25 after a failed placement, later commits successfully, and receives every phase exactly once.
- Commercial and Industrial cover commitment, complication, setback, recovery, and completion; later tile-count reversal does not change route.
- Save/load at every phase, undo before/after commitment, grouped speed, uninterrupted execution, typed-command replay, backup recovery, and immutable snapshot analytics match exactly.
- Repeated fingerprints are frozen for nil, awaiting choice, and every active phase. Every changed golden digest is explained.
- Dense simulation, save size, snapshot derivation, retained memory, and full native suite remain within accepted budgets.

## Adoption order

1. Integration publishes CONTRACT-007 and claims.
2. PLAY-013 implements the smallest gameplay model/rules/analytics slice.
3. PLAY-042 adopts fingerprints, persistence, replay, recovery, snapshots, and performance fixtures.
4. PLAY-033 consumes the derived analytics and implements the HUD journey.
5. PLAY-051 reruns the exact failed opening, both strategies, persistence, default, and compact gates.

## Rejected expansion

This contract does not authorize a general quest/event engine, save-schema bump, UI-owned clock, panel-state persistence, new command, renderer input, HUD redesign, or unrelated balance change.
