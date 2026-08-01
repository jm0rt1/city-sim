---
name: produce-citysim-world-art
description: "Author and validate CitySim directional building source art through parallel, direction-exclusive cells on the governed `codex/citysim-world-art*` branches. Use for PLAY-027/079/080/081 family-contract predesign, zero-pixel proofs, source scenes, A/B/C masters, provenance, non-shipping source records, N/E/S/W consistency, alias audits, contact sheets, and machine-readable source-art handoffs. This skill forbids live renderer, shipping atlas, gameplay, UI, save, and shared-manifest changes."
---

# Produce CitySim World Art

Create high-quality, truth-safe building masters for later renderer ingestion.
The output is a reviewed source batch, not a shipping renderer change.

## Start every turn

1. Run `pwd`, `git branch --show-current`, and `git status --short --branch`.
2. Require one exact governed branch and one Integration-issued active claim
   whose task, batch, branch, direction, path roots, and published base match
   the current shared ledger. The current Industrial L4 profile uses:
   - `codex/citysim-world-art` → `PLAY-027.world-art.md`;
   - `codex/citysim-world-art-east` → `PLAY-079.world-art-east.md`;
   - `codex/citysim-world-art-south` → `PLAY-080.world-art-south.md`;
   - `codex/citysim-world-art-west` → `PLAY-081.world-art-west.md`.
   A later family may use different `PLAY-*` claims only when Integration
   publishes those exact mappings in its family ledger. Never reuse an
   Industrial L4 claim for another family. Stop on any branch, direction,
   batch, or claim mismatch.
3. Read and follow [the shared model-routing and cost-control contract](../operate-citysim-integration/references/model-routing-and-cost-control.md). Complete the applicable authority read for a new thread or claim, changed claim/authority/skill/reference hash, routing mismatch, context loss, or stale compact packet. On an unchanged same-thread continuation, verify every recorded hash and Git revision before consuming the compact lane-context packet.
4. When a complete read is required, read this skill, the branch-mapped claim,
   all required conditional references,
   `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`,
   `docs/production/decisions/CONTRACT-006-generated-world-asset-pack.md`,
   `docs/production/decisions/CONTRACT-010-directional-building-art.md`,
   `docs/production/decisions/CONTRACT-020-deterministic-dcc-world-art.md`, and
   `docs/production/decisions/CONTRACT-021-parallel-directional-art-cells.md`
   completely.
5. Confirm the branch contains the claim’s published base and is clean.
6. Resolve and compare the exact full hashes for the current family contract,
   stage authority, appearance lock, source-production profile, handoff schema,
   semantic validator, compute envelope, claim revision, and published base.
   Record an explicit missing/blocked state for authorities that are not yet
   legal at the current stage; never infer them from nearby artifacts.
7. Confirm the named direction and its exclusive source, process, output, and
   evidence roots, then state the world-art mission and current batch before
   generating anything.

## Preserve the ownership boundary

Own only:

- ImageGen prompts, raw attempts, accepted masters, provenance, and rejection
  records under the exact direction-exclusive ImageGen subroots named by the
  claim;
- task-owned non-shipping source records and source validators;
- task-owned contact sheets, geometry reports, and evidence under the exact
  active claim's `PLAY-*` roots.

Direction cells additionally own only the exact direction named by their
claim. They may consume the published family/material/camera contract but may
not edit a sibling direction's scene, tools, raw pixels, or evidence. Do not
copy a sibling scene as the starting geometry; author each orientation
explicitly from the shared family requirements.

Do not edit `Rendering/`, shipping atlas pages, production selection, shared
manifest types, shared family/material/toolchain contracts, package/build
scripts, gameplay, simulation, UI, saves, PLAY-024 artifacts, or legacy
Python. A direction cell must return any required shared-surface change to
Integration for publication or to a separately claimed non-direction
shared-toolchain writer; Integration may not appoint North, East, South, or
West as that writer. Never push, integrate, or self-accept.

## Route design authority and directional production separately

- `FRONTIER_AUTHORITY` owns North hero design, family vocabulary, appearance lock, unresolved art direction, shared toolchain decisions, and subjective source or production acceptance.
- `LUNA_IMPLEMENTATION` owns Integration-authorized East/South/West DCC production under frozen contracts; `LUNA_MECHANICAL` owns provenance, normalization, deterministic checks, contact sheets, hashes, and handoff packets. North mechanical validation may use Luna, but North visual disposition remains frontier-owned.
- `LUNA_LOCAL_DEBUG` may repair only a reproducible direction-local defect with frozen inputs and no shared-contract ambiguity; stop after two unsuccessful repair attempts.
- A substantial `PLAY-*` family is split into the frontier North/design authority, disjoint direction execution packets, and independent frontier acceptance. Stop on every escalation trigger in the shared contract.
- Each Luna direction runs only its focused source gates. Passing siblings remain immutable when one direction returns. Renderer runs the full suite/resource smoke once at exact 4/4 assembly; independent frontier QA runs the single final app journey.

## Direction-cell execution

Before prelock work, DCC authorization, per-process execution, parallel helper work, or a direction-local return, read
[references/direction-cell-parallel-execution.md](references/direction-cell-parallel-execution.md)
completely.

## Source production and quality

Before generating, authoring, normalizing, comparing, or judging a directional source, read
[references/source-production-and-quality.md](references/source-production-and-quality.md)
completely.

## Handoff and checkpoints

Before validating, checkpointing, returning, or handing off a source candidate, read
[references/source-handoff-and-checkpoints.md](references/source-handoff-and-checkpoints.md)
completely.
