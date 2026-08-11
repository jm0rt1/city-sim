# Observation and Upgrade Protocol

Read this reference for every new PLAY-089 route and whenever the observation
boundary, route schema, claim, or authority changes.

## Outcome lease boundary

A validated schema-2 claim, route, and selected dispatch are one outcome lease
for an exact branch/HEAD/status contract and reversible local work with explicit
allowed paths, declared focused proof, and no product-semantics,
shared-contract/schema, irreversible/external-action, candidate-acceptance, or
release judgment. Frozen/protected user dirt is allowed only outside the claim
and must remain unchanged. The lease covers inspection,
allowed-path edits, focused proof, explicit staging, and one coherent commit.
It does not require separate ACK-only, static-review, execution-release,
receipt-review, or routine optimizer-observation rounds.

Allowed paths are a maximum mutation boundary, not a touched-file minimum.
Never manufacture a no-op edit to satisfy a predicted path count. Fewer changed
paths are valid when the bounded deliverable and focused proof pass and every
changed path remains in the allowlist; any extra or unexpected path escalates.
Stage and prove the exact paths actually changed.

Integration may validate and dispatch eligible routine work directly. Manual
CTO review remains mandatory at the excluded judgment boundaries. The outcome
lease never grants acceptance, push, release, or self-review authority.

A validated temp-local route and selected dispatch are sufficient for eligible
reversible local work. Durable publication is required when the carrier is a
durable governance/product artifact or crosses a judgment boundary.

For sandbox, permission, or tool-transport failure before product execution and
before mutation, allow one identical retry without a fresh carrier. No changed
command or second retry is authorized.

A failed mechanical implementation action may be corrected once inside the
same outcome lease only after an exact post-failure audit proves zero
out-of-allowlist mutation, unchanged intended outcome and paths, no replay of
any completed product or proof action, and no semantics or data nondeterminism.
This corrected mechanical action requires no fresh carrier and is independent
of both the identical infrastructure retry and the focused proof budget. A
second correction or any failed audit condition escalates.

An eligible implementation may also use one bounded local repair loop: at most
two focused proof attempts total, with edits confined to the original
allowlist. The first failure may inform one repair without a fresh carrier, ACK,
or release. A second failure, scope expansion, semantics ambiguity, or
unexpected path escalates. This is distinct from the mutation-free
infrastructure retry above.

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
7. remove redundant handoff rounds through one outcome lease;
8. remove a stale or contradictory authority path.

Do not optimize away independent QA, real-app proof, candidate identity,
claims, save/determinism gates, or atomic four-direction activation.

## Change threshold

Implement only when the evidence names a repeated or high-impact failure, the
change has exact owners and rollback, focused adversarial proof is possible,
and Integration has frozen every shared path. Otherwise return a proposal or
`NO_CHANGE`.

## Exception-triggered cadence and stop

Use `triggered-operating-review-policy.json` as the machine-readable authority.
Eligible routine delegations produce no optimizer event or receipt. Review once
per unique exception key at:

- every frontier worker-route assignment;
- two consecutive bounded snapshots without durable/tool progress, excluding a
  declared protected active operation;
- first focused-gate failure, first return, and second unsuccessful repair;
- candidate handoff, exact-candidate QA start, and integration close;
- a useful lane becoming idle while disjoint claimed work is ready;
- useful active concurrency falling below the governed floor after protected
  operations are excluded;
- a repeated full context load while authority, claim, skill, and reference
  hashes are unchanged;
- duplicate full-gate requests, route/model mismatch, claim/baseline mismatch,
  or any setup defect before mutation.

Historical delegation/acknowledgement triggers remain parseable, but they are
not emitted for an eligible outcome lease. Use them only for an explicitly
assigned ineligible-boundary audit or historical evidence preservation.

The observer uses Luna mechanical/medium and one compact receipt of no more than
the per-event policy byte cap. One canonical observer turn may batch at most
eight event keys within the aggregate cap, but returns one receipt per key.
Freeze branch/HEAD first. Immediate events close before worker synchronization
or mutation; authority reading may overlap the review. It does not poll tasks or spawn more reviews. It may return
`NO_CHANGE`, `REFILL`, `RETURN`, `ESCALATE`, or one bounded proposal. Only
Integration executes a refill, return, escalation, shared change, acceptance,
integration, or push. Stop immediately after one exception receipt/commit, on any
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

Do not emit `delegation_ready_for_dispatch` for eligible routine work. Emit
`worktree_or_dispatch_setup_failed_before_mutation` for a detached, wrong,
dirty, stale-HEAD, or unbound setup stop, and
`ready_handoff_waiting_for_owner` when a clean accepted handoff has no assigned
review/intake owner or exact serialized dependency in the same management turn.
One source event with multiple triggers requires one receipt for every trigger.
The optimizer never reviews its own observer route: Integration performs the
policy's non-recursive frontier bootstrap checks before dispatch.

When repeated waste is already proven and exact control-plane mutation is
authorized, implement the rule repair directly with focused static proof. Do
not create another observer loop first.

Keep detailed evidence in the task. Upward updates contain only done, blocker,
owner, next, and deadline confidence unless a hash or command ledger changes a
decision. In deadline mode, freeze optional scope, maintain one critical path,
exclude optional slices at cutoff, and keep aggregate build and independent QA
moving. Use exact titles from each Obsidian agent note, permit documented
direct-report coordination for routine work, and run full aggregate/build/
real-app QA once per changed candidate.
