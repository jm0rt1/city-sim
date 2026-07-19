---
name: build-citysim-gameplay-loop
description: "Build consequential CitySim gameplay on `codex/citysim-gameplay-loop`, including economy pressure, demand, population, employment, happiness, services, objectives, incidents, progression, recovery, and scenario balance. Use for every prompt in the gameplay-loop worktree and whenever a PLAY task changes simulation rules or the player's build-diagnose-adjust loop."
---

# Build CitySim Gameplay Loop

Make CitySim worth playing: every important choice must create measurable, visible, understandable consequences and a plausible recovery path.

## Orient before every task

1. Run `pwd`, `git branch --show-current`, and `git status --short --branch`.
2. Require `codex/citysim-gameplay-loop` for mutations.
3. Read `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`, the claimed `PLAY-*` task, and linked requirements/design sources.
4. Confirm a gameplay-lane claim exists and record the current base commit.
5. Preserve unrelated changes and legacy Python code.

## Own the gameplay outcome

- Own economy, development, population, employment, happiness, services, objectives, incidents, progression, recovery, win/fail states, and balance fixtures.
- Keep authoritative rules in models/services, not SwiftUI or SpriteKit.
- Expose typed analytics or snapshot data so UI and rendering can explain real causes.
- Keep deterministic inputs and save compatibility unless an approved contract task says otherwise.
- Do not redesign HUD composition, renderer art, persistence formats, or platform architecture.

## Work from a playable contract

Before editing, state:

- current reproducible player problem;
- decision the player should face;
- consequence and feedback timing;
- recovery or counterplay;
- code/data owner;
- scenario and acceptance evidence;
- save, accessibility, UI, renderer, and performance effects.

Split work that cannot reach an integrated player outcome within one iteration.

## Implement and prove

1. Add focused deterministic tests and scenario fixtures with the behavior.
2. Test early, pressured, recovery, and established states; do not tune one save.
3. Verify conservation, caps, denominators, time units, and failure behavior.
4. Run the complete Swift suite and `git diff --check`.
5. Build and operate the staged app through the claimed loop.
6. Confirm HUD and world feedback agree with simulation truth.
7. Capture hands-on evidence of decision, consequence, diagnosis, and recovery.

## Shared-contract rule

If blocked by a shared store, snapshot, save, command, or rendering contract, write the smallest interface proposal and affected-lane risks in the completion record. Do not change integration-controlled contracts silently.

## Commit intelligently

- Run `git status --short` before staging and preserve unrelated work.
- Stage only explicit files belonging to the claimed task; never use `git add -A` in a dirty checkout.
- Inspect the staged diff, run `git diff --cached --check`, and commit one coherent gameplay outcome at a time.
- Use `PLAY-###: Imperative outcome` messages. Use named checkpoint commits only for incomplete recoverable work and disclose unrun/failing validation.
- Commit after each validated scenario/outcome, before risky refactors, handoff, task switches, or ending a turn with completed work.
- Keep the lane clean between checkpoints. Finished-but-uncommitted work is invalid; workers never push or merge.

## Completion

Commit focused work on the lane branch and write the required completion record with exact commands, results, scenario outcomes, proof, and limitations. Do not push or merge. A balanced spreadsheet without an understandable play session is incomplete.
