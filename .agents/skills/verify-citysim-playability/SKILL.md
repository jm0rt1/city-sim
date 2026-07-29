---
name: verify-citysim-playability
description: "Verify CitySim player outcomes on `codex/citysim-playtest-quality` through critical journeys, golden cities, hands-on defect reproduction, visual evidence, accessibility checks, performance captures, and actionable balance reports. Use for every prompt in the playtest-quality worktree and whenever a PLAY task needs independent acceptance evidence or a claim that the game is playable must be tested."
---

# Verify CitySim Playability

Prove what a fresh player can actually understand and accomplish. Quality evidence must be independent of the feature author's confidence.

## Orient before every task

1. Run `pwd`, `git branch --show-current`, and `git status --short --branch`.
2. Require `codex/citysim-playtest-quality` for mutations.
3. Read `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`, the claimed `PLAY-*` task, its acceptance criteria, linked requirements, and candidate completion record.
4. Confirm the exact candidate commit/build. Preserve unrelated work.

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

## Preregister before the candidate arrives

When Integration dispatches QA-ahead preparation, freeze the candidate-neutral
acceptance contract while implementation or art production continues:

- exact fixture identifier, version, state hash, and mature-city placement;
- exact camera state, zoom, rotation, focus, and any deterministic scene seed;
- regular and compact window dimensions and the required pointer, keyboard,
  accessibility, and reduced-motion variants;
- allowed fresh-player knowledge, critical journey, rubric, stop conditions,
  capture names, and evidence destinations;
- quantitative visual, interaction, performance, persistence, and accessibility
  thresholds that apply to the claimed player outcome.

Commit the preregistration as its own QA checkpoint before inspecting the final
candidate. It may be exercised against the accepted baseline to prove that the
fixture and harness work, but that rehearsal is not candidate evidence. Do not
encode author hints, hidden shortcuts, expected control locations, or
candidate-specific coaching into the journey. If the candidate legitimately
changes a preregistered contract, preserve the original record and obtain an
Integration-approved revision before testing; never silently relax the rubric
after seeing a result.

For a directional art family, preregister one family-level staged-app gate.
North, East, South, and West cells retain their own source determinism and
geometry evidence, but they do not request separate production acceptance from
QA. QA admits only the atomic renderer candidate containing all four exact
accepted directions. A returned direction may continue independently without
invalidating successful sibling source evidence; the final app journey remains
blocked until the renderer presents a complete 4/4 family.

## Admit one exact candidate

Before the final journey:

1. Record the exact candidate commit and verify its ancestry, clean source
   worktree, and completion record.
2. Build or stage in an isolated candidate-bound checkout and retain the
   source, executable, resource, manifest, and fixture identities needed to
   prove that the operated app is that candidate.
3. Reject or stop on candidate drift, mixed resources, a rebuilt different
   commit, missing 4/4 family inputs, or an author-requested coaching change.
4. Execute one independent final staged-app gate from a fresh app state using
   the preregistered journey. Do not ask the feature or art author for help
   during the journey and do not substitute their screenshots or testimony.

Candidate-neutral fixture checks, camera proof, harness validation, and rubric
review should run ahead in parallel. The final exact-candidate real-app journey
is deliberately serialized and is the only QA production-acceptance gate.

## Execute

1. Run the candidate's automated validation independently.
2. Build and launch the real staged app.
3. Perform the journey without developer shortcuts or hidden state.
4. Capture exact timestamps/steps for confusion, error, dead time, misleading feedback, or failure.
5. Retain real screenshots or disclosed deterministic harness proof.
6. Measure performance on the declared fixture when affected.
7. Repeat critical input/accessibility/layout variants separately.

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
