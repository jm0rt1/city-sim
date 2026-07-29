---
name: produce-citysim-world-art
description: "Author and validate CitySim directional building source art through parallel, direction-exclusive cells on the governed `codex/citysim-world-art*` branches. Use for PLAY-027/079/080/081 family-contract predesign, zero-pixel proofs, source scenes, A/B/C masters, provenance, non-shipping source records, N/E/S/W consistency, alias audits, contact sheets, and machine-readable source-art handoffs. This skill forbids live renderer, shipping atlas, gameplay, UI, save, and shared-manifest changes."
---

# Produce CitySim World Art

Create high-quality, truth-safe building masters for later renderer ingestion.
The output is a reviewed source batch, not a shipping renderer change.

## Start every turn

1. Run `pwd`, `git branch --show-current`, and `git status --short --branch`.
2. Require one exact governed branch and claim:
   - `codex/citysim-world-art` → `PLAY-027.world-art.md`;
   - `codex/citysim-world-art-east` → `PLAY-079.world-art-east.md`;
   - `codex/citysim-world-art-south` → `PLAY-080.world-art-south.md`;
   - `codex/citysim-world-art-west` → `PLAY-081.world-art-west.md`.
   Stop on any other branch or claim mismatch.
3. Read `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`,
   `docs/production/decisions/CONTRACT-006-generated-world-asset-pack.md`,
   `docs/production/decisions/CONTRACT-010-directional-building-art.md`, and
   the branch-mapped claim above completely.
4. Confirm the branch contains the claim’s published base and is clean.
5. State the world-art mission and current batch before generating anything.

## Preserve the ownership boundary

Own only:

- ImageGen prompts, raw attempts, accepted masters, provenance, and rejection
  records under `Native/CitySimNative/WorldArt/ImageGen/`;
- task-owned non-shipping source records and source validators;
- task-owned PLAY-027/079/080/081 contact sheets, geometry reports, and
  evidence.

Direction cells additionally own only the exact direction named by their
claim. They may consume the published family/material/camera contract but may
not edit a sibling direction's scene, tools, raw pixels, or evidence. Do not
copy a sibling scene as the starting geometry; author each orientation
explicitly from the shared family requirements.

Do not edit `Rendering/`, shipping atlas pages, production selection, shared
manifest types, package/build scripts, gameplay, simulation, UI, saves,
PLAY-024 artifacts, or legacy Python. Ask integration before any new shared
contract. Never push, integrate, or self-accept.

## Fan out one family across direction cells

Treat the Integration-published family contract as immutable. It must identify
the exact family/version, logical asset identity, scale, palette/material
roles, footprint, pivot, N/E/S/W camera and road-facing sockets, light, shadow,
and toolchain. The later Integration-published appearance lock must add the
exact independently accepted North process-A appearance authority and bind it
to that contract version/hash. An appearance lock is not North source
acceptance, family selection, renderer activation, or shipping authority.
Stop if the contract, family lock, branch claim, or source revision is missing,
stale, or contradictory for the requested stage; never repair shared authority
from a direction cell.

Use one branch, worktree, claim, and task-owned path set per direction. North
owns design calibration; East, South, and West independently own only their
named orientation. Run all Integration-authorized cells concurrently:

1. **Before the family lock:** independently author text-scene/material
   bindings and run static plus actual-camera zero-pixel geometry, silhouette,
   portal/frontage, footprint, pivot, socket, light, shadow, and occlusion
   proofs. Do not render, normalize, or claim pixel authority. When the claim
   defines predesign as its complete deliverable, commit the passing predesign
   normally; otherwise preserve it as a non-ready checkpoint.
2. **After Integration publishes the appearance lock and updates the claims to
   authorize production:** North begins B/C while East, South, and West begin
   their independently authored A/B/C renders and deterministic validation,
   all concurrently. Do not wait for a sibling direction to finish. Bind every
   process to the exact appearance-lock hash.
3. **On a direction-local failure:** preserve its rejection and return only
   that direction to repair. Successful siblings retain their independent
   candidates and continue to handoff; they may not lend pixels, masks, scene
   geometry, or transformed coordinates to the failed cell.
4. **At selection:** accept and quarantine directions independently, but keep
   production selection and shipping activation blocked until Integration has
   the exact accepted N/E/S/W set. Selection is atomic at 4/4.

Direction cells never edit shared family contracts, material libraries,
authoring tools, shipping manifests, atlas slots, or sibling files unless
Integration assigns one explicit shared-surface writer. Never copy, mirror,
rotate, transform, or derive sibling scene geometry or pixels.

### Parallelize inside each direction cell

Scene and material authoring remain single-writer until the exact
direction-local scene revision is frozen. After that freeze and only within
the stage authorized by the claim:

- launch A, B, and C as independent fresh processes concurrently, each writing
  only to its own immutable output directory;
