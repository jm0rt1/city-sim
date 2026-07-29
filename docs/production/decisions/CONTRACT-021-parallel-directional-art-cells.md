# CONTRACT-021 — Parallel directional World Art cells

**Status:** Approved, revision 2

**Owner:** Integration

## Decision

Industrial L4 source production may use four direction-exclusive World Art
branches and worktrees. North remains on `codex/citysim-world-art`; East,
South, and West use their named branches and PLAY-079/080/081 claims.

Parallelism is permitted only because each cell owns disjoint text-scene,
zero-pixel proof, provenance, and evidence paths. No cell may edit a sibling
direction, shared renderer/shipping surfaces, or another lane's worktree.

## Shared immutable inputs

Every direction consumes the published:

- CONTRACT-020 deterministic Blender/Cycles camera and render pipeline;
- Industrial L4 family scale, material-role, footprint, pivot, light, shadow,
  and frontage requirements;
- accepted North art-direction authority once Integration publishes it.

The cells may share material-role names and numerical family targets. They may
not share or transform component coordinates, scene geometry, camera-facing
facade layout, rendered pixels, masks, or contact sheets.

## Parallel authorization

Before North is accepted, East, South, and West may:

- audit the direction-specific road-facing facade and socket;
- author an independent text-scene/material binding under their claimed path;
- run static and actual-camera zero-pixel projection, portal, silhouette,
  footprint, pivot, light, shadow, and occlusion proofs;
- commit durable predesign evidence.

They may not render process A, normalize pixels, claim source authority, or
enter Renderer ingestion until Integration accepts North's art direction and
publishes the shared family/material lock. This prevents three polished but
incompatible siblings while removing idle predesign time.

## Appearance lock and source acceptance

North's first passing process A is the design-calibration gate. After
independent technical and literal-game-scale review accepts that exact A,
Integration publishes an immutable family/material appearance lock. The lock
binds the accepted North design vocabulary, material roles, scale, cameras,
sockets, light, shadow, toolchain, and exact A evidence. It does not declare
North source-ready, select the family, or authorize shipping.

The appearance lock releases all remaining contract-independent source work:

1. North renders B and C to complete its deterministic A/B/C gate.
2. East, South, and West merge the exact lock without rewriting their accepted
   predesign histories, then render A/B/C independently and concurrently.
3. Each cell validates its own three fresh processes, source geometry,
   registration, frontage, material identity, compact color and grayscale
   survival, provenance, and non-aliasing.
4. Renderer and fresh QA may review direction-local source packets in parallel.
   These are technical and literal-scale source reviews, not production
   acceptance or staged-app QA.
5. A failed direction returns only to its owning cell. Passing siblings remain
   quarantined and source-ready; they do not rerender merely because another
   direction failed.
6. Direction-local Renderer quarantine is permitted after source review.
   Shipping ingestion, runtime activation, production selection, and the one
   independent staged-app family gate remain blocked until Integration accepts
   the exact source-ready North, East, South, and West set.

## Merge and review order

1. North process A passes independent technical and literal-scale appearance
   review.
2. Integration publishes the non-production family/material appearance lock.
3. North B/C and East/South/West A/B/C execute concurrently under disjoint
   claims.
4. Integration accepts and quarantines each complete direction independently.
5. Renderer assembles one exact 4/4 candidate only after every direction is
   source-ready.
6. QA runs one preregistered, independent staged-app family gate.
7. Integration alone may authorize shipping ingestion and production
   selection.

Strictest review wins. A passing validator does not override a failed
literal-game-scale visual review.
