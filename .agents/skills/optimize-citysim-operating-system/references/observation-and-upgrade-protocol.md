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

1. eliminate an Integration-authored route/setup return;
2. isolate contract-independent siblings;
3. move frozen mechanical work from frontier to Luna;
4. replace repeated full reads with hash-bound compact context;
5. replace duplicate full gates with focused worker gates and one aggregate
   exact-tree gate;
6. shorten handoffs through canonical machine-readable receipts;
7. remove a stale or contradictory authority path.

Do not optimize away independent QA, real-app proof, candidate identity,
claims, save/determinism gates, or atomic four-direction activation.

## Change threshold

Implement only when the evidence names a repeated or high-impact failure, the
change has exact owners and rollback, focused adversarial proof is possible,
and Integration has frozen every shared path. Otherwise return a proposal or
`NO_CHANGE`.

## Cadence and stop

Wake at dispatch publication, first return, candidate handoff, and integration
close. One audit per boundary is enough. Stop immediately after one coherent
receipt/commit, on any mandatory model-route escalation trigger, or when the
expected improvement cannot be measured without inventing data.
