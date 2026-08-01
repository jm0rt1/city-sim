# Directional Art Parallelism

## Contents

- Six-cell batch phases and same-turn dispatch
- Failure isolation and visible status
- Parallel execution accounting and ownership
- Ledger, acknowledgement, and state-machine authority
- Schedules, compute envelopes, source admission, and 4/4 activation

Operate each directional family as one six-cell batch:

| Batch phase | North | East | South | West | Renderer | QA |
|---|---|---|---|---|---|---|
| `prelock_active` | hero predesign plus the one explicitly granted Process A | independent zero-pixel blockout | independent zero-pixel blockout | independent zero-pixel blockout | non-shipping intake graph and fixture preparation | candidate-neutral gate preregistration |
| `appearance_lock_pending` | independent technical and literal-scale review | finish or refresh predesign | finish or refresh predesign | finish or refresh predesign | keep quarantine harness current | keep fixture, camera, and rubric current |
| `abc_active` | B/C production and validation | A/B/C production and validation | A/B/C production and validation | A/B/C production and validation | quarantine each admitted direction on arrival | parallel direction-local literal-scale review only |
| `4of4_ready` | retain exact packet | retain exact packet | retain exact packet | retain exact packet | atomic assembly, build, and resource smoke | wait on the exact Renderer candidate |
| `exact_candidate_qa` | freeze | freeze | freeze | freeze | freeze exact candidate | one exclusive staged-app acceptance gate |

## Same-turn dispatch cycle

In one management turn:

1. Resolve the immutable family contract, exact claims, direction roots,
   Renderer intake authority, QA preregistration authority, and compute
   envelope.
2. Send one bounded assignment to every stage-legal row through its canonical
   visible thread.
3. Wait for each row to acknowledge the exact authority and begin its first
   legal job, or record a structured exemption that proves no preparation is
   legal.
4. Publish the six-row ledger, board projection, and complete dispatch receipt
   from those live acknowledgements.
5. Reserve the next Renderer-ingestion and independent-QA slots before ending
   the turn.

North review blocks only appearance-dependent pixel production. It never
blocks sibling zero-pixel work, Renderer intake preparation, QA
preregistration, or other contract-independent validation. After the
appearance lock, dispatch all authorized direction processes in the same
management turn.

## Failure isolation

- Return only the failed process or direction.
- Preserve exact passing sibling packets and quarantine results.
- Do not let a DCC queue idle CPU-only provenance, validation, fixture,
  contact-sheet, inventory, or handoff work.
- Do not activate a partial family.
- Keep production selection, shipping mutation, the exact-candidate QA gate,
  integration, and push serialized.

## Required visible status

Maintain this projection from the canonical machine ledger:

| Batch | North | East | South | West | Renderer | QA |
|---|---|---|---|---|---|---|
| `<family>` | `<state/claim/head>` | `<state/claim/head>` | `<state/claim/head>` | `<state/claim/head>` | `<intake state/head>` | `<gate state/head>` |

Each row must expose its current bounded deliverable, stop condition, active
jobs, join, unused capacity, blocker, and next refill action. A thread, branch,
plan, or sent message without an acknowledged running job does not count as an
active workstream.

## Complete Integration control contract

## Enforce useful parallelism

Parallel delivery is an Integration invariant, not an optional optimization.

This complete reference, including its six-cell phase matrix and same-turn
dispatch cycle, is normative operating procedure rather than optional guidance.

At every dispatch, status review, candidate return, and integration boundary:

1. Identify every unit of work that is independent under the published contracts and current path ownership.
2. Dispatch every eligible unit during the same management turn through its visible lane thread.
3. Maintain at least three active useful workstreams whenever three claimed units of useful work exist. A lane awaiting another candidate receives non-conflicting preparation, validation, fixture, audit, or evidence work instead of remaining idle.
   Define `eligibleUsefulWorkstreams` as the claimed, contract-independent
   units that have disjoint mutation authority and one legal bounded
   deliverable now. The minimum-useful-concurrency invariant is
   `requiredUsefulWorkstreams = min(3, count(eligibleUsefulWorkstreams))`; a
   management checkpoint may close only when at least that many distinct
   canonical rows are acknowledged and executing, or each missing row carries
   a validated structured exemption naming the exact prohibition, owner,
   resumption event, and unavailable preparation.
4. Split slow lanes into direction-, fixture-, evidence-, or contract-exclusive cells when they can work without shared-file mutation.
5. Repair detached branches, stale baselines, missing claims, or completed-but-idle lanes promptly, then refill them from the published backlog.
6. Never manufacture concurrency by allowing two writers on one shared surface, weakening exact-candidate identity, or overlapping the final independent app gate.

