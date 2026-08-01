# Model Routing and Cost Control

**Status:** Integration-owned mandatory operating contract

## Contents

- Execution tiers and mandatory route packet
- Escalation and judgment-boundary rules
- Lane routing boundaries
- Compact context loading and tiered validation
- Dispatch acknowledgements and pilot measurement

Use the least expensive model that can complete a packet without making a
product, architecture, shared-contract, or acceptance judgment. Cost control
never weakens Git identity, claims, ownership, deterministic behavior,
candidate-bound evidence, staged-app proof, or independent QA.

## Execution tiers

| Classification | Model | Effort | Legal ownership |
|---|---|---|---|
| `FRONTIER_AUTHORITY` | `gpt-5.6-sol` | `high` | Product and architecture decisions, shared contracts and schemas, claims, art direction, ambiguous cross-system debugging, semantic conflict resolution, integration acceptance, final staged-app QA, publication, and push |
| `LUNA_IMPLEMENTATION` | `gpt-5.6-luna` | `high` | Bounded implementation under frozen contracts, exact allowed paths, focused gates, one coherent commit, and explicit escalation |
| `LUNA_MECHANICAL` | `gpt-5.6-luna` | `medium` | Inventories, hashes, manifests, fixtures, schema checks, focused tests, deterministic normalization, evidence capture, path/diff audits, and packet assembly |
| `LUNA_LOCAL_DEBUG` | `gpt-5.6-luna` | `max` | Reproducible lane-local defects with frozen inputs and no shared-contract ambiguity; stop and escalate after two unsuccessful repair attempts |

The classification, model, and effort are one immutable tuple. No substitute
model, lower effort, or nearby classification is implied by availability.

## Mandatory `modelRoute` packet

Every worker dispatch must bind one committed machine-readable route packet
validated by
`scripts/validate_model_route_v1.py`. The packet contains:

- classification, model, effort, and rationale;
- exact authority commit, base commit, claim path and claim hash;
- immutable input paths and hashes;
- assignment thread, feature-author thread when applicable, and ownership
  booleans for shared authority, subjective judgment, and final QA;
- claim-owned roots plus exact allowed and forbidden path prefixes;
- one bounded deliverable and stop condition;
- focused-gate owner and commands;
- distinct full-gate owner and commands;
- expected evidence paths and coherent commit requirement;
- all mandatory escalation triggers;
- independent reviewer identity; and
- context-loading mode plus verified context hashes.

The visible-thread prompt and dispatch receipt must project the exact packet
path, SHA-256, and content. A worker independently resolves the committed
packet, claim, inputs, base, and authority before acknowledging. Prompt text is
not authority. Any mismatch is a zero-mutation stop.

## Mandatory escalation triggers

Every Luna packet must carry all of these fail-closed triggers:

1. `shared_contract_or_schema_decision`
2. `unresolved_product_visual_or_interaction_judgment`
3. `path_outside_claim`
4. `baseline_or_candidate_identity_mismatch`
5. `failure_outside_focused_scope`
6. `save_or_migration_uncertainty`
7. `cross_lane_semantic_conflict`
8. `two_unsuccessful_repair_attempts`
9. `subjective_acceptance_required`

Escalation preserves the current branch, evidence, and coherent checkpoint.
It does not authorize broader work. A Luna worker may diagnose the boundary
but may not decide it.

## Break substantial tasks at judgment boundaries

For every substantial `PLAY-*` task, Integration publishes three layers:

1. a `FRONTIER_AUTHORITY` design or authority packet freezing the outcome,
   contracts, tradeoffs, and acceptance boundary;
2. one or more disjoint Luna execution packets with exact roots and focused
   gates; and
3. an independent `FRONTIER_AUTHORITY` acceptance packet bound to the exact
   aggregated candidate.

Do not assign an ambiguous feature end-to-end when deterministic
implementation, mechanical evidence, and subjective judgment can be separated.
One writer owns each worktree, Git index, governed evidence packet, and commit.

## Lane routing boundaries

- **Gameplay:** Luna implements frozen rule slices, fixtures, analytics, and
  deterministic tests. Frontier owns tradeoff design, pacing, economy balance,
  recovery quality, and cross-system tuning.
