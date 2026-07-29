# Industrial L4 directional bridge v06 acceptance

- **Disposition:** Accepted as the zero-pixel coordinate authority
- **Source candidate:** `3e01ca6738d7574718f9aeff4b66771eee109feb`
- **Integrated proof commit:** `3d76fab8a45807c34198a6d8bb1dd1eeff7be51e`
- **Mapping contract SHA-256:**
  `5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7`
- **Repeat proof SHA-256:**
  `21cea6b32cda57fc2b9c4642f4f16d4150961aad98f4cd671d8e7935b0dc4c4b`

Integration accepts the single right-handed global basis:

```text
B(CitySim[x,y,z]) = Blender[z,x,y]
```

It applies without a per-direction transform or footprint permutation to
component positions and dimensions, camera position and target, direction
normals, light and shadow vectors, footprint points, pivot, and frontage
sockets. Descriptor contact order is `[0,1,2,3]`.

| Direction | CitySim socket | Blender-native socket | Source-pixel socket |
|---|---:|---:|---:|
| North | `[0,0,-28]` | `[-28,0,0]` | `[896,704]` |
| East | `[28,0,0]` | `[0,28,0]` | `[896,832]` |
| South | `[0,0,28]` | `[28,0,0]` | `[640,832]` |
| West | `[-28,0,0]` | `[0,-28,0]` | `[640,704]` |

Independent Integration review confirmed:

- the static contract validator passes;
- all four directional sockets, frontage edges, origin, and pivot pass the
  `0.001` source-pixel tolerance;
- maximum observed projection delta is `0.000183105469` source pixel;
- two fresh Blender factory-startup proofs are byte-identical;
- render, ImageGen, normalizer, contact-sheet, and raw-pixel invocation counts
  are all zero;
- `sourceAuthority` and `productionSelected` remain false.

This acceptance releases corrected North zero-pixel architecture and
East/South/West bridge adoption plus zero-pixel revalidation in their exclusive
roots. It does not authorize A/B/C pixels, renderer source admission,
production selection, shipping mutation, or staged-app acceptance. Those
remain blocked until Integration publishes an exact North appearance lock and
post-lock source-production authority.
