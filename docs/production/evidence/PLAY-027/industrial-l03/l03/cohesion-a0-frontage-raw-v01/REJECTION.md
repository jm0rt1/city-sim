# PLAY-027 Industrial L3 source-v05 North/West raw gate

Final disposition: **REJECTED — repeat identity**

The authorized six-process gate is complete and preserved without normalization or repair.

- North A/B are file- and decoded-pixel-identical. North C differs from A/B at exactly two opaque pixels and two RGB channels:
  - `(688,391)` red `16 -> 48`
  - `(795,748)` red `176 -> 208`
- West B/C are file- and decoded-pixel-identical. West A differs from B/C at exactly one opaque pixel and one RGB channel:
  - `(847,391)` red `48 -> 16`
- Alpha, non-chroma occupied bounds, occupied pixel counts, padding, and completeness are unchanged across every run.
- North and West primaries are unique from one another and from immutable East/South; all four primary file and decoded-pixel identities are unique.
- North/West primary raw hashes have an empty intersection with the 40 accepted raw hashes in the committed Residential, Commercial, Industrial L1, and Industrial L2 catalogs.
- Registration provenance is stable at ground pivot `[768,896]`, source-v05, and renderer commit `f7e67031f5fcd222e2755a75270685c54b4bd038`.

The actual-pixel panels remain available for independent art inspection, but art quality is not promoted through a failed repeat gate. `sourceAuthority=false` and `productionSelected=false`. SceneKit process count is exactly six; normalizer process count is zero. No descriptor, geometry, material, East/South, renderer/shipping/package/shared-manifest, L4, or A2 surface changed.
