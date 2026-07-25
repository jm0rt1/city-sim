# PLAY-027 Industrial L2 source-v05 explicit no-MSAA isolation

Disposition: **diagnostic complete; MSAA is not a differentiating causal
variable for source-v05; stop.**

The frozen source-v05 descriptors, materials, geometry, camera, registration,
authored contact shadow, factor-4 oversampling, software Lanczos downsample,
quantizer, compositor, and canonicalizer were not changed. Twelve fresh
Metal-visible processes ran with explicit diagnostic options:

```text
--diagnostic-antialiasing none
--diagnostic-scene-shadows current
--diagnostic-material-lighting current
```

Every provenance record binds the exact diagnostic contract, renderer commit
and binary, Apple M5 Pro device, `sourceAuthority: false`, and
`productionSelected: false`.

## Negative causal result

This is not a true 4x-MSAA-to-no-MSAA counterfactual. The frozen source-v05
schema-2 descriptor already resolves SceneKit antialiasing to `none`; its
descriptor-bound SceneKit shadows already resolve to `disabled`. Explicit
`none/current` therefore changes neither effective setting. The renderer
records that fact in every attempt.

All four diagnostic triplets remain nondeterministic:

| Direction | Frozen maximum split | Diagnostic maximum split | Diagnostic identities |
|---|---:|---:|---:|
| North | 2 pixels | 1,328 pixels in a 44x105 facade-detail band | 3 |
| East | 724 pixels in a 29x95 vertical band | 724 pixels in the same 29x95 band | 3 |
| South | 1 pixel | 4 isolated pixels | 2 |
| West | 1 pixel | 2 isolated pixels | 3 |

East diagnostic run C exactly reproduces frozen East run B at both file and
decoded-pixel identity. West diagnostic runs A and B exactly reproduce the two
frozen West decoded-pixel identities. These recurring identities, combined
with the unchanged effective antialiasing state, disprove MSAA resolve as the
source-v05 differentiating cause.

The diagnostic does distinguish two retained signatures:

- sparse, fully opaque, one-quantum RGB outliers in the frozen N/S/W packet;
- a larger facade-detail presentation band in East, now also observed in one
  North diagnostic identity.

All reported comparisons have zero alpha differences. All twelve raws retain
stable occupied bounds and counts; the 4/4 exact RGBA visibility gate passes
with zero hidden non-magenta pixels. The problem is color/detail identity, not
silhouette, alpha, completeness, pivot, socket, contact, or shadow
registration.

The authorized slice does not isolate whether the residual variation enters
the rendered RGB input or through later quantizer-support response. No stage
capture, new renderer variable, source revision, scene/material/geometry
change, normalization, or production selection was performed. Further causal
isolation requires a new integration disposition.
