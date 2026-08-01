# Source Handoff and Checkpoints

Read this reference before source validation, checkpointing, handoff, or return.

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
