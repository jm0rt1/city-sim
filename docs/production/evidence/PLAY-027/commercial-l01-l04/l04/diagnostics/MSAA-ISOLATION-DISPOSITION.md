# PLAY-027 Commercial L4 West MSAA isolation disposition

## Result

The retained five-pixel Commercial L4 West split is caused by the SceneKit
4x MSAA resolve path.

The counterfactual changed only SceneKit snapshot antialiasing from
`multisampling4X` to `none`. Scene shadows remained current. The committed
`source-v02` West descriptor, descriptor SHA-256, 2x oversampling factor,
camera, materials, scene graph, light, deterministic registered footprint
shadow, compositor, quantizer, PNG canonicalizer, and output registration
remained fixed.

| Isolation | Fresh processes | File identities | Pixel identities | Result |
|---|---:|---:|---:|---|
| retained 4x MSAA, current shadows | 3 | 2 | 2 | split by 5 RGB pixels |
| no MSAA, current shadows | 3 | 1 | 1 | exact repeat identity |

All three no-MSAA attempts have file SHA-256
`99275296eee285161d90d52489acd0e1978f9e931a7da1fcb3507a08af2f782a`
and canonical pixel SHA-256
`cc65643caddce7f00aee9fc7335c0ce580b0c2abe2a066b9b03979d398030fa0`.
The renderer source commit recorded by every attempt is
`f6db35aa93a571c918e96a3368a6f1a821818883`.

The exact-RGBA gate also passes: alpha visibility ratio `1.0`, zero hidden
non-magenta pixels, matching RGB/alpha-visible occupied bounds
`[619,418,1029,906]`, complete occupied area, and flat chroma corners.

Because the first ordered isolation restored exact identity, the
shadows-disabled and per-node/group probes were not run. Shadow rasterization
and a specific renderer-created overlapping subgeometry are not needed to
explain this retained split.

## Authority boundary

These are diagnostic bytes, not `source-v03`, accepted source art,
normalization input, or production selection. They remain under:

```text
docs/production/evidence/PLAY-027/commercial-l01-l04/l04/diagnostics/
```

No authored scene geometry, accepted raw/normalized file, runtime surface,
shipping surface, package topology, or shared manifest was changed.

## Proposed deterministic production pipeline

This proposal is not implemented and requires integration approval.

1. Disable SceneKit hardware MSAA for every governed offline source render.
2. Increase the fixed linear oversampling factor from 2x to 4x while retaining
   the same camera frustum, world geometry, registration, and final
   1536 x 1024 source canvas.
3. Downsample exactly once with the existing task-owned software
   `CILanczosScaleTransform` path at scale `0.25`, using the frozen software
   Core Image context and sRGB output.
4. Preserve the existing deterministic quantization, registered footprint
   shadow, flat chroma compositor, ImageIO write, and native `sips`
   canonicalization stages.
5. Record antialiasing `none`, oversampling `4`, downsample filter/scale,
   renderer/toolchain hashes, and source commit in every provenance record.
6. Treat 4x as one frozen pipeline choice. Do not select 8x opportunistically
   per building or direction; any different factor requires a new governed
   calibration.

## Required regression evidence before approval

At minimum, the proposed pipeline must prove the following against all twelve
accepted Commercial L1-L3 N/E/S/W sources:

1. Three fresh processes per direction produce exact raw pixel identity.
2. Two independent normalization runs produce exact block, neighborhood, and
   city LOD identity.
3. All twelve raw identities and all thirty-six normalized identities remain
   unique with no cross-level or cross-direction alias.
4. Footprint, pivot, socket, door base, contact, occupied bounds, padding,
   southeast shadow, alpha, chroma, spill, and hidden-RGB gates pass with no
   registration drift.
5. Side-by-side source-scale, normalized-alpha native-2x, grayscale, footprint,
   and zoom panels show no lost window/door hierarchy, softened frontage,
   halo, stair-step, material-value drift, or density regression relative to
   the independently accepted L1-L3 packets.
6. Existing accepted L1-L3 raw and normalized bytes remain preserved; proposed
   rerenders live in task-owned diagnostic paths until independent review
   explicitly approves a new source revision.
7. Independent art review must approve the unified L1-L4 sampling treatment
   before any accepted source record, production selection, renderer
   ingestion, or shipping asset is changed.

Residential L1-L4 should additionally be sampled as a cross-family style and
edge-quality regression before adopting the pipeline for later Industrial
production.
