# PLAY-073 Industrial L4 direction quarantine preparation

## Disposition

`PREP_COMPLETE_AWAITING_INTEGRATION_REVIEW`

This is a non-shipping renderer intake boundary. It accepts no actual
Industrial L4 source direction, changes no product byte, and grants no source,
assembly, staging, QA, or production authority.

## Exact lineage

- Published authority:
  `30af21b5a3cbabb26c415f76d8ce35934dcc5082`.
- Clean synchronization merge:
  `183d9fe6456ea8d53398415fd64315b6d1a44db2`.
- Packet schema and validator boundary:
  `56444245f555d2ac50afed995a65c34a95618f8c`.
- Deterministic mutation matrix and rejection coverage:
  `f4c0dcda7a1f2d84d2587ff3cb4e298ce13cd3a4`.
- Preserved R2 product/evidence prerequisites remain ancestors:
  `25d291a7373833a797dc3bb3ba36658e18eccc06` and
  `de6805092478c97d85f0230c93f7f10edcb257e6`.
- The candidate-bound external fixture checkpoint remains preserved at
  `cdcd1e92b2864f7f5c5ad879ee015ca2179459bd`; it is still not independently
  adoptable on master.

## Outcome

The machine-readable direction packet binds:

- Industrial L4 family, level, variant, logical direction and logical ID;
- CONTRACT-021 revision 2 and exact contract hash;
- future Integration-published appearance-lock document, commit, document
  hash, North process-A source hash and decoded-RGBA hash;
- exact source candidate commit/key/decoded-RGBA hash;
- unique authored-geometry, component-manifest and City/Neighborhood/Block LOD
  hashes;
- source-manifest, toolchain and normalization provenance paths and hashes;
- footprint, canvas, pivot, occupied bounds, contact polygon, southeast
  shadow, alpha/chroma/hidden-RGB evidence, frontage and socket; and
- all eight D4 pixel fingerprints. Alias, mirror, rotation and other
  transformed-sibling rejection is computed from those content fingerprints,
  not accepted from a trusted boolean.

The pure test-only quarantine accumulator proves:

- `0` packets → `inactive`;
- `1–3` exact packets → `quarantined_incomplete`, preserving every accepted
  sibling and naming all missing directions;
- `4/4` exact packets → `ready_for_atomic_assembly`; and
- every state remains `productionSelected = false` with no shipping resource
  or runtime lookup mutation.

`ready_for_atomic_assembly` is only an intake disposition. Integration must
still authorize exact 4/4 atomic assembly, candidate-only staging, PLAY-075,
shipping ingestion and production selection separately.

## Validation

Final focused command:

```bash
CLANG_MODULE_CACHE_PATH=/private/tmp/play073-l4-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/play073-l4-swift-cache \
swift test --package-path Native/CitySimNative --filter IndustrialL4
```

Result: **7 passed, 0 failed**. This includes the two pre-existing fail-closed
L4 intake tests, one packet-schema test and four matrix/rejection tests.

The schema parses with `jq`; `git diff --check` passes. No full suite or staged
app was run because this task changes only non-shipping test/evidence surfaces,
and the dispatch explicitly forbids staging.

## Rejection boundary

The validator fails closed on duplicate/missing assembly directions, source or
LOD aliasing, any sibling identity equal to a packet's mirror/rotation
fingerprint, incomplete provenance, CONTRACT-021 or appearance-lock drift,
registration/frontage drift, fallback references, non-ready sources and any
production-selected packet.

Actual direction quarantine remains blocked until World Art returns an
independently accepted, Integration-authorized exact source packet. Synthetic
packet hashes in the tests are validator fixtures only and must never be
copied into an actual source handoff.
