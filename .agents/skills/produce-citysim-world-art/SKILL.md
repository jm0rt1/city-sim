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
3. Read `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`,
   `docs/production/decisions/CONTRACT-006-generated-world-asset-pack.md`,
   `docs/production/decisions/CONTRACT-010-directional-building-art.md`,
   `docs/production/decisions/CONTRACT-020-deterministic-dcc-world-art.md`,
   `docs/production/decisions/CONTRACT-021-parallel-directional-art-cells.md`,
   and the branch-mapped claim above completely.
4. Confirm the branch contains the claim’s published base and is clean.
5. Resolve and compare the exact full hashes for the current family contract,
   stage authority, appearance lock, source-production profile, handoff schema,
   semantic validator, compute envelope, claim revision, and published base.
   Record an explicit missing/blocked state for authorities that are not yet
   legal at the current stage; never infer them from nearby artifacts.
6. Confirm the named direction and its exclusive source, process, output, and
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

Freeze one immutable direction binding per cell:
`{familyContractPath/hash, direction, branch, worktree, claimPath/hash,
publishedBase, sourceRoot, evidenceRoot}`. The binding must be unique across
North/East/South/West and must not change during the claimed stage. Reject a
missing, duplicated, cross-direction, or drifted binding; only Integration may
publish a replacement family contract or claim revision.

1. **Before the family lock:** East, South, and West independently author
   text-scene/material bindings and run static plus actual-camera zero-pixel
   geometry, silhouette, portal/frontage, footprint, pivot, socket, light,
   shadow, and occlusion proofs. They do not render, normalize, or claim pixel
   authority. North does the same predesign work and may additionally execute
   exactly one Integration-scheduled and per-process-granted Process A
   appearance calibration. That North exception authorizes no B/C, source
   candidate, normalization, production handoff, sibling pixel authority,
   family selection, or renderer activation. North stops after Process A for
   independent technical and literal-scale review. When a sibling claim
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
4. **At handoff:** return direction candidates independently. Integration
   admits source candidates and Renderer quarantines admitted directions;
   direction cells perform neither action. Production selection and shipping
   activation remain blocked until Integration has the exact admitted and
   Renderer-quarantined N/E/S/W set. Selection is atomic at 4/4.

Direction cells never edit shared family contracts, material libraries,
shared authoring tools, shipping manifests, atlas slots, or sibling files.
Shared changes return to Integration or a separately claimed non-direction
shared-toolchain writer. Never copy, mirror, rotate, transform, or derive
sibling scene geometry or pixels.

Before every checkpoint, audit the complete changed-path range from the
claimed base through `HEAD`. Fail if any changed path is outside the
direction's claim-owned roots or if the cell consumed a sibling scene,
geometry, raster, mask, coordinate set, or evidence packet. Record the
changed-path inventory and `siblingInputsConsumed: []` in the machine-readable
handoff.

A post-lock production claim and dispatch authority must bind the exact claim
revision and published base; appearance-lock and source-production-profile
paths, hashes, and commits; authorized process set; immutable process/output
and evidence roots; source revision; compute-slot and queue policy; bounded
deliverable; and stop condition. A prelock claim or an appearance lock by
itself never authorizes pixels.

Launch production only through the Integration-approved orchestrator and an
exact validated per-process launch grant. The grant must bind the global
schedule, compute lease, direction, claim revision, published base, frozen
scene/material/toolchain hashes, process ID, exclusive input/output/evidence
roots, and exactly-one child start. A low-level direction runner must verify
that grant or remain non-invocable directly. Do not begin A/B/C while the
parallel schedule schema, strict validator, adversarial tests, or launch grant
is missing, proposed, stale, or unvalidated.

A passing schedule consumer or adapter is preparation, not launch readiness.
The direction must also consume the Integration-owned execution-closure
authority and prove, at a validation-only zero-child boundary, that the exact
schedule plus authenticated one-attempt authority reaches its named
high-level orchestrator and runner contract. Never report `launch_ready` while
the high-level orchestrator intentionally rejects a future interface, while a
consumer stops before launch-bundle preparation, or while the runner lacks the
schedule/grant entrypoint. Direction-local closure code may bind the shared
interface read-only but may not copy North's launcher, constants, evidence, or
task paths.

