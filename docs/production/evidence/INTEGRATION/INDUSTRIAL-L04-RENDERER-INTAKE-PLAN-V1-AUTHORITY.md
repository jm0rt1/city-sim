# Industrial L4 Renderer intake plan v1 authority

- **Published base:** `9217e64c796fef3e9d45d0726453157e70b4ef16`
- **Batch:** `industrial_l04_directional_family`
- **Renderer claim:** `PLAY-073`
- **Renderer thread:** `019f7c8a-69a2-78c2-ae70-fa23ee7bfcd0`
- **Renderer branch:** `codex/citysim-world-rendering`
- **Disposition:** `AUTHORIZED_CANDIDATE_NEUTRAL_NONSHIPPING_INTAKE_PREPARATION`

This authority makes Renderer intake-ahead executable without claiming that an
Industrial L4 source exists. It freezes the four logical IDs, twelve LOD slots,
directional registration, failure isolation, read-only fixture/camera
expectations, per-direction quarantine graph, and later single-writer atomic
assembler assignment. It grants preparation only.

## Frozen executable controls

| Control | SHA-256 |
|---|---|
| `industrial-l04-renderer-intake-plan-schema-v1.json` | `a2f7fe762f3f79ea95286284224161dbaddf152e8af174ead6365fda3da060fa` |
| `industrial-l04-renderer-intake-plan-v1.json` | `1f3877c85f665ac4d35ecf2b8ec883e3cd2b0d125ffe0c385a31829137f0887e` |
| `validate_industrial_l04_renderer_intake_plan_v1.py` | `68890a663c2c710addc14b57e63b8a937d999a1c2b0fc2c0864626dbbbb8a89a` |
| `test_validate_industrial_l04_renderer_intake_plan_v1.py` | `e9d2c7ae63e6b8ea9365e484cd7a8ed4b6f81dc1ca9d0737ad219af941f75817` |

The plan itself binds twenty exact current-master inputs, including
CONTRACT-010, CONTRACT-021, the direction bridge, source-stage and admission
controls, non-alias inventory, existing Renderer quarantine and atomic
assembler tool plus its exact Swift harness, current Industrial L3
catalog/source/shipping identities, and the candidate-neutral mature-city
fixture/camera preflight.

## Authorized preparation

Renderer may prepare, under its existing claim and single visible thread:

- exact `industrial_l04_v0_<direction>` identity and
  `city`/`neighborhood`/`block` slot assertions;
- read-only placement descriptors against the bound accepted-L3 mature-city
  fixture;
- regular and compact City/Neighborhood/Block camera and LOD expectations;
- four independent quarantine invocations and evidence roots, one per
  direction;
- the non-shipping atomic-assembler invocation that remains blocked on an
  Integration-published exact 4/4 input manifest; and
- deterministic synthetic validation evidence under
  `docs/production/evidence/PLAY-073/industrial-l04-renderer-intake-plan-v1/`.

This authority does not grant edits to the bound PLAY-075 fixture or camera
artifacts. They are read-only inputs used to remove arrival-time setup delay.
It does not grant an app build, launch, capture, measurement, or score.

## Direction-local intake and failure isolation

North, East, South, and West each have one prepared quarantine job with an
exclusive task-owned output root. Each job remains
`prepared_blocked_waiting_source_admission` until its exact
Integration-issued source-admission receipt exists. Once separately
dispatched, a failure returns only that direction. It may not discard,
invalidate, or delay a successful sibling quarantine.

One through three exact directions remain `quarantined_incomplete`. They may
not activate a family, enter the shipping atlas, alter runtime mapping, or
stand in for the missing direction.

## Exact 4/4 assembly boundary

The plan contains the exact Swift `L4V2AssemblyInputManifest` field layout:
top-level `acceptedL3Baseline`; its `commit`, `catalog`, and
`industrialL3Manifest` children; and direction entries containing only
`direction`, `packet`, `sourceAdmission`, `quarantineReceipt`, and six
locators. The shipping-manifest hash remains a separately frozen intake input;
it is not an assembler-manifest field. All future packet, admission,
quarantine, and locator bindings are explicitly null.

Integration is the only writer that may replace those placeholders. After all
four direction-local source admissions and Renderer quarantine receipts exist,
Integration may publish a separate manifest whose disposition changes from
`integration_assembly_input_unbound_template` to
`integration_assembly_input_admitted`. This preparation authority cannot make
that transition itself.

The fourth exact quarantine is a same-turn trigger. Integration must publish
one immutable, fully bound 4/4 manifest and dispatch job
`industrial-l04-atomic-assembler-v1` to the canonical PLAY-073 Renderer thread.
The assembler is the already retained test-owned wrapper at SHA-256
`f5a4c672a76b005385fb66fbcf87a55b71477b9cd67f59a63ae313371cf8a5ab`.
Its only authorized output is an `atomic-admission-ledger-v1` with runtime,
shipping, and production flags false.

Atomic assembly does not authorize atlas packing, shipping-manifest mutation,
runtime selection, staging, QA, or production selection. Those remain
serialized Integration authorities after exact source and candidate review.

## Automatic rejection

The semantic validator rejects:

- missing, extra, reordered, or aliased direction identities and LOD slots;
- accepted-master or sibling alias, fallback, mirror, rotation, or other D4
  transform equivalence;
- frontage, socket, pivot, footprint, contact, canvas, LOD, contract, or bridge
  drift;
- stale source-stage, admission, quarantine, fixture, camera, catalog,
  shipping-manifest, or assembler inputs;
- path traversal, symlink escape, duplicate direction output roots, or a second
  Git index writer;
- any prebound source or assembly field before Integration admission;
- partial-family activation; and
- any runtime, package, shipping, production, app, QA, integration, or push
  grant.

## Validation

Run from the repository root:

```bash
PYTHONPYCACHEPREFIX=/private/tmp/citysim-intake-pycache \
python3 .agents/skills/operate-citysim-integration/scripts/validate_industrial_l04_renderer_intake_plan_v1.py

PYTHONPYCACHEPREFIX=/private/tmp/citysim-intake-pycache \
python3 .agents/skills/operate-citysim-integration/scripts/test_validate_industrial_l04_renderer_intake_plan_v1.py

CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-intake-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-intake-swift-cache \
swift test --package-path Native/CitySimNative \
  --filter IndustrialL4V2SourceAdmissionHarnessTests
```

The schema and semantic adversarial suite performs no DCC, rendering,
normalization, pixel creation, GUI operation, staging, integration, or push.

Compatibility validation also derives the accepted manifest key sets directly
from the bound Swift `validateManifestShape` implementation and confirms that
the bound shell tool invokes
`testCallerSuppliedAtomicAssemblyManifest`. The focused native harness suite
must remain green; its caller-supplied case remains intentionally skipped until
Integration publishes the later admitted 4/4 manifest.
