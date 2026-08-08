---
name: produce-citysim-world-art
description: "Author and validate CitySim source art through governed `codex/citysim-world-art*` cells. Use for CONTRACT-025 authored North/East/South/West 2.5D ImageGen building batches, appearance-anchor preservation, sibling-view generation, prompts, raw masters, provenance, deterministic normalization, alias audits, contact sheets, and machine-readable handoffs. This skill forbids renderer, shipping atlas, gameplay, UI, save, and shared-manifest changes."
---

# Produce CitySim World Art

Create high-quality, truth-safe building masters for later renderer ingestion.
The output is a reviewed source batch, not a shipping renderer change.

## Start every turn

1. Run `pwd`, `git branch --show-current`, and `git status --short --branch`.
2. Require one exact governed `codex/citysim-world-art*` branch and one
   Integration-issued active claim whose task, family/toolchain role, path
   roots, and published base match. Never reuse a historical directional claim
   for CONTRACT-025 work. Stop on any branch, family, direction, task, or claim mismatch.
3. Read and follow [the shared model-routing and cost-control contract](../operate-citysim-integration/references/model-routing-and-cost-control.md). Complete the applicable authority read for a new thread or claim, changed claim/authority/skill/reference hash, routing mismatch, context loss, or stale compact packet. On an unchanged same-thread continuation, verify every recorded hash and Git revision before consuming the compact lane-context packet.
4. When a complete read is required, read this skill, the branch-mapped claim,
   `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`, CONTRACT-006, and the
   active family contract completely. For CONTRACT-025 read the exact accepted
   South anchor packet and the claim's direction-specific ImageGen brief.
   Read historical directional contracts and references only when an exact
   published claim explicitly resumes that historical path.
5. Confirm the branch contains the claim’s published base and is clean.
6. Resolve and compare the exact full hashes for the current family contract,
   style/registration references, production profile, handoff schema, semantic
   validator, claim revision, and published base.
   Record an explicit missing/blocked state for authorities that are not yet
   legal at the current stage; never infer them from nearby artifacts.
7. Confirm the named family/toolchain role and its exclusive source, output,
   and evidence roots, then state the mission and batch before generating.

## Preserve the ownership boundary

Own only:

- ImageGen prompts, raw attempts, candidate masters, provenance, and rejection
  records under the exact family-exclusive ImageGen subroots named by the
  claim;
- task-owned non-shipping source records and source validators;
- task-owned contact sheets, geometry reports, and evidence under the exact
  active claim's `PLAY-*` roots.

Family or direction cells own only the exact family/direction named by their claim. They may consume
the published style, camera, registration, and toolchain contracts but may not
edit sibling family pixels, tools, or evidence.

Do not edit `Rendering/`, shipping atlas pages, production selection, shared
manifest types, shared family/material/toolchain contracts, package/build
scripts, gameplay, simulation, UI, saves, PLAY-024 artifacts, or legacy
Python. A direction cell must return any required shared-surface change to
Integration for publication or to a separately claimed non-direction
shared-toolchain writer; Integration may not appoint North, East, South, or
West as that writer. Never push, integrate, or self-accept.

## Route design authority and directional production separately

- `FRONTIER_AUTHORITY` owns style vocabulary, appearance locks, unresolved art direction, shared toolchain decisions, and subjective source or production acceptance.
- `LUNA_IMPLEMENTATION` owns Integration-authorized direction-exclusive ImageGen sibling production under frozen CONTRACT-025 briefs. Each North/East/West call binds the exact accepted South raw as its identity reference and may not change the building's massing, materials, roofline, variant, or gameplay meaning. `LUNA_MECHANICAL` owns inventories, provenance, normalization, deterministic checks, four-view contact sheets, hashes, and handoff packets.
- `LUNA_LOCAL_DEBUG` may repair only a reproducible direction-local defect with frozen inputs and no shared-contract ambiguity; stop after two unsuccessful repair attempts.
- Luna may reproduce an executable art pipeline only after Integration binds an accepted
  executable reference whose real Blender smoke completed successfully. A
  zero-child/static prelaunch packet proves structure only; it never proves
  Blender launch, scene construction, rendering, output containment, or pixel
  validity. Novel or repeatedly false-green DCC architecture returns to
  frontier authority.
- A substantial `PLAY-*` family is split into frontier design authority,
  disjoint family/asset execution packets, and independent frontier acceptance.
- Each Luna cell runs only focused source gates. Passing siblings remain
  immutable when one asset returns. Renderer runs the full suite/resource smoke
  once at exact aggregate assembly; independent frontier QA runs one final app journey.

## Authored four-view execution

Before any CONTRACT-025 direction work, parallel helper work, or direction-local return, read
[references/direction-cell-parallel-execution.md](references/direction-cell-parallel-execution.md)
completely, applying its disjoint-claim and failure-isolation rules but not its
Blender/DCC-specific launcher controls. Built-in ImageGen is the only authorized
source generator. South anchors remain immutable; failed siblings return only
their exact identity-direction; runtime mirroring or raster rotation is forbidden.

## Source production and quality

Before generating, authoring, normalizing, comparing, or judging a directional source, read
[references/source-production-and-quality.md](references/source-production-and-quality.md)
completely.

## Handoff and checkpoints

Before validating, checkpointing, returning, or handing off a source candidate, read
[references/source-handoff-and-checkpoints.md](references/source-handoff-and-checkpoints.md)
completely.
