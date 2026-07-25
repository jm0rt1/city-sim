# PLAY-027 directional template v2 repair

**Repair authority:** `80aef87`

**Date:** July 24, 2026

**Disposition:** deterministic repair frozen; one north v02 probe authorized

North and south source-v01 attempts both interpreted frontage language as a
straight-on facade. The original 1 x 1 registration reference correctly
encoded the diamond, pivot, sockets, height and shadow bounds, but it did not
show an unmistakable three-dimensional camera and massing cue.

The task-owned v2 repair adds four deterministic 1536 x 1024 reference images.
Each contains:

- the exact 1 x 1 isometric diamond and 768 x 896 pivot;
- one solid orthographic 2:1 prism, preventing a front-elevation
  interpretation;
- one highlighted named frontage edge, socket, entrance marker and inward
  arrow;
- explicit instructions that guide marks must not be rendered.

The four templates have unique hashes and `orientationTransform: none`. The
source generator and manifest are retained beside them. These are non-shipping
ImageGen references and do not change production geometry.

The residential family anchor is narrowed to materials, floor/door scale and
family identity only. It is explicitly not camera, composition, footprint or
registration authority. No rejected source is referenced.

Per the two-failure rule, the repair authorizes only one
`residential_l01/variant-0/north/source-v02` probe. That raw attempt must be
preserved and reviewed before another sibling call. Renderer ingestion,
shipping selection and PLAY-024 remain untouched.
