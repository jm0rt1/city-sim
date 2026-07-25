# PLAY-027 Industrial L1 source-v01 raw disposition

**Disposition:** rejected before normalization

## Retained technical result

- Three fresh native SceneKit processes per direction are preserved.
- All four primary/B/C triplets are byte- and pixel-identical.
- The four primary raw identities are unique.
- All exact retained PNGs are fully alpha-visible:
  - alpha-visible/RGB occupancy ratio `1.0`;
  - zero hidden non-magenta pixels;
  - matching RGB and alpha-visible occupied bounds;
  - flat opaque chroma corners.
- Scene descriptors remain independently authored and untransformed.

Primary raw SHA-256:

| Direction | SHA-256 |
|---|---|
| north | `008d6a17ad4780951ca26c0610d4dc4e58a695f0399a1677ff2e6b4e70472b49` |
| east | `a5bdb4158b5f324b62b9d178f5f284a945c27c8807507ea2a2e0b3d2661c583c` |
| south | `342aeda71fd25020f3361e240f0b87f00de0826e0efe53e66e7afe5f0e4cc200` |
| west | `0102bca80e40073a475a3052ba47a24b8e8e100e780e61e52008c7e4bae879e2` |

## Rejection reason

Direct inspection of `EXACT-RGBA-OCCUPIED-CROPS.png` rejects the set as art:

- east presents a complete, grounded roll-up loading bay and dock;
- south retains a service canopy but the roll-up door hierarchy is marginal;
- north hides the primary road-facing loading bay behind the warehouse mass,
  leaving only a tiny safety-colored return cue;
- west likewise reduces the declared frontage to a small personnel-scale
  return at the base of an otherwise blank wall.

North and west therefore fail frontage correctness and native-scale industrial
recognition even though their hashes, occupancy, and alpha are valid. This is
the same class of far-edge occlusion defect that cannot be waived by technical
determinism.

No source-v01 raw is accepted, normalized, or production-selected.

## Preserved diagnostic trail

The first sandboxed north render and an accepted Commercial control both
stopped at `SceneKit could not prepare the complete scene graph` without
emitting Industrial pixels. The same accepted control passed under the native
graphics context, proving a host/sandbox limitation rather than scene
geometry. All twelve authoritative processes then ran under that fixed native
context.

Two exact-byte occupancy reference probes are preserved under `diagnostics/`:

1. Commercial L4 was rejected as a size reference because its tower occupied
   at least 94,536 pixels; Industrial L1 intentionally occupies about 60,000.
2. Residential L1 nearly passed, but its 276-pixel minimum height made the
   complete 260-pixel West warehouse miss a generic 0.95 height ratio by
   0.008.

Those cross-family height mismatches are not hidden-RGB defects. The binding
within-set exact-byte report passes against independent Industrial N/E/S
envelopes. Literal Residential and Commercial non-alias comparisons remain
required later.

## Repair boundary

Source-v02 may change only task-owned Industrial L1 scene/renderer geometry.
It must ground a clearly visible loading-bay-scale cue for North and West
without moving the authoritative socket, transforming a sibling, or changing
the accepted schema-2 v3 sampling contract. Source-v01 descriptors, raws,
provenance, repeats, reports, and crops remain immutable rejection evidence.
