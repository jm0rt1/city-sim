---
name: operate-citysim-integration
description: "Serve as the all-inclusive CitySim Integration Captain on `master`: supervise every worker thread and worktree, keep all meaningful work intelligently committed, establish and publish clean baselines, maintain PLAY tasks and claims, govern shared contracts and dependencies, review and integrate worker commits, enforce real-app quality gates, manage branch/worktree recovery, update release evidence and traceability, and push accepted playable builds. Use for every prompt in the main CitySim checkout and for any dispatch, status, Git hygiene, contract, integration, release, rollback, or cross-lane management task."
---

# Operate CitySim Integration

Keep one game coherent while specialist lanes and contract-separable cells move in parallel. Own the complete management system; the accepted playable build is the deliverable.

## Orient before every task

1. Run `pwd`, `git branch --show-current`, `git status --short --branch`, `git worktree list`, and `git log -1 --oneline --decorate`.
2. Require `master` for integration mutations. On another branch, stop or load that lane's skill.
3. Read `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md` completely.
4. Read the active `PLAY-*` tasks, claims, completion records, affected requirements, and relevant worker-thread updates.
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

Use thread coordination tools to inspect progress, send corrections, request missing evidence, redirect scope, and wait for completion. Do not let a worker silently run through an ownership conflict or stale baseline. Do not substitute status narration for intervention.

## Enforce useful parallelism

Parallel delivery is an Integration invariant, not an optional optimization.

At every dispatch, status review, candidate return, and integration boundary:

1. Identify every unit of work that is independent under the published contracts and current path ownership.
2. Dispatch every eligible unit during the same management turn through its visible lane thread.
3. Maintain at least three active useful workstreams whenever three claimed units of useful work exist. A lane awaiting another candidate receives non-conflicting preparation, validation, fixture, audit, or evidence work instead of remaining idle.
4. Split slow lanes into direction-, fixture-, evidence-, or contract-exclusive cells when they can work without shared-file mutation.
5. Repair detached branches, stale baselines, missing claims, or completed-but-idle lanes promptly, then refill them from the published backlog.
6. Never manufacture concurrency by allowing two writers on one shared surface, weakening exact-candidate identity, or overlapping the final independent app gate.

For each active family or release batch, publish and maintain a visible status table in the task authority or integration status artifact:

| Batch | North | East | South | West | Renderer | QA |
|---|---|---|---|---|---|---|
| `<family>` | `<state/claim/commit>` | `<state/claim/commit>` | `<state/claim/commit>` | `<state/claim/commit>` | `<intake state>` | `<gate state>` |

Integration is the single writer for the shared batch ledger. Publish it in a
machine-readable integration-owned artifact before pixel production begins.
Each cell reports through its task-owned handoff packet; workers never edit the
shared ledger. Every cell entry must identify owner, visible thread, branch,
absolute worktree, claim, published base, exact head, state, blocker, next
action, and update time. Reserve the intended renderer-ingestion window and
independent-QA window in the same ledger so completed sources do not enter an
undefined queue.

For directional World Art, the canonical control surfaces are
`docs/production/evidence/INTEGRATION/WORLD_ART_PARALLEL_BATCH_LEDGER.json`,
`docs/production/evidence/INTEGRATION/WORLD_ART_PARALLEL_BOARD.md`, and one
timestamped
`docs/production/evidence/INTEGRATION/WORLD_ART_PARALLEL_DISPATCH-*.json`
receipt. The ledger is authoritative; the board and receipt are projections
and must not be maintained as independent truth.

Before reporting status, dispatching work, admitting a source, or integrating a
candidate, compare every recorded cell against its live visible-thread status
and exact worktree branch, `HEAD`, and clean/dirty state. A stale ledger is a
hard management stop: mark stale rows explicitly, refresh them in the same
Integration checkpoint, and do not describe a sent, completed, blocked, dirty,
or mismatched row as active. Each row must also record `dispatchState`,
`acknowledgedAt`, `claimRevision`, `cleanState`, `boundedDeliverable`, and
`stopCondition`. The batch artifact must bind the immutable family contract,
appearance-lock state and hash, source-production-profile state and hash, and
Integration semantic-validator state and hash. Use explicit `null` plus a
blocking status when an authority does not yet exist; never imply it from a
nearby artifact.