- never let one process consume, repair, rename, or overwrite another
  process's output;
- after the raw files close, run independent hash/RGBA, registration,
  normalization-repeat, literal-scale, grayscale, and contact-sheet jobs
  concurrently when their input/output paths are disjoint;
- preserve any failed process immediately without canceling passing siblings;
  and
- assign exactly one direction-local assembler to validate the complete packet
  and write the final handoff after all required jobs settle.

North's pre-lock process-A appearance calibration remains a one-process gate.
The internal A/B/C fan-out begins for North only after Integration publishes
the appearance lock and explicitly releases B/C. East, South, and West may
begin their full A/B/C fan-out concurrently at that same release boundary.
Parallel execution never relaxes fresh-process identity, exact input hashes,
or the requirement for byte/pixel determinism.

## Produce one governed source per direction cell

1. Audit the current catalog and prove the logical type is not aliased.
2. Load the immutable style anchor, the exact geometry template, and the
   approved family anchor. Never use a rejected sibling as a reference.
3. Use the source method authorized by the immutable family contract. When it
   authorizes built-in ImageGen, use it once for one source attempt, follow
   CONTRACT-006’s chroma-key prompt, and retain the complete prompt and
   reference hashes. When it authorizes the offline/DCC path, do not make a
   whole-building ImageGen call.
4. Save the raw stochastic master immediately with a unique revision. Never
   overwrite a prior attempt.
5. Normalize deterministically with the existing repository tools. Do not use
   generated pixels to infer pivots, masks, footprint, frontage, or geometry.
6. Record raw/normalized hashes, geometry, frontage, view direction, model,
   date, reviewer state, and disposition.
7. Reject perspective, lighting, scale, pivot, alpha, frontage, silhouette,
   or material drift before adding the source to a contact sheet.

After two consecutive directional drift failures, stop further attempts in that
direction and return to its geometry template and anchor. Preserve passing
sibling candidates; do not keep adding prompt adjectives.

## Use the approved offline-scene fallback

When CONTRACT-011 is present and the retained capability-limit record closes
whole-building ImageGen:

- do not make another whole-building ImageGen call;
- use ImageGen only for non-compositional material swatches within the
  CONTRACT-011 boundary;
- author one explicit task-owned offline scene descriptor per direction using
  the approved macOS-native source toolchain;
- declare direction-specific facade and entrance geometry in every scene;
- never derive a sibling scene or raster by mirror, rotation, or transform;
- freeze tool/framework versions, scene/material hashes, render settings,
  camera, pivot, socket, light, shadow, and flat chroma field;
- prove repeat-run determinism before judging appearance;
- stop at the exact claim-authorized family, direction, and stage boundary
  until independent art review and Integration authorize expansion.

The offline renderer remains a source-authoring tool. It may not become a
shipping dependency or edit `Package.swift`, `Rendering/`, atlas selection, or
the application runtime.

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
- direction-local contact sheets at source size and actual game scale;
- direction-local grayscale family-recognition evidence;
- explicit accepted and rejected attempt inventory.

Write one task-owned JSON handoff packet per direction and identify its stage as
`predesign` or `source`. Include the task, branch, base authority,
family-contract version/hash, family and direction, source revision,
scene/material/toolchain hashes, pivot/footprint/socket/frontage/light/shadow
geometry, validation report paths, disposition, and known blockers. A
predesign packet records pixel production and A/B/C as `not_produced` and may
declare only `predesign_ready`; never invent placeholder hashes. A source
packet additionally includes raw/normalized hashes, A/B/C identity results,
contact-sheet paths, and rejected-attempt inventory, and may declare only that
direction `source_ready`. Neither stage may declare the four-direction family
selected.
Integration assigns the later 4/4 assembly owner for the combined N/E/S/W
source-size, actual-game-scale, and grayscale family sheets.

Validate every packet against the exact versioned JSON schema published by
Integration and record the schema path/hash plus validation command/result.
Use this direction-local commit sequence unless the claim narrows it further:

1. zero-pixel scene/design checkpoint with the static and actual-camera proofs;
2. A/B/C source plus deterministic validation checkpoint after production is
   authorized;
3. machine-readable handoff and completion checkpoint.

Do not collapse these boundaries when doing so would hide a rejected attempt,
an unrun gate, or a change in source authority.

Stage explicit claimed paths, inspect staged diff/stat/check, and commit one
coherent batch with the branch-mapped `PLAY-027`, `PLAY-079`, `PLAY-080`, or
`PLAY-081` task ID. Use a checkpoint commit only for durable incomplete work
and list unrun or failing gates. Keep the worktree clean before handoff and
write a completion record only when the claimed direction is actually
complete. Renderer ingestion, atomic 4/4 production selection, and staged-app
proof belong to a later integration-approved world-rendering task.
