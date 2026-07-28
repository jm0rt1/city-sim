# PLAY-027 Blender North registration calibration v02 — pre-pixel disposition

**Disposition:** `PASS_PREPIXEL_PROJECTION`

This successor calibration preserves the complete rejected v01 packet. Its
only rendering change is the authorized landscape conversion:

```text
aspect = renderViewportPixels.width / renderViewportPixels.height
ortho_scale = 2 * SceneKit orthographicScale * aspect
```

For the immutable 1536×1024 North descriptor, the configured Blender value is
`237.58786010742188` (the binary representation of the governed
`237.5878601074218`). `shift_x=0` and `shift_y=0.125` remain unchanged.

The actual configured Blender camera resolves:

- footprint: `[768.0,640.0]`,
  `[1024.0000305175781,767.9999389648438]`,
  `[768.0,895.9999237060547]`,
  `[512.0000152587891,767.9999694824219]`;
- pivot: `[768.0,895.9999237060547]`;
- socket: `[896.0000610351562,703.9999694824219]`; and
- edge contact: `false`.

Every absolute coordinate error is below one source pixel. The zero-render
proof constructs all 51 governed geometry components and the exact configured
camera, then exits before any `bpy.ops.render` call.

## Bound hashes

- descriptor:
  `3696b813e6c3e0f46251e689582163bdbdcc5d84a3a9c1125bfbefba37da2630`
- material library:
  `147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202`
- calibration contract:
  `8dc1a31e9dd7c114523f46b66128d5c99114ab32df8da52ddc9ca8d41f23f962`
- renderer/importer:
  `f3ba911b2b69296831ad133c50905b8226a1f4360a5a52e5311a357e18d2f1d8`
- validator:
  `4db8f33b9e324b12946d27f63f0d0586ef6334e244cda89347302a3fa16177ef`
- toolchain fingerprint:
  `e4e658c5131169e1edfc3a2aca6f5d86424926866ec17dd7f534c43b4808ee32`
- validation:
  `24dbf68520cc30a288b5033d2f9a49478dc65b22392a6c505048503aa4e80e24`
- projection proof:
  `153fa1d6d3c590c4767a6cbbb834001d08478e3aa2ec70142ba0acf47fe007ed`
- object mapping:
  `1020c2ef11c56c09ae29beb168a84f8bcd4d13c5f4aa306eaaebc735015076e5`

## Process accounting

- Blender projection-only processes: 1 successful final proof
- Blender render processes: 0
- SceneKit/Metal processes: 0
- normalizer processes: 0
- source authority: false
- production selected: false

The fresh A/B/C render cadence remains unconsumed at this checkpoint.