Advance each batch through this explicit state machine:

`contract_pending → prelock_active → appearance_lock_pending → abc_active →
4of4_ready → exact_candidate_qa → integrated`

Only Integration advances shared batch state. Direction-local cells may report
their own completed stage, but may not declare the family advanced. If a cell
becomes idle before its next transition is legal, assign stage-legal
preparation, validation, fixture, audit, or evidence work; do not bypass the
gate and do not leave useful capacity dormant.

Track each direction separately inside the batch:

`predesign → source_candidate`

`source_candidate → returned | integration_admitted`

`returned → predesign | source_candidate`

`integration_admitted → returned | renderer_quarantined`

Track Renderer separately:

`intake_preparing → intake_ready → quarantining → 4of4_assembled`

Track QA separately:

`preregistering → preregistered → exact_candidate_active → passed | returned`

Keep the batch at `abc_active` while only some directions have advanced.
Derive `4of4_ready` only when the exact North, East, South, and West packet
identities are all Integration-admitted and Renderer-quarantined.

Publish a dispatch receipt for every management turn that changes work:

- authority commit and exact claim revision sent to each cell;
- thread/worktree/branch binding and send timestamp;
- whether the thread acknowledged the assignment;
- exact worker head and clean/dirty state at acknowledgement;
- the first bounded deliverable and its stop condition; and
- `planned`, `sent`, `acknowledged`, `working`, `returned`, or `blocked`.

Every dispatch receipt contains all six rows, including unchanged rows, with
`changedThisTurn: true|false`. Do not split unchanged or review-pending rows
into a weaker side list. Each row carries its exact head, dispatch state,
acknowledgement, bounded deliverable, stop condition, blocker, next refill
action, and live observation time.

Do not count a row as an active workstream until the visible thread has
acknowledged the exact authority and begun a legal bounded deliverable.
Likewise, do not leave a completed thread labeled active. Refresh the ledger
and dispatch receipt when a worker returns, blocks, or becomes idle. The
parallelism invariant is measured by useful acknowledged work, not by the
number of branches, threads, or optimistic status labels.

Before ending a management turn, requery all six visible threads and
worktrees; refill every returned, blocked, completed, or idle row with
stage-legal work in the same turn; wait for acknowledgement; refresh the
ledger, board, and complete receipt; validate them; and commit the management
checkpoint. A row may remain unstaffed only when the ledger names the exact
stage prohibition, owner, resumption event, and why no non-conflicting
preparation exists. `planned`, `sent`, `review_pending`, or an unacknowledged
assignment does not satisfy this gate.

Run
`python3 .agents/skills/operate-citysim-integration/scripts/validate_world_art_parallel_state.py`
before committing a directional World Art management checkpoint. Treat any
stale, partial, non-resolving, or contradictory control-surface result as a
hard stop.

For directional World Art, use this default fan-out:

- North is the hero/design-calibration cell and authors the proposed family
  vocabulary; Integration freezes the shared appearance lock only after
  independent review.
- East, South, and West independently complete zero-pixel blockouts plus camera/socket proofs while North is under review.
- Renderer prepares stable IDs, mapping, atlas/LOD quarantine, registration tests, fallback rejection, and staged fixture placement without activating unfinished art.
- QA preregisters exact camera states, mature-city fixture, regular/compact layouts, interaction route, and acceptance rubric before the renderer candidate arrives.
- Once independent technical and literal-scale review accepts North process A,
  publish a non-production appearance lock. Immediately authorize North B/C
  and East, South, and West A/B/C concurrently. The lock does not make North
  source-ready or authorize renderer activation. A failed direction returns
  only that direction.
- Production selection and shipping activation remain atomic at four accepted directions.

Only genuine shared authorities remain serialized: family-contract publication, shared toolchain changes, shipping atlas/manifest mutation, production selection, final exact-candidate QA, integration, and push.

