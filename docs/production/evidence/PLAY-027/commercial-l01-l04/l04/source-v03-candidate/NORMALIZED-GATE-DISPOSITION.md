# PLAY-027 Commercial L4 source-v03 normalized gate

Commercial L4 `source-v03` passes deterministic normalization and is a
non-shipping review candidate.

## Technical result

- Two independent normalization runs for north, east, south, and west.
- Block, neighborhood, and city outputs match byte-for-byte and pixel-for-pixel
  across all 12 repeat pairs.
- All 12 primary normalized source/LOD identities are unique.
- Zero alpha, exact-chroma, visible-magenta-spill, or padding failures.
- Four normalization provenance pairs are identical.
- Source ground pivot remains `[768, 896]`.
- Uniform object registration remains `410 / 234`.
- `productionSelected` remains false.

The exact per-source/LOD file and decoded-pixel hashes are retained in
`NORMALIZED-UNIQUE.json`; the 12 individual repeat reports are retained under
`normalized-validation/`.

## Visual review packet

The `review/` directory contains:

- unaltered N/E/S/W source-scale raw sheet;
- normalized-alpha native-2x color sheet;
- native-2x grayscale recognition sheet;
- exact registered-footprint native-2x color and grayscale sheets;
- registered zoom sheet;
- hash-complete review manifest.

The task-owned diagnostic comparison packet
`../diagnostics/source-v03-level-comparisons/` contains literal
accepted-level-left versus L4-v03-right comparisons against Commercial L1,
L2, and L3 for source scale, native-2x color, grayscale, registered footprint,
and zoom. The L4 tower is materially taller, more vertically articulated, and
has a distinct stepped crown while preserving commercial storefront/lobby,
mechanical-roof, material, projection, light, shadow, and family identity.

## Boundary

This is not acceptance or production selection. No renderer ingestion,
shipping asset, runtime, shared manifest, package, gameplay, UI, simulation,
save, Industrial, or additional source revision is authorized.