Operate two levels of concurrency deliberately:

- **Across lanes/cells:** keep every contract-independent visible worktree moving
  through its canonical user-visible thread.
- **Inside a lane/cell:** require the worker to expose its dependency graph and
  fan out independent process, read-only review, validation, fixture, evidence,
  and comparison jobs after their inputs freeze. One coordinator remains the
  only Git index, shared-file, packet-assembly, and final-commit writer.

Do not treat one active agent per lane as sufficient parallelism. Every dispatch
message must ask for a compact execution plan listing `readyNow`, `running`,
`waitingOnJoin`, `serializedAuthority`, and `nextRefill` work. It must also name
the available worker/process capacity, the safe jobs launched against that
capacity, and the exact ownership or dependency reason for every intentionally
unused slot. Require actual start/end or overlap evidence in the worker's
machine-readable return; optimistic labels and future plans do not count.

Project that return into each ledger/receipt row as one exact
`executionAccounting` object containing the five plan fields above plus
`capacity {helperSlots,dccSlots}`, `launchedJobs`, `unusedCapacityReasons`,
`overlap {status,jobIds,startedAt,endedAt,reason}`, and
`join {state,requiredJobs,completedJobs}`. The parallel-state validator must
reject missing fields, fabricated overlap, unknown jobs, unexplained active
capacity, or a join that does not match `waitingOnJoin`.

Every ledger and dispatch receipt must also project one identical top-level
`parallelismProof {requiredConcurrentCells, eligibleCells, jobRefs, startedAt,
endedAt}`. Each `jobRef` must resolve to one launched job in a distinct
canonical row; derive `startedAt` as the maximum referenced start and `endedAt`
as the minimum referenced end, and require `startedAt < endedAt`. Completed
historical jobs may prove measured overlap, but plans, status labels, per-row
overlap alone, unrelated-batch jobs, and future timestamps never count.

`serializedAuthority` is an object binding the row's exact visible
`threadId`, `branch`, and `worktree`, with that same thread as the sole
`gitIndexWriter` and `governedEvidenceWriter`. Each `launchedJobs` entry binds
its ID to the exact batch, claim, published base, head, visible thread, branch,
worktree, resource class, mutation class, exclusive root, process/slot when
DCC-backed, state, start/end timestamps, and evidence ID. Running job IDs must
resolve to those entries and fit their resource-class capacity. Observed
overlap is derived from the bound per-job intervals, not asserted by prose.
Evidence IDs bind the exact visible thread/turn/item. Mutating roots must be
claim-owned direction roots or claim-token-bound isolated temporary roots,
disjoint across all rows and forbidden from overlapping any canonical
worktree or broad filesystem/home/temp root.
`unusedCapacityReasons` accounts for exactly one helper or DCC slot per entry,
so every intentionally unused slot has its own reason; DCC capacity and jobs
must match the dispatch receipt's published compute envelope and assigned
slots.

When a worker commits its receipt after the measured jobs finish, preserve the
identity boundary explicitly: the canonical row's `head` is the clean live
receipt-candidate commit, `observedHead` is the immutable pre-receipt commit
against which its retained jobs actually ran, and every job's `head` must equal
`observedHead`. `observedHead` is allowed only when it is an ancestor of
`head` and the entire intervening diff is confined to that row's
`docs/production/evidence/PLAY-###/` root. Never rewrite historical job heads
to the later receipt commit. Omit `observedHead` when the live and executed
commit are identical.

Allocate scarce concurrency to the current critical path. Use internal helpers
for bounded read-only review or isolated temporary roots outside the visible
worker's worktree when useful, but keep all worktree mutation authority and
user-visible responsibility in the canonical lane thread. The visible worker
alone may adopt validated temporary outputs into governed evidence. A helper
never stages, commits, rewrites shared authority, performs the final app gate,
or substitutes for the visible worker.

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

Count only work bound to the ledger's exact batch. Do not count an unrelated
renderer feature, prior-family QA gate, generic audit, or merely available
thread as an active family workstream. Every active row must carry a structured
`authorityAcknowledgement` that exactly repeats its visible thread, authority
commit, claim revision, acknowledgement time, bounded deliverable, and stop
condition, plus the visible thread turn/item identifier used as evidence.

