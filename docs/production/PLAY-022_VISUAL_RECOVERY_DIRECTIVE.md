# PLAY-022 Visual Recovery Directive

## Decision

The current world-rendering candidate is visually rejected.

Passing renderer tests, deterministic identity, bounded actions, and fast frame
times remain necessary engineering evidence. They are not evidence that the
world is attractive. The retained candidate still reads as programmer art: a
few disconnected icon-like buildings and pasted road strips floating on a large
flat green board.

This directive reopens PLAY-022 around a visible quality outcome. Do not add
another broad set of consequence badges, density variants, or renderer features
until the golden-block gate below is accepted.

## Rejection evidence

- `docs/production/evidence/PLAY-021/after-default-live.jpeg`: the real staged
  view is dominated by empty, nearly uniform grass; the small central settlement
  lacks street enclosure, ground detail, scale cohesion, and visual life.
- `docs/production/evidence/PLAY-022/renderer-strategy-block.png`: building
  silhouettes are clearer than the prior baseline but remain flat, sparse, and
  compositionally unrelated. Roads terminate as visible strips instead of
  forming believable blocks.
- `docs/production/evidence/PLAY-022/spatial-consequences/spatial-recovery-default.png`:
  repeated cyan loops, bolts, and status marks overwhelm the architecture and
  read as debug annotation rather than an inhabited city recovering.
- `docs/production/evidence/PLAY-021/art-direction-reference.png`: this is the
  disclosed quality and composition reference. The product need not copy its
  pixels, but it must close the obvious gap in density, material depth, coherent
  scale, vegetation, road integration, lighting, and sense of place.

## Player-facing north star

At first glance the map should look like a place worth inspecting, not a board
covered in symbols. At city scale the player sees a coherent settlement and its
district hierarchy. At neighborhood scale they can read connected streets,
parcel edges, architecture families, landscaping, and activity. At block scale
materials, entrances, props, construction, condition, and selected state reward
closer inspection without drowning the underlying world.

## Recovery sequence

### Gate A — one exceptional golden block

Build one representative developed district in the shipping `CityScene` and
make it excellent before scaling the system. It must include:

- a connected road/intersection/curb/sidewalk language with no seams or pasted
  strip ends;
- buildings seated convincingly on parcels, facing streets, sharing one
  projection, light direction, footprint scale, and shadow language;
- terrain with macro variation and restrained micro detail instead of a single
  green field;
- enough trees, planting, street furniture, markings, parked/ambient objects,
  and small movement to feel inhabited while remaining bounded and compatible
  with Reduce Motion;
- authored material and silhouette differences across every land-use family
  visible in the block;
- a camera composition in which developed land fills roughly 55–70 percent of
  the available world viewport and the city, not empty terrain or HUD, is the
  visual subject.

The gate is a real staged-app screenshot at default size plus a matching compact
view. Renderer-harness output is supporting evidence only. Integration and the
playtest lane must accept Gate A before the lane expands breadth.

### Gate B — systemize the visual language

After Gate A is accepted, turn its assets and rules into deterministic terrain,
road, parcel, architecture, vegetation, prop, lighting, LOD, and reuse systems.
Retain stable coordinate identity, hit testing, placement feedback, overlays,
accessibility, and performance. Every visible land-use family needs multiple
meaningfully different forms, but asset counts do not substitute for visual
quality.

The Pillow-only geometry generator is no longer a quality constraint. The lane
may use repo-authored raster art, carefully art-directed generative assets, or a
hybrid workflow. Every shipping asset must have documented source, generation
prompt or authoring method, cleanup steps, license/provenance, projection,
lighting, scale, and stable digest in the repository. Raw generated sprite
sheets do not ship without isolation, edge cleanup, scale correction, and
in-app inspection.

### Gate C — consequences that belong in the world

Only after the base city passes Gates A and B should factual utility,
pollution, prosperity, strain, decline, and recovery presentation be polished.
Use environmental storytelling first: localized light, maintenance, vegetation,
material wear, smoke/steam, repair activity, and bounded ambient behavior.
Icons and rings are secondary interaction aids, not the dominant visual layer.
Normal play must not resemble a debug overlay.

## Independent visual scorecard

Integration and playtest each score the real staged candidate from 0 to 4 in
five categories:

1. **Composition and hierarchy** — the developed city owns the frame and has a
   readable skyline, district structure, and focal points.
2. **Projection and physical coherence** — roads connect, buildings sit on
   parcels, scale is consistent, and nothing visibly floats or collides.
3. **Material, light, and depth** — roofs, walls, ground, vegetation, props,
   contact shadows, and atmospheric color create convincing depth.
4. **Density, variety, and life** — repeated forms are disguised by meaningful
   variation and the world feels inhabited at all three camera levels.
5. **State and interaction clarity** — gameplay truth, selection, placement,
   overlays, and Reduce Motion remain legible without obscuring the city.

Gate A requires at least 3 in every category and at least 17/20 overall from
both reviewers. A reviewer must explain every lost point against a retained
frame. No implementation author may self-accept the candidate.

## Automatic rejection conditions

Reject the candidate without averaging the score if any of these remain:

- a representative developed default frame is still mostly undifferentiated
  empty terrain because of content or camera composition;
- ordinary road junctions have visible seams, overlaps, or unexplained ends;
- major buildings use visibly inconsistent projection, scale, or light;
- repeated status rings, bolts, labels, or markers dominate normal play;
- improvement is primarily recolor, added badges, added asset count, or a
  fixture-only composition;
- the best evidence is cropped, off-window, a renderer harness, or a concept
  image instead of the exact staged app;
- asset provenance is ambiguous, interaction regresses, nodes/actions grow
  without bound, or renderer timing regresses by more than 20 percent without
  explicit integration approval.

## Required proof packet

Retain exact-candidate identity and uncropped staged-app captures for:

- same seed and camera: current accepted baseline versus candidate;
- default and 900 x 600 compact windows;
- city, neighborhood, and block camera levels;
- normal, selected, valid/invalid placement, overlay, and localized consequence
  states;
- Reduce Motion;
- a grayscale contact sheet demonstrating non-color hierarchy;
- before/after renderer timing, node/draw/action counts, reuse, hit testing,
  accessibility, focused tests, full suite, and staged build verification.

PLAY-022 remains open until all three gates and the independent scorecard pass.
