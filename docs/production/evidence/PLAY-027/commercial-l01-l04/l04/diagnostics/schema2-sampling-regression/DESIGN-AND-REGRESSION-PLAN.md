# PLAY-027 schema-2 deterministic sampling design

Status: pre-pixel architecture checkpoint; non-shipping; independent review
required before Commercial L4 source-v03.

Authority: the accepted MSAA causal diagnosis at
`b3a891c50d7f48804d3213ef0df174928a541413`.

## Compatibility boundary

Accepted Residential L1-L4 and Commercial L1-L3 descriptors remain schema 1,
byte-for-byte. The resolver requires schema 1 to omit a sampling block, retain
camera factor 2, render with SceneKit `multisampling4X`, and apply the existing
software Core Image Lanczos scale 0.5. This is the legacy reproduction path,
not a default that schema 2 can silently inherit.

Schema 2 is additive. Every schema-2 descriptor binds its own source revision
to `play027-deterministic-4x-no-msaa-lanczos-v1` and declares:

- SceneKit antialiasing `none`;
- linear oversampling factor 4;
- `CILanczosScaleTransform`, scale 0.25, aspect 1;
- software CI context, disabled intermediate cache, extended-sRGB working
  space, and sRGB output;
- `step32-midpoint-offset8-v1` quantization with exact opaque-magenta bypass;
- ImageIO encoding followed by `/usr/bin/sips` PNG canonicalization.

Production invocation has no sampling switch. The descriptor resolves the
path. Existing CLI antialiasing and shadow controls remain explicit
diagnostics-only overrides and cannot write outside a diagnostics path.

## Immutable diagnostic sample

The regression sample contains:

- Commercial L1-L3 variant-zero North/East/South/West: 12 sources;
- Residential L1-L4 variant-zero West: 4 sources.

West is the residential sample direction because it is the far-frontage
orientation matching the isolated five-pixel Commercial L4 seam. This gives
one density-progression sample at the renderer's known high-risk orientation
without redefining the accepted residential source set.

The task-owned descriptor-copy tool writes only under this diagnostics tree.
It changes exactly `schema`, `camera.oversamplingFactor`, and `sampling`. A
canonical immutable-payload digest proves every authored geometry, material,
camera, registration, frontage, light, and shadow field otherwise matches its
accepted schema-1 source.

## Binding regression gates

Before any Commercial L4 source-v03 work:

1. Legacy schema-1 renderer reproduction matches every accepted Commercial
   L1-L3 raw byte-for-byte.
2. Each of the 16 schema-2 samples is rendered in three fresh processes with
   no CLI sampling override; every per-source raw file and decoded pixel hash
   is identical.
3. The 16 primary raw identities are unique.
4. Exact retained RGBA bytes have no hidden non-magenta RGB and matching
   alpha-visible/RGB occupied bounds.
5. Every primary raw is normalized twice with the existing task-owned
   deterministic normalizer; corresponding LOD files are byte-identical.
6. All 48 schema-2 normalized LOD files are unique.
7. Normalized validation reports zero alpha, chroma, spill, and padding
   violations and preserves pivot, socket, frontage, contact, and southeast
   shadow registration.
8. Original-resolution color and grayscale, normalized native-2x, and zoom
   comparisons are retained against the accepted schema-1 reference.
9. Accepted descriptors, raw sources, normalized sources, provenance, and
   all Residential/Commercial L1-L3 files remain byte-identical to the
   pre-regression tree.

Any failed binding gate stops the regression. It does not authorize a geometry
change, a source-revision change, normalization into accepted paths, or an L4
source-v03.

## Ownership

All tools, copied descriptors, renders, normalization attempts, reports, and
review sheets are task-owned PLAY-027 diagnostics. `productionSelected`
remains false. No runtime, renderer handoff, shipping atlas, shared manifest,
Package.swift, build script, UI, gameplay, simulation, save, Industrial, push,
integration, self-score, or self-acceptance is in scope.
