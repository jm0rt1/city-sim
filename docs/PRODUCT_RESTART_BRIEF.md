# CitySim restart brief

## Next outcome

Make one representative city block look intentional and coherent inside the
running game. Do not expand gameplay scope until that result is visibly better.

## Visual rules

- Every visible building uses one canonical near-orthographic/isometric camera
  family: consistent roofline slope, facade exposure, footprint axes, base,
  pivot, and ground contact.
- Use one lighting and shadow language. Do not hide mismatched art through
  per-asset rotation, skew, or camera hacks.
- The city, not diagnostic chrome, is the dominant view. Keep details available
  without permanently consuming the playable map.

## Proof of success

Compare the real composed game screen before and after at 1280x800 and 900x600.
The block must read as one world, remain map-dominant, and support the intended
player interaction. A passing build or isolated component test is not enough.

## Working rule

Use one accountable implementer for this outcome. Bring in a short-lived
specialist only for a genuinely independent, bounded contribution. Keep the
task brief and proof in the task itself; do not create a standing operational
control plane.
