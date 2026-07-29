# CONTRACT-021 — Parallel directional World Art cells

**Status:** Approved

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

## Merge and review order

1. North art direction and deterministic A/B/C.
2. Integration publishes the family/material lock.
3. East, South, and West rebase or merge that exact authority without
   rewriting their predesign histories.
4. Each direction renders one A independently and receives Renderer plus fresh
   QA review.
5. Integration accepts the complete four-direction family before any shipping
   ingestion.

Strictest review wins. A passing validator does not override a failed
literal-game-scale visual review.