For Industrial L4, validate the exact Integration schedule with
`.agents/skills/operate-citysim-integration/scripts/validate_industrial_l04_parallel_execution_schedule_v1.py`.
Treat
`docs/production/evidence/INTEGRATION/industrial-l04-parallel-execution-schedule-schema-v1.json`
as the wire contract and
`docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-PARALLEL-EXECUTION-SCHEDULE-V1-AUTHORITY.md`
as the operating authority. Direction-local adapters and runners may consume
those shared files read-only; they never edit them.

For any other family, resolve the schedule schema, validator, adversarial
tests, and operating authority from that family's exact Integration ledger and
contract. Fail closed if family-specific controls do not exist; never point a
new family at the Industrial L4 profile merely to obtain a passing validator.

### Parallelize inside each direction cell

Scene and material authoring remain single-writer until the exact
direction-local scene revision is frozen. After that freeze and only within
the stage authorized by the claim:

- publish a compact direction-local job plan before launching work. List every
  job's frozen inputs, exclusive output root, dependency, execution owner,
  state (`ready`, `running`, `joined`, or `blocked`), and join condition.
  Separate DCC/render capacity from CPU/helper capacity so a full render queue
  does not hide idle validation or evidence work;
- enqueue every authorized A, B, and C fresh process immediately, each writing
  only to its own immutable output directory. Integration's global scheduler
  keeps every available DCC slot occupied up to the published compute cap;
  queued processes do not block direction-local CPU validation, evidence, or
  packet preparation;
- never let one process consume, repair, rename, or overwrite another
  process's output;
- after the raw files close, run independent hash/RGBA, registration,
  normalization-repeat, literal-scale, grayscale, and contact-sheet jobs
  concurrently when their input/output paths are disjoint;
- preserve any failed process immediately without canceling passing siblings;
  and
- assign exactly one direction-local assembler to validate the complete packet
  and write the final handoff after all required jobs settle.

Use available internal helpers or parallel tool calls for bounded read-only
inspection and jobs writing only to isolated temporary roots outside the
direction worktree. The direction's visible worker remains the sole
scene/material writer before freeze and the sole worktree, Git index, governed
evidence packet, handoff, and commit writer throughout; it alone may validate
and adopt temporary outputs. Helpers may not mutate a shared scene, consume
unfinished inputs, stage or commit, relax a validator, or claim direction
completion. When safe eligible jobs outnumber launched jobs, record the
concrete capacity limit or ownership conflict; "working sequentially" is not
an explanation.

Follow this dependency graph; concurrency does not authorize consumers to race
unfinished inputs:

`raw A/B/C fan-out → per-process provenance/RGBA fan-out → identity join →
normalization-repeat fan-out → literal color/grayscale/contact-sheet fan-out →
single packet assembly`

Emit one machine-readable parallel-execution receipt containing the frozen
scene, material, schema, toolchain, and authority hashes; process IDs and
distinct roots; start/end timestamps; exactly-one-invocation assertions;
actual overlap; join results; validation-job roots; and the final assembler
identity. Also record ready-job count, maximum available DCC and helper
capacity, launched-job count, unused-capacity reasons, and each required join.
Its `executionAccounting` projection must use the exact Integration schema:
one bound job object per launch with batch, claim revision, base, head, visible
thread, branch, worktree, resource/mutation class, exclusive root, state,
interval, DCC slot/process when applicable, and exact visible-thread item
evidence. Bind the visible cell as sole Git/evidence writer, list every running
job exactly once, and give each unused helper or DCC slot its own reason.
If Integration's compute envelope requires a sequential render wave, record
the resource exception and queue order. Claim overlap only when the timestamps
prove it, and never exceed the published global DCC cap.

