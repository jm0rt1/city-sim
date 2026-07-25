# PLAY-063 Frozen 20-Point Industrial L1 Rubric

This rubric is preregistered before receipt of any PLAY-062 candidate. Each
category is scored from zero through four. Every lost point must name an
observable cause and exact candidate-bound evidence.

## 1. Industrial L1 identity and road-facing frontage — required 4/4

Four requires all twelve `N/E/S/W x city/neighborhood/block` identities to:

- use the accepted source-v05 identity for that exact road frontage;
- resolve direction from authoritative adjacent-road frontage, never camera,
  process, frame order, or presentation state;
- remain unmistakably Industrial L1 in unlabeled color and grayscale and never
  alias Residential, Commercial, another direction, or a generic fallback;
- show an honest, grounded road-facing entrance/loading relationship for
  north, east, south, and west;
- preserve exact source, normalized, packed, page, runtime, pivot, footprint,
  entrance socket, contact, shadow, alpha, padding, and registration identity;
- remain byte-stable through unchanged pulses, LOD changes, save/load, undo,
  overlays, selection, construction, condition, Focus City, and Reduce Motion;
  and
- report `orientationTransform: none` with no runtime mirror or rotation.

Any wrong, missing, transformed, substituted, or ambiguous identity makes this
category less than four and automatically rejects.

## 2. Whole-scene world/HUD cohesion — required 4/4

Four requires regular and exact compact scenes to feel like one shipping
product:

- the Industrial works belongs physically to roads, terrain, public realm,
  Residential and Commercial neighbors, without material or silhouette
  collision;
- city shows a legible industrial district, neighborhood shows road frontage
  and service context, and block shows entrance, gantry, factory, service
  apron, condition, construction, and interaction;
- roads, reciprocal seams, foundations, shadows, selection, preview,
  construction, overlays, and public-realm props remain coherent;
- closed HUD, Details, Focus City, priority action, objectives, notices,
  warning/action routes, speed, and selected target preserve truthful aperture
  and hierarchy at both widths; and
- the candidate is materially preferred over the frozen same-state baseline in
  uncropped regular and exact 900 x 600 comparison.

Any public-realm, world/HUD, map-aperture, control, or scene-composition
regression makes this category less than four and automatically rejects.

## 3. Silhouette, material hierarchy, LOD, and family recognition — minimum 3/4

Four requires the loading-works gantry, factory mass, roof/equipment rhythm,
entrance, and service apron to remain complete, grounded, and readable at city,
neighborhood, and block LOD. Direction must remain distinguishable in
unlabeled color and grayscale. Industrial must remain materially distinct from
Residential and Commercial without mixed fidelity, muddy value hierarchy,
fringe, false state marks, baked roads, or a toy/icon effect. Three permits one
minor polish limitation that cannot confuse family, level, direction,
frontage, state, ground contact, or gameplay.

## 4. Interaction, state truth, persistence, and accessibility — minimum 3/4

Four requires pointer, Return, Space, menu/command, FKA, and AX to announce and
mutate exactly one identical coordinate once. Preview, click, key activation,
AX value/help/action, selection, rejection reason, construction, condition,
all five overlays, Focus City, save/load, and undo must agree. Focus and
topmost-first Escape remain stable in regular and compact. Reduce Motion
preserves identity and meaning. Three permits one non-blocking limitation with
no false feedback, stale target, pointer leak, or inaccessible critical action.

## 5. Shipping identity, determinism, and performance — minimum 3/4

Four requires exact product/bundle/executable/manifest/resource/PID/data-root/
window identity, accepted-source-to-staged-pack parity, two-build deterministic
bytes, zero fallback diagnostics, focused and full test passes, and governed
staged verification.

CONTRACT-006 remains binding:

- no more than four active 2048 x 2048 pages;
- approximately 96 MiB target active texture memory and 128 MiB hard
  active-plus-adjacent high-water after repeated LOD cycling;
- no texture, node, action, or RSS accumulation;
- staged RSS no more than accepted settled baseline plus 128 MiB, with
  accepted absolute ceiling 333.8 MiB;
- unchanged-pulse average at or below 2.1 ms;
- no existing metric regression over 20 percent without integration approval;
- LOD transition p95 below 16.7 ms and maximum below 33.3 ms; and
- zero silent fallback, decode-growth, or staged/source resource mismatch.

Three permits one explained, accepted, non-player-blocking limitation that
does not weaken identity, determinism, fallback, or hard budgets.

## Automatic rejects

Any item rejects regardless of total:

- ambiguous or substitute commit, bundle, executable, manifest, resource,
  fixture, digest, camera, target, window, defaults domain, data root, or PID;
- cropped, resized, composited, transient-obscured, harness-only, author-only,
  or single-width evidence;
- any Residential or Commercial alias, wrong Industrial level, wrong
  road-facing frontage, generic/synthesized fallback, cross-direction alias,
  runtime mirror, or runtime rotation;
- source-v05/raw/normalized/packed/staged/runtime hash mismatch;
- cropped or obscured gantry, factory, entrance, loading bay, service apron,
  contact shadow, or road-facing frontage at any required LOD/width;
- footprint, pivot, entrance socket, exclusion zone, foundation, shadow,
  ground contact, projection, material, light, alpha, padding, or registration
  drift;
- building/building, building/road, building/prop, building/public-realm,
  HUD/world, overlay/selection, label/art, or material overlap;
- broken/unexplained road end, reciprocal seam, apron-road discontinuity, or
  public-realm regression;
- identity, direction, condition, construction, selection, preview, overlay,
  Focus City, consequence, warning, priority, speed, save/load, or undo truth
  mismatch;
- stale or moved active target, pointer leak, double activation, inaccessible
  critical action, modal/text-field leakage, unstable focus, or broken Escape
  order;
- critical AX-only information that is visually clipped, hidden, microscopic,
  or unreachable;
- Reduce Motion information loss or state change;
- nondeterministic pack bytes, silent fallback, more than four active pages,
  over-budget or accumulating residency/RSS, or unexplained
  cold/update/render regression;
- one hero frame masking a failure elsewhere in four directions, three LODs,
  regular/compact, color/grayscale, or interaction/accessibility state; or
- product/source mutation, source redesign, coaching, candidate substitution,
  author self-score, or post-result waiver entering the quality disposition.
