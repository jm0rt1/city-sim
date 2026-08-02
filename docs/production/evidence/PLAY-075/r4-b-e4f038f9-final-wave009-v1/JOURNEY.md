# PLAY-075 R4-B one-shot independent journey

Disposition: **RETURN** for exact candidate
`e4f038f942f8c011a0b38b71353e40b4ac5054d4`.

## Player-visible result

R4-B materially fixes one of R4-A's two automatic returns. The city is no
longer surrounded by a broad, flat green quadrant: irregular value islands,
ground marks, and restrained tonal shifts survive at regular and compact
widths without competing with roads or buildings.

The second automatic return remains. In the northwest developed block, two
orange, black-roofed buildings sit immediately beside one another. At city,
neighborhood, and block views they retain nearly the same silhouette, palette,
roof line, and frontage mass. The pair still reads first as repeated content,
not as an intentional mixed neighborhood. Because the route makes resolution
of both R4-A automatic returns a condition of approval, this is a binding
RETURN even though the terrain repair is successful.

No new overlap, clipping, fallback, missing resource, mixed-fidelity edge, or
contact/material regression was visible in the tested regular and exact
900x600 compositions.

## One fresh journey

- Launched the pre-staged executable exactly once after a clean, passing route
  and identity admission.
- Dismissed the first-player welcome surface without loading or substituting a
  save.
- Captured regular City, Neighborhood, and Block views.
- Resized by the player-visible window edge to exact 900x600 content; Computer
  Use retained the expected 904x652 decorated capture envelope.
- Entered compact Focus City and used the player-facing `0` frame-developed-city
  action before capturing compact City, Neighborhood, and Block views.
- Verified keyboard map focus: Right Arrow changed the AX-selected target from
  Open Land block 13,3 to Open Land block 14,3.
- Opened the command guide, searched the available camera commands, and verified
  Escape returned to the map.
- Performed one pointer placement: Road at block 14,3. Treasury changed by the
  shown $120 cost and Undo became available; Escape then cancelled the pending
  follow-on placement and returned to Inspect mode.
- Paused before compact capture to keep state stable.
- Terminated exact PID 2976 with SIGTERM; no second launch occurred.

Industrial L4 was neither activated nor scored.

## Evidence index

- `live/regular/lod-city.png`
- `live/regular/lod-neighborhood.png`
- `live/regular/lod-block.png`
- `live/compact/lod-city.png`
- `live/compact/lod-neighborhood.png`
- `live/compact/lod-block.png`
- `live/interaction/pointer-road-placement.png`