Do not dispatch a four-direction family as a North-only task. In the same
management turn that establishes or revises the family contract, dispatch
every legal direction cell plus Renderer intake preparation and QA
preregistration. North appearance review is a design-calibration gate, not a
department-wide mutex: before its lock, siblings perform zero-pixel work; after
its lock, all authorized source processes fan out immediately. If fewer than
three useful workstreams are acknowledged, the shared ledger must name the
exact gate preventing each absent stream, its owner, the legal preparation
available meanwhile, and the next refill action. “Waiting for North” is not a
sufficient blocker for sibling blockout, Renderer intake, or QA preparation.

For an active directional family, the default target is six acknowledged
useful rows: North, East, South, West, Renderer, and QA. A missing row is legal
only when its ledger entry names the exact stage prohibition or exhaustion of
non-conflicting preparation. The general three-stream minimum applies to other
work; it does not weaken this six-row family default.

Publish a compute envelope with each source release. Logical cells may all
remain active while expensive render processes run in bounded waves. Specify
the maximum simultaneous Blender/DCC processes, assigned process slots, queue
order, machine/resource assumptions, and exception owner. Do not create
apparent speed by oversubscribing the machine and invalidating determinism,
memory, or timing evidence.

Source-stage direction packets may report only `source_candidate` with
`candidateReadyForIndependentReview:true`; predesign packets may report
`predesign_ready`.
Integration advances a direction to `integration_admitted` only after the
versioned handoff passes the Integration-owned semantic validator and its
independent technical plus literal-scale review dispositions are recorded.
This source admission is direction-local: a returned East candidate must not
demote an admitted North, South, or West candidate. Renderer activation and
production selection remain separately blocked until the exact admitted set
is 4/4.

For every admitted direction, publish an Integration-owned source-admission
receipt binding the source packet path/hash, content commit, family-contract
and appearance-lock hashes, semantic-validator path/hash/result, independent
technical disposition, independent literal-scale disposition, admitted raw
and decoded hashes, and resulting shared-ledger revision. Renderer quarantine
must consume this receipt rather than a worker-authored readiness boolean.

## Keep delegation visible without pinning threads

- Delegate lane work through user-visible Codex threads whenever the user expects to observe or enter the work. Use an existing canonical lane thread when one exists; otherwise create a clearly titled project/worktree thread.
- Never pin an individual Codex thread. Do not call `set_thread_pinned` with `pinned: true` as a dispatch, prominence, reminder, or status mechanism. Pinning is user-owned interface organization.
- Keep tasks findable through descriptive thread titles, explicit delegation messages, reported thread IDs, and `list_threads`, `read_thread`, `send_message_to_thread`, and `wait_threads` status management.
- Do not alter pre-existing pin state. If this integration agent pinned a thread during the current operation, undo only that pin and disclose the correction.
- Internal subagents may support bounded analysis, but they must not substitute for a requested user-visible lane thread or edit the same worktree concurrently with its visible owner.

### Bind visible threads to exact worktrees

Treat a thread as a communication surface, never as sufficient routing
authority. Before every dispatch, verify and record the tuple
`{lane, direction, thread_id, branch, absolute_worktree, claim, base, head,
state}`. Reuse a canonical visible thread only when its current worktree,
branch, and claim match that tuple. Otherwise repair the routing or create a
new clearly titled project/worktree thread; never send mutation authority to a
stale, detached, or differently claimed checkout. Report the binding in the
management update so the user can inspect it without relying on pin state.

## Enforce intelligent commits everywhere

Treat commits as continuous durability and review boundaries, not end-of-project cleanup.

### Commit invariants

- Never use `git add -A` in a dirty multi-owner checkout. Stage explicit files or narrow directories.
- Inspect `git status --short`, `git diff`, `git diff --cached --check`, and `git diff --cached --stat` before every commit.
- Keep one coherent player, contract, test, evidence, or management outcome per commit.
- Never mix unrelated user work, multiple lanes, generated output, or speculative cleanup into a commit.
- Use messages such as `PLAY-030: Add typed command registry` or `Integration: Publish wave 1 baseline`.
- Commit after a coherent validated checkpoint, before handoff, before changing task or lane, before risky refactors/merges, and before ending a work turn with completed work.
- Allow explicit `checkpoint(PLAY-###): ...` commits on worker branches only when work is incomplete but worth preserving. Checkpoints cannot support `ready-for-integration` and must state failing or unrun validation.
- Require a completion record to name exact commit hashes. Completed-but-uncommitted work is invalid.
- Workers commit locally but do not push or integrate. Integration pushes accepted `master` and may preserve recovery branches when necessary.

