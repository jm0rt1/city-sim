---
name: optimize-citysim-operating-system
description: "Operate CitySim's low-overhead intelligence optimization lane on codex/citysim-os-optimization: observe receipts and outcomes, detect avoidable context/validation/coordination cost, implement only frozen-path routing or skill improvements, and return evidence without weakening governance or product quality."
---

# Optimize CitySim Operating System

Improve the work system only when evidence shows the change should produce
better accepted CitySim outcomes per unit of frontier judgment, elapsed time,
or context cost. `NO_CHANGE` is a successful result when no material waste is
found.

## Orient and bind authority

1. Run `pwd`, `git branch --show-current`, `git status --short --branch`,
   `git worktree list`, and `git log -1 --oneline --decorate`.
2. Require `codex/citysim-os-optimization`; stop on detached or unexpected
   routing, dirt outside the claim, or an unbound worktree path.
3. Read the shared model-routing contract and apply its full-read versus
   compact-continuation rule. On a complete read, consume the operating system,
   this skill, PLAY-089, the exact dispatch receipt, and
   [the observation protocol](references/observation-and-upgrade-protocol.md).
4. Resolve every SHA with Git. Verify the exact authority, claim, route hash,
   allowed paths, focused/full gate owners, escalation triggers, reviewer, and
   stop condition before mutation.
5. State the lane, route, observation boundary, dirt risk, and bounded outcome.

## Default to cheap observation

- Use `LUNA_MECHANICAL / gpt-5.6-luna / medium` for inventories, timings,
  receipt joins, byte/hash counts, idle-gap detection, and `NO_CHANGE` audits.
- Use `LUNA_IMPLEMENTATION / gpt-5.6-luna / high` only for an Integration-frozen
  design with exact shared paths and focused tests.
- Use `LUNA_LOCAL_DEBUG / gpt-5.6-luna / max` only for a reproducible local
  defect with frozen inputs; escalate after two unsuccessful repairs.
- Frontier Integration owns policy, architecture, shared authority, semantic
  conflict, subjective quality, candidate acceptance, final QA, and push.

## Work exception-first

At each unique event in
[the triggered operating-review policy](references/triggered-operating-review-policy.json):

1. Read only the exact receipts and compact context needed for that boundary.
2. Separate worker defects from Integration-authored routing/setup defects.
3. Quantify repeated context, duplicate validation, idle waits, route returns,
   unbounded handoffs, false-green worker PASS results, and frontier work that
   could be frozen Luna execution.
4. Preserve non-negotiable claims, exact identity, shared-contract control,
   deterministic/save compatibility, staged-app proof, independent QA,
   intelligent commits, atomic art activation, and clean publication.
5. Return exactly one policy decision: `NO_CHANGE`, `PROPOSE`, `REFILL`,
   `RETURN`, or `ESCALATE`. A claimed implementation commit is allowed only
   when the frozen route explicitly owns that bounded mutation. Never open
   speculative cleanup.

The default review is one `LUNA_MECHANICAL / gpt-5.6-luna / medium` turn using
hash-bound compact context capped by the policy. A turn may accept at most eight
queued event keys and 32 KiB total compact context, but emits one independently
validated receipt per key. Freeze branch/HEAD first. Immediate triggers close
before worker synchronization or mutation; authority reading may proceed concurrently. Reuse the
canonical visible optimizer task instead of creating one task per event. Do not poll tasks, fan reviews
out into more reviews, or run product builds, full suites, DCC, staged apps, or
real-app QA merely to observe operations. A trigger is deduplicated by authority,
task, route, event type, and candidate/result commit. Unknown timing, token, or
pricing values stay `null`.

Review the management system, not just worker output. In addition to the normal
dispatch/return/acceptance boundaries, emit one compact receipt when:

- a delegation is ready to send, proving the lowest legal route, frozen
  judgment boundary, exact claim/paths, distinct gate owners, independent
  reviewer, and useful-concurrency delta before mutation;
- a frontier route is assigned, proving why authority or judgment could not be
  frozen into a Luna packet;
- a task completes or stops, proving its durable result or exact blocker and
  naming the next dependency/refill without rerunning its gates;
- useful concurrency falls below the governed floor, excluding protected active
  operations before demanding a refill;
- unchanged authority/claim/skill hashes are loaded in full again instead of a
  compact continuation packet;
- a delegation acknowledgement fails to bind the exact receipt, route, claim,
  and allowed paths; or
- a full gate is requested again, proving whether the exact candidate changed or
  prior evidence actually became stale.
- a worktree, branch, HEAD, cleanliness, or dispatch setup fails before
  mutation; or
- a ready candidate or asset handoff has no assigned review/intake owner,
  refill, or exact serialized dependency.

Validate every durable review receipt with
`scripts/validate_operating_review_receipt_v1.py` using the repo root and the
mandatory Integration-owned ledger at
`docs/production/evidence/PLAY-089/OPERATING-REVIEW-EVENT-LEDGER-V1.json`.
Input paths and hashes must resolve to repository bytes. The observer reports the
defect and one bounded next action; only Integration changes routes, refills a
lane, escalates judgment, or mutates shared authority.

If one Integration event envelope declares multiple triggers, emit one receipt
for each trigger. Missing coverage is a return, not an implicit `NO_CHANGE`.
The observer never edits the shared ledger; Integration records accepted
receipts and dispositions when it integrates the optimizer packet.

Never review this lane's own observer dispatch. Integration bootstraps an
optimizer route with full schema-2 validation, exact Git/claim/HEAD/path
binding, one independent static route review, and zero worker mutation. This
non-recursive bootstrap is the only delegation-ready exception.

For an idle-lane or no-progress trigger, first distinguish a protected active
operation (exact-candidate QA, DCC render, frozen proof, coherent commit, or
long-running focused gate) from avoidable inactivity. If useful disjoint work is
ready, propose or request a same-turn refill. If it is genuinely serialized,
record the exact dependency and return `NO_CHANGE`. Never wake a task merely to
ask for status when the compact thread snapshot already answers the question.

Treat a false-green as a first-class cost defect: a task reports PASS while the
claimed behavior was never executed, its artifact is absent/undecodable, or
independent review finds an immediate runtime failure. Prefer strengthening the
proof boundary before changing models or adding more retries.

## Commit and hand off

Stage explicit claimed paths, inspect cached diff/check/stat, run focused tests,
and commit each coherent result as `PLAY-089: Imperative outcome`. Never push,
integrate, pin, edit product surfaces, or claim cost savings without a measured
before/after basis. Report exact files, commit, validation, measured effect,
limitations, and the next event boundary.

Validate the shared trigger policy with:

`PYTHONDONTWRITEBYTECODE=1 python3 .agents/skills/optimize-citysim-operating-system/scripts/test_validate_triggered_operating_review_policy_v1.py`

Validate durable review receipts with:

`PYTHONDONTWRITEBYTECODE=1 python3 .agents/skills/optimize-citysim-operating-system/scripts/test_validate_operating_review_receipt_v1.py`

Validate batched event-key coverage with:

`PYTHONDONTWRITEBYTECODE=1 python3 .agents/skills/optimize-citysim-operating-system/scripts/test_validate_operating_review_batch_v1.py`

When Integration-published immutable inputs are newer than the worker base,
keep outputs on the worker branch and pass the clean Integration checkout as
`--authority-root`. `--repo-root` remains the exact worker/output Git root.
Never copy authority files into a worker branch or weaken their hash binding.
