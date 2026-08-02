# PLAY-073 R4-D vertical residential silhouette authority

**Owner:** Integration frontier visual authority

**Status:** active successor to returned R4-C implementation attempts

**Execution boundary:** LUNA_IMPLEMENTATION / gpt-5.6-luna / high

**Acceptance boundary:** independent FRONTIER_AUTHORITY / gpt-5.6-sol / high

## Why R4-C stopped

R4-C attempt 1 is preserved at
51f6a4f52cc50d46c4884570b86d18ce1fbd0eb5. Its city-scale grove and court
were technically present but far too small to change the player-visible
building read.

R4-C attempt 2 is preserved as a known-failing checkpoint at
45eefc1e693a46ede4cfcb3e9d62aa0834fa28c3. It enlarged the silhouettes to
useful scale, then correctly stopped when the inherited test applied the
72-by-36 ground-plane diamond to every canopy vertex. That produced 20
containment failures and a maximum normalized escape of 1.52798.

The frozen R4-C authority already distinguished ground contact from elevated
canopy: every ground-contact point stays within the lot, while canopies may
create vertical silhouette above their own grounded lot. The second route
blurred those categories by asking for all accumulated geometry containment.
R4-D corrects that Integration-authored ambiguity. It does not lower the
player-visible scale target.

## Frozen visual composition

The target remains an unmistakable garden-grove lot beside an open
terraced-court lot. Preserve accepted building sprites and use renderer-owned
context only.

### Garden-grove

- Use a deliberately authored, asymmetric, multi-lobed deciduous canopy rather
  than one tiny flat oval.
- Large canopy accumulated bounds: at least 22 x 16 render points.
- Companion canopy accumulated bounds: at least 12 x 9 render points.
- Combined canopy silhouette: at least 32 x 18 render points.
- Visible trunks: at least 6 render points high, with distinct grounded
  contact marks and a continuous low hedge/planting bed.
- Use related foliage values with visible light/shadow separation and one
  coherent northwest-light read; do not recolor or tint the accepted building.
- At city and neighborhood detail, offset the grove away from the adjacent
  starter residence so it changes the combined silhouette instead of hiding
  behind the roof.

### Terraced court

- Keep the building silhouette open: no tree canopy.
- Warm-stone court accumulated bounds: at least 24 x 9 render points.
- Include one low linear hedge, a narrow planted strip, and visible paving or
  step rhythm so the court reads as designed public realm rather than one
  colored polygon.
- Keep palette and line weight coherent with the accepted district materials.

Variants 2 and 3 retain deterministic non-aliasing by changing side, geometry,
count, and palette role within their grove/court families.

## Four explicit geometry classes

Tests and evidence must classify actual geometry before applying an envelope.
Node names may identify the authored role, but passing requires real path,
position, accumulated-frame, color, and raster evidence.

1. **Ground contact:** court paving, planting bed, hedge ground line, planted
   strip, trunk contact marks, and contact shadows. Every actual path vertex,
   after transforms, stays within the owning 72-by-36 lot diamond and at least
   4 points from the authoritative entrance socket.
2. **Elevated silhouette:** trunk bodies, canopy lobes, canopy outline, and
   canopy highlights. Their ground anchors must pass class 1. Their projected
   pixels may extend above the ground diamond, but remain within the owning
   tile's explicit vertical silhouette envelope: horizontal half-width 36,
   lower bound -18, upper bound +38, all relative to the tile center.
3. **Road/frontage envelope:** a 16 x 8 rectangle centered on the selected road
   socket and aligned to the frontage. No ground-contact or elevated silhouette
   geometry may intersect it.
4. **Neighbor building-contact envelope:** a 52-by-24 isometric diamond at the
   adjacent occupied tile center. Elevated grove pixels and every ground shape
   must not intersect this envelope. This is a conservative contact/entrance
   envelope, not the full rectangular bounds of an isometric sprite.

For the exact starter pair, use WorldVisualStyle.isoPosition without an
invented translation. Centers for (6,10) and (6,11) differ by the exact
authoritative vector (-36,-18). Compose both contexts into one world container
and prove:

- ground-contact shapes remain in their owning diamonds;
- the grove/court context envelopes do not intersect each other;
- the grove does not intersect the South residence's building-contact
  envelope;
- neither composition intersects either selected road/frontage envelope; and
- deterministic scene z-order remains stable.

The ordinary isometric overlap of full sprite bounding rectangles is not a
failure and must not be used as a substitute for contact or pixel evidence.

## Test and proof contract

Replace the over-broad R4-C containment assertion before rerunning the inherited
test. Add table-driven coverage for all four variants and all four frontages:

- exact repeat identity of path scalar bits, positions, z-order, fill, stroke,
  and line width;
- correct ground/elevated classification;
- ground diamond and entrance clearance;
- vertical silhouette envelope and required accumulated dimensions;
- actual-pair world-space context, road, and neighbor-contact separation;
- no labels, actions, hit targets, semantic state, or non-residential nodes;
- unchanged commercial, industrial/service, civic, park, terrain, sprite,
  resource, and interaction behavior.

Add one deterministic technical contact-sheet test containing:

- regular 1280-by-800 city, neighborhood, and block views;
- exact 900-by-600 compact neighborhood;
- the exact starter pair centered consistently;
- one color sheet and one deterministic integer Rec.709 grayscale sheet;
- byte-identical repeat generation and exact SHA-256 hashes.

The contact sheets are technical evidence for Integration review, not worker
visual acceptance.

## Exact mutable surfaces

- Native/CitySimNative/Sources/CitySimNative/Rendering/LotContextRenderer.swift
- Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift
- docs/production/evidence/PLAY-073/r4-d-vertical-residential-silhouette-v1/

Everything else is read-only. Preserve the R4-C commits and evidence. Do not
edit accepted source sprites, sprite identity/presentation, LotRenderer.swift,
TerrainRenderer.swift, CityScene.swift, assets/manifests, package/build files,
app/UI/gameplay/simulation/save surfaces, claims, backlog, prior evidence, or
shared authority.

## Focused execution and stop

Implementation starts from exact clean checkpoint
45eefc1e693a46ede4cfcb3e9d62aa0834fa28c3. One product repair commit and one
evidence/handoff commit are required. Run the targeted export twice, complete
focused WorldRenderingTests, JSON/hash validation, and the exact descendant
diff check.

Stop on any path expansion, source-art or shared-contract need, inability to
meet the four envelopes, duplicate/full-suite work, resource/performance
regression, unresolved visual decision, or mandatory escalation trigger.
Integration owns aggregate build review; fresh PLAY-075 owns the one
candidate-bound staged-app disposition. The worker does not score, accept,
merge, push, integrate, or pin.
