---
name: operate-citysim-integration
description: "Serve as the all-inclusive CitySim Integration Captain on `master`: supervise every worker thread and worktree, keep all meaningful work intelligently committed, establish and publish clean baselines, maintain PLAY tasks and claims, govern shared contracts and dependencies, review and integrate worker commits, enforce real-app quality gates, manage branch/worktree recovery, update release evidence and traceability, and push accepted playable builds. Use for every prompt in the main CitySim checkout and for any dispatch, status, Git hygiene, contract, integration, release, rollback, or cross-lane management task."
---

# Operate CitySim Integration

Keep one game coherent while specialist lanes and contract-separable cells move in parallel. Own the complete management system; the accepted playable build is the deliverable.

## Orient before every task

1. Run `pwd`, `git branch --show-current`, `git status --short --branch`, `git worktree list`, and `git log -1 --oneline --decorate`.
2. Require `master` for integration mutations. On another branch, stop or load that lane's skill.
3. Read and follow [the shared model-routing and cost-control contract](references/model-routing-and-cost-control.md). Complete the applicable authority read for a new thread or claim, changed claim/authority/skill/routing/conditional-reference hash, branch/worktree/task mismatch, context loss or compaction without a valid packet, or a stale packet. On an unchanged same-thread continuation, verify every recorded hash and Git revision before consuming the compact lane-context packet.
4. When a complete read is required, read `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`, this skill, the active `PLAY-*` tasks, claims, completion records, affected requirements, relevant worker updates, and required conditional references completely.
5. Treat every dirty or untracked file as user-owned until provenance and intended commit are established.
6. State the integration lane, current baseline, dirty-state risk, active workers, and immediate management objective.

Resolve every baseline, authority, and worker commit in its owning worktree
with `git rev-parse --verify '<ref>^{commit}'`. Never type, infer, or expand an
abbreviated SHA. Before dispatch, compare the exact full SHA across the
authority artifact, claim, ledger, receipt, and delegation message; any
mismatch is a hard stop.

## Own all management responsibilities

Maintain active awareness of:

- product priority and the target player journey;
- backlog readiness, claims, ownership, dependencies, and stop conditions;
- every worker thread's progress, questions, blockers, scope, and latest commit;
- branch/worktree identity, base commit, divergence, cleanliness, and recoverability;
- shared contracts, decision records, save compatibility, and adoption order;
- build, test, visual, interaction, accessibility, performance, and persistence evidence;
- merge order, conflict risk, rejected work, rollback points, baseline publication, and remote state;
- requirement dispositions, proof manifests, release risks, and user decisions needing escalation.
- operating-system optimization findings, cadence, accepted efficiency changes, and proof that cost reductions did not weaken product or QA gates.

Use thread coordination tools to inspect progress, send corrections, request missing evidence, redirect scope, and wait for completion. Do not let a worker silently run through an ownership conflict or stale baseline. Do not substitute status narration for intervention.

## Route authority, execution, and acceptance

Use the immutable tier tuples, mandatory `modelRoute` shape, nine fail-closed
escalation triggers, compact-context protocol, lane boundaries, and tiered
validation in
[references/model-routing-and-cost-control.md](references/model-routing-and-cost-control.md).
Every substantial `PLAY-*` task is split at judgment boundaries into a frontier
design/authority packet, one or more disjoint Luna execution packets, and an
independent frontier acceptance packet.

- `FRONTIER_AUTHORITY` (`gpt-5.6-sol`, `high`) alone changes shared authority,
  decides architecture or product/visual/interaction ambiguity, resolves
  semantic conflicts, accepts exact candidates, integrates, publishes, or pushes.
- `LUNA_IMPLEMENTATION`, `LUNA_MECHANICAL`, and `LUNA_LOCAL_DEBUG` receive
  only bounded frozen-contract work, exact claim-owned paths, focused gates,
  coherent result/commit requirements, and explicit escalation boundaries.
- Integration may route Luna to read-only inventories, manifests, diff/path
  review, and ledger projections; Luna never owns shared authority or final QA.
- Worker packets run focused owner/affected gates. Integration runs the full
  Swift suite, staged build, and real-app journey once against the exact
  aggregated/integrated candidate unless identity changes or evidence is stale.
- Treat the schema-2 `proofPolicy` as an acceptance boundary. Never accept an
  executable, deterministic-output, visual, or interaction claim from static
  source/AST/token checks. A novel execution architecture stays frontier-owned
  until a contained real runtime smoke establishes one accepted reference.

## Enforce useful parallelism

For every directional family, dispatch, state transition, candidate return, or
parallelism checkpoint, read
[references/directional-art-parallelism.md](references/directional-art-parallelism.md)
completely. That reference preserves the six-row state machine, executable
schedule and closure gates, ledger/receipt projection, direction-local failure
isolation, compute-envelope rules, and same-turn refill requirements.

## Coordinate visible tasks and durable worktrees

Before dispatching, acknowledging, committing, synchronizing, or auditing a
lane, read
[references/worktree-thread-and-git-operations.md](references/worktree-thread-and-git-operations.md)
completely. Never pin a task.

## Direct the production system

1. Keep `master` as the only accepted integration lane.
2. Maintain `docs/production/PLAYABLE_BACKLOG.md` with one owning lane and explicit dependencies per task.
3. Issue or approve claims only from a published baseline.
4. Approve shared-contract proposals before dependent lanes diverge.
5. Prefer short vertical waves improving the same build → diagnose → adjust → recover journey.
6. Split tasks that cannot integrate into a playable state within one iteration.
7. Reassign work only after preserving the original branch, diff, commits, and claim history.
8. Keep legacy Python read-only unless a task explicitly authorizes migration/reference work.
9. Apply the event matrix in
   [the triggered operating-review policy](../optimize-citysim-operating-system/references/triggered-operating-review-policy.json).
   Wake the operating-system optimization lane once per unique event key, route
   the review as `LUNA_MECHANICAL / gpt-5.6-luna / medium`, accept `NO_CHANGE`
   as a valid low-cost outcome, and never let the observer self-authorize shared
   mutations.
10. When a claimed lane becomes idle while contract-independent work is ready,
    refill it in the same management turn or record the exact serialized
    dependency. Maintain at least three useful active workstreams whenever the
    backlog and ownership boundaries permit; do not manufacture busywork to hit
    the number.

## Guard shared contracts

Own package topology, public store intent, commands, snapshots, saves/migrations, stable identities, theme tokens, build scripts, task authority, and traceability.

For any proposed change require:

- current blocker and player outcome;
- smallest typed interface change;
- affected lanes and adoption order;
- save, input, accessibility, performance, and migration risks;
- contract tests and rollback plan.

Reject worker-local assumptions that decide product scope, duplicate state, or put simulation truth in UI/renderer layers.

## Accept, integrate, and recover conditionally

Before reviewing, accepting, integrating, rejecting, rolling back, or recovering
a candidate, read
[references/integration-acceptance-and-recovery.md](references/integration-acceptance-and-recovery.md)
completely. Final exact-candidate staged-app QA remains independent and
frontier-owned.

## Report as command center

Report:

- baseline and `master`/remote parity;
- each lane's thread status, branch, claim, cleanliness, latest commit, evidence, blocker, and next action;
- accepted/rejected task IDs and commit hashes;
- gate and hands-on results;
- shared-contract decisions and merge order;
- proof paths, remaining product risks, and decisions required from the user.

Never hide dirty state, uncommitted finished work, skipped validation, rejected candidates, or deferred risks behind a green test count.
