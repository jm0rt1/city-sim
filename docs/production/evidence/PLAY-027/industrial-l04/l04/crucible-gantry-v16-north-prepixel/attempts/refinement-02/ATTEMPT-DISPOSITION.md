# PLAY-027 Industrial L4 North v16 refinement 02

`REJECTED_MACHINE_AND_LITERAL_VISUAL_GATE`

This is the second and final authorized visual refinement of the same
L-shaped side-return layout.

Improvements over refinement 01:

- North throat remains valid at `7.6665193728056558` compact pixels.
- All four structural apertures now have zero positive-solid overlap.
- Freight 3 retains a valid empty-aperture-first, inset-back-plane-second ray.
- Each side-return freight aperture projects to about `4.0` compact pixels
  wide and `5.26–5.96` compact pixels high.
- Registration/contact remains fixed and the v14 material hierarchy is
  byte-preserved.

Binding failures:

- Freight 1 remains occluded by the north gantry girder, trolley, and south
  lower flange.
- Freight 2 remains occluded by the crucible upper body and west gantry pier.
- The separate staff inset plane remains occluded by its own right reveal.
- Literal exact-192 color and grayscale still expose only one truthful
  recessed freight depth; the grouped logistics return and separate staff
  opening do not survive unaided.

No third refinement, threshold change, raw render, normalization, or replay
identity gate was run.