Treat the compute slot as a lease, not a department lock. A queued or failed
DCC process blocks only its own exclusive output root. Continue every
direction-local CPU-only provenance, validator, review-sheet, inventory, and
packet task whose inputs are closed, while sibling cells do the same. Never
cancel passing sibling work merely because one direction or process fails.

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
claim path/hash, family-contract version/hash, family and direction, source
revision, scene/material/toolchain hashes, pivot/footprint/socket/frontage/light/shadow
geometry, validation report paths, disposition, and known blockers. Include a
`directionRootMap` with the exact scene, raw, normalized, process, output,
evidence, and handoff roots plus the parallel-execution receipt path/hash.
Fail before authoring, launch, or handoff unless every root is inside the
claim-owned direction prefix, all process/output roots that must be exclusive
are pairwise disjoint, and no root equals, contains, or is contained by a
sibling or shared-contract root. A
predesign packet records pixel production and A/B/C as `not_produced` and may
declare only `predesign_ready`; never invent placeholder hashes. A source
packet additionally includes raw/normalized hashes, A/B/C identity results,
contact-sheet paths, and rejected-attempt inventory, and may declare only that
direction `source_candidate` with
`candidateReadyForIndependentReview:true`. It must keep
`sourceReady`, `integrationAdmitted`, `rendererQuarantined`, and
`productionSelected` false. A direction worker never self-accepts source art:
Integration alone advances the shared ledger to `integration_admitted` after the
Integration-owned semantic validator and independent technical plus
literal-scale reviews pass. Neither stage may declare the four-direction
family selected.
Integration assigns the later 4/4 assembly owner for the combined N/E/S/W
source-size, actual-game-scale, and grayscale family sheets.

The standard source handoff is immutable once returned. Integration hashes and
admits that exact packet in a separate canonical source-admission receipt;
Renderer consumes that receipt and may not reinterpret a worker readiness
field as admission. If Integration returns the packet, create a new source
revision and handoff rather than editing the returned packet in place.

Validate every packet against the exact versioned JSON schema published by
Integration and then run the Integration-owned semantic validator. Record the
schema path/hash, semantic-validator path/hash, common accepted-master
non-alias authority path/hash/count/set digest, validation commands, and
results. Direction-local validators may consume the common loader; they must
not copy, truncate, reinterpret, or replace its forbidden inventory. Schema
validation alone is insufficient because it cannot prove repository paths,
file hashes, commit ancestry, process-root isolation, A/B/C identity, LOD
dimensions, or non-alias intersection.
Use this direction-local commit sequence unless the claim narrows it further:

1. zero-pixel scene/design checkpoint with the static and actual-camera proofs;
2. A/B/C source plus deterministic validation checkpoint after production is
   authorized;
3. machine-readable handoff and completion checkpoint.

These are three direction-local, independently reviewable commit boundaries.
The zero-pixel commit must predate every render grant; the A/B/C commit must
bind three distinct fresh-process roots and their deterministic validation;
the handoff commit must add only the schema-valid machine-readable packet and
completion evidence. No combined, cross-direction, or sibling commit satisfies
another direction's gate. A returned direction advances only through a new
direction-owned revision; passing siblings remain unchanged. Integration may
select production only from one atomic manifest binding the exact independently
admitted and Renderer-quarantined North/East/South/West packet paths, hashes,
and content commits; fewer than four is a hard stop.

When the claim explicitly defines predesign as its complete deliverable, the
passing zero-pixel and predesign-handoff commits complete that claim stage
normally; they do not imply directional source completion. Use incomplete
checkpoint wording only when a required gate remains failing or unrun.

Do not collapse these boundaries when doing so would hide a rejected attempt,
an unrun gate, or a change in source authority.

Stage explicit claimed paths, inspect staged diff/stat/check, and commit one
coherent batch with the exact active claim's `PLAY-*` task ID. For the current
Industrial L4 profile those are `PLAY-027`, `PLAY-079`, `PLAY-080`, and
`PLAY-081`; do not carry them into a later family without new Integration
authority. Use a checkpoint commit only for durable incomplete work and list
unrun or failing gates. Keep the worktree clean before handoff and write a
completion record only when the claimed direction is actually complete.
Renderer ingestion, atomic 4/4 production selection, and staged-app proof
belong to a later integration-approved world-rendering task.
