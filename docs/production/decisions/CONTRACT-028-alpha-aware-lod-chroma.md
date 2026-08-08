# CONTRACT-028: Alpha-aware LOD residual-chroma admission

**Status:** Approved Integration normalization authority

**Owner:** Integration

## Purpose

CONTRACT-026 governs the full-canvas registration profile. This contract
defines the narrow residual-chroma gate for normalized four-view LOD payloads
when a keyed ImageGen matte is downsampled. It separates genuine edge ringing
from dark authored material and does not admit pixels, activate the renderer,
or change the four-view identity contract.

## Immutable source boundary

- Raw 1536x1024 source PNG bytes are immutable inputs and must not be
  regenerated, cropped, recolored, or overwritten by this repair.
- The repair may operate only on deterministic post-resize RGBA LOD outputs
  derived from those frozen raw bytes.
- Source-space pivot, socket, footprint, canvas, identity, direction, and
  frontage metadata remain code-owned CONTRACT-026 values.

## Two-level chroma test

Every normalized payload reports both predicates independently:

1. **Strict keyed matte:** a visible pixel is keyed only when
   `alpha > 0`, `red >= 180`, `blue >= 150`, `green <= 110`, and
   `red + blue >= 4 * green`. The strict count must be zero.
2. **Boundary residual chroma:** a visible pixel is a residual candidate only
   when all conditions hold:
   - `alpha` is in `1...254`;
   - at least one 4-neighbor has `alpha == 0`;
   - `max(red, blue) >= 64`; and
   - `red + blue - 2 * green >= 64`.

Opaque, non-boundary, near-black authored material is therefore not a residual
candidate merely because its red/blue ratio exceeds a ratio-only heuristic.
The boundary rule is an admission diagnostic, not permission to waive visible
pink or purple fringe.

## Deterministic post-resize cleanup

The normalizer may apply one deterministic, idempotent despill pass to
boundary residual candidates after the whole-canvas resize and before PNG
serialization. The pass may adjust RGB only; it must preserve alpha, canvas
dimensions, registration coordinates, and source/LOD identity. It must not
infer geometry, crop, trim, recenter, or alter opaque non-boundary material.

After cleanup, every payload must satisfy:

- strict keyed matte count `0`;
- boundary residual-chroma count `0`;
- hidden RGB count `0` for `alpha == 0`;
- frame-edge alpha occupancy `0`; and
- byte-identical output across two fresh processes and two isolated output
  roots.

Any remaining boundary residual is a rejection. Raising thresholds, accepting
the aggregate count, or changing raw ImageGen sources is not a valid repair.

## Evidence and disposition

The focused packet must preserve the pre-repair hashes, report strict and
boundary counts separately for all 129 LODs, bind this contract hash, and show
reproduced color/grayscale/contact sheets at literal scale. The packet remains
`candidateReadyForIndependentReview=true` with `sourceReady=false`,
`integrationAdmitted=false`, `rendererQuarantined=false`, and
`productionSelected=false` until independent Frontier visual review. No
renderer, atlas, manifest, runtime, save, UI, or shipping change is authorized
by this contract.
