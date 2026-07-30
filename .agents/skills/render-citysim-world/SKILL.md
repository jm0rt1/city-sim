---
name: render-citysim-world
description: "Build and verify CitySim's SpriteKit world on `codex/citysim-world-rendering`: terrain, roads, lots, buildings, props, animation, effects, lighting, overlays, camera, hit testing, placement feedback, deterministic variation, assets, render performance, and intake-ahead preparation for governed directional art families. Use for every prompt in the world-rendering worktree and whenever a PLAY task changes how simulation truth is presented in the city or prepares exact source art for atomic renderer ingestion."
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

## Run intake ahead of final pixels

Begin non-shipping renderer preparation as soon as Integration publishes an immutable family contract and a renderer intake claim. Do not wait for all four directional sources when contract-independent work is available.

1. Freeze the exact family identity, contract hash, expected North/East/South/West source keys, scale, camera, footprint, pivot, sockets, frontage, light, shadow, palette, LOD sizes, and deterministic selection rules. Stop rather than inventing a missing value or editing the family contract locally.
2. Prepare claimed quarantine mapping, logical atlas-slot reservations, LOD validation, pivot/socket/frontage tests, alias and transformed-sibling rejection, fallback rejection, fixture placement, and staged-camera acceptance states before final pixels arrive. Keep these changes non-shipping; shared atlas pages, production manifests, package topology, and production selection remain serialized Integration-controlled mutations.
   Record these reservations in a renderer-owned intake plan keyed by the exact
   family contract and expected direction IDs so the fourth direction triggers
   assembly immediately rather than entering an undefined queue.
3. Quarantine each Integration-admitted direction independently in a task-owned quarantine. Consume the exact Integration source-admission receipt; never treat a worker return, `source_candidate`, or worker-authored readiness boolean as admission authority. Bind its exact source commit and decoded-pixel hashes, then validate provenance, semantic direction, unique geometry, registration, alpha/chroma/padding, every LOD, deterministic reruns, and absence of mirroring, rotation, sibling aliasing, or fallback substitution. Record success as renderer quarantine acceptance, never source admission, QA, or production acceptance.
4. Preserve a passing direction while returning only a failing direction to its source cell. Never make East wait for South or invalidate North because West failed. Emit one task-owned, versioned quarantine packet per direction with the source handoff schema/hash, exact source commit, decoded hashes, validation result, and disposition. Integration alone updates the shared batch ledger with columns for North, East, South, West, renderer preparation, and QA preparation. Renderer owns only its claimed quarantine/intake paths and never edits World Art source roots.
5. Do not expose a quarantined source to normal runtime lookup, fixture fallback, or production selection. A family is activatable only when the exact contract-bound North/East/South/West packets are all Integration-admitted and independently Renderer-quarantined, and Integration authorizes the shipping mutation.
6. When the fourth exact Integration-admitted direction passes Renderer quarantine, immediately assemble the frozen 4/4 set as one atomic renderer candidate and run source-to-pack identity plus resource-integrity checks. Stage the real app through the Integration-authorized candidate-only resource path. If staging would require an unapproved shared shipping atlas or manifest mutation, stop and request that authority. Do not silently substitute a newer source, nearby baseline, or partially accepted family.

Treat the transition to `4of4_ready` as an immediate work trigger. Begin atomic
assembly in the same acknowledged worker turn; if assembly cannot start, emit
a blocking receipt naming the exact missing Integration authority or
shared-surface decision rather than entering an undefined queue.

The same Integration receipt that records the fourth quarantine must bind the
atomic assembly manifest and an acknowledged batch-local Renderer assignment.
Do not let unrelated renderer feature work count as the family assembler. A
completed 4/4 assembly must return one exact candidate receipt binding the
input ledger/manifest, product commit, all source/LOD/pack/runtime hashes,
catalog/atlas/manifest hashes, two-build identity, full-suite result, build
verification, and non-interactive resource smoke.

A worker-authored source packet is an independent-review candidate, not
`integration_admitted` authority. Before marking a direction renderer-quarantined,
require the exact Integration source-admission receipt that binds the packet,
content commit, semantic-validator result, and independent technical plus
literal-scale dispositions. Intake harness preparation and focused
candidate inspection may run before that receipt, but normal runtime lookup,
shipping mutation, and quarantine acceptance may not.

At direction-local intake, compare the candidate against the complete
Integration-published accepted-master set and every sibling packet already
admitted for this batch. Do not claim proof against a sibling that has not yet
arrived. At the exact 4/4 join, rerun complete North/East/South/West source,
LOD, geometry, and D4 transform uniqueness across the frozen set. Parallel
direction checks write only direction-exclusive receipts or temporary roots;
one Renderer assembler owns common candidate and commit surfaces.

## Use tiered intake gates

Keep per-direction intake fast and independent:

- On each direction arrival, run only the focused provenance, identity,
  registration, alpha/chroma/padding, LOD, transform-rejection, and quarantine
  tests needed for that packet.
- Do not rerun the full Swift suite or staged app for every isolated direction.
- At exact 4/4, run resource integrity, source-to-pack identity, the complete
  Swift suite, build verification, and a non-interactive launch/resource smoke.
  Renderer may retain technical render-fixture and telemetry captures, but must
  label them non-acceptance evidence and must not perform the player-facing
  acceptance journey reserved for independent QA.
- Hand that exact renderer candidate SHA to one independent QA lane for the
  single final camera, layout, interaction, accessibility, performance, and
  visual acceptance gate. A newer rebuild or nearby commit is a different
  candidate.

When multiple direction packets arrive together, run their focused quarantine
validations concurrently in direction-exclusive input and evidence
directories. One renderer-owned writer may change the common intake harness;
direction jobs consume that frozen harness and may not edit it. Join the
results only after every job completes, preserve passing directions, and
return failing directions independently. Atomic 4/4 assembly remains a
separate serialized mutation after all four exact packet identities pass.

The Renderer row in Integration's shared ledger may advance only through
`intake_preparing → intake_ready → quarantining → 4of4_assembled`. Renderer
reports its task-owned evidence and proposed state; Integration remains the
single writer that records the transition. A worker packet can trigger focused
inspection, but only an Integration admission receipt can trigger quarantine
acceptance.

## Implement and prove

1. Prefer focused renderer components, cached reusable geometry/textures, and incremental tile updates.
2. Add unit/contract coverage for topology, identity, detail levels, hit testing, or state mapping.
3. For ordinary renderer features, run the complete Swift suite and `git diff --check`; for directional intake, defer the complete suite until exact 4/4 and run focused packet gates beforehand.
4. For ordinary renderer features, build and operate the real staged app. For directional intake, build the exact 4/4 renderer candidate and perform only a non-interactive launch/resource smoke; independent QA owns the player-facing staged-app journey.
5. At that final renderer-candidate stage, retain technical resource, geometry, LOD, fixture-render, and telemetry proof. Do not capture or score default/compact player interaction as Renderer acceptance evidence.
6. Record performance before and after at the final affected candidate; inspect accumulating nodes/actions during longer play.
7. Disclose when a deterministic harness substitutes for window capture.

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
