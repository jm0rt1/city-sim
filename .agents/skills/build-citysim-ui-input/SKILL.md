---
name: build-citysim-ui-input
description: "Build CitySim's map-first SwiftUI interface and complete input system on `codex/citysim-ui-input`, including HUD, tools, inspector, alerts, objectives, overlays, settings, onboarding, responsive layouts, command registry, keyboard, focus, and accessibility. Use for every prompt in the UI/input worktree and whenever a PLAY task changes player commands, information architecture, or native interface behavior."
---

# Build CitySim UI and Input

Make every important action quick, understandable, reversible, discoverable, and operable without a pointer while keeping the city as the primary surface.

## Orient before every task

1. Run `pwd`, `git branch --show-current`, and `git status --short --branch`.
2. Require `codex/citysim-ui-input` for mutations.
3. Read and follow [the shared model-routing and cost-control contract](../operate-citysim-integration/references/model-routing-and-cost-control.md). Complete the applicable authority read for a new thread or claim, changed authority/skill/reference hash, routing mismatch, context loss, or stale compact packet. On an unchanged same-thread continuation, verify every recorded hash and Git revision before consuming the compact lane-context packet.
4. When a complete read is required, read `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`, this skill, the claimed `PLAY-*` task, linked UX requirements, and applicable UI/keyboard/audit plans completely.
5. Confirm a UI/input claim and preserve all unrelated work.

## Route work at judgment boundaries

- `LUNA_IMPLEMENTATION` implements approved components, command mappings, shortcuts, focus behavior, and accessibility tests; `LUNA_MECHANICAL` owns inventories, command/AX fixtures, focused checks, and packet assembly; `LUNA_LOCAL_DEBUG` may repair only a reproducible lane-local defect with frozen inputs and stops after two unsuccessful attempts.
- `FRONTIER_AUTHORITY` owns information architecture, HUD hierarchy, interaction tradeoffs, shared-contract decisions, and final usability judgment.
- A substantial `PLAY-*` task must arrive as a frontier authority packet, one or more disjoint Luna execution packets, and an independent frontier acceptance packet. Stop on every escalation trigger in the shared contract.
- Luna runs only the focused owner and affected gates in its validated `modelRoute`. The lane coordinator aggregates coherent packets; the full Swift suite, staged build, pointer and keyboard journey, and default/compact real-app proof run once against the exact aggregate/integrated candidate unless identity changes or evidence is stale.

## Own player interaction

- Own `App/`, `Views/`, UI/input state in `CityGameStore`, `GameTheme`, responsive composition, keyboard commands, focus, and accessibility.
- Keep one command/state source of truth across menus, HUD, SpriteKit bridge, shortcut help, and accessibility help.
- Keep simulation rules in models/services and visual world work in SpriteKit.
- Preserve stable focus and identity during simulation pulses.
- Design default and compact layouts together; never create map space by shrinking hit targets.
- Use labels, shape, icon, pattern, and text so color is never the only status channel.

## Define the interaction contract

Before editing, state:

- player intent and current failure;
- entry, success, cancellation, recovery, undo, and error paths;
- keyboard, pointer, Full Keyboard Access, and VoiceOver routes;
- default and compact behavior;
- exact state owner and renderer bridge;
- evidence required to prove the interaction.

## Execute and prove conditionally

For implementation, focused evidence, and aggregate acceptance requirements,
read [references/ui-input-execution-and-evidence.md](references/ui-input-execution-and-evidence.md).

## Shared-contract rule

Do not change shared model enums, snapshot contracts, save schemas, or package boundaries without integration approval. If UI needs new truth, request the smallest typed analytics/state contract.

## Commit intelligently

- Run `git status --short` before staging and preserve unrelated work.
- Stage only explicit claimed app/view/store/test/proof paths; never use `git add -A` in a dirty checkout.
- Inspect the staged diff, run `git diff --cached --check`, and commit one coherent command, interaction, or responsive-layout outcome at a time.
- Use `PLAY-###: Imperative outcome` messages. Mark incomplete preservation commits as checkpoints with validation gaps.
- Commit after validated input/UI milestones, before risky refactors, handoff, task switches, or ending a turn with completed work.
- Keep the lane clean between checkpoints. Finished-but-uncommitted work is invalid; workers never push or merge.

## Completion

Use the completion requirements in
[references/ui-input-execution-and-evidence.md](references/ui-input-execution-and-evidence.md).
