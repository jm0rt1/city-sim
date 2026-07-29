# PLAY-027 Industrial L3 source-v06 material repair authority

- Exact causal trace checkpoint:
  `722c8c5456f58716827adee598c48361d0ee0295`
- Exact rejected source-v05 raw checkpoint:
  `baa444fb3e34f8aa72c6d9ae74955b8c591eea3d`
- Integration disposition: `AUTHORIZE_PREPIXEL_MATERIAL_REPAIR`
- Authorized directions: North and West only
- Authorized new revision: `source-v06`
- SceneKit/raw processes: `0`
- Normalization: `false`
- Source authority: `false`
- Production selected: `false`

The trace proves that all governed repeat splits begin in immutable
post-Lanczos prequantized support. The resolver, quantizer, canonicalizer,
geometry, camera, frontage, registration, occupancy, and alpha remain stable.
The corrective surface is therefore the authored material input, not the
approved geometry or the deterministic contract.

## Analytical ownership gate

Before creating source-v06, add a standalone task-owned analytical projection
tool that does not invoke SceneKit. It must read the exact source-v05
descriptor, material library, camera, explicit geometry, and these four raw
coordinates:

- North `(688,391)`;
- North `(795,748)`;
- West `(847,391)`;
- West `(786,524)`.

For each coordinate, back-project the full positive Lanczos support into the
4x scene, ray-intersect and depth-sort explicit primitives/faces, and report
primary/secondary primitive and material contributors with kernel-weight
coverage. Attribution passes only when the expected primary material owns at
least 80 percent of positive support:

| Coordinate | Expected primitive role | Expected material |
|---|---|---|
| North `(688,391)` | North high-bay parapet trim | `l3c-charcoal-outline-steel` |
| West `(847,391)` | West high-bay parapet trim | `l3c-charcoal-outline-steel` |
| North `(795,748)` | North annex parapet edge | `l3c-warm-trim` |
| West `(786,524)` | West loading-spine edge | `l3c-warm-formed-concrete` |

Stop without source-v06 if any attribution is below 80 percent or identifies a
different primary material. A separately rendered semantic-ID pass is not
authorized by this disposition.

## Exact source-v06 transformation

If attribution passes, create dedicated North/West source-v06 descriptors and
a task-owned source-v06 material-library copy. Preserve every accepted
source-v05 geometry, transform, camera, footprint, pivot, socket, door-base,
height, light, shadow, sampler, pattern, roughness, metalness, and material
assignment. Change only:

1. `l3c-charcoal-outline-steel.baseColorRGBA[0]` by exactly `+2/255`;
2. `l3c-warm-trim.baseColorRGBA[0]` by exactly `+2/255`;
3. `l3c-warm-formed-concrete.baseColorRGBA[2]` by exactly `+2/255`;
4. source revision/binding from `source-v05` to `source-v06`;
5. task-owned library/descriptor/geometry IDs and provenance needed to name
   the new revision.

The positive sign moves the implicated samples away from the retained
`23/24`, `183/184`, and equivalent blue-channel boundaries toward the local
quantized majority while remaining visually sub-perceptual. The cumulative
delta may not exceed `2/255`; do not try the opposite sign or a wider delta
under this authority.

## Required pre-pixel checkpoint

Retain:

- analytical attribution JSON and a deterministic support/ownership panel;
- exact v05 versus v06 descriptor and material-library hashes;
- a machine diff proving only the authorized fields changed;
- material swatch and grayscale comparisons at enlarged and native scale;
- replay-identical pre-pixel frontage, silhouette, socket, registration, and
  structural reports; and
- explicit `sourceAuthority=false` and `productionSelected=false`.

Commit one clean pre-pixel source-v06 candidate and stop. Do not edit the
source-v05 descriptors/library, add resolver authority, render pixels,
normalize, touch East/South, change the canonicalizer, modify renderer or
shipping surfaces, begin L4/A2, push, or self-accept.
