---
name: render-citysim-world
description: "Build and verify CitySim's SpriteKit world on `codex/citysim-world-rendering`: terrain, roads, lots, buildings, props, animation, effects, lighting, overlays, camera, hit testing, placement feedback, deterministic variation, assets, render performance, and intake-ahead preparation for governed directional art families. Use for every prompt in the world-rendering worktree and whenever a PLAY task changes how simulation truth is presented in the city or prepares exact source art for atomic renderer ingestion."
---

# Render CitySim World

Make the city dominant, readable, alive, and truthful. Visual spectacle must improve play rather than obscure state.

## Orient before every task

1. Run `pwd`, `git branch --show-current`, and `git status --short --branch`.
2. Require `codex/citysim-world-rendering` for mutations.
3. Read and follow [the shared model-routing and cost-control contract](../operate-citysim-integration/references/model-routing-and-cost-control.md). Complete the applicable authority read for a new thread or claim, changed authority/skill/reference hash, routing mismatch, context loss, or stale compact packet. On an unchanged same-thread continuation, verify every recorded hash and Git revision before consuming the compact lane-context packet.
4. When a complete read is required, read `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`, this skill, the claimed `PLAY-*` task, linked art/technical requirements, relevant visual plan, and required conditional references completely.
5. Confirm a world-rendering claim and preserve all unrelated work.

## Own the world presentation

- Own `Rendering/`, native world assets, camera behavior, world hit testing, in-world feedback, render fixtures, and renderer telemetry.
- Consume model/store truth through typed state; never invent gameplay rules in SpriteKit nodes.
- Keep deterministic variation stable across relaunch and save/load.
- Preserve selection, placement, roads, warnings, and overlays at every camera detail level.
- Honor Reduce Motion, non-color cues, compact viewport, and performance tiers.
- Do not rebalance systems, redesign general HUD composition, or change save schemas.

## Define the visual contract

For each task record:

- state being communicated;
- required camera distances and window classes;
- normal, selected, placement, warning, overlay, and reduced-motion states;
- deterministic seed or asset identity;
- node/draw/frame/memory budget;
- real-scene proof frames;
- interaction and accessibility consequences.

## Route work at judgment boundaries

- `LUNA_IMPLEMENTATION` owns frozen intake mapping, quarantine, LOD/socket/pivot tests, fixtures, resource integrity, and bounded approved components; `LUNA_MECHANICAL` owns inventories, hashes, manifests, focused validation, and packet assembly; `LUNA_LOCAL_DEBUG` may repair only reproducible lane-local defects with frozen inputs and stops after two unsuccessful attempts.
- `FRONTIER_AUTHORITY` owns visual architecture, composition, difficult performance tradeoffs, mixed-fidelity judgment, atomic assembly acceptance, shared-contract decisions, and final subjective acceptance.
- A substantial `PLAY-*` task must arrive as a frontier authority packet, one or more disjoint Luna execution packets, and an independent frontier acceptance packet. Stop on every escalation trigger in the shared contract.
- Luna runs only focused owner/affected gates. Direction packets are quarantined independently; the full Swift suite, staged build, and resource smoke run once at exact 4/4 assembly, followed by one independent frontier real-app gate.

## Directional intake procedure

Before intake planning, quarantine, four-direction assembly, or a directional return, read
[references/directional-art-intake.md](references/directional-art-intake.md)
completely.

## Ordinary renderer feature evidence

For a non-directional renderer feature, read
[references/renderer-feature-evidence.md](references/renderer-feature-evidence.md)
before implementation, validation, or completion.

## Shared-contract rule

Propose snapshot, store, theme, command, or package changes to integration before implementing them. Renderer convenience does not justify duplicated durable state.

Serialize genuine shared authorities: family-contract publication, shared art-toolchain changes, shipping atlas or manifest mutation, production selection, final exact-candidate QA, integration, and push. Parallel intake preparation and direction quarantine never authorize those actions.

## Commit intelligently

- Run `git status --short` before staging and preserve unrelated work.
- Stage only explicit claimed renderer, asset, test, and proof paths; never use `git add -A` in a dirty checkout.
- Inspect the staged diff and asset provenance, run `git diff --cached --check`, and commit one coherent visual/interaction outcome at a time.
- Use `PLAY-###: Imperative outcome` messages. Mark incomplete preservation commits as checkpoints with validation gaps.
- Commit after validated renderer milestones, before risky refactors, handoff, task switches, or ending a turn with completed work.
- Keep the lane clean between checkpoints. Finished-but-uncommitted work is invalid; workers never push or merge.

## Completion

Commit only the claimed slice and write its completion record with proof and budgets. Do not push or merge. Attractive art that misstates the simulation, harms input, or lacks live proof is incomplete.
