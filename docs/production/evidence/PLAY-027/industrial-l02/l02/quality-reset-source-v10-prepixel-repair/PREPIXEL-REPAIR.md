# PLAY-027 Industrial L2 source-v10 geometry repair

Status: **pre-pixel freeze; not art acceptance**

Source-v09 and its rejection remain byte-exact. Source-v10 changes physical
foundation geometry rather than weakening the completeness invariant or
shrinking metadata:

- North retains the loading apron at `z=-28`; its ground-bearing slab now
  reaches `x=-28...28` and rear `z=28`.
- East retains the loading apron at `x=28`; its slab reaches rear `x=-28` and
  `z=-28...28`.
- South retains the loading apron at `z=28`; its slab reaches
  `x=-28...28` and rear `z=-28`.
- West retains the loading apron at `x=-28`; its slab reaches rear `x=28`
  and `z=-28...28`.

Every repaired union now has exact minimum `(-28, 0, -28)` and at least exact
maximum `(28, required-height, 28)`. The slab stops one world unit behind the
road-facing apron plane so it does not create a second owner on that plane.
All mass blocks, props, facade/frontage declarations, sockets, camera, light,
shadow, material library, and schema-2 v3 sampling payload are unchanged.

The legacy structural validator reports inherited collisions in source-v09.
Its canonical collision arrays are byte-identical for source-v10, proving the
foundation repair introduces no new coincident or overlapping authored
subgeometry. Production selection remains false.