A QA row may reach `preregistered` only after Integration acknowledges one
task-owned machine-readable preregistration packet bound to the exact batch,
claim hash, published base, family-contract hash, expected N/E/S/W logical
keys, current ledger revision, Renderer intake-plan hash, fixture/camera/rubric
hashes, and exclusive evidence root, with
`rendererCandidateReceipt: null`. Record that packet path/hash in the QA row.
A generic, prior-family, or prose-only QA plan does not satisfy the row.

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
appearance-lock state and hash, source-production-profile state and hash,
validated parallel-execution schedule/schema/validator, and Integration
semantic-validator state and hash. Use explicit `null` plus a blocking status
when an authority does not yet exist; never imply it from a nearby artifact.
`abc_active` is illegal until the post-lock schedule and per-process
launch-grant validator are published.

Schedule validation alone is never `launch_ready`. Before a direction can be
described as launch-ready, an independently reviewed, Integration-owned
execution-closure contract must select one exact mode:

- `delegated_authenticated`, backed by a trust root the worker cannot choose;
  or
- `integration_direct`, where Integration itself validates and executes the
  one authorized high-level orchestrator and the worker has no launch grant.

The closure must bind the trusted-master schedule, claim, base, direction,
process, slot, roots, orchestrator, and exactly-one attempt. It must reject
replay, wrong identity, and direct low-level invocation. A delegated mode must
also reject forged worker authority; an Integration-direct mode instead proves
that the direction cell cannot start a child and that only an Integration-owned
process receipt can advance launch state. Never use a repository-local public
builder plus caller-selected key as authentication. Keep the cell at
`predesign` and name the missing closure explicitly until the selected mode is
accepted.

Resolve the executable schedule controls from the exact batch ledger and family
contract. Every family must bind its own versioned schedule schema, semantic
validator, adversarial tests, and operating authority. Never validate a new
family against a prior family's conveniently nearby controls.

The current Industrial L4 profile binds:

- schema:
  `docs/production/evidence/INTEGRATION/industrial-l04-parallel-execution-schedule-schema-v1.json`;
- semantic validator:
  `.agents/skills/operate-citysim-integration/scripts/validate_industrial_l04_parallel_execution_schedule_v1.py`;
- no-DCC adversarial tests:
  `.agents/skills/operate-citysim-integration/scripts/test_validate_industrial_l04_parallel_execution_schedule_v1.py`; and
- authority:
  `docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-PARALLEL-EXECUTION-SCHEDULE-V1-AUTHORITY.md`.

Run the exact family-bound semantic validator on every proposed schedule before
publication and again before describing any process grant as active. A pre-lock
schedule may grant only North A. A post-lock schedule must grant North B/C plus
East/South/West A/B/C with at least three DCC slots.

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

The fourth quarantine is a same-turn trigger, not a queue entry. In the same
management receipt, move Renderer to `quarantining`, bind the exact atomic
assembly manifest, and dispatch its acknowledged batch-local assembler. A
`4of4_assembled` row must bind the exact Renderer candidate receipt; an
`exact_candidate_active` QA row must bind its exclusive one-attempt gate lease;
and `passed` must bind the immutable QA result. Unrelated Renderer or QA work
never satisfies these states.

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

Run the exact parallel-state validator path and hash bound by the family ledger
before committing a directional World Art management checkpoint. For the
current Industrial L4 profile this is:

`python3 .agents/skills/operate-citysim-integration/scripts/validate_world_art_parallel_state.py`

That current script's built-in cell bindings are Industrial L4-specific. A
later family must publish and bind either a family-specific validator or a
newer generalized validator whose adversarial tests prove its exact
task/claim/thread/branch/worktree mapping. Never run the Industrial L4 binding
against a later family. Treat a missing family-bound validator, or any stale,
partial, non-resolving, or contradictory result, as a hard stop.

The family-bound validator is the executable parallelism gate. It must fail
closed on the canonical direction/lane/thread/branch/claim/base mapping, exact
claim-file hashes, governed batch and cross-cell states, authority file hashes,
timezone-bearing observations, exact dispatch-to-ledger row projection,
mandatory `ledgerSha256`, and the published compute envelope. A direction
recorded as `integration_admitted` must bind its exact
`sourceAdmissionReceipt`; a direction recorded as `renderer_quarantined` must
also bind its exact `rendererQuarantinePacket`. Do not waive a failure in
prose. Repair the canonical ledger or receipt, rerun the exact validator's
focused adversarial tests, and publish one new coherent management checkpoint.

Every compute envelope declares the simultaneous DCC cap, exclusive slot
owners, queue identities, machine/resource assumptions, prohibited work, and
exception owner. Logical World Art cells may all remain active while the
expensive DCC queue runs in waves, but assigned simultaneous slots may never
exceed the cap. This distinction prevents resource serialization from
becoming department-wide idleness.

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
