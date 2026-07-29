# PLAY-027 Industrial L4 directional bridge v06

**Disposition:** `PENDING_INDEPENDENT_COORDINATE_BRIDGE_REVIEW`

The candidate global basis is:

```text
B(CitySim[x,y,z]) = Blender[z,x,y]
```

Two fresh Blender 4.5.12 LTS factory-startup, camera-only processes produced
byte-identical machine proofs. The unpermuted contact polygon projects in
descriptor order, all canonical N/E/S/W socket midpoints and frontage edges
project within `0.001` source pixel, and the maximum observed absolute delta is
`0.000183105469` source pixel. The basis is right-handed with determinant
`+1`; it changes neither winding nor source order.

The v06 proof explicitly supersedes these v04/v05 assumptions:

- Blender-native `[-28,0,0]` is not CitySim North; it is the image of
  canonical CitySim North socket `[0,0,-28]` under the global basis.
- CitySim North is `z=-28`, not `x=-28`.
- CitySim North outward normal is `[0,0,-1]`, mapped to Blender
  `[-1,0,0]`; it is not a Blender-native direction relabeled as CitySim.
- The contact polygon uses descriptor order `[0,1,2,3]`; the historical
  `[0,3,2,1]` reorder is forbidden and absent.
- Passing source-space registration cannot validate a mismatched world-space
  coordinate label.

No geometry revision, source pixel, render call, ImageGen call, normalization,
contact sheet, raw process, sibling mutation, or production selection occurred.
North v07 geometry and A/B/C remain unauthorized and unproduced.
