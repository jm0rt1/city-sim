# PLAY-027 built-in ImageGen directional capability limit

**Reference repair checkpoint:** `9fcb514`

**Date:** July 24, 2026

**Disposition:** north source-v03 rejected before normalization; no further
ImageGen calls authorized; alternate pipeline requires integration approval

## Governed probe

Exactly one built-in ImageGen call used the frozen v3 inputs:

1. the immutable accepted global style anchor;
2. the target-face-dominant north registration template;
3. the material-and-scale board cropped deterministically from the accepted
   residential calibration source.

No rejected sibling was referenced. The prompt, three reference hashes, raw
attempt, tool artifact ID, contact sheets, and provenance are retained.

The raw source is 1536 x 1024 and has SHA-256
`1e6d596f1ef607d881936cb2bd630d69619f1eca9472d8b360f14d1bac45882e`.
Its hash is unique among all five retained PLAY-027 attempts.

## Result

The probe retained the desired material family and a usable orthographic
isometric projection. It did not honor the authored frontage:

- the v3 north template makes the complete upper-right plane green and centers
  the doorway base at north socket `(896,704)`;
- the generated source puts its only entry and stoop on the lower near
  south-facing facade;
- the north target plane has windows only;
- all eight retained background samples differ from flat `#ff00ff`, including
  corner RGB values `(241,11,236)`, `(245,15,238)`, `(235,34,232)`, and
  `(241,28,236)`.

The source-scale comparison sheet has SHA-256
`e8ac50eeec3f2eebb153c9de30f62423e849591935431e1c9591f7dc5567e915`.
The exact native-2x actual-scale sheet has SHA-256
`c01665d76f5a345cf110514b550ec4caee460aff395c59e23896934c1b1b3f61`.
Both place the authoritative north template on the left and the raw attempt on
the right.

## Exact capability limit

Across the governed residential probes, built-in ImageGen can recover a
high-quality isometric residential appearance, but it has not preserved an
authored non-near entrance plane/socket or a flat chroma field:

- v2 supplied an explicit named edge, socket, and entrance marker;
- v3 removed the full-building composition prior and made the entire target
  plane the dominant visual instruction;
- the independently justified v3 probe still reassigned the entrance to the
  lower near facade.

The failure is therefore no longer attributable to missing prompt adjectives,
a rejected sibling, or the diagnosed v2 painter-order bias. Further
whole-building prompt iteration is not justified under PLAY-027.

## Proposed alternate authoring pipeline

Integration approval is requested for a four-scene orthographic DCC pipeline:

1. Author one task-owned 1 x 1 scene file per north/east/south/west view.
   Every scene uses the same declared dimensions, pivot, vertical envelope,
   floor/door scale, and family material library, but the facade geometry and
   entrance are authored separately on that view's declared world edge.
2. Use a fixed orthographic 2:1 camera, fixed northwest key, fixed southeast
   shadow receiver, and exact 1536 x 1024 output registration in every scene.
   No raster is mirrored or rotated, and no scene derives a sibling by image
   transformation.
3. Limit built-in ImageGen, if retained at all, to non-compositional material
   swatches. It may not choose camera, massing, footprint, facade, entrance,
   pivot, light direction, or shadow placement.
4. Render oversampled antialiased masters, composite a mathematically flat
   `#ff00ff` field, and retain the DCC source, render settings, texture hashes,
   and raw render for each independently authored direction.
5. Use only existing deterministic normalization for alpha, padding, pivot,
   and export. Keep every output non-shipping and outside renderer ingestion.
6. Accept a four-view set only after unique raw/normalized hashes,
   geometry/socket/projection/light/shadow validation, source- and
   actual-scale N/E/S/W contact sheets, grayscale recognition, and explicit
   accepted/rejected inventory.

This pipeline preserves CONTRACT-006 and CONTRACT-010 boundaries: ImageGen
authors appearance only, registration remains deterministic, all four sources
are separately authored, and PLAY-027 still makes no renderer, atlas,
production-selection, manifest, build, gameplay, simulation, UI, save, or
PLAY-024 change.
