# PLAY-080 Industrial L4 South zero-pixel predesign review request

## Disposition

`READY_FOR_INDEPENDENT_PREDESIGN_REVIEW`

This is a South-only, zero-pixel checkpoint. It is not source authority,
production selection, Renderer ingestion, or self-acceptance. Pixel A remains
forbidden until Integration publishes the North-bound family/material lock and
updates PLAY-080.

## Independent South design

The text scene was authored from published family, registration, camera, light,
shadow, and literal-scale requirements. No sibling scene, script, component
coordinates, raster, mask, contact sheet, mirror, rotation, or transform was
opened or consumed.

The South facade uses:

- one broad high-bay hall and low control/staff wing;
- three South road-facing freight recesses, with one monumental deep portal;
- a separate projecting staff vestibule;
- an asymmetric three-part monitor roof;
- one offset stack and rear process bay;
- a rear gantry and turbine/process court outside the portal projection; and
- provisional warm masonry, charcoal steel, oxidized machinery, restrained
  green, glazing, roof, heat, portal, service-shadow, and apron roles.

## Static proof

`PREDESIGN-STATIC-PROOF.json` passes all 14 checks:

- exact 56×56 grounded footprint within the 72×36 tile basis;
- South socket at `[28,0,0]`, southeast pivot at `[28,0,28]`, and `y=0`
  ground;
- three freight openings plus separate staff entrance on the South frontage;
- monumental portal frame, reveal, and dark inset;
- unique independent component identities and `orientationTransform: none`;
- full provisional material-role coverage with pixel rendering blocked;
- northwest source light and southeast contact vector; and
- more than three static silhouette height breaks.

## Actual-camera zero-pixel proof

`PREDESIGN-ACTUAL-CAMERA-PROOF.json` passes all 9 checks under Blender
`4.5.12 LTS`, build `84afd5f785f7`, using the frozen background/factory-startup
boundary. The validator creates Blender meshes and projects them through the
configured orthographic camera. It never invokes a render operator and reports
`renderInvocations: 0`, `imageOutputs: 0`.

Observed analytic results:

- footprint maximum error: `0.000496` source pixel against the published R3
  diamond;
- South socket maximum error: `0.000473` source pixel;
- monumental portal: `14.057144 × 21.025661` pixels at literal 192;
- jamb projected widths: at least `3.428576` literal pixels;
- header projected thickness: `11.242420` literal pixels;
- secondary freight openings: `8.057144` literal pixels each;
- process components intersecting the portal projection: `0`; and
- distinct silhouette rows separated by at least two compact pixels: `7`.

## Requested independent judgment

Please judge whether the independently authored South massing and frontage are
ready to consume the future North family/material lock. Static and analytic
proof do not establish visual acceptance. In particular, review the broad-hall
hierarchy, monumental portal proportions, three-opening logistics rhythm,
staff-entrance separation, rear-process silhouette, and whether the provisional
material roles can reconcile without redesign.

Return the checkpoint if the South facade reads as a generic warehouse,
storefront rhythm, sibling-derived view, compact tower, weak heavy-industry
silhouette, obstructed freight portal, wrong socket/pivot, or a design that
would require family-lock divergence.
