# PLAY-073 Industrial L4 source-stage adapter prototype

## Outcome

Renderer now has a self-contained, test-only prototype for the proposed
`source-stage-v2` to Renderer direction-packet-v2 mapping. It consumes
synthetic East, South, and West source candidates from Integration's exact
reserved locator paths in isolated temporary roots. North is deliberately
excluded from that source-adapter loop. A separate quarantine-only
North/East/South/West identity model can now bind one synthetic accepted
pre-lock North packet to the adapted East/South/West packets and prove the
exact 4/4 readiness boundary without activating any product path.

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
a strict, test-local direction-packet harness with separately encoded
synthetic Integration source-admission receipts. Two repeat passes emit
identical direction-local quarantine receipts. A South decoded-hash drift is
rejected without changing the admitted East/West packets, their receipt bytes,
or their batch result. Correcting only the South receipt returns the three-
direction batch to `quarantined_incomplete`; North remains the sole missing
direction and atomic assembly is rejected.

The strict test-local harness also exposed and corrected three assumptions in the
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

## Current-master portability repair

Integration's disposable replay of `88a3d423` plus `8bf6b1d5` on exact
published master `aeaecb0bef4e7fe1e9670b1d57bd49b50b4eeab7` exposed that the
two new tests still referenced historical Renderer-only packet-file harness
types. Implementation commit
`95678368a144dec7e7f488b0cb5f3280bdf78e14` replaces those references with
private synthetic admission, quarantine, strict-shape, isolation, and receipt
types built entirely on the already integrated `L4AdapterRendererPacket`.

The exact range was then replayed in a fresh disposable clone:

1. base `aeaecb0bef4e7fe1e9670b1d57bd49b50b4eeab7`;
2. `88a3d423` replayed as `448add7d`;
3. `8bf6b1d5` replayed as `33973db1`; and
4. `95678368` replayed as `43403fad`.

`swift test --package-path Native/CitySimNative --filter
IndustrialL4SourceStageAdapterPrototypeTests` compiled the complete current-
master test target and passed 6/6 with zero failures. The repaired source file
contains zero references to the six historical packet-file harness/model/
validator symbols implicated by the return. No broad Renderer history or
prerequisite file was imported.

## Four-direction quarantine repair

Implementation commit `009e28e2` removes the unreachable-readiness defect
without adding North to `L4AdapterDirection` or to its East/South/West adapter
loop. The quarantine layer now has its own exact
`{north,east,south,west}` identity model.

The focused proof binds a synthetic accepted pre-lock North packet/admission
to the three adapted sibling packets. It proves:

- three admitted siblings remain `quarantined_incomplete` with North missing;
- a bad North admission returns only North while all three admitted packet and
  receipt byte identities remain unchanged;
- the corrected North receipt is repeat-identical;
- the exact fourth packet changes the result to
  `ready_for_atomic_assembly`;
- `requireReadyForAtomicAssembly` succeeds;
- all four packet/admission bindings and one shared appearance lock are
  revalidated at the join;
- all four source, geometry, component-manifest, packet, and admission
  identities remain unique;
- all 12 LOD and 32 D4 identities remain unique; and
- runtime mapping, shipping resources, and production selection remain false.

No real North packet or source admission was consumed. This is synthetic
quarantine-readiness evidence only.

## Exact published-master replay

The complete relevant range plus `009e28e2` was replayed in order onto exact
published master `54658b2e4ef159185153ae3daa788f6f248d1e6e`.
The initial adapter/proof/portability patches were already patch-equivalent in
that master. The remaining replay commits were:

1. `88a3d423` -> `2b134405`;
2. `8bf6b1d5` -> `0912846c`;
3. `95678368` -> `14ea491d`;
4. `350763ba` -> `295e086f`; and
5. `009e28e2` -> `fc098b77`.

The replay passed:

- `IndustrialL4SourceStageAdapterPrototypeTests`: 7/7, zero failures;
- `IndustrialL4`: 34 executed, 32 passed, two expected caller-input skips,
  zero failures; and
- `git diff --check`.

Historical branch-local totals of 40 tests and three file-harness tests are
superseded for portability purposes. The long-lived Renderer branch currently
contains additional retained test surfaces and reports 41 IndustrialL4 tests;
that count is not the current-master adoption gate.

## Owned paths

- `Native/CitySimNative/Tests/CitySimNativeTests/IndustrialL4SourceStageAdapterPrototypeTests.swift`
- `docs/production/evidence/PLAY-073/industrial-l04-source-stage-adapter-prototype-v1/`

## Import order

1. Published master `54658b2e4ef159185153ae3daa788f6f248d1e6e`.
2. `88a3d423689bc28bc6c7090abe6f4507150f8a62`.
3. `8bf6b1d5cdddee2d4361d97a583c0d8165e93fa9`.
4. `95678368a144dec7e7f488b0cb5f3280bdf78e14`.
5. `350763baf0b4b714e747aed4789167a99525bc61`.
6. `009e28e2` four-direction quarantine repair.
7. The evidence descendant containing this record.

## Stop conditions

Stop on any real or provisional source packet, missing North authority,
authority/hash/path drift, alias/transform/fallback, request for admission or
quarantine acceptance, shared schema/contract change, runtime/resource/atlas/
manifest/package mutation, app staging, or production selection.
