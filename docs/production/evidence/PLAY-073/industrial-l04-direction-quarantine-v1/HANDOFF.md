# PLAY-073 Industrial L4 direction quarantine preparation

## Disposition

`BRIDGE_BOUND_AWAITING_DIRECTION_PACKETS_AND_INTEGRATION_REVIEW`

This is a non-shipping renderer intake boundary. It accepts no actual
Industrial L4 source direction, changes no product byte, and grants no source,
assembly, staging, QA, or production authority.

## Exact lineage

- Published authority:
  `aa20d5963c356eee812f66bafff8582215293bbb`.
- Clean synchronization merge:
  `ce6a41f9c401c16cde9c062c3b8ed5caba14f218`.
- Packet schema and validator boundary:
  `56444245f555d2ac50afed995a65c34a95618f8c`.
- Deterministic mutation matrix and rejection coverage:
  `f4c0dcda7a1f2d84d2587ff3cb4e298ce13cd3a4`.
- Canonical source-pixel socket and direction-bridge schema boundary:
  `4e71720f4dc4a724030b51ca19c4edf69d28dfeb`.
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
- the accepted Integration direction-bridge document, source candidate,
  document hash and canonical-mapping hash;
- future Integration-published appearance-lock document, commit, document
  hash, North process-A source hash and decoded-RGBA hash;
- exact source candidate commit/key/decoded-RGBA hash;
- unique authored-geometry, component-manifest and City/Neighborhood/Block LOD
  hashes;
- source-manifest, toolchain and normalization provenance paths and hashes;
- footprint, canvas, source-pixel pivot, occupied bounds, contact polygon,
  southeast shadow, alpha/chroma/hidden-RGB evidence, frontage and canonical
  CitySim source-pixel socket; and
- all eight D4 pixel fingerprints. Alias, mirror, rotation and other
transformed-sibling rejection is computed from those content fingerprints,
not accepted from a trusted boolean.

## Coordinate boundary

Quarantine packets use only the canonical CitySim source coordinate system
`citysim_source_pixels_v1`:

| Direction | Canonical source-pixel socket |
|---|---:|
| North | `[896,704]` |
| East | `[896,832]` |
| South | `[640,832]` |
| West | `[640,704]` |

All four retain source-pixel pivot `[768,896]`. No Blender-native, DCC-native
or packet-claimed world-coordinate mapping is encoded or trusted. A packet
cannot decode without the direction-bridge record, and admission rejects any
bridge document/candidate/hash/mapping mismatch. The bound accepted authority
is:

- document:
  `docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-DIRECTIONAL-BRIDGE-V06-ACCEPTANCE.md`;
- source candidate:
  `3e01ca6738d7574718f9aeff4b66771eee109feb`;
- document SHA-256:
  `9765d88191d8a555de41dcccfb83b3da16d8f1423d534d66312ffa98a4615208`;
- mapping-contract SHA-256:
  `5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7`.

The packet test hashes both published files directly. The returned v05
candidate `b8f85934563376727be70fee34fcf88c780b5d9f` rejects as stale, and a
packet with a mismatched mapping hash rejects. Actual direction payloads and
the future appearance lock remain unavailable; synthetic source/LOD/lock
values remain test fixtures only.

The pure test-only quarantine accumulator proves:

- `0` packets → `inactive`;
- `1–3` exact packets → `quarantined_incomplete`, preserving every accepted
  sibling and naming all missing directions;
- `4/4` exact packets → `ready_for_atomic_assembly`; and
- every state remains `productionSelected = false` with no shipping resource
  or runtime lookup mutation.

The catalog guard is candidate-neutral: it compares the maximum accepted
Industrial level before and after the mutation matrix instead of requiring a
particular baseline level. It therefore proves the same non-mutation invariant
on accepted master, where Industrial L2 is current, and on the preserved
replacement-R2 branch, where Industrial L3 is present.

`ready_for_atomic_assembly` is only an intake disposition. Integration must
still authorize exact 4/4 atomic assembly, candidate-only staging, PLAY-075,
shipping ingestion and production selection separately.

## Validation

Final focused command:

```bash
CLANG_MODULE_CACHE_PATH=/private/tmp/play073-l4-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/play073-l4-swift-cache \
swift test --package-path Native/CitySimNative --filter IndustrialL4Direction
```

The exact `IndustrialL4Direction` filter passed **7 tests, 0 failed** in
**0.279 seconds**. The first attempt passed 6/7 but exposed an obsolete test
guard: a broad lowercase `dcc` substring check matched characters inside the
accepted opaque document SHA. The guard now rejects only actual forbidden
coordinate field names; candidate evaluation did not change. The broader
previously recorded `IndustrialL4` result remains **9 passed, 0 failed** and
was not rerun under the tiered intake rule.

The schema parses with `jq`; `git diff --check` passes. No full suite or staged
app was run because this task changes only non-shipping test/evidence surfaces,
and the dispatch explicitly forbids staging.

## Rejection boundary

The validator fails closed on duplicate/missing assembly directions, source or
LOD aliasing, any sibling identity equal to a packet's mirror/rotation
fingerprint, incomplete provenance, CONTRACT-021 or appearance-lock drift,
direction-bridge drift, registration/frontage/canonical-source-socket drift,
fallback references, non-ready sources and any production-selected packet.

Actual direction quarantine remains blocked until World Art returns an
independently accepted, Integration-authorized exact source packet and
appearance lock. Synthetic packet/source/LOD/lock hashes in the tests are
validator fixtures only and must never be copied into an actual source
handoff. The direction bridge is no longer synthetic: it is the exact accepted
v06 authority above.
