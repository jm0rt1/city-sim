# PLAY-073 R4-F4 district fabric return handoff

## Result

The bounded renderer return replaces the full-map connected green macro bed
with a restrained established soil/grass material transition. Vacant land
remains authored and buildable; no crop, opaque screen, fixture-only geometry,
or invented occupancy was added. The exact worker commit is reported in the
post-commit handoff because this evidence root is part of the same coherent
commit and cannot self-reference its containing Git identity.

## Focused proof

- `PLAY073DistrictFabricTests`: 5/5 passed.
- The conservative largest connected green component outside the complete
  district bounding rectangle measured at or below `0.25` in all five exact
  apertures: regular, 900x600 compact, compact Focus City, maximized regular,
  and maximized Focus City.
- Each aperture was rendered twice and the PNG bytes were identical.
- Existing district ground, road hierarchy, connected fabric, topology,
  hit/buildability, LOD, and the existing 121-patch/three-regional-material
  coverage tests remained passing.
- Exact ratios, aperture rectangles, exports, and route bindings are recorded
  in `RESULT.json` and `METRICS.json`.

## Scope and boundary

Only the two renderer/test surfaces permitted by the dispatch and this
evidence root changed; `RoadRenderer.swift` remained unchanged because the
existing accepted road fabric already satisfied this repair's focused gates.
No full Swift suite, staged build, app launch, independent PLAY-075 judgment,
self-score, integration, push, or pinning was performed.

Integration owns aggregation, the full suite, staged exact-SHA candidate, and
the independent player-facing disposition.
