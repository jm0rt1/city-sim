---
name: evolve-citysim-simulation
description: "Evolve CitySim's deterministic simulation platform on `codex/citysim-simulation-platform`, including commands and ticks, snapshots, stable identities, saves, migrations, replay, recovery, performance, diagnostics, package boundaries, and clean-build infrastructure. Use for every prompt in the simulation-platform worktree and whenever a PLAY task changes shared runtime, persistence, or production contracts."
---

# Evolve CitySim Simulation Platform

Build the trustworthy foundation on which gameplay, rendering, UI, saves, and evidence agree.

## Orient before every task

1. Run `pwd`, `git branch --show-current`, and `git status --short --branch`.
2. Require `codex/citysim-simulation-platform` for mutations.
3. Read and follow [the shared model-routing and cost-control contract](../operate-citysim-integration/references/model-routing-and-cost-control.md). Complete the applicable authority read for a new thread or claim, changed authority/skill/reference hash, routing mismatch, context loss, or stale compact packet. On an unchanged same-thread continuation, verify every recorded hash and Git revision before consuming the compact lane-context packet.
4. When a complete read is required, read `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`, this skill, the claimed `PLAY-*` task, linked technical requirements, ADRs, and save/performance contracts completely.
5. Confirm a platform-lane claim and preserve unrelated work.

## Route work at judgment boundaries

- `LUNA_IMPLEMENTATION` implements replay, diagnostics, profiling, fixtures, and frozen-schema slices; `LUNA_MECHANICAL` owns inventories, hashes, fixture generation, focused measurements, and packet assembly; `LUNA_LOCAL_DEBUG` may repair only a reproducible lane-local defect with frozen inputs and stops after two unsuccessful attempts.
- `FRONTIER_AUTHORITY` owns schemas, snapshot contracts, migrations, persistence decisions, subtle nondeterminism, shared-contract decisions, and final acceptance.
- A substantial `PLAY-*` task must arrive as a frontier authority packet, one or more disjoint Luna execution packets, and an independent frontier acceptance packet. Stop on every escalation trigger in the shared contract.
- Luna runs only the focused owner and affected gates in its validated `modelRoute`. The lane coordinator aggregates coherent packets; the full Swift suite, staged build, and real-app journey run once against the exact aggregate/integrated candidate unless identity changes or evidence is stale.
- A focused `swift test` result is complete only when its combined output passes
  the shared model-route validator's `--swift-test-log` check. `Build complete!`
  alone is compilation-only; capture a result-bearing run without source edits
  before handoff.

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

## Execute and prove conditionally

For implementation, focused evidence, and aggregate acceptance requirements,
read [references/simulation-execution-and-evidence.md](references/simulation-execution-and-evidence.md).

## Commit intelligently

- Run `git status --short` before staging and preserve unrelated work.
- Stage only explicit claimed platform, contract, fixture, and test paths; never use `git add -A` in a dirty checkout.
- Inspect the staged diff, run `git diff --cached --check`, and commit one coherent invariant, migration, or runtime contract at a time.
- Use `PLAY-###: Imperative outcome` messages. Mark incomplete preservation commits as checkpoints with validation gaps.
- Commit after validated contract/platform milestones, before risky migrations/refactors, handoff, task switches, or ending a turn with completed work.
- Keep the lane clean between checkpoints. Finished-but-uncommitted work is invalid; workers never push or merge.

## Completion

Use the completion requirements in
[references/simulation-execution-and-evidence.md](references/simulation-execution-and-evidence.md).