### Worktree audit

At dispatch, status review, handoff, and integration, verify for every lane:

- expected branch/worktree and base ancestry;
- clean or explicitly explained dirty state;
- task claim matches changed paths;
- latest durable commit is current with reported progress;
- no staged leftovers, accidental generated files, or unrelated changes;
- divergence and merge dependencies are understood;
- completion hashes exist before acceptance.

If finished work is dirty, direct the owner to validate and commit it. If provenance is ambiguous, freeze the lane and preserve the diff before any cleanup.

## Direct the production system

1. Keep `master` as the only accepted integration lane.
2. Maintain `docs/production/PLAYABLE_BACKLOG.md` with one owning lane and explicit dependencies per task.
3. Issue or approve claims only from a published baseline.
4. Approve shared-contract proposals before dependent lanes diverge.
5. Prefer short vertical waves improving the same build → diagnose → adjust → recover journey.
6. Split tasks that cannot integrate into a playable state within one iteration.
7. Reassign work only after preserving the original branch, diff, commits, and claim history.
8. Keep legacy Python read-only unless a task explicitly authorizes migration/reference work.

## Guard shared contracts

Own package topology, public store intent, commands, snapshots, saves/migrations, stable identities, theme tokens, build scripts, task authority, and traceability.

For any proposed change require:

- current blocker and player outcome;
- smallest typed interface change;
- affected lanes and adoption order;
- save, input, accessibility, performance, and migration risks;
- contract tests and rollback plan.

Reject worker-local assumptions that decide product scope, duplicate state, or put simulation truth in UI/renderer layers.

## Integrate a candidate

1. Freeze the exact candidate commit and confirm the worktree is clean.
2. Confirm its completion record contains scope, commits, validation, live evidence, proof, risks, and shared-contract notes.
3. Review the full commit range and verify only claimed surfaces changed.
4. Return oversized, mixed, weakly proven, or cross-lane work to its owner.
5. Preserve a recoverable pre-integration `master` commit.
6. Integrate in dependency order: platform contracts, simulation/gameplay, rendering, UI/input, quality fixtures.
7. Resolve only narrow mechanical conflicts; return semantic conflicts to owners.
8. Run:
   - `swift test --package-path Native/CitySimNative`
   - `git diff --check`
   - `bash -n script/build_and_run.sh`
   - `./script/build_and_run.sh --verify`
9. Operate the target journey in the staged app using pointer and affected keyboard paths at default and compact layouts.
10. Check accessibility, focus, save/load, undo, visual truth, performance, and recovery when affected.
11. Update completion, baseline, proof, decision, and requirement records truthfully.
12. Commit integration-only changes separately, push accepted `master`, verify remote parity, and announce the next baseline.

## Reject false completion

Do not accept work because it compiles, has isolated tests, looks attractive once, closes checkboxes, or is committed. Require an understandable decision, visible consequence, recovery path, correct ownership, live operation, and retained evidence.

## Recover safely

- Preserve dirty or rejected work on its branch; never erase it for convenience.
- Stop on stale baseline, unknown provenance, detached mutation, missing claim, conflicting contract, failing gate, or staged-app regression.
- Use explicit rollback commits or preserved pre-merge commits; never rewrite shared history to hide integration mistakes.
- When a worker is blocked, identify the exact owner, required decision/input, safe interim work, and resumption condition.
- Escalate only decisions that materially alter product promise, architecture, commercial scope, irreversible content investment, or user authority.

## Report as command center

Report:

- baseline and `master`/remote parity;
- each lane's thread status, branch, claim, cleanliness, latest commit, evidence, blocker, and next action;
- accepted/rejected task IDs and commit hashes;
- gate and hands-on results;
- shared-contract decisions and merge order;
- proof paths, remaining product risks, and decisions required from the user.

Never hide dirty state, uncommitted finished work, skipped validation, rejected candidates, or deferred risks behind a green test count.
