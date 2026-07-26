# PLAY-073 R1 focused staged results

## Exact process

- Product: `c032c4f2e7f73a339ec4d1b1898cc2ece1f746d7`
- Candidate: `world-rendering-w5f893ad1da1b`
- Bundle:
  `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- PID: `9620`
- Start: `Sun Jul 26 03:51:51 2026`
- RSS after the compact/default interaction pass: `64,256 KiB`
- Process disposition: terminated exactly with `SIGTERM`; no matching process
  survived the pass.

## Focused real-app journey

The exact `visible-city-industrial-upgraded-district-v3.json` save bytes
(`d6e60c425fb240c196655516c236eda1ee5cf7d17ad19b11b2b1149492715826`)
were loaded paused at Day 212.

- Keyboard movement selected displayed **Industrial block 15,12**.
- Pointer selection on the visible structure resolved the same block.
- AX reported **Industrial · Level 2 · Operational**, 89 workers / 220
  capacity, $8/cycle upkeep, and connected road access.
- The state coordinate is 14,11 and the authoritative road is directly south
  at 14,12. The staged south-authored source visibly faces that road.
- Pointer demolition removed the L2 structure and enabled Undo.
- Undo restored treasury from $67,743 to $67,999, net from +$194 to +$415,
  employment capacity, and the exact L2 state.
- Regular and compact layouts retained the same identity, ground contact,
  selection boundary, road context, and unobscured interaction surface.
- The focused renderer gate separately binds construction stages, condition
  restoration, all three semantic LODs, overlays, and Reduce Motion without
  fabricating N/E/W gameplay states.

## Retained frames

- `live/regular-default.jpeg`: uncropped 1,277x768 default window.
- `live/regular-industrial-l2-selected.jpeg`: uncropped 1,277x768 pointer
  selection with Industrial L2 details and road context.
- `live/compact-industrial-l2-selected.jpeg`: uncropped 900x652 decorated
  window, containing the exact 900x600 compact content.
- `live/regular-industrial-l2-AX.txt` and
  `live/compact-industrial-l2-AX.txt`: full selected-state accessibility
  identity.

This packet is an author proof for the R1 ingestion slice, not independent
PLAY-075 acceptance and not renewed acceptance of the deferred PLAY-073
composition work.
