# CONTRACT-010: Authored directional building art

**Status:** Approved for PLAY-027 source production

**Date:** July 24, 2026

## Decision

Every CitySim building variant will have four separately authored orthographic
views: north, east, south, and west frontage. Production may not mirror or
rotate one raster to impersonate another direction. No source or packed raster
may alias a different logical building type.

This contract extends CONTRACT-006 at the source-art boundary. It does not
change simulation state, save data, parcel geometry, road connectivity, player
intent, or the current shipping asset selection.

## Identity and non-aliasing

The stable source key is:

```text
<logical-building-id>/<variant-id>/<view-direction>/<source-revision>
```

- `logical-building-id` names exactly one buildable identity and density level.
- `variant-id` changes massing, roofline, entrance rhythm, and material
  treatment; recolor or prop-only siblings are invalid.
- `view-direction` is one of `north`, `east`, `south`, or `west`.
- `source-revision` preserves rejected and superseded attempts without
  overwriting accepted stochastic masters.

Two different logical building IDs must not share a source hash, normalized
pixel hash, packed pixel rectangle, or fallback alias. Four directional views
of one variant must also have distinct accepted source and pixel hashes.

## Directional geometry

Each four-view set declares one immutable registration record:

- authoritative `footprintTiles` and 72 x 36 point tile basis;
- ground pivot and opaque contact polygon;
- vertical and presentation envelope;
- named road-facing frontage socket and entrance exclusion zone;
- northwest key light and southeast shadow vector;
- city, neighborhood, and block source-pixel budgets.

Across the four views:

- ground pivot drift is at most 0.5 source pixel;
- footprint/contact coordinates are identical after deterministic registration;
- opaque envelope width/height varies by at most five percent unless the
  approved geometry template explicitly requires otherwise;
- entrance remains on the named frontage edge;
- shadow direction, floor scale, door scale, material palette, and silhouette
  identity remain coherent;
- no baked road, parcel, label, UI mark, selection mark, agent, or false state
  may appear.

ImageGen authors appearance only. Deterministic repository templates own
registration, pivots, masks, frontage sockets, scale, and validation.

## Source catalog record

PLAY-027 source records must contain:

- logical building ID, family, density/level, variant, and view direction;
- prompt ID, full prompt, generation date, exposed model or
  `built-in/model-not-exposed`;
- style-anchor, family-anchor, and geometry-template hashes;
- raw, normalized, alpha, and contact-sheet hashes;
- footprint, pivot, envelope, frontage socket, entrance zone, and shadow vector;
- intended gameplay meaning, reviewer, disposition, and rejection reason;
- explicit `orientationTransform: none` and `productionSelected: false`.

The source catalog is not the shipping manifest. The world-art cell may add
task-owned source records, but only integration may approve shared manifest
shape and only the renderer lead may ingest accepted sources into atlas pages
or change production selection.

## Deterministic runtime selection

Later renderer ingestion selects among accepted variants using stable logical
building identity, authoritative level, world seed, and tile coordinate. View
direction is selected from the authoritative adjacent-road frontage. Selection
must not depend on frame order, process hash randomization, camera state, or
save-local presentation state.

PLAY-027 does not implement this runtime mapping. It must nevertheless produce
complete four-view sets so the renderer never needs mirroring, rotation, or
cross-type substitution.

## Batch order and gates

1. Audit current generated-v4 sources and publish an alias/coverage matrix.
2. Freeze one geometry template and family anchor for each of residential,
   commercial, and industrial.
3. Author the 48-source variant-zero spine: twelve R/C/I level identities,
   each with N/E/S/W views.
4. Pass source, alpha, geometry, projection, light, grayscale-recognition, and
   actual-scale contact-sheet review.
5. Expand to variants one and two, then civic/service/utility families, only
   after the prior batch is independently approved.

Use one built-in ImageGen call per source attempt. A rejected result may not
become a sibling reference. After two consecutive direction-drift failures,
freeze that family and return to its geometry template and family anchor.

## Ownership and integration

- The world-art cell owns prompts, raw masters, provenance, source records,
  normalization inputs, and source-level evidence under PLAY-027.
- The world-rendering lane owns ingestion, atlas compilation, live mapping,
  render behavior, and staged-app proof after PLAY-024 acceptance.
- Integration owns this contract, shared manifest changes, merge order,
  independent review, production selection, and publication.
- PLAY-027 may start from the published contract while PLAY-024 finishes, but
  no PLAY-027 pixels enter the shipping pack until PLAY-024 is accepted and the
  renderer lead approves the handoff.
