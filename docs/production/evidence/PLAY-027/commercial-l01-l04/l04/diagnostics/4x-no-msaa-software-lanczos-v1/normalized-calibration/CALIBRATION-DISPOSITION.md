# PLAY-027 Commercial L4 West normalized diagnostic calibration

**FINAL_DISPOSITION:** `ACCEPT_FOR_DIAGNOSTIC_USE`

**Source authority:** No

**Production selected:** No

**SceneKit/Metal process count:** 0

**Normalizer process count:** 2

This checkpoint authorizes no source replacement, production selection,
renderer ingestion, or shipping change. It records that the existing
task-owned normalizer removes the opaque raw matte contamination from the
frozen 4x/no-MSAA/Lanczos West diagnostic repeatably and without visible
registration or material-identity loss. Independent integration retains final
authority over any later source-pipeline decision.

## Immutable input and exact tools

- Branch base:
  `3d9d4379d6ba28c4638a655f21b4468f391ee733`
- West diagnostic run-A input SHA-256:
  `889de4bfb6eda7ae1eed79669918ca5089590a80672eff6ce6a63a3b2126832a`
- `NormalizeOfflineSource.swift` source SHA-256:
  `e4ef0afc870c90f8bf4f24ef0fe91d3d1d94b1d86edfbfe51cc596864d452c02`
- Normalizer binary SHA-256:
  `e9a31fd105d21f7d28bf40d2e21e5af71488cafbae067be6cde16b9bbe6a005b`
- Existing validator binary SHA-256:
  `d9c20aff460595fa69ff6a9339abcf2284920da0e3c1822e172d6481d4623161`
- Additive review-builder source SHA-256:
  `d6b77215339b829ad31b2874c6f113578c1df0648753d8be284932cab7528f81`
- Additive review-builder binary SHA-256:
  `b5ac566b0d8b9371cf09de116e0bce2ddf147aefbdde755075734b3981d1f78d`
- Object width: `410`
- Reference width: `234`
- `productionSelected`: `false`

## Two-process repeat identity

Run A and run B are byte-identical and canonical decoded-pixel-identical at
each LOD:

| LOD | File SHA-256 | Decoded RGBA SHA-256 |
|---|---|---|
| block | `7ea6e2b0fd3d5693073244ac5cdb22ab9ae29ab22a2f433f8820c611a0341115` | `b83aab2c78334591af1a3fec2cf59b12313b6d561428a2110023ad8b32dbf6d9` |
| neighborhood | `066a93388b1704de13e0d937508f82c149da25372a3c7408f7bbd674a8227fad` | `f8c3d3eadffadbf143b8f5673c61ba55dbc45281a017032724e9fd3290653b0e` |
| city | `10e9cc6658b0a1e829065f46fa9bf8d2d0304efc746902aaaaf404b96a8f0f06` | `2f62e2bec9469a4ff9184d0975d35abd0fd4206b6fd38626826bbfbe822738e6` |

The three LOD file identities and decoded-pixel identities are 3/3 unique.
Both normalization provenance records are byte-identical. The no-Metal review
builder also reproduced its report and all nine panels byte-identically.

## Technical gates

All three LODs pass:

- canonical 8-bit sRGB premultiplied RGBA dimensions;
- alpha range `[0,255]`;
- zero opaque exact-chroma pixels;
- zero visible-magenta-spill pixels;
- zero hidden-RGB pixels;
- transparent and visible populations present;
- padding greater than two pixels on every edge;
- exact run-A/run-B file and decoded-pixel identity;
- unique block/neighborhood/city identities;
- source registration target origin `[559,200]`, size `[419,696]`, and
  ground pivot `[768,896]`;
- byte-identical registration contract to accepted Commercial L4 v3 West.

Diagnostic and accepted v3 alpha bounds, visible-pixel counts, and alpha bytes
are identical at block, neighborhood, and city. There are zero visibility
category flips, so the footprint, contact shadow, and registered silhouette
lose no pixels.

## Visual comparison against accepted Commercial L4 v3 West

The panel order is diagnostic color, accepted-v3 color, diagnostic grayscale,
accepted-v3 grayscale.

| LOD | Differing pixels | Maximum channel delta | Alpha differences | Visibility flips |
|---|---:|---:|---:|---:|
| block | 7,860 | 30 | 0 | 0 |
| neighborhood | 3,535 | 15 | 0 | 0 |
| city | 1,477 | 7 | 0 | 0 |

Direct inspection of all nine committed panels finds:

- no edge or silhouette loss;
- no visible magenta halo after normalization;
- no new stair-step defect at actual scale;
- no footprint or southeast contact-shadow loss;
- no pivot, socket, or frontage registration drift;
- no material-role or broad value-hierarchy change;
- window/frame, frontage, roof, and side-entry features survive at all three
  LODs;
- the bounded RGB differences appear as minor sampling softness only and do
  not alter Commercial L4 recognition in color or grayscale.

The machine report preserves its generation-time
`PENDING_INDEPENDENT_VISUAL_REVIEW` state. Independent integration
subsequently inspected the block zoom, block registered-footprint, city
actual-scale, and machine evidence across all LODs and returned the exact
limited disposition `ACCEPT_FOR_DIAGNOSTIC_USE`. That disposition does not
accept Commercial source art, Industrial pixels, shipping selection, or a
shared production contract.
