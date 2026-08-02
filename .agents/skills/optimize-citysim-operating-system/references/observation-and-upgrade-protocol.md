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
- two consecutive bounded snapshots without durable/tool progress, excluding a
  declared protected active operation;
- first focused-gate failure, first return, and second unsuccessful repair;
- candidate handoff, exact-candidate QA start, and integration close;
- a useful lane becoming idle while disjoint claimed work is ready;
- duplicate full-gate requests, route/model mismatch, or claim/baseline mismatch.

The observer uses Luna mechanical/medium and compact receipts. It may return
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
