# PLAY-073 Industrial L4 source-stage adapter prototype

## Outcome

Renderer now has a self-contained, test-only prototype for the proposed
`source-stage-v2` to Renderer direction-packet-v2 mapping. It consumes
synthetic East, South, and West source candidates from Integration's exact
reserved locator paths in isolated temporary roots. North remains explicitly
pending and no 4/4 assembly or activation path exists in this slice.

The prototype pins the published locator authority, source-stage schema,
CONTRACT-021, direction bridge, semantic validator, canonical decoder, and
non-alias loader. It maps worker/source/LOD/provenance/registration/D4 fields
deterministically into in-memory packet-v2 bytes.

## Fail-closed proof

Focused tests prove:

- two complete East/South/West passes emit byte-identical packets;
- all nine LOD hashes and all 24 D4 hashes are unique;
- a wrong authority or source hash fails before mapping;
- a symlinked reserved source path fails containment;
- a failing South leaves the exact passing East and West bytes unchanged;
- fallback, duplicate transform, and cross-direction alias inputs fail;
- North remains pending and runtime, shipping, quarantine, admission, and
  production-selection flags remain false.

No real source packet or pixel was read, created, admitted, quarantined,
packed, staged, or selected.

## Synthetic admission-to-quarantine follow-up

After Integration published the adapter candidate on exact master
`2f218104cf924c5cb2e80f9a07501dd3755612bf`, Renderer merged that authority
cleanly and added a test-only bridge at
`88a3d423689bc28bc6c7090abe6f4507150f8a62`.

The adapter's synthetic East, South, and West packet bytes now reopen through
the existing strict direction-packet file harness with separately encoded
synthetic Integration source-admission receipts. Two repeat passes emit
identical direction-local quarantine receipts. A South decoded-hash drift is
rejected without changing the admitted East/West packets, their receipt bytes,
or their batch result. Correcting only the South receipt returns the three-
direction batch to `quarantined_incomplete`; North remains the sole missing
direction and atomic assembly is rejected.

The strict harness also exposed and corrected three assumptions in the
synthetic source fixture: the canonical contact diamond, identity D4 binding
to decoded RGBA, and one family-shared appearance lock. No validator, shared
schema, contract, runtime, resource, atlas, manifest, package, or app surface
changed. See `ADMISSION-QUARANTINE-VALIDATION.json`.

## Published-master replay

The two focused commits were cherry-picked without conflict onto exact
published master `e30b57243e05c487509fbe22ef103f4c3b00cb69` in a disposable
clone, producing replay commits `88dd12b06f29fdfaf7393e87a53dbce5db7979a7`
and `1eb911a6f7cb05e5ae45e65daf1b85203b49bbc1`. The prototype suite compiled
against that tree and passed 4/4 with zero failures. No retained Renderer
test or helper file is a prerequisite.

## Owned paths

- `Native/CitySimNative/Tests/CitySimNativeTests/IndustrialL4SourceStageAdapterPrototypeTests.swift`
- `docs/production/evidence/PLAY-073/industrial-l04-source-stage-adapter-prototype-v1/`

## Import order

1. Published master `e30b57243e05c487509fbe22ef103f4c3b00cb69`.
2. Renderer sync merge `fa95453871c669d9fca541a9665714f811f0b3c2`.
3. Adapter prototype `7e754a0dfbef6c8e91130b091015970702e417ca`.
4. This evidence commit.

## Stop conditions

Stop on any real or provisional source packet, missing North authority,
authority/hash/path drift, alias/transform/fallback, request for admission or
quarantine acceptance, shared schema/contract change, runtime/resource/atlas/
manifest/package mutation, app staging, or production selection.
