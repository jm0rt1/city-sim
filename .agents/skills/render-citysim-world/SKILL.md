---
name: render-citysim-world
description: "Build and verify CitySim's SpriteKit world on `codex/citysim-world-rendering`: terrain, roads, lots, buildings, props, animation, effects, lighting, overlays, camera, hit testing, placement feedback, deterministic variation, assets, and render performance. Use for every prompt in the world-rendering worktree and whenever a PLAY task changes how simulation truth is presented in the city."
---

# Render CitySim World

Make the city dominant, readable, alive, and truthful. Visual spectacle must improve play rather than obscure state.

## Orient before every task

1. Run `pwd`, `git branch --show-current`, and `git status --short --branch`.
2. Require `codex/citysim-world-rendering` for mutations.
3. Read `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`, the claimed `PLAY-*` task, linked art/technical requirements, and relevant visual plan.
4. Confirm a world-rendering claim and preserve all unrelated work.

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

## Implement and prove

1. Prefer focused renderer components, cached reusable geometry/textures, and incremental tile updates.
2. Add unit/contract coverage for topology, identity, detail levels, hit testing, or state mapping.
3. Run the complete Swift suite and `git diff --check`.
4. Build and operate the real staged app: pan, zoom, inspect, build, reject, select, overlay, undo.
5. Capture default, compact, city, neighborhood, normal, overlay, and interaction proof when affected.
6. Record performance before and after; inspect accumulating nodes/actions during longer play.
7. Disclose when a deterministic harness substitutes for window capture.

## Shared-contract rule

Propose snapshot, store, theme, command, or package changes to integration before implementing them. Renderer convenience does not justify duplicated durable state.

## Commit intelligently

- Run `git status --short` before staging and preserve unrelated work.
- Stage only explicit claimed renderer, asset, test, and proof paths; never use `git add -A` in a dirty checkout.
- Inspect the staged diff and asset provenance, run `git diff --cached --check`, and commit one coherent visual/interaction outcome at a time.
- Use `PLAY-###: Imperative outcome` messages. Mark incomplete preservation commits as checkpoints with validation gaps.
- Commit after validated renderer milestones, before risky refactors, handoff, task switches, or ending a turn with completed work.
- Keep the lane clean between checkpoints. Finished-but-uncommitted work is invalid; workers never push or merge.

## Completion

Commit only the claimed slice and write its completion record with proof and budgets. Do not push or merge. Attractive art that misstates the simulation, harms input, or lacks live proof is incomplete.
