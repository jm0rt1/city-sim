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

Every worker dispatch must bind one committed machine-readable route object,
identified by `routeId` and the SHA-256 of its canonical JSON, and validated by
`scripts/validate_model_route_v1.py`. The route object contains:

- classification, model, effort, and rationale;
- exact authority commit, base commit, claim path and claim hash;
- immutable input paths and hashes;
- assignment thread, branch, absolute worktree, expected starting HEAD,
  feature-author thread when applicable, and ownership
  booleans for shared authority, subjective judgment, and final QA;
- claim-owned roots plus exact allowed and forbidden path prefixes;
- one bounded deliverable and stop condition;
- focused-gate owner and commands;
- distinct full-gate owner and commands;
- expected evidence paths and coherent commit requirement;
- all mandatory escalation triggers;
- independent reviewer identity; and
- context-loading mode plus verified context hashes.

New dispatches use route and dispatch schema `2`. Schema `1` receipts are
historical evidence only and may not authorize a continuation, repair, or new
mutation.

Every schema-2 route also carries `proofPolicy` with:

- `architectureState`: `frozen_reference` or `novel_or_ambiguous`;
- an exact path/hash binding for the accepted reference implementation when
  the architecture is frozen;
- the precise deliverable claims: static structure, executable behavior,
  deterministic output, visual quality, and/or real-app interaction;
- focused and full proof levels from `static_only`, `contained_smoke`,
  `deterministic_replay`, and `real_app_journey`;
- every command that actually exercises claimed behavior; and
- the mandatory evidence substitutions that are forbidden.

Static source inspection, AST shape, token presence, manifests, prose, and a
worker's self-report can prove structure or intent only. They cannot prove that
an executable launches, a renderer emits valid pixels, repeated runs are
deterministic, a visual is good, or an independent player journey passes.

Every new or rebound route with a focused or full command invoking `swift test`
must carry a validator-clean `swiftExecution` contract and invoke that command
through `run_swift_test_lease_v1.py`; raw Swift test commands cannot authorize
execution. The contract binds the runner and result-validator bytes, one unique
lease, canonical build/scratch root, attempt, retained log and terminal receipt,
and the mandatory parent/process-group/observed-descendant closure policy.
Historical routes remain immutable evidence, but cannot authorize a new Swift
execution until rebound prospectively.

Every new or rebound route whose focused or full gate invokes an artifact
writer must carry a validator-clean `writerExecution` contract. It binds the
exact command environment, one canonical absolute generated-output root, and
root-relative artifacts in three explicit phases: hash-bound
`required_input`, absent-at-preflight `prospective_output`, and one
`post_execution_receipt`. Validate the terminal receipt with
`validate_model_route_v1.py --writer-route <route> --writer-receipt <receipt>`;
it must bind the same command, environment, root, zero exit, and every declared
output byte. Compare and materialization inputs may not escape or substitute
the declared root. This applies prospectively and adds no reviewer or
acceptance turn.

An XCTest-backed artifact writer additionally uses prospective
`writerExecution` schema 2. Before any writer runs, its contract binds one
terminal, descendant-free, zero-exit Swift prebuild receipt whose retained log
contains a positive executed-test result, plus the exact executable inside the
produced `.xctest` bundle by canonical path and SHA-256. The executable must be
contained by the receipt's build root, and every XCTest writer argv must consume
that exact bundle. A stale or substituted bundle, compile-only receipt, hash
mismatch, or writer that names another bundle fails preflight. Schema-1
non-XCTest routes and historical route bytes remain valid evidence; they cannot
authorize a new XCTest writer. This is execution identity inside the existing
writer gate, not another reviewer, aggregate, or acceptance layer.

`Build complete!` is an intermediate compilation marker, not a terminal test
result. The runner holds its live OS lease and build-root locks until the parent,
process group, and every observed descendant exit, then applies
`validate_model_route_v1.py --swift-test-log <path>` to the original combined
output. A retry or evidence-capture continuation requires the prior attempt's
bound terminal, descendant-free receipt; never infer completion from sampled
PID visibility. This remains inside the existing gate and adds no reviewer or
acceptance layer.

