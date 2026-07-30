# PLAY-073 current-authority intake replay

## Disposition

`PASS_CURRENT_AUTHORITY_CANDIDATE_NEUTRAL_NONSHIPPING`

Published authority `aaee294718a8176b70a4688b738b517f216dd3a7` was
normally merged without rewriting the preserved candidate
`9506bf5aafd93725574f51b114ca177709b7aaec`.

The exact observed live-binding checkpoint is
`bef68100ce0d4bc93c55b09e53f353daeb5d32c7`. Only `WORK-GRAPH.json`
and `ATOMIC-ASSEMBLER-JOB-DESCRIPTOR.json` required prospective binding
updates. Historical receipts and all product, runtime, resource, atlas,
manifest, and shipping state remain unchanged.

## Current bindings

The replay binds the refreshed non-alias input, source-stage schema,
source-admission validator, locator authority/schema, Renderer intake plan,
and plan validator at their exact published hashes. `VALIDATION.json` records
the authoritative paths and hashes.

The projection is exact:

- 7 prepared descriptors;
- 4 canonical directions;
- 12 unique LOD slots;
- 6 camera states;
- shared 1536x1024 registration, 1x1 footprint, pivot [768,896], and
  [72,36] tile basis;
- all alias, mirror, rotation, transform, fallback, locator, hash, direction,
  registration, and premature-assembly cases fail closed; and
- the corrected fourth exact quarantine receipt invokes the existing
  nonshipping assembler exactly once.

There are zero live Integration source-admission receipts. No source was
admitted, no Renderer quarantine was accepted, no atomic assembly was
executed, and runtime activation, shipping mutation, and production selection
remain false.

## Gates

- Renderer intake-plan semantic validation: PASS, 20 inputs, 4 directions,
  12 LOD slots, 4 direction jobs.
- Adversarial plan matrix: 37/37.
- Source publication gate: PASS_PUBLICATION_ONLY, zero live receipts.
- Source-admission validator: 17/17.
- Focused Swift locator/adapter/quarantine/join gate: 28 executed, 26 passed,
  2 expected caller-input skips, 0 failures.
- Three exact-head read-only authority, descriptor, and rejection/join audits:
  PASS.

The first focused Swift attempt was blocked before test execution by the
managed sandbox. The exact authorized rerun passed; no inputs changed.

## Receipt boundary

`EXECUTION-RECEIPT.json` binds every validation job to observed head
`bef68100ce0d4bc93c55b09e53f353daeb5d32c7`. A worker receipt cannot
self-reference its containing commit. Integration should project the
containing evidence commit as canonical `head`, retain `observedHead` as
`bef68100ce0d4bc93c55b09e53f353daeb5d32c7`, and leave every historical
job head unchanged at that observed checkpoint.

Measured overlap reached four concurrent read-only process gates from
`2026-07-30T15:33:57.316Z` through `2026-07-30T15:33:57.505Z`. Three
independent helper audits also ran and joined at `2026-07-30T15:34:42Z`.
The visible Renderer owner remained the sole worktree, Git index, and
governed-evidence writer.

## Stop and refill

The next legal refill is an exact Integration source-admission receipt. This
checkpoint does not authorize source consumption, quarantine acceptance,
runtime or shipping activation, atlas or manifest mutation, staged app work,
QA disposition, push, Integration, scoring, or self-acceptance.
