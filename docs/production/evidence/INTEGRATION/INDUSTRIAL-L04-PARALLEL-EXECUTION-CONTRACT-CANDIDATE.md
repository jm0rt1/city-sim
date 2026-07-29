# Industrial L4 parallel execution contract candidate

- **Owner:** Integration
- **Status:** `DESIGN_FROZEN_IMPLEMENTATION_AND_INDEPENDENT_AUDIT_REQUIRED`
- **Batch:** `industrial_l04_directional_family`
- **Governing contract:** `CONTRACT-021` revision 2
- **Production authority:** none
- **DCC authority:** none
- **Pixel authority:** none

This record freezes the contract architecture needed to run North B/C and
East/South/West A/B/C without serializing the art department or trusting
worker-authored readiness. It does not publish the executable schemas,
validator, source-production profile, appearance lock, process leases, or
source release.

## Authority order

The order is intentionally acyclic:

1. Integration publishes the immutable appearance lock and source-production
   profile after North Process A passes independent technical and literal-scale
   review.
2. Integration publishes one global schedule containing immutable process
   allocations, slots, roots, dispatch sequence, and any explicit sequential
   exception.
3. Direction cells execute only their allocated work and write task-owned
   direction-local receipts. A cell may never claim that it proved the global
   cap.
4. Integration validates the exact committed schedule and direction receipts,
   derives actual concurrency, and issues any later source-admission receipts.

The schedule must not hash, name, or depend on future direction receipts.
Direction receipts bind the earlier schedule by exact path, commit, and
SHA-256.

## Required shared artifacts

Integration is the only writer for:

- `industrial-l04-direction-parallel-execution-receipt-schema-v1.json`;
- `industrial-l04-global-dcc-schedule-schema-v1.json`;
- the batch-specific global schedule;
- the shared strict validator and its adversarial tests;
- sequential exceptions, cancellation dispatches, and retry dispatches; and
- source-admission and final closeout receipts.

Direction cells write only their claimed execution receipts and evidence.
Their `integrationAdmitted`, `rendererQuarantined`, `productionSelected`, and
`shipping` grants remain exactly `false`.

## Identity and Git bindings

Every authority record binds a repo-relative POSIX path, 40-character commit,
and SHA-256 of the exact blob obtained from:

```text
git show <commit>:<path>
```

The validator verifies the edge-specific history:

```text
published baseline
  -> schedule authority
  -> cellContentCommit
  -> receipt commit or candidate head
```

An Integration authority commit must be an ancestor of the worker-dispatched
base when that worker is required to consume it. The worker content commit may
and normally will descend from the earlier Integration baseline; it is not
required to be the baseline's ancestor. Every named path must resolve to a
regular Git blob at its named commit. Reject Git symlink mode `120000`, trees,
submodules, and other non-blob modes.

A direction receipt records the pre-receipt `cellContentCommit`; it must not
embed a self-referential `receiptCommit`. Integration may bind the later
receipt commit in a separate closeout record.

## Strict schema separation

The global schedule schema contains only Integration allocations, leases,
dispatch/cancellation/retry events, modes, slots, and exceptions. It forbids
local execution results, evidence hashes, direction-receipt hashes, and grant
fields.

The direction-receipt schema contains its immutable schedule binding plus
direction-local invocations, evidence, jobs, joins, and assembler result. It
forbids global aggregate/cap claims, Integration dispatch authorship, source
admission, Renderer quarantine, production selection, and shipping.

Both schemas use `additionalProperties: false` recursively.

## Paths and immutable capture

Reject absolute paths, backslashes, NUL, empty components, `.`, `..`, broad
roots, sibling roots, shared roots, and any overlap between raw, semantic, job,
or evidence roots across all directions.

Resolve from an explicit repository root. Every ancestor component must be a
real non-symlink directory; every terminal authority or input must be a regular
file. Open the parent directory by file descriptor, then open the terminal
with no-follow semantics. Compare `fstat` device, inode, size, modification
nanoseconds, and change nanoseconds before and after reading; re-`lstat` the
path after capture. Validate and hash the single captured byte buffer. Path
resolution plus device/inode alone is insufficient because it cannot detect an
in-place mutation.

## Schedule model

North Process A is the separately reviewed appearance-calibration prerequisite
and is not part of the post-lock queue. The post-lock queue contains eleven
jobs:

1. North B
2. East A
3. South A
4. West A
5. North C
6. East B
7. South B
8. West B
9. East C
10. South C
11. West C

