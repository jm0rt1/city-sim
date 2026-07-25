# PLAY-027 Industrial L1 source-v02 partial raw disposition

**Disposition:** rejected; family frozen for geometry-template repair

Source-v02 attempted to make North and West loading frontage visible with
renderer-created corner returns. The attempt does not pass the raw gate.

## Retained outcomes

- North emitted three byte/pixel-identical raws.
- East emitted three raws but split into two identities:
  - one green-channel pixel at source coordinate `[845, 771]`;
  - primary/C match; B differs by one quantization quantum.
- South emitted three raws but split into two identities:
  - 107 pixels in bounds `[828, 765, 847, 779]`;
  - the split lies on the lower loading-dock/wall/material intersection;
  - primary/B match; C selects a different depth/material winner.
- West emitted no raw or provenance:
  - exact pre-write diagnostic metrics were 62,078 non-chroma pixels;
  - occupied bounds were `410 x 255`;
  - the immutable renderer floor is `50,000 / 400 x 260`;
  - the failure was therefore five occupied-height pixels, not empty geometry.

The East and South locality reports and contact zooms are retained under
`diagnostics/`. No threshold or canonicalizer rule was changed.

## Visual rejection

Direct inspection also rejects the design independently of the technical
splits:

- North gains a large visible return, but the deterministic footprint/shadow
  treatment becomes visually weak and the return reads detached.
- South still presents a dark projecting mass instead of a clearly legible
  roll-up loading bay.
- West never reaches retained-pixel review.

## Required redesign

Two consecutive source revisions have failed frontage or deterministic raw
gates, so the Industrial family is frozen before another render. Source-v03
must repair the authored geometry template, not prompt wording or sampling:

- use direction-specific warehouse setbacks and grounded dock-house massing so
  the declared frontage is directly visible;
- remove renderer-created corner-return overlap/depth ambiguity;
- keep four explicit descriptors and no sibling transforms;
- preserve exact footprint, pivot, socket, light, shadow, schema-2 v3
  sampling, and `productionSelected: false`;
- preserve all source-v01/v02 descriptors, emitted pixels, provenance,
  failures, and locality evidence.

No source-v02 output is normalized or accepted.
