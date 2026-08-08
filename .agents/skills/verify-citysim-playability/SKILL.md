---
name: verify-citysim-playability
description: "Verify CitySim player outcomes on `codex/citysim-playtest-quality` through critical journeys, golden cities, hands-on defect reproduction, visual evidence, accessibility checks, performance captures, and actionable balance reports. Use for every prompt in the playtest-quality worktree and whenever a PLAY task needs independent acceptance evidence or a claim that the game is playable must be tested."
---

# Verify CitySim Playability

Prove what a fresh player can actually understand and accomplish. Quality evidence must be independent of the feature author's confidence.

## Orient before every task

1. Run `pwd`, `git branch --show-current`, and `git status --short --branch`.
2. Require `codex/citysim-playtest-quality` for mutations, or the named clean
   successor `codex/citysim-playtest-single-angle` when an exact active claim
   and validated Integration route bind it.
3. Read and follow [the shared model-routing and cost-control contract](../operate-citysim-integration/references/model-routing-and-cost-control.md). Complete the applicable authority read for a new thread or claim, changed authority/skill/reference hash, routing mismatch, context loss, or stale compact packet. On an unchanged same-thread continuation, verify every recorded hash and Git revision before consuming the compact lane-context packet.
4. When a complete read is required, read `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`, this skill, the claimed `PLAY-*` task, its acceptance criteria, linked requirements, candidate completion record, and required conditional references completely.
5. Confirm the exact candidate commit/build. Preserve unrelated work.

## Own verification, not the feature

- Own critical journeys, golden cities, fixtures, harnesses, evidence, audits, and reproducible defect reports.
- Remain read-mostly against feature code. Add focused reproduction tests when useful; return fixes to the owning lane.
- Test causality, pacing, discoverability, recovery, dominant strategies, false feedback, dead time, and fatigue.
- Verify default/compact, pointer/keyboard, Full Keyboard Access/VoiceOver, Reduce Motion, save/load, and performance when relevant.
- Do not advance requirements or declare acceptance; integration owns disposition.

## Build an evidence contract

For each candidate define:

- starting fixture and build commit;
- player goal and allowed knowledge;
- steps that must remain discoverable without coaching;
- decision, consequence, diagnosis, recovery, and completion signals;
- failure and stop conditions;
- quantitative captures and proof paths;
- expected accessibility and compact behavior.

Do not rewrite the journey after seeing the result merely to make the candidate pass.

## Route preparation and final acceptance separately

- `LUNA_MECHANICAL` owns candidate-neutral preregistration, fixture/camera preparation, scripted checks, measurements, literal-scale review packets, and reproducible defect packets. `LUNA_IMPLEMENTATION` is legal only for a bounded claimed QA harness or fixture implementation. `LUNA_LOCAL_DEBUG` may repair only a reproducible lane-local harness defect with frozen inputs and stops after two unsuccessful attempts.
- One independent `FRONTIER_AUTHORITY` task owns the exact-candidate fresh-player real-app journey and `APPROVE`/`RETURN` judgment. It cannot be the feature-author task.
- A substantial `PLAY-*` task must arrive as a frontier authority packet, disjoint Luna preparation packet(s), and the independent frontier acceptance packet. Stop on every escalation trigger in the shared contract.
- Luna runs only preregistered focused checks. Consume an exact candidate-bound aggregate/full-suite result when current; rerun the full suite only for missing, stale, mismatched evidence or a journey-exposed defect requiring reproduction.

## Candidate-neutral preparation

Before preregistration, source review, fixture/camera preparation, or baseline rehearsal, read
[references/preregistration-and-source-review.md](references/preregistration-and-source-review.md)
completely.

## Exact-candidate real-app gate

Before admitting or operating a candidate, read
[references/exact-candidate-real-app-gate.md](references/exact-candidate-real-app-gate.md)
completely. This gate is frontier-only and serialized.

## Report

Classify each acceptance criterion as passed, failed, partial, not reproduced, or blocked. Give defects a reproducible start state, exact steps, expected/actual outcome, severity, owner lane, and evidence. Avoid implementation prescriptions unless needed to explain a violated contract.

## Commit intelligently

- Run `git status --short` before staging and preserve unrelated work.
- Stage only explicit claimed fixtures, tests, harnesses, and evidence records; never use `git add -A` in a dirty checkout.
- Inspect the staged diff and proof provenance, run `git diff --cached --check`, and commit one coherent verification outcome at a time.
- Use `PLAY-###: Imperative outcome` messages. Mark incomplete evidence preservation as a checkpoint with limitations.
- Commit after each reproducible journey/evidence milestone, before handoff, task switches, or ending a turn with completed work.
- Keep the lane clean between checkpoints. Finished-but-uncommitted work is invalid; workers never push or merge.

## Completion

Commit only fixtures, tests, harnesses, and evidence records on the quality branch; do not push or merge. A test run without a real player journey cannot prove playability, and a visually polished session with unclear cause and effect does not pass.
