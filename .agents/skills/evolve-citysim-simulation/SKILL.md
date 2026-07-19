---
name: evolve-citysim-simulation
description: "Evolve CitySim's deterministic simulation platform on `codex/citysim-simulation-platform`, including commands and ticks, snapshots, stable identities, saves, migrations, replay, recovery, performance, diagnostics, package boundaries, and clean-build infrastructure. Use for every prompt in the simulation-platform worktree and whenever a PLAY task changes shared runtime, persistence, or production contracts."
---

# Evolve CitySim Simulation Platform

Build the trustworthy foundation on which gameplay, rendering, UI, saves, and evidence agree.

## Orient before every task

1. Run `pwd`, `git branch --show-current`, and `git status --short --branch`.
2. Require `codex/citysim-simulation-platform` for mutations.
3. Read `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`, the claimed `PLAY-*` task, linked technical requirements, ADRs, and save/performance contracts.
4. Confirm a platform-lane claim and preserve unrelated work.

## Own runtime trust

- Own deterministic tick/command boundaries, snapshots, identities, persistence, migrations, replay, recovery, diagnostics, profiling, and assigned build infrastructure.
- Keep presentation snapshots immutable and useful to both SwiftUI and SpriteKit.
- Preserve atomic saves, versioning, failure recovery, and historical fixtures.
- Measure mature/pressured workloads rather than empty-city performance.
- Keep platform changes player-outcome driven; architecture is not completion by itself.
- Do not rebalance gameplay, design interface composition, or produce decorative renderer behavior.

## Define the contract

Before editing, record:

- invariant and failure being addressed;
- affected commands, snapshots, saves, or packages;
- backward compatibility and migration behavior;
- deterministic test fixture and state hash;
- CPU, memory, save/load, and file-size budgets as applicable;
- affected lanes and adoption sequence;
- rollback and malformed-input behavior.

Shared contract changes require integration approval before dependent implementations diverge.

## Implement and prove

1. Add deterministic, migration, recovery, malformed-input, or performance tests with the change.
2. Verify repeated runs from the same seed/commands produce the promised state.
3. Verify save/load/undo and renderer/UI snapshot consumers when affected.
4. Run the complete Swift suite, `git diff --check`, and build-script syntax check.
5. Launch the staged app for every runtime change and complete the affected player journey.
6. Record measured performance and save evidence, not estimates.

## Commit intelligently

- Run `git status --short` before staging and preserve unrelated work.
- Stage only explicit claimed platform, contract, fixture, and test paths; never use `git add -A` in a dirty checkout.
- Inspect the staged diff, run `git diff --cached --check`, and commit one coherent invariant, migration, or runtime contract at a time.
- Use `PLAY-###: Imperative outcome` messages. Mark incomplete preservation commits as checkpoints with validation gaps.
- Commit after validated contract/platform milestones, before risky migrations/refactors, handoff, task switches, or ending a turn with completed work.
- Keep the lane clean between checkpoints. Finished-but-uncommitted work is invalid; workers never push or merge.

## Completion

Commit the focused contract and implementation with a completion record containing hashes, fixtures, measurements, compatibility, and adoption notes. Do not push or merge. A technically elegant subsystem that has not survived real app use, recovery, and dependent consumers is incomplete.
