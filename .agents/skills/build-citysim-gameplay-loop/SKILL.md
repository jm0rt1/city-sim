---
name: build-citysim-gameplay-loop
description: "Build consequential CitySim gameplay on `codex/citysim-gameplay-loop`, including economy pressure, demand, population, employment, happiness, services, objectives, incidents, progression, recovery, and scenario balance. Use for every prompt in the gameplay-loop worktree and whenever a PLAY task changes simulation rules or the player's build-diagnose-adjust loop."
---

# Build CitySim Gameplay Loop

Make CitySim worth playing: every important choice must create measurable, visible, understandable consequences and a plausible recovery path.

## Orient before every task

1. Run `pwd`, `git branch --show-current`, and `git status --short --branch`.
2. Require `codex/citysim-gameplay-loop` for mutations.
3. Read and follow [the shared model-routing and cost-control contract](../operate-citysim-integration/references/model-routing-and-cost-control.md). Complete the applicable authority read for a new thread or claim, changed authority/skill/reference hash, routing mismatch, context loss, or stale compact packet. On an unchanged same-thread continuation, verify every recorded hash and Git revision before consuming the compact lane-context packet.
4. When a complete read is required, read `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`, this skill, the claimed `PLAY-*` task, and linked requirements/design sources completely.
5. Confirm a gameplay-lane claim exists and record the current base commit.
6. Preserve unrelated changes and legacy Python code.

## Route work at judgment boundaries

- `LUNA_IMPLEMENTATION` implements frozen rule slices, fixtures, analytics, and deterministic tests; `LUNA_MECHANICAL` may build inventories, fixtures, receipts, and focused evidence; `LUNA_LOCAL_DEBUG` may repair only a reproducible lane-local defect with frozen inputs and stops after two unsuccessful attempts.
- `FRONTIER_AUTHORITY` owns tradeoff design, pacing, economy balance, recovery quality, cross-system tuning, shared-contract decisions, and final subjective acceptance.
- A substantial `PLAY-*` task must arrive as a frontier authority packet, one or more disjoint Luna execution packets, and an independent frontier acceptance packet. Stop on every escalation trigger in the shared contract.
- Luna runs only the focused owner and affected gates in its validated `modelRoute`. The lane coordinator aggregates coherent packets; the full Swift suite, staged build, and real-app journey run once against the exact aggregate/integrated candidate unless identity changes or evidence is stale.
- A focused `swift test` result is complete only when its combined output passes
  the shared model-route validator's `--swift-test-log` check. `Build complete!`
  alone is compilation-only; capture a result-bearing run without source edits
  before handoff.

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

## Execute and prove conditionally

For implementation, focused evidence, and aggregate acceptance requirements,
read [references/gameplay-execution-and-evidence.md](references/gameplay-execution-and-evidence.md).

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

Use the completion requirements in
[references/gameplay-execution-and-evidence.md](references/gameplay-execution-and-evidence.md).
