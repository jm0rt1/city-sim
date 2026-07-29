# PLAY-027 Industrial L2 East source-v06 proof rerun

**Disposition:** REJECTED/FROZEN before normalization.

Exactly three fresh Metal-visible processes rendered the unchanged East
source-v06 descriptor through the committed diagnostic-only capture contract.
All three 33×33 support windows at source coordinate `(707,687)` are
byte-identical, and all three final PNG files and decoded pixels are exact.
The frozen RGBA, occupied-bounds, registration, and visual evidence therefore
remains valid.

The binding upstream identity gate nevertheless fails:

- the complete SceneKit 4× decoded frame has three identities across A/B/C;
- the post-Lanczos prequantized full frame has two identities, with A differing
  from B/C;
- quantization converges the runs to one identity, and every later stage is
  exact.

Because the authorized gate required exact identity at the complete 4×
SceneKit frame as well as the support window and final raw, this packet is not
an East raw review candidate. No normalization was run. No descriptor,
topology, material, camera, compositor, normalizer, N/S/W source, runtime,
shipping surface, shared manifest, or production selection was changed.

The exact stage and file hashes are frozen in
`STAGE-IDENTITY-MATRIX.json`. All 12 generated run artifacts are retained
under
`diagnostics/east-707x687-scene-kit-vs-lanczos/{run-a,run-b,run-c}`.
