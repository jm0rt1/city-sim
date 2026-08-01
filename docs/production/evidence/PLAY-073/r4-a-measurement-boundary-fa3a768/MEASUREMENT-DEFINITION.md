# PLAY-073 R4-A measurement boundary

Status: `REJECTED_BEFORE_PRODUCT_REPAIR`

This packet freezes the measurement definitions and records the first honest
fresh-process results before any new renderer product mutation.

## Identity

- Synchronized merge base: `0a86c2eaceff2579938c1c8a216864ffc3a63d4d`
- Preserved returned candidate ancestor:
  `aed682f61d2593209740da0a1fd14577bd445e6c`
- Published authority ancestor:
  `2b2c06533e8f6d8caef899accc2a4bd7e9b6193f`
- Measurement harness:
  `fa3a768785dc3d09ee0bb8c54a39c095323c0a02`
- PLAY-073 claim SHA-256:
  `47a260aea5ab9d38a98ceaaefb61e89e00322110b5a833e964a59d13157d7a49`
- Focused test binary SHA-256:
  `60c2c38a3039d369ddb5b677ff8f5a403d26b5f76c808145debb53655089e046`

## Governed cold-path definition

Each retained sample launches a new Swift test process from the same built test
binary. The process must observe
`TerrainRenderer.cachedBackdropTemplateCountForTesting == 0` before rendering.
No process-global backdrop entry may be prewarmed.

`make-backdrop` measures the direct synchronous construction of the block-detail
24 by 24 backdrop, then repeats it once in the same process to disclose the
cache-warm copy cost. `scene-first-grid` renders a new seed-42 city at
1280 by 800 with Reduce Motion enabled. Its first `CityScene` is the governed
process-cold render. A second newly constructed scene in the same process
discloses the cache-warm first-grid render.

The 6.03 ms ceiling applies to
`RendererDiagnosticsSnapshot.worldUpdateDurationMilliseconds`. That timer
contains synchronous backdrop creation. Asset decode/load and total render are
retained separately and are not substituted for world update.

Every retained sample proves cache counts `0 -> 1 -> 1`. Deferring work to a
later player-visible frame or moving it into an unmeasured prewarm is not an
allowed repair.

## Coarse district-mass definition

Definition:
`play073-r4-a-coarse-semantic-district-mass-v2`.

The input is the frozen binary semantic district/public-realm mask, not the
rendered terrain color. This intentionally ignores per-pixel chroma, noise,
macro-patches, and other vacant-terrain modulation.

1. Divide the safe aperture into 32 by 32 backing-pixel blocks, clipping edge
   blocks to the aperture.
2. Mark a block authored district when at least 10 percent of its pixels belong
   to the semantic district/public-realm mask.
3. Treat every other block as coarse plain/vacant.
4. Compute four-connected components over coarse plain/vacant blocks.
5. Divide the largest component by all coarse aperture blocks.

The baseline inputs are the unchanged pre-product masks from product
`b69a9b7c83156ebdd9d0d126198942becdacafc3`. The compared R4-A masks are from
product `570f4c8d4598a05ad3ef263e28c5df24722d6558`. The test executes twice and
the two complete ledgers are byte-identical at SHA-256
`46e721aa6ab95f3b898e9a71e329231f1dd24a85b28de05862169cb08a15de33`.

## Bound result

- Fresh-process cold world update: 0 of 5 at or below 6.03 ms; median
  22.021833 ms.
- Fresh-process cold backdrop inside first-grid update: median 12.130167 ms.
- Cache-warm first-grid world update: median 7.687042 ms, also above 6.03 ms.
- Direct process-cold backdrop creation: median 36.667917 ms; median warm copy
  0.200958 ms.
- Regular largest coarse plain component: 74.598930 percent baseline and
  74.255157 percent candidate, still above the 25 percent gate.
- Regular semantic district width: 70.819805 percent baseline and
  71.631494 percent candidate.
- Regular semantic district pixel mass: 19.374099 percent baseline and
  20.723190 percent candidate.

This rejects the prior terrain-only pass and the current cold-path
implementation. It does not claim a contract conflict yet: an in-timer
renderer-owned architectural repair remains feasible but is outside this
measurement-only checkpoint.

The full same-camera state/LOD matrices, road-mask mosaic, placement inventory,
two-build product proof, AX, Reduce Motion, and staged-app proof are not part of
this bounded checkpoint. In particular, staged-app work remains blocked by the
isolated L3 gate and is not represented as run.
