# Wave 006 — Make the City the Hero

## Integration disposition

**Wave 006 accepted.** The initial integrated candidate was correctly rejected,
then the returned PLAY-024 repair was merged as exact product
`ad2f35314bb471a07923c41653374b05ace51ee3`.

Independent PLAY-053 evidence
`2e83570eda92e14fcf39bca78b9152ff3c7b8411` approved that exact staged product
at 19/20: composition 4/4, projection/material/light/street coherence 4/4,
useful LOD/depth/variety/life 3/4, state/consequence/interaction clarity 4/4,
and shipping/HUD/accessibility/performance 4/4. No category fell below 3, both
governed comparisons were materially preferred, and no automatic reject
remained.

The exact packet is
`docs/production/evidence/PLAY-053/rescore-ad2f353/`. The remaining lost point
is narrow building-family and directional-view breadth; PLAY-027 and
CONTRACT-011 own that next source-art system, and no incomplete art is
production-selected.

## Defects that drove the accepted repair

1. The world reads as a small crossroads diorama, not a growing city.
2. Long roads end abruptly inside the frame and make the network feel like
   isolated strips rather than purposeful streets.
3. Large undifferentiated green fields surround a tiny high-detail core.
4. Buildings carry more detail than terrain, edges, vegetation, and public
   realm, producing a mixed-fidelity collage.
5. Repeated house and utility silhouettes weaken district identity and make
   growth feel like duplication.
6. Curbs, sidewalks, crossings, frontage transitions, trees, and props do not
   yet create a continuous civic fabric.
7. The upper status wall, floating priority card, and lower command wall
   compete with the city. The HUD is operable but visually louder than the
   world it is meant to explain.
8. Selection is semantically excellent but visually too quiet against the
   detailed center and too detached from the vast empty field.

These are product defects for Wave 006. Asset count, pixel fidelity, green
tests, or a single hero screenshot cannot close them.

## Work order

### PLAY-016 + PLAY-048 — Authoritative starter-city truth

The accepted opening state itself currently contains one horizontal and one
vertical road plus eight occupied lots. Rendering may improve the material,
termini, ground, public realm, and readability of that truth, but it may not
turn empty cells into apparent streets or developed parcels.

Gameplay therefore owns a richer deterministic starter district under
PLAY-016: a connected multi-block road/building arrangement with legitimate
growth choices and the same viable strategic pressure. Simulation platform
adopts the frozen checkpoint under PLAY-048 so saves, story fixtures,
fingerprints, replay, undo, and snapshots remain exact. This is not permission
to fake density or weaken the game loop for a screenshot.

### PLAY-024 — Environment and street-system excellence

World rendering owns the visible systemic repair:

- replace flat board space with cohesive, deterministic terrain composition;
- make the 16-mask road grammar read as a connected street network with
  credible continuations, intersections, curbs, sidewalks, crossings, and
  frontage transitions;
- establish shared projection, scale, light direction, material response, and
  ground contact across every visible kind;
- add deterministic vegetation and public-realm props that fill space without
  obscuring hit targets or inventing simulation facts;
- ensure city, neighborhood, and block LODs each add useful meaning rather than
  simply changing texture size;
- prove the opening, a built-out route, construction, strain, recovery, and
  exact compact mode in the real staged app.

The lane may use image generation for authored source art, but connectivity,
anchors, masks, geometry, provenance, normalization, packing, and acceptance
remain deterministic and tool-verified. Every visible road and occupied parcel
must originate in authoritative `CityGameState`; PLAY-024 must automatically
consume PLAY-016 topology and must never prefigure it with decorative roads.

### PLAY-039 — World-first HUD hierarchy

UI/input owns the visual balance around the world:

- materially increase the visible map aperture in default and exact compact
  layouts;
- remove the impression of two opaque control walls and a floating modal card;
- keep one calm priority, one obvious action, one unambiguous paused/running
  state, and one persistent selected-target explanation;
- preserve the single command catalog/store route, every keyboard shortcut,
  Full Keyboard Access, accessibility actions, rejection recovery, and compact
  operation.

No renderer art or geometry may move into SwiftUI.

### PLAY-053 — Independent excellence gate

Quality preregisters the comparison before seeing the final candidate, freezes
the exact baseline frames, and independently scores the integrated result.
PLAY-024 and PLAY-039 authors do not score themselves.

Quality must retain two comparisons: the frozen Wave 005 state rendered by the
new world/HUD for isolated presentation proof, and the old versus new authored
fresh-start experience for composition and player-choice proof. A changed
starter topology may not be mislabeled as a same-state art comparison.

## Automatic rejection conditions

Any one of the following rejects the wave:

- toy-island or demo-diorama framing;
- non-edge road ends that look accidental or disconnected;
- large featureless green areas dominating the playable aperture;
- visible sprite overlap, floating foundations, broken ground contact, seams,
  or mixed projection/light direction;
- high-resolution buildings pasted onto visibly lower-fidelity terrain;
- debug labels, glyphs, or color washes carrying primary world truth;
- HUD chrome obscuring the active target or reading more strongly than the
  city;
- a default-only hero shot without exact compact, LOD, construction,
  consequence, Reduce Motion, and hands-on interaction evidence;
- regression in pointer, keyboard, accessibility, hit testing, deterministic
  identity, memory, or frame budgets.

## Acceptance bar

The exact integrated candidate must:

- score at least 19/20 independently;
- earn 4/4 for composition/map occupancy;
- earn 4/4 for projection/material/light/street coherence;
- score no category below 3/4;
- trigger no automatic reject;
- win an explicit same-state side-by-side comparison against the frozen Wave
  005 baseline;
- pass the full native suite, exact staged build, default and 900 x 600 play,
  keyboard and pointer routes, Full Keyboard Access/AX inspection, Reduce
  Motion, LOD cycling, overlap/seam diagnostics, and declared memory/frame
  budgets.

The old 17/20 result proved a recoverable production baseline. It is not
evidence of excellence and is not sufficient for this wave.
