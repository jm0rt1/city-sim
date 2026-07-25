# PLAY-027 Industrial L2 source-v03 pre-pixel gate — PASSED

Source-v03 is the frozen descriptor input authorized to enter the raw-render
gate. It is not accepted source art and remains non-shipping with
`productionSelected: false`.

The only source-v02 geometry repair raises the primary hazard apron lane by
0.05 world unit so it no longer shares a structural boundary with the service
apron. Camera, footprint, pivot, socket, contact, shadow, light, authored
massing, materials, and validator thresholds remain unchanged.

## Governed results

- Generic scene validation: pass, four of four directions.
- Industrial L2 frontage/progression validation: pass.
- Structural-boundary validation: zero coincident boundaries in N/E/S/W.
- Unique descriptor hashes: 4/4.
- Unique geometry IDs: 4/4.
- Per direction: 9 mass blocks, 6 roof volumes, 10 trim bands, three-post
  logistics gantry, dual headers/crowns, two apron lanes, and exact socket.
- L1→L2 progression: floors 2→3, wall height 28→42, maximum authored
  structural top 59.8→76, and a distinct massing profile.

## Exact descriptor hashes

- North: `aee5c7ef5de5b62fb357335c09d9a020ed97582882bfd1bf7ac7bc21f6d3a5b6`
- East: `24ccd400535090532be046fe9868c069f3fc1b94aa999fc4c6569b74c24c03e1`
- South: `ce4c8067135a1f57ee50dbfed9aa3b83b7fab6aa847aa7bd8c79cb783bb72d1c`
- West: `8ce989ea6c4b85fbdf04ba002236179c45b71b0fbe2cc2d5a39a2abf28b29a1e`

The next gate is exactly three fresh native SceneKit processes per direction.
No normalization is permitted unless raw A/B/C file and pixel identity,
four-view uniqueness, RGBA visibility, occupancy, registration, and literal
visual completeness all pass.
