# PLAY-027 Commercial L4 source-v02 rejection

## Disposition

Commercial L4 `source-v02` is rejected before normalization. The committed
descriptor boundary is
`d6df5e256863a7fe9c6b8d690eec77a7711558f3`. Exactly three fresh renderer
processes were run for each independently authored direction. Preserve all
four primary raws, all eight repeat raws, all twelve provenance records, the
repeat/uniqueness reports, and the exact-RGBA report and occupied-crop sheet.

No `source-v02` byte is accepted, normalized, production-selected, or
authorized for renderer/shipping ingestion.

## Raw repeat result

| Direction | Primary file SHA-256 | Run B file SHA-256 | Run C file SHA-256 | Pixel identities | Result |
|---|---|---|---|---:|---|
| north | `6e6f922169ff6b762d34343e79a4797240a10c9b80eddb3ed58789331cb328d3` | same | same | 1 | pass |
| east | `9f724ceae603a0b84e9c750f3168a791f6485d6ef8adf1d76aae4f2b05c161cb` | same | same | 1 | pass |
| south | `846c849b8f131faee41b569c387d957f53cee772f0f667098ec6b516b4077d41` | same | same | 1 | pass |
| west | `fd652cada0a87cbd90aa415b82c8a157eae114632b6c831dc99d0d7414a71146` | `7d5fbba2e15fc2742d689d7800c89280b181275d73dd3d9bce5a62059574e91c` | same as B | 2 | reject |

The west primary canonical pixel SHA-256 is
`05bd2543d624772a781c674f3e7d57522f97357143098d5dc70e84b0e0ceccbe`;
runs B and C share
`9eeefea7342355e47ceb151ad0d990e57d858ca743a0a9181a5c9d9fd0295ea2`.
This violates the exact fresh-process pixel-identity contract even though the
two west variants have the same occupied bounds and occupied-pixel count.

## Retained passing evidence

- Primary N/E/S/W raws have four unique pixel identities.
- All twelve raws are 1536 x 1024, fully opaque raw chroma sources with flat
  chroma corners and passing minimum occupancy/bounds checks.
- Exact-RGBA review reports alpha visibility ratio `1.0`, zero hidden
  non-magenta pixels, and matching RGB/alpha-visible occupied bounds in all
  directions.
- The exact occupied-crop sheet visibly contains the complete tower,
  footprint plate, southeast shadow, crown, and direction-specific lobby in
  N/E/S/W.
- The descriptor gate remains independently valid: four unique descriptors,
  four unique geometry IDs, exact registration, and zero coincident authored
  structural Y boundaries in each direction.

These passing checks do not waive west repeat nondeterminism.

## Diagnostic boundary

The non-coplanar descriptor repair was necessary but not sufficient. With
authored structural boundary coincidences eliminated, the remaining west-only
split may originate in renderer-created subgeometry, shadow rasterization, or
another native SceneKit ordering boundary not represented by the descriptor
envelope audit.

Freeze Commercial L4 at this rejection checkpoint. Do not author `source-v03`,
normalize, or propagate a workaround until integration reviews the retained
exact bytes and authorizes a specific next diagnostic.
