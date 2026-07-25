# PLAY-060 hands-on staged results

## Regular

Exact staged candidate `world-rendering-w5f893ad1da1b` was launched from the packaged `.app` with an isolated data root.

- Clean City view retained at `live/regular/commercial-charter-city-clean.png`.
- Pointer selection at the visible Commercial storefront resolved to displayed block 14,12.
- AX exposed `Commercial Level 1 Operational`, workers/capacity, road access, construction state, condition, and consequence text.
- The underlying zero-based state coordinate is 13,11 and its road is directly south at 13,12, matching the selected south-authored source.
- Left Arrow moved to displayed road 13,12; Right Arrow returned to the same Commercial lot.
- Commercial build on the occupied lot was unavailable with the exact demolition reason.
- Commercial build on open displayed block 17,14 was available at $2,400 plus $6/cycle.
- Return committed the placement and AX announced `Construction site, 0 percent`.
- Toolbar Undo restored open land and disabled Undo again.
- Save announced `City saved`; Command-O loaded the quicksave paused.
- City, neighborhood, and block captures are uncropped 1,278×768 decorated windows and have distinct SHA-256 values.

## Exact compact

The same staged executable was relaunched with `CITYSIM_COMPACT_WINDOW=1` and isolated data. The active, non-terminal `story-commercial-complication-v1.json` fixture has SHA-256 `fbcff0377fb1692595292cabd81c2ea70f2b69681a9964006078d031546fe03a`.

- Command-O loaded Day 33 paused with Commercial priority `Protect local storefronts`.
- The decorated screenshots are 900×652; the content request is the exact 900×600 proof window plus native window chrome.
- Pointer selection resolved the same displayed Commercial block 14,12 and AX exposed `Commercial Level 1 Operational`.
- Compact city/neighborhood/block captures have distinct hashes:
  - city: `24fa520f9e4304462b8722bc045d75f2e965183678850b73a1a45537640b1da5`
  - neighborhood: `9c48693bb9bc2af46a89d34c4c11307ed71c0732ccf698c1d7ecda84cec95d2d`
  - block: `80d8426a67fc3b0d71d3f310096429f9d486764411f4d08a0407cfc5bf4c44cf`
- After three explicit city/neighborhood/block cycles, RSS was 201,696 KiB.

## Reduce Motion

The exact executable was relaunched with `CITYSIM_REDUCE_MOTION_PROOF=1` and the same active Commercial fixture.

- Day 33 loaded paused.
- Commercial skyline silhouettes, frontage, selection meaning, and public-realm context remained present.
- Focused tests report zero reduced-motion actions for the lifecycle proof and bounded suppression across save/load/undo replay.
- Live RSS was 275,136 KiB, below the 333.8 MiB ceiling.

## Rejected capture

The first compact attempt loaded the terminal Town Charter fixture and presented its legitimate blocking victory modal. It is retained under `rejected/` and excluded from comparative visual claims.

The accepted compact packet instead uses the active, paused `story-commercial-complication-v1.json` fixture.
