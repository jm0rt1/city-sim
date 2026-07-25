# PLAY-061 Frozen 20-Point Commercial Skyline Rubric

This rubric is preregistered before receipt of any PLAY-060 candidate. Each
category is scored from zero through four. Every lost point must name an
observable cause and exact candidate-bound evidence.

## 1. Commercial identity and road-facing direction — required 4/4

Four requires all sixteen `L1-L4 x N/E/S/W` identities to:

- use the accepted authored source for that exact level and frontage;
- resolve level from authoritative building state and direction from
  authoritative road adjacency, never the camera;
- remain Commercial and visibly distinct from Residential and Industrial;
- retain unmistakable, grounded road-facing frontage at city, neighborhood,
  and block LOD;
- preserve footprint, pivot, entrance socket, foundation, ground contact,
  shadow, projection, material, light, alpha, padding, and registration;
- remain byte-stable through unchanged pulses, LOD changes, save/load, undo,
  overlay, selection, construction, condition, and Reduce Motion; and
- report exact raw, normalized, packed, page, runtime, level, and frontage
  identity without mirror, rotation, alias, substitution, or fallback.

Any wrong or missing identity makes this category less than four and
automatically rejects the gate.

## 2. Whole-scene world/HUD cohesion — required 4/4

Four requires the complete regular and compact scenes to feel authored as one
shipping product:

- Commercial massing creates a legible L1-to-L4 skyline without toy repetition
  or overwhelming roads, public realm, Residential neighbors, or the HUD;
- city shows district composition and growth direction, neighborhood shows
  frontage/roads/public fabric, and block shows entrance, condition,
  construction, and interaction;
- roads, reciprocal seams, foundations, shadows, public-realm props, selection,
  overlays, and construction remain physically coherent;
- closed HUD, Details, Focus City, warning/action routes, speed, objectives,
  notices, and selected target preserve truthful map aperture and priority; and
- the candidate is materially preferred over the frozen same-state baseline in
  uncropped regular and exact compact comparisons.

Any whole-scene composition or control regression makes this category less
than four and automatically rejects the gate.

## 3. Skyline progression, material hierarchy, and LOD readability — minimum 3/4

Four requires L1 storefront, L2 market/arcade, L3 office/department block, and
L4 tower identity to progress materially in massing, height, roofline,
fenestration, density, and commercial character. The sequence must remain
legible in color and grayscale at all three useful LODs, without aliasing,
muddy values, mixed fidelity, material overlap, fringe, or a level-scaled-clone
effect. Three permits one disclosed minor polish limitation that does not
confuse level, family, frontage, or state.

## 4. Interaction, state truth, persistence, and accessibility — minimum 3/4

Four requires pointer, Return, Space, command/menu, FKA, and AX to announce and
mutate exactly one identical coordinate once. Preview, click, key activation,
AX value/help/action, selection, rejection reason, construction, condition,
overlay, Focus City, save/load, and undo must agree. Focus and topmost-first
Escape must remain stable. Reduce Motion must preserve identity and meaning.
Three permits one non-blocking limitation with no false feedback or inaccessible
critical action.

## 5. Shipping identity, determinism, and performance — minimum 3/4

Four requires exact product/bundle/executable/manifest/resource/PID/data-root/
window identity, accepted-source-to-staged-pack parity, two-build deterministic
bytes, zero fallback diagnostics, focused and full test passes, and governed
staged verification. CONTRACT-006 remains binding: at most four active 2048 x
2048 pages, approximately 96 MiB target active texture memory, 128 MiB hard
high-water after repeated LOD cycling, no accumulation, staged RSS no more than
the accepted baseline plus 128 MiB, unchanged-pulse average at or below 2.1 ms,
no existing metric regression over 20 percent without approval, LOD transition
p95 below 16.7 ms, and maximum below 33.3 ms. Three permits one explained,
accepted, non-player-blocking limitation.

## Automatic rejects

Any item rejects regardless of total:

- ambiguous or substitute commit, bundle, executable, manifest, resource,
  state, camera, selection, window, defaults domain, data root, or PID;
- cropped, resized, composited, transient-obscured, harness-only, author-only,
  or single-width evidence;
- any Residential or Industrial alias, wrong Commercial level, wrong
  road-facing frontage, runtime mirror or rotation, synthesized fallback, or
  cross-level Commercial alias;
- footprint, pivot, entrance socket, foundation, shadow, ground-contact,
  projection, material, light, alpha, padding, or registration drift;
- building/building, building/road, building/prop, HUD/world, overlay/selection,
  label/art, or public-realm material overlap;
- broken or unexplained road end, reciprocal seam, or public-realm regression;
- identity, direction, condition, construction, selection, preview, overlay,
  Focus City, consequence, warning, objective, speed, save/load, or undo truth
  mismatch;
- stale or moved active target, pointer leak, double activation, inaccessible
  critical action, modal/text-field leakage, unstable focus, or broken Escape
  order;
- critical AX-only information that is visually clipped, hidden, microscopic,
  or unreachable;
- Reduce Motion information loss or state change;
- source/staged pack mismatch, nondeterministic bytes, silent fallback, more
  than four active pages, over-budget or accumulating residency/RSS, or
  unexplained cold/update/render regression;
- one hero frame masking a failure elsewhere in the 16-row matrix or three
  LODs; or
- product mutation, coaching, candidate substitution, author self-score, or a
  post-result waiver entering the independent disposition.