- **Simulation:** Luna owns replay, fixtures, diagnostics, profiling, and
  implementation under a frozen schema. Frontier owns schemas, snapshot
  contracts, migrations, persistence decisions, and subtle nondeterminism.
- **UI and input:** Luna owns approved component implementation, command
  mappings, shortcuts, focus tests, and accessibility tests. Frontier owns
  information architecture, HUD hierarchy, interaction tradeoffs, and final
  usability judgment.
- **Renderer:** Luna owns intake mapping, quarantine, LOD/socket/pivot tests,
  fixtures, resource integrity, and bounded approved components. Frontier owns
  visual architecture, composition, difficult performance tradeoffs, atomic
  assembly acceptance, and mixed-fidelity judgment.
- **World Art:** Frontier owns the North hero design, family vocabulary, and
  appearance lock. Luna owns Integration-authorized East/South/West DCC jobs,
  provenance, normalization, deterministic checks, contact sheets, and handoff
  packets. North mechanical validation may use Luna, but its visual disposition
  remains frontier-owned.
- **QA:** Luna owns preregistration, fixture/camera preparation, scripted
  checks, measurements, and defect packets. A fresh independent frontier task
  owns the one exact-candidate real-app journey and `APPROVE`/`RETURN` judgment.
- **Integration:** Luna may prepare read-only manifests, inventories, diff/path
  reviews, and ledger projections. Only the frontier captain changes shared
  authority, integrates, resolves semantic conflicts, accepts, publishes, or
  pushes.

## Compact context loading

A full applicable authority read is mandatory when any of these is true:

- new visible thread;
- new or revised claim;
- changed authority, contract, route-packet, or skill-core hash;
- context loss or compaction without a retained context receipt; or
- any stale, missing, or contradictory binding.

An unchanged same-thread continuation may consume a compact lane-context packet
instead of rereading unchanged long documents only when it independently proves:

- the same thread, task, branch, worktree, claim path/hash, authority and base;
- unchanged mandatory skill-core and previously consumed reference hashes;
- the previous bounded deliverable, current checkpoint, focused-gate result,
  remaining work, and stop condition; and
- a complete list of conditional references required for the next packet.

At continuation startup, resolve every recorded hash from repository bytes and
Git objects. A mismatch forces a complete reread. Compact context may summarize
operational facts but may not omit, weaken, or reinterpret safety rules.

## Tiered validation

- Luna execution packets run only the focused owner and directly affected
  gates named by their route packet.
- The lane coordinator joins coherent packets and verifies path, claim,
  identity, and evidence integrity without rerunning unrelated suites.
- The full Swift suite, staged build, and real-app journey run once against the
  exact aggregated or integrated tree. Repeat them only when identity changes,
  focused evidence is stale, or the journey exposes a defect requiring fresh
  reproduction.
- UI and gameplay changes still require real-app proof at the aggregate
  candidate boundary.
- Direction-local art uses focused source gates. Renderer runs the full suite
  and resource smoke once at exact 4/4 assembly. Independent frontier QA then
  runs one fresh-player candidate-bound gate.

Evidence remains machine-readable and candidate-bound. Compact receipts and
exception-driven review replace duplicate prose, not proof.

## Dispatch and acknowledgement

Integration sends the canonical visible task with the route packet's exact
model and effort override. The worker must acknowledge the route packet hash,
authority, claim, allowed roots, bounded deliverable, focused gate, full-gate
owner, escalation triggers, and stop condition before work begins. Never pin a
task.

Luna cannot own shared authority, production selection, semantic disposition,
final QA, integration, publication, or push. Final QA cannot run in a feature
author's task. Passing sibling rows remain immutable when another direction is
returned.

## Pilot measurement

For each packet record:

- route classification, model, and effort;
- elapsed time and number of turns;
- approximate token use when the product exposes it;
- validation time;
- return and rework count;
- accepted commit or result; and
- frontier escalation reason, if any.

Report accepted outcomes per frontier turn, Luna return rate, duplicate
full-suite minutes, dispatch-to-accepted-candidate time, and total token/cost
trend without inventing pricing. The initial target is at least 60% of eligible
worker execution turns on Luna. Increase the share only after accepted-output
and return-rate evidence supports it.
