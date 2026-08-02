# Observation and Upgrade Protocol

Read this reference for every new PLAY-089 route and whenever the observation
boundary, route schema, claim, or authority changes.

## Compact observation receipt

Record only exposed values:

- exact authority, route, task, model, effort, thread, branch, worktree, and
  starting/result commits;
- context bytes actually loaded or the bound compact-packet bytes;
- elapsed time, turns, validation time, duplicate full-gate time, worker
  rework, Integration rework, accepted result, and escalation reason;
- idle interval only when both boundary timestamps exist;
- files and hashes used to support the finding.

Use `null` for unavailable measurements. Never infer tokens, pricing, or time.

## Improvement priority

Prefer, in order:

1. eliminate false-green proof that lets static checks impersonate runtime,
   deterministic, visual, or interaction evidence;
2. eliminate an Integration-authored route/setup return;
3. isolate contract-independent siblings;
4. move proven-reference mechanical work from frontier to Luna;
5. replace repeated full reads with hash-bound compact context;
6. replace duplicate full gates with focused worker gates and one aggregate
   exact-tree gate;
7. shorten handoffs through canonical machine-readable receipts;
8. remove a stale or contradictory authority path.

Do not optimize away independent QA, real-app proof, candidate identity,
claims, save/determinism gates, or atomic four-direction activation.

## Change threshold

Implement only when the evidence names a repeated or high-impact failure, the
change has exact owners and rollback, focused adversarial proof is possible,
and Integration has frozen every shared path. Otherwise return a proposal or
`NO_CHANGE`.

## Event-triggered cadence and stop

Use `triggered-operating-review-policy.json` as the machine-readable authority.
Review once per unique event key at:

- dispatch publication and authority acknowledgement;
- every frontier worker-route assignment;
- task completion or stop, including a durable-result/blocker and next-action
  check without re-running worker validation;
- two consecutive bounded snapshots without durable/tool progress, excluding a
  declared protected active operation;
- first focused-gate failure, first return, and second unsuccessful repair;
- candidate handoff, exact-candidate QA start, and integration close;
- a useful lane becoming idle while disjoint claimed work is ready;
- useful active concurrency falling below the governed floor after protected
  operations are excluded;
- a repeated full context load while authority, claim, skill, and reference
  hashes are unchanged;
- a delegation acknowledgement that fails to bind the exact receipt, route,
  claim, or allowed paths;
- duplicate full-gate requests, route/model mismatch, or claim/baseline mismatch.

The observer uses Luna mechanical/medium and one compact receipt of no more than
the per-event policy byte cap. One canonical observer turn may batch at most
eight event keys within the aggregate cap, but returns one receipt per key.
Freeze branch/HEAD first. Immediate events close before worker synchronization
or mutation; authority reading may overlap the review. It does not poll tasks or spawn more reviews. It may return
`NO_CHANGE`, `REFILL`, `RETURN`, `ESCALATE`, or one bounded proposal. Only
Integration executes a refill, return, escalation, shared change, acceptance,
integration, or push. Stop immediately after one receipt/commit, on any
mandatory model-route escalation trigger, or when the expected improvement
cannot be measured without inventing data.

Every review that summarizes more than one lane, route, or art direction must
include one machine-readable coverage row per source row. Each row carries the
exact task, route, workstream, state, evidence commit, and disposition. North,
East, South, and West are separate rows whenever the four-direction family is
in scope. An aggregate statement cannot substitute for those rows; any omitted,
duplicated, or invented row forces `RETURN` rather than `NO_CHANGE`.

Each durable receipt binds the exact policy bytes, event key, compact-context
hashes/bytes, input receipt hashes, route tuple, trigger-specific evidence,
decision, prohibited-work flags, exposed metrics, and one bounded next action.
Validate it with `../scripts/validate_operating_review_receipt_v1.py`; an event
key already present in the mandatory supplied ledger is a duplicate and fails
closed. The validator resolves every input path and SHA-256 against the supplied
authority root while batch receipt outputs resolve only against the exact
worker/output root. When these roots differ, both must be explicit exact Git
roots; this permits immutable post-baseline Integration authority without
copying it into the worker branch. The validator limits operation kinds to
cheap read/hash/diff/schema/receipt work and enforces the one-turn budget.
Integration owns the append-only ledger and
must disposition actionable results before the related lifecycle advances.

Before delegation, emit `delegation_ready_for_dispatch`. Also emit
`worktree_or_dispatch_setup_failed_before_mutation` for a detached, wrong,
dirty, stale-HEAD, or unbound setup stop, and
`ready_handoff_waiting_for_owner` when a clean accepted handoff has no assigned
review/intake owner or exact serialized dependency in the same management turn.
One source event with multiple triggers requires one receipt for every trigger.
The optimizer never reviews its own observer route: Integration performs the
policy's non-recursive frontier bootstrap checks before dispatch.
