# CONTRACT-027: World rotation to authored-view mapping

**Status:** Approved Integration runtime-selection authority

**Owner:** Integration

## Purpose

CONTRACT-025 defines the four-view 2.5D art matrix and CONTRACT-026 defines
registration. This contract freezes the missing runtime rule that maps a
rotating world and a road frontage to one independently authored sprite. It
does not admit pixels or activate the renderer pack.

## Rotation state

`rotationIndex` is a transient renderer presentation value in `0...3`.

- `0` is canonical South-anchor presentation and the default at launch.
- Increasing the value by one rotates the world clockwise by one quarter turn.
- Values wrap modulo four; negative steps wrap in the opposite direction.
- The value is presentation state, not simulation state and not save-schema
  state. Save/load, replay, and Undo preserve the logical city and variant;
  they do not need to persist the current camera presentation.

The input/UI lane may expose clockwise and counter-clockwise commands, but the
renderer consumes only this typed value. A future persisted rotation requires a
separate Integration contract.

## Frontage selection

The lot's frontage is resolved from `RoadConnectionMask.resolving(at:in:)`.
For multi-road lots, the existing deterministic priority remains authoritative:

```text
south, north, east, west
```

A built lot with no cardinal road is a rejected presentation with a typed
diagnostic; it must not select a fallback or an arbitrary view.

## Authored-view permutation

`authoredView = frontage.rotatedClockwise(rotationIndex)` using the cardinal
ordering `north -> east -> south -> west -> north`.

| Frontage | rotation 0 | rotation 1 | rotation 2 | rotation 3 |
| --- | --- | --- | --- | --- |
| north | north | east | south | west |
| east | east | south | west | north |
| south | south | west | north | east |
| west | west | north | east | south |

This means the road-facing identity and variant remain fixed while the visible
authored face follows the clockwise world presentation. The four cells are
source selections, never bitmap transforms.

## Exact lookup and invalidation

The renderer lookup key is:

```text
(family, level?, variant, frontage, authoredView, lod)
```

It must resolve exactly one manifest descriptor whose identity, frontage,
view, LOD, pivot, socket, footprint, and payload hash all match. Missing,
duplicate, aliased, mismatched, fallback, mirrored, rotated, or transformed
records produce a rejection diagnostic and no building sprite.

`rotationIndex` is part of the tile render signature and generated residency
key. A rotation change invalidates/rebuilds the affected authored building
selection and preloads only the new exact view; it does not change variant,
world coordinate, footprint, or LOD identity.

## Required proof

Before shipping activation, focused renderer proof must exercise every admitted
identity at all `4` rotation values, all `4` frontage directions, and all `3`
LODs. It must prove the expected authored source hash, stable variant,
frontage, pivot/socket registration, no catalog fallback, no SpriteKit
transform, deterministic fresh-process replay, and save/load/Undo stability.
Production selection remains atomic at `43 identities x 4 views x 3 LODs`.

No renderer or resource mutation is authorized by this document alone. A
separate child route may implement the selector only after the exact aggregate
manifest and admitted four-view source packets exist.
