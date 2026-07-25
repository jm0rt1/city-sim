# PLAY-027 schema-2 raw regression disposition

Disposition: **FAIL — deterministic raw gate stopped**.

No Commercial L4 source-v03, Residential L4 diagnostic render, normalization,
production selection, or shipping/runtime mutation is authorized by this
checkpoint.

## Completed evidence

- The unchanged schema-1 reproduction path produced 12/12 Commercial L1-L3
  N/E/S/W PNGs byte-for-byte and pixel-for-pixel identical to the accepted
  raws.
- Commercial L1-L3 schema-2 diagnostics completed three fresh processes per
  direction: 36/36 renders, with three-process file and decoded-pixel identity
  for every source.
- Residential L1 and L2 West schema-2 diagnostics completed six renders with
  three-process identity.
- Residential L3 West completed three renders. Runs A and B are identical;
  run C differs.
- All 15 completed primary schema-2 raws have unique file identities.
- The exact retained-byte alpha/RGB validator passes all 15 completed
  primaries: opaque chroma corners, zero hidden non-magenta pixels, matching
  RGB/alpha-visible occupied bounds, and occupancy comparable to the accepted
  source.

## Binding failure

Residential L3 West run C differs from runs A/B at one decoded RGBA pixel:

```text
source coordinate: x=733, y=778
run A/B RGBA:      [16, 48, 16, 255]
run C RGBA:        [16, 16, 16, 255]
differing channel: green
alpha difference:  none
```

The retained contact zoom localizes the pixel to the dark foliage edge beside
the facade. Geometry, occupied bounds, alpha, registration, and surrounding
pixels are unchanged. This is a schema-2 quantization-boundary split after the
no-MSAA SceneKit render, not a missing volume, alpha-compositing defect, or
authored geometry change.

## Stop boundary

The raw gate is not deterministic, so Residential L4 was deliberately not
rendered. The existing normalizer was not invoked, and no normalized or review
candidate path was created. Any sampling-contract repair must preserve this
attempt, remain additive and task-owned, leave the schema-1 reproduction path
unchanged, and be committed before a fresh regression attempt.

Binding machine evidence:

- `RAW-REGRESSION-INVENTORY.json`
- `RESIDENTIAL-L03-WEST-PIXEL-SPLIT.json`
- `RESIDENTIAL-L03-WEST-PIXEL-SPLIT-ZOOM.png`
- `COMPLETED-RAW-EXACT-RGBA-VISIBILITY.json`
- `COMPLETED-RAW-EXACT-RGBA-OCCUPIED-CROPS.png`

`productionSelected` remains false.
