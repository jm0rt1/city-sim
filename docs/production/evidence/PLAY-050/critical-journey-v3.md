# PLAY-050 Critical Journey v3 — Integrated PLAY-010 Gate

**Status:** Frozen before integrated-candidate execution

**Task:** `PLAY-050`

**Accepted product baseline:** `f96ff8022ee12e0ac32f0250621993d23f2f0d23`

**Evaluation branch candidate:** exact descendant commit recorded in the run manifest

**Authority:** `CONTRACT-001` at `87e83355058e0a5b54bf0a261bd8adde45545bb0` and accepted PLAY-010 completion at `f96ff8022ee12e0ac32f0250621993d23f2f0d23`

## Inheritance

This journey inherits the player brief, timed phases, objective measures, operational definitions, critical variants, and stop conditions from [critical-journey-v1.md](critical-journey-v1.md). It supersedes [critical-journey-v2.md](critical-journey-v2.md) only for the precise timing and deterministic-horizon checks learned from the accepted implementation. The economic standards remain owned by PLAY-010.

The run must use the repository-built staged app and accepted deterministic scenarios without developer coaching. A harness may establish exact rule checkpoints, but it cannot substitute for real-app comprehension, layout, keyboard, accessibility, recovery, or visible cause-and-effect evidence.

## Exact Town Charter timing contract

One simulated day is exactly four simulation ticks. Qualification and legacy-state normalization are evaluated only when `tick % 4 == 0`:

1. Ticks 1, 2, and 3 do not increment, reset, award, or normalize Town Charter progression.
2. Tick 4 is the next daily boundary and performs exactly one qualification check.
3. Eleven full consecutive qualifying days produce a count of 11 with no award and no `Town Charter Awarded` message.
4. The twelfth full consecutive qualifying day produces a count of 12, sets the durable award, and emits exactly one `Town Charter Awarded` message.
5. If a qualifying standard becomes false between daily boundaries, the prior count remains unchanged until the next boundary; that boundary resets the count to zero.
6. After recovery, a later uninterrupted 12-day qualifying sequence can award the Charter.
7. Once awarded, later failures do not revoke the Charter, lower the recorded count, or emit another award message.
8. New and awarded state round trips, existing undo, and legacy decode preserve the approved progression semantics. A legacy missing field remains `nil` through ticks 1–3 and normalizes to zero/not-awarded at tick 4.

Any award, reset, or normalization on a non-boundary tick is false authoritative feedback and a critical failure.

## Golden-session checkpoints

| Checkpoint | Required authoritative result | Required player-facing comprehension |
| --- | --- | --- |
| Start | Seed, tick, day, state identity, progression, and candidate commit are recorded. | Player can identify immediate pressure, the ordered objective sequence, and at least two credible first responses. |
| First decision by 02:00 | A meaningful action changes at least two declared outcome dimensions. | Cost, legality, tradeoff, and next observable consequence are clear without coaching. |
| Ticks 1–3 of a qualifying day | Progression does not change. | No surface prematurely implies that a full day qualified. |
| Tick 4 / first daily boundary | Count changes by exactly one if all accepted standards qualify. | Objective status exposes the exact count and named unmet standards when applicable. |
| Eleven full qualifying days | Count is exactly 11; award flag is false; award-message count is zero. | No objective, HUD, notice, world, or persistence surface claims success. |
| Twelfth full qualifying day | Count is 12; award is true; exactly one stable-title message exists. | Milestone, sustained cause, permanence, and next action are comprehensible. |
| Failure before a boundary | Prior count is unchanged for ticks 1–3. | Player is not falsely told that the completed prior day was erased early. |
| Next boundary after failure | Count resets to zero. | The failed standard and a useful recovery action are discoverable within two minutes. |
| Recovery sequence | A later 12-day qualifying run awards once. | Visible/numerical improvement is readable before minute 18 in the timed journey. |
| Post-award failure | Award and count 12 remain; message count remains one. | Permanent outcome is not contradicted. |
| Persistence and undo | Partial and awarded states round-trip exactly; undo restores the snapshotted value; legacy state normalizes only at tick 4. | Save/load success and resumed pressure/outcome are understandable within one minute. |

## Exact 20-minute strategy horizon

The accepted deterministic seed-42 opening has two reference strategies. Both must remain distinct and viable through exactly tick 2,800 / Day 701, which is approximately 19.6 minutes at the app's declared 1× cadence:

| Strategy | Distinguishing decision | Exact-horizon requirements |
| --- | --- | --- |
| Industry first | Two industrial builds before utility expansion at the accepted coordinates/order. | At tick 2,800 / Day 701: Charter awarded once, status not lost, treasury positive, and pollution pressure higher than the commerce path. |
| Commerce plus tax | Temporary 14% tax with two commercial builds before utility expansion at the accepted coordinates/order. | At tick 2,800 / Day 701: Charter awarded once, status not lost, treasury positive, and tax rate higher than the industry path. |

The strategy criterion fails if either path ends before or after the exact horizon, loses, exhausts the treasury, lacks the Charter, duplicates its award, or ceases to expose the declared tradeoff. Deterministic viability proves balance possibility; the staged journey must separately prove that a fresh player can discover and understand the choices.

## Critical integrated-candidate failures

In addition to v1's failures, reject the candidate for:

- any progression evaluation, reset, award, or legacy normalization on ticks not divisible by four;
- an award after only 11 full qualifying days or no award on the twelfth;
- a failure that resets before the next daily boundary or does not reset at that boundary;
- an exact-horizon mismatch for either reference strategy at tick 2,800 / Day 701;
- a strategy that reaches the horizon but is lost, insolvent, unawarded, or indistinguishable in its accepted tradeoff;
- objective, notice, inspector, save/resume, or accessibility output that contradicts the authoritative count, standards, reset timing, or durable award;
- inability to explain the current pressure, leading cause, consequence, recovery action, or milestone without coaching;
- an inaccessible critical route, a critical compact-layout obstruction, or a false save/resume success signal.

## Required retained evidence

- exact accepted baseline, evaluation commit, staged-app identity, and clean-tree provenance;
- focused automated logs proving ticks 1–4, 11 versus 12 days, boundary reset, later recovery, one-time award, legacy decode, round trips, undo, objective routing, and the two exact-horizon strategies;
- a real 20-minute staged-app journey record with decision, consequence, diagnosis, recovery, outcome, confusion, dead-time, and false-feedback timestamps;
- pointer/default, keyboard, 900×600 compact, Reduce Motion, VoiceOver/Full Keyboard Access, and save/resume dispositions;
- real-app captures of opening pressure, objective progress/blockers, warning/diagnosis, recovery, award or declared limitation, compact layout, and resumed state;
- a criterion matrix classified `passed`, `failed`, `partial`, `blocked`, or `not-reproduced`, plus reproducible defects returned to their owner lanes.
