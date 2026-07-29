# PLAY-081 Industrial L4 West zero-pixel predesign disposition

**Disposition:** `PREDESIGN_PASS_PENDING_NORTH_FAMILY_MATERIAL_LOCK`

This is a durable West-only predesign checkpoint, not source acceptance.
Pixel A, B/C, normalization, renderer ingestion, shipping, runtime changes,
production selection, push, integration, and self-acceptance remain blocked.

## Independent West design

- scene geometry ID:
  `industrial-l04-west-v01-forge-throat-independent`;
- no sibling scene, component coordinates, raw pixels, masks, contact sheets,
  mirror, rotation, or transform were consumed;
- the governed West socket is `(640,704)` on DCC ground edge `x=-28`;
- a short, lighter apron connects that exact socket to a monumental recessed
  freight throat;
- the separately authored massing uses a long high-bay forge hall, three
  unequal roof-monitor heights, a subordinate offset stack, a low warm control
  wing, and a projection-separated gantry/process court;
- material values are provisional numeric roles only and explicitly await
  Integration's North-bound family/material lock.

## Static zero-pixel proof

`STATIC-PREDESIGN-PROOF.json` passes with zero failures:

- exact `56×56` footprint, centered registration, pivot, and West socket;
- every component inside the footprint and vertical envelope;
- complete provisional material-role coverage;
- portal-frame grayscale separation above the published minimums;
- `MISSING_NOT_ALIASED` catalog disposition for `industrial_l04`; and
- ImageGen, raw renderer, normalizer, SceneKit, and pixel-output counts all
  equal to zero.

## Actual governed Blender camera proof

`ACTUAL-CAMERA-PREDESIGN-PROOF.json` passes under Blender `4.5.12 LTS` without
calling `bpy.ops.render` or writing an image:

- maximum ground registration error: `0.000183` source pixel;
- literal-192 portal inset: `22.285715 × 29.339066` pixels, exceeding the
  `14 × 12` target;
- literal-192 jamb bounds: `5.714281 × 22.453064` and
  `5.714287 × 22.453064` pixels;
- literal-192 header bounds: `30.857140 × 18.927837` pixels;
- declared process intersection with the portal inset: exactly `0.0` pixels
  for the stack, gantry beam, both gantry supports, and turbine vessel;
- qualifying silhouette breaks: `6`, exceeding the minimum `3`; and
- render invocation and pixel-output counts: `0`.

Static and actual-camera reports reproduce byte-for-byte on a second run.

## Required next authority

After this checkpoint is committed, merge the published parallel operating
baseline, reload the updated World Art skill and live board, and revalidate.
No Pixel A work may begin until Integration publishes the North-bound
family/material lock and updates PLAY-081.
