---
name: produce-citysim-world-art
description: "Author and validate CitySim directional building source art on `codex/citysim-world-art`. Use for PLAY-027 ImageGen prompts, raw masters, provenance, non-shipping source records, N/E/S/W consistency, alias audits, contact sheets, and source-art handoffs. This skill forbids live renderer, shipping atlas, gameplay, UI, save, and shared-manifest changes."
---

# Produce CitySim World Art

Create high-quality, truth-safe building masters for later renderer ingestion.
The output is a reviewed source batch, not a shipping renderer change.

## Start every turn

1. Run `pwd`, `git branch --show-current`, and `git status --short --branch`.
2. Require `codex/citysim-world-art`; stop on any other branch.
3. Read `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`,
   `docs/production/decisions/CONTRACT-006-generated-world-asset-pack.md`,
   `docs/production/decisions/CONTRACT-010-directional-building-art.md`, and
   `docs/production/claims/PLAY-027.world-art.md` completely.
4. Confirm the branch contains the claim’s published base and is clean.
5. State the world-art mission and current batch before generating anything.

## Preserve the ownership boundary

Own only:

- ImageGen prompts, raw attempts, accepted masters, provenance, and rejection
  records under `Native/CitySimNative/WorldArt/ImageGen/`;
- task-owned non-shipping source records and source validators;
- PLAY-027 contact sheets, geometry reports, and evidence.

Do not edit `Rendering/`, shipping atlas pages, production selection, shared
manifest types, package/build scripts, gameplay, simulation, UI, saves,
PLAY-024 artifacts, or legacy Python. Ask integration before any new shared
contract. Never push, integrate, or self-accept.

## Produce one governed source at a time

1. Audit the current catalog and prove the logical type is not aliased.
2. Load the immutable style anchor, the exact geometry template, and the
   approved family anchor. Never use a rejected sibling as a reference.
3. Use built-in ImageGen once for one source attempt. Follow CONTRACT-006’s
   chroma-key prompt and retain the complete prompt and reference hashes.
4. Save the raw stochastic master immediately with a unique revision. Never
   overwrite a prior attempt.
5. Normalize deterministically with the existing repository tools. Do not use
   generated pixels to infer pivots, masks, footprint, frontage, or geometry.
6. Record raw/normalized hashes, geometry, frontage, view direction, model,
   date, reviewer state, and disposition.
7. Reject perspective, lighting, scale, pivot, alpha, frontage, silhouette,
   or material drift before adding the source to a contact sheet.

After two consecutive directional drift failures, stop that family and return
to its geometry template and anchor. Do not keep adding prompt adjectives.

## Enforce four-direction and family quality

- Author north, east, south, and west separately; never mirror or rotate.
- Keep footprint, pivot, contact, floor/door scale, vertical envelope, light,
  shadow, materials, and identity within CONTRACT-010 tolerances.
- Keep the entrance on the declared road-facing frontage.
- Give every logical building type its own source and pixel identity.
- Make variants materially different in massing, roofline, entrance rhythm,
  and materials; reject recolor-only or prop-only changes.
- Require unlabeled grayscale recognition for residential, commercial, and
  industrial families.
- Include no baked roads, labels, UI, selection marks, agents, or false state.

## Validate and checkpoint

End each coherent source batch with:

- alias/coverage matrix;
- prompt, provenance, inventory, and hash validation;
- alpha/chroma, padding, pivot, footprint, frontage, projection, light, and
  shadow reports;
- N/E/S/W contact sheet at source size and actual game scale;
- grayscale family-recognition sheet;
- explicit accepted and rejected attempt inventory.

Stage explicit claimed paths, inspect staged diff/stat/check, and commit one
coherent batch with `PLAY-027: ...`. Use a checkpoint commit only for durable
incomplete work and list unrun or failing gates. Keep the worktree clean before
handoff and write a completion record only when the claimed batch is actually
complete. Renderer ingestion and staged-app proof belong to a later
integration-approved world-rendering task.