Before the first DCC scene launch for an exact executable hash, Integration
must bind the executable path, SHA-256, architecture, version/build, and host
architecture, then require one contained factory-startup version probe. Reuse
the resulting hash-bound passing receipt across directions and batches while
the executable and host tuple remain unchanged; do not repeat the probe per
direction. A failed probe blocks scene launch and is attributed to the
toolchain boundary, not to unexecuted CitySim source. Runtime or host drift
invalidates the cached receipt and triggers one new `LUNA_LOCAL_DEBUG` probe.

The visible-thread prompt must identify the committed dispatch-receipt path,
route ID, canonical route SHA-256, and exact model/effort. The receipt embeds
the complete route object beside that hash. A worker independently resolves
the receipt object, claim, inputs, base, and authority before acknowledging.
Prompt text is not authority. Any mismatch is a zero-mutation stop.

For a multi-row dispatch, a worker validates its exact row with
`validate_model_route_v1.py --dispatch <receipt> --dispatch-route-id <routeId>`.
The validator still checks receipt-wide row shape, canonical hashes, shared
authority projection, and unique route IDs, but applies live branch/HEAD and
full route checks only to the selected row. Unrelated sibling HEAD movement
must not demote a correctly bound worker; an unknown or duplicate route ID and
any selected-row identity mismatch fail closed.

Before Integration activates final QA, it creates one schema-2 `qa_handoff`
envelope and runs `validate_model_route_v1.py --qa-handoff <path>`. The
envelope binds the exact acceptance route and dispatch bytes, candidate
ref/commit, absolute staged-app root, canonical tree seal and producer, and
launch argv/environment/window. Its Integration-produced `stage_receipt`
machine-binds `sourceCommit` to the candidate commit and projects the exact
staged root, canonical digest producer, and seal into the handoff; a seal alone
cannot establish source provenance. A 900x600 handoff must carry
`CITYSIM_COMPACT_WINDOW=1` and an absolute isolated `CITYSIM_DATA_ROOT`.
It also binds the stage producer's exact PID, sealed bundle executable, and
required environment with exactly one disposition: the producer terminated
the process before handoff and no same-executable process remains, or it
transferred that exact live PID to QA and no unnamed same-executable process
exists. The validator enforces this live preflight. Independent QA then
verifies the required environment on the actual transferred or newly launched
PID before interacting. That verification is result-bearing: QA retains the
exact `ps eww -p <pid>` output and validates one `qa_launch_receipt` that binds
the handoff hash, actual PID, sealed executable, launch argv/environment, and
retained output hash. Interaction cannot begin from a declaration or sampled
PID alone. A missing or mismatched envelope or launch receipt is setup failure, not
a product RETURN, rebuild request, reviewer, or second acceptance gate.

## Outcome lease fast path

A validated schema-2 claim, route, and selected dispatch form one outcome lease
when the assigned branch, HEAD, exact status contract, claim, and explicit paths
match; frozen/protected user dirt is outside the claim and unchanged; focused
proof is declared; the work is reversible and local; and no product-semantics,
shared-contract/schema, irreversible/external-action, candidate-acceptance, or
release judgment is required.

A validated temp-local route and selected dispatch are sufficient for eligible
reversible local work. Durable publication is required when the carrier is
itself a durable governance/product artifact or crosses a judgment boundary.

For eligible routine work, the named agent may inspect, edit only allowed
paths, run focused proof, stage explicit paths, and create one coherent commit
in the same task. Route validation activates the lease. Do not create separate
ACK-only, static-review, execution-release, receipt-review, or optimizer
observer rounds. Integration may validate and dispatch this work directly.

Allowed paths are a maximum mutation boundary, not a touched-file minimum.
Never manufacture a no-op edit to satisfy a predicted path count. Fewer changed
paths are valid when the bounded deliverable and focused proof pass and every
changed path remains in the allowlist; any extra or unexpected path escalates.
Stage and prove the exact paths actually changed.

Manual CTO review is reserved for the excluded judgment boundaries. Distinct
independent QA and acceptance ownership still apply, and no worker may
self-accept, push, or release.

If the exact command fails from sandbox, permission, or tool transport before
product execution and before mutation, allow one identical retry without a
fresh carrier only after its runner receipt proves terminal descendant closure.
A changed command, second failure, live/unterminated receipt, product execution,
or any mutation ends this infrastructure allowance.

Separately, a failed mechanical implementation action may be corrected once
inside the same outcome lease after an exact post-failure audit proves zero
out-of-allowlist mutation, unchanged intended outcome and paths, no replay of
any completed product or proof action, and no semantics or data nondeterminism.
This corrected mechanical action requires no fresh carrier and consumes neither
the identical infrastructure retry nor a focused proof attempt. A second
correction or any failed audit condition escalates.

