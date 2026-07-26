# PLAY-027 Industrial L2 source-v05 lighting proposal

**Status:** proposal only. No source-v05 descriptor, material, raw,
normalization, provenance, or production-selection file has been created.
Integration authority is required before implementation.

## Causal basis

The unchanged East source-v04 descriptor is nondeterministic under the current
Lambert plus SceneKit-light interaction. Three fresh Apple M5 Pro processes
with all SceneKit materials forced to `.constant` and both scene lights
disabled emitted one exact file SHA and one decoded-pixel SHA. Registration,
silhouette, authored contact/footprint shadow, alpha, chroma, occupied bounds,
geometry, and material colors were unchanged.

The combined isolation proves the dynamic material-light interaction is the
unstable stage. It does not separately assign causality to Lambert evaluation,
the directional key, or the ambient light. The source-v04 rejection remains
binding.

## Proposed descriptor-bound mode

If integration authorizes source-v05, add one backward-compatible schema-2
sampling field whose semantic value binds the complete offline lighting mode:

```text
sceneKitLightingMode: authored-constant-v1
```

`authored-constant-v1` would require:

- every SceneKit geometry material uses `.constant`;
- every SceneKit scene light has zero intensity and cannot cast a shadow;
- no CLI override can produce source authority;
- no-MSAA, SceneKit shadows disabled, 4x linear oversampling, software
  `CILanczosScaleTransform` at 0.25, the frozen step-32 quantizer, compositor,
  and schema-2 v3 canonicalizer remain unchanged;
- the southeast contact/footprint shadow remains authored geometry;
- the toolchain fingerprint and provenance bind the mode and count the
  affected materials and disabled lights.

The resolver would default the field to the current Lambert/scene-light path
for every accepted descriptor and for source-v04. Only
`industrial_l02/source-v05` could resolve `authored-constant-v1` under the
initial authorization. This proposal does not change any shared runtime,
shipping contract, accepted source, or default renderer behavior.

## Authored shading recovery

The literal comparison shows that constant/unlit rendering preserves the
industrial silhouette and detail but flattens the northwest-key value
hierarchy. A source-v05 pre-pixel design should recover that hierarchy through
new task-owned, source-revision-specific authored material roles rather than
SceneKit lighting:

- freeze a separate Industrial L2 source-v05 material library so accepted
  Industrial L1 and source-v04 bytes remain immutable;
- author explicit northwest-lit, side-plane, recess, roof, trim, glazing, and
  loading-throat value roles with a fixed grayscale ladder;
- assign those roles independently in the N/E/S/W descriptors according to
  each authored plane and frontage composition, without rotating or mirroring
  a sibling;
- preserve the existing material identities and colors as family anchors while
  introducing only the value offsets needed to restore roof/facade depth,
  recessed loading-bay hierarchy, and premium hazard/trim separation;
- keep the authored southeast/contact shadow geometry, footprint, pivot,
  socket, camera, massing, and all registration coordinates fixed.

Before any pixels, integration should review the additive schema rule,
source-v05-only resolver guard, toolchain fingerprint, four descriptor hashes,
new material-role hashes, grayscale ladder, and accepted-source preservation
report. Only a separately authorized gate should render N/E/S/W in three fresh
processes and consider normalization.

## Required future regression

Any authorized implementation should prove:

- all accepted Residential, Commercial, and Industrial L1 descriptors still
  resolve and reproduce through their existing lighting modes;
- source-v04 remains byte-addressable and rejected;
- diagnostic CLI lighting cannot write outside `diagnostics/`;
- source-v05 N/E/S/W raw file and pixel identity across three processes;
- exact RGBA/completeness, frontage, pivot, socket, shadow, and registration;
- grayscale recovery at source, native-2x, and all normalized LOD scales before
  independent art review.
