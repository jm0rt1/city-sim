# CONTRACT-026: Full-canvas authored four-view registration

**Status:** Approved Integration registration authority

**Owner:** Integration

## Purpose

CONTRACT-025 remains the visual, identity, direction, and atomic-activation
authority. This contract supplies the missing numeric registration profile for
South-anchor admission and all four authored directions. It does not select
pixels or authorize renderer/shipping activation.

## Source space

Every source sprite is an authored `1536 x 1024` RGBA canvas. The source-space
ground pivot is `[768, 896]`. The governed one-tile footprint is the diamond
`[[768, 640], [1024, 768], [768, 896], [512, 768]]` and is identical for every
family, level, and variant. Per-level visual height and materials remain
authored properties of each identity; they are never inferred from occupied
pixels.

Direction frontage sockets are code-owned source coordinates:

| Direction | Socket |
| --- | --- |
| north | `[896, 704]` |
| east | `[896, 832]` |
| south | `[640, 832]` |
| west | `[640, 704]` |

These coordinates are registration metadata, not generated-pixel geometry.

## LOD mapping

The only permitted source-to-LOD transform is a whole-canvas deterministic
Lanczos downsample to:

| LOD | Canvas |
| --- | --- |
| block | `1024 x 683` |
| neighborhood | `512 x 342` |
| city | `256 x 171` |

For every source coordinate `(x, y)`, each LOD computes coordinates with exact
rational arithmetic and round-half-to-even independently:

```text
lodX = round_half_even(x * lodWidth / 1536)
lodY = round_half_even(y * lodHeight / 1024)
```

The unrounded source-space registration is retained in every receipt. The
normalized payload never crops, trims, resizes-to-bounds, recenters, or derives
pivot, socket, footprint, scale, or frontage from occupied/shadow/prop pixels.
No clamping is allowed; an out-of-envelope coordinate fails the gate.

Examples for the source pivot are block `[512, 598]`, neighborhood `[256, 299]`,
and city `[128, 150]`.

## Admission requirements

The South admission packet must preserve raw PNG bytes, bind the exact identity,
direction `south`, prompt, South reference, raw and record hashes, and emit all
three whole-canvas LOD payloads with the profile hash. Mechanical validation
rejects missing profile bindings, path-dependent receipts, raw or normalized
aliases, hidden chroma/alpha defects, and incomplete provenance. Frontier review
still owns visual quality and final source admission; no partial family may ship.

The historical `normalize_calibration_asset.py` crop/resize helper is not a
CONTRACT-026 reference implementation. A task-local normalizer may implement
this profile under its claim-owned roots; shared toolchain changes require a
separate Integration decision.