Separately, routine reversible implementation may use one bounded local repair
inside the same outcome lease: at most two focused proof attempts total, with
every edit confined to the original allowlist. The first focused failure may
inform one repair without a fresh carrier, ACK, or release only after any Swift
attempt has a bound terminal, descendant-free runner receipt. A second focused
failure, live/unterminated attempt, scope expansion, semantics ambiguity, or
unexpected path escalates.

Keep full logs in the task. CEO/user updates use only done, blocker, owner,
next, and deadline confidence unless a hash or command ledger changes a
decision. In deadline mode, freeze optional scope, maintain one critical path,
exclude optional slices at cutoff, and keep build and QA moving.

Every visible task and specialist subagent title must exactly match its
Obsidian agent note; generic worker/explorer/task titles are invalid. Agents may
coordinate documented direct reports for eligible routine work without another
CEO round, but may not expand path, product, acceptance, push, or release
authority.

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

A user-authorized standing Operational Excellence goal plus a validator-clean
`FRONTIER_AUTHORITY` carrier with `sharedAuthorityOwnership: true` is sufficient
authority for the named control-plane paths. Do not invent a fresh-user
authorization round when task, route, claim, branch, HEAD, and allowed paths
still match; any mismatch remains a zero-mutation return.

`LUNA_IMPLEMENTATION` and `LUNA_LOCAL_DEBUG` may claim executable behavior only
when an accepted executable reference is bound and the focused gate runs a
contained behavioral smoke command. Novel launchers, DCC pipelines, rendering
architectures, persistence mechanisms, and other unproven execution paths are
`FRONTIER_AUTHORITY` until one reference implementation passes its real runtime
gate. After that freeze, disjoint Luna packets may reproduce the proven pattern.

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
- **World Art:** Frontier owns style direction, family vocabulary, appearance
  locks, and subjective source acceptance. Luna owns Integration-authorized
  disjoint ImageGen asset/family production or frozen-reference DCC jobs,
  provenance, normalization, deterministic checks, contact sheets, and handoff
  packets. Mechanical validation may use Luna; visual disposition remains
  frontier-owned.
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

Proof is a ladder, not a collection of interchangeable green checks:

1. `static_only` proves file shape, schema, ownership, and source invariants;
2. `contained_smoke` executes the claimed path in an isolated output root and
   proves exit status plus decodable/nonempty outputs where applicable;
3. `deterministic_replay` repeats the real path in fresh processes/roots and
   compares the governed outputs byte-for-byte or by the frozen semantic rule;
4. `real_app_journey` operates the exact staged candidate and supplies the
   independent visual, interaction, accessibility, and playability judgment.

Executable claims require at least `contained_smoke` in the worker's focused
gate. Deterministic-output claims require `deterministic_replay`. Visual or
interaction claims require a frontier-owned `real_app_journey` full gate.
Presence checks may supplement these gates but never replace them.

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
- Art cells use focused source gates. Renderer runs the full suite and resource
  smoke once at the exact aggregate assembly required by the active contract.
  Independent frontier QA then runs one fresh-player candidate-bound gate.

Evidence remains machine-readable and candidate-bound. Compact receipts and
exception-driven review replace duplicate prose, not proof.

## Dispatch and acknowledgement

Integration sends the canonical visible task with the route object's exact
model and effort override. The worker validates the receipt path, route ID,
canonical route hash, authority, claim, allowed roots, bounded deliverable,
focused gate, full-gate owner, escalation triggers, and stop condition inside
the same task. A passing preflight activates the outcome lease; it does not
require a separate acknowledgement task or management turn. Never pin a task.

Luna cannot own shared authority, production selection, semantic disposition,
final QA, integration, publication, or push. Final QA cannot run in a feature
author's task. Passing sibling rows remain immutable when another direction is
returned.

The full aggregate, build, and real-app QA run once per changed candidate. A
handoff alone does not justify a rerun; rerun only when candidate identity
changes or prior evidence is stale.

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
trend without inventing pricing. Separately record false-green returns where a
worker reported PASS but the required behavior was not executed or failed
independent review. The initial target is at least 60% of eligible worker
execution turns on Luna. Increase the share only after accepted-output,
false-green, and return-rate evidence supports it.