The normal mode is `parallel_two_slot`:

- effective DCC cap `2`;
- deterministic global FIFO;
- lower-slot tie-breaking is used only while Integration constructs the
  immutable schedule;
- at runtime a job may acquire only its preassigned slot and lease;
- Integration derives actual overlap globally from all exact committed
  direction receipts and records the qualifying process pair; no direction
  may self-prove the parallel gate; and
- a cap-two run with no observed overlap is a non-ready result, not an implied
  exception.

The alternate mode is `sequential_exception`:

- effective DCC cap `1`;
- actual overlap is forbidden;
- one exact Integration exception binds owner, path, commit, SHA-256, reason,
  and queue order; and
- direction cells cannot create or infer the exception.

Every allocation binds a monotonic Integration dispatch sequence, allocation
ID, attempt ID, task, direction, process, preassigned slot, planned half-open
lease, output/evidence roots, and optional `retryOf`.

## Observed execution

East, South, and West receipts record exactly one fresh invocation for A, B,
and C. North binds the separately accepted pre-lock Process A receipt plus one
fresh B and one fresh C invocation. All invocations bind immutable receipts,
roots, UTC start/end times, result, and allocation identity.

The Integration scheduler owns authoritative dispatch, acquire, failure,
cancellation, and retry event sequence. A direction receipt may echo immutable
scheduler event IDs, but may not author or reorder them. Wall-clock timestamps
are evidence, not the FIFO tie breaker.

Intervals are half-open `[start,end)`. The global sweep processes end events
before start events at the same timestamp, may never produce a negative active
count, and must finish at zero. Validate both planned leases and observed
process intervals. An observed interval must fit its exact lease and slot.
Schedule validity alone never proves actual concurrency.

## Failure, cancellation, and retry

A process failure cancels only same-direction work that has not reached the
authoritative slot-acquire event. Already-running same-direction work may
finish. Cancellation allocations and events remain in immutable history and
consume no runtime after cancellation. Other directions retain their original
FIFO sequence and passing evidence.

Retry is never automatic. It requires a new Integration dispatch, new
allocation and attempt identities, new disjoint roots, an exact `retryOf`
binding, and append-only placement after every allocation already dispatched
or queued when the retry authority is published. The retry carries a new
Integration sequence and cannot be backdated. Unaffected FIFO order is
preserved.

Failed, canceled, and superseded attempts and their roots remain immutable.
The retry dispatch states whether it retries one process or restarts a complete
A/B/C direction set. The final join selects exactly one accepted attempt per
A/B/C process while retaining the complete attempt history. For North, the
selected A is the separately admitted calibration attempt. The packet
assembler runs exactly once.

## Fixed direction-local DAG

The executable schema and validator must bind exact job IDs and dependencies
for:

- provenance A, B, and C;
- A/B/C identity join;
- normalization repeat 1 and repeat 2;
- literal color;
- grayscale;
- contact sheet; and
- packet assembly.

All invocation counts, barriers, hashes, overlap pairs, concurrency values,
join results, and final dispositions are recomputed by the validator. Worker
JSON is evidence input, never trusted authority.

## Required adversarial proof

Before publication, the executable candidate must reject:

- duplicate keys, non-finite values, missing or additional fields;
- malformed, stale, non-ancestral, or working-tree-only authority bindings;
- absolute/traversing/symlinked/replaced paths and cross-direction root aliases;
- missing, reused, foreign, or mismatched allocations;
- lease escape, same-slot overlap, cap violation, false overlap, and invalid
  sequential exceptions;
- wall-clock tie manipulation, cancellation races, and FIFO changes to
  unaffected directions;
- retry root reuse, backdating, overwritten attempts, and ambiguous retry
  scope;
- wrong process sets, duplicate invocations, DAG cycles, missing barriers, and
  a missing or second assembler;
- false raw/semantic identity joins; and
- any true admission, quarantine, selection, or shipping grant.

Run at least two byte-identical validator passes. Include boundary ties, zero
and reversed intervals, more than two queued jobs, cross-direction failures,
cap-two overlap, cap-two no-overlap non-readiness, and an explicitly authorized
cap-one sequential exception.

## Publication gate

This design becomes production-consumable only after Integration commits the
two exact schemas, strict validator, adversarial tests, and a candidate
authority record containing their SHA-256 values; an independent reviewer then
approves that exact candidate. Until then, the current South prototype and
East/West synthetic orchestration work remain task-owned zero-DCC preparation.
