# Four-View Source Integration Proof

This directory composes the accepted Blender source assets on CitySim's exact
88x44 grid without changing any source sprite. It is review evidence only: no
asset is registered with `LotRenderer`, `WorldAssets.atlas`, or a live catalog.

Run from this directory:

```sh
python3 compose_source_block.py
```

The compositor uses every source PNG at native 384x384 resolution, the shared
`(192,300)` pivot, `camNE`, declared multi-tile spacing, and screen vectors
`(+44,+22)` / `(-44,+22)`. It performs no rotation, skew, crop, scale, or
per-asset offset. Outputs are deterministic RGBA PNGs at 1280x800 and 900x600.

