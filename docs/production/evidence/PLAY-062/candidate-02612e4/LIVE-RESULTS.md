# PLAY-062 hands-on staged results

## Exact candidate

- Product: `02612e414912fdabcab858b0ca97e1f5edbc2757`
- Candidate: `world-rendering-w5f893ad1da1b`
- Bundle: `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Executable:
  `dist/CitySim-world-rendering-w5f893ad1da1b.app/Contents/MacOS/CitySimNative-w5f893ad1da1b`
- Packaged resource:
  `dist/CitySim-world-rendering-w5f893ad1da1b.app/CitySimNative_CitySimNative.bundle/WorldAssets.atlas`

## Exact compact

The decorated screenshots are 900×652; the requested application content is
the exact 900×600 compact window plus native window chrome.

- Day 53 loaded paused with no load toast retained in comparative frames.
- Pointer selection resolved displayed Industrial block 15,12.
- AX exposed `Industrial Level 1 Operational`, 95 workers / 110 capacity,
  road-connected truth, completed condition, utility strain, severe pollution,
  and prosperous vitality.
- The underlying state coordinate is 14,11 and its authoritative road is
  directly south at 14,12, matching the south-authored source.
- Four keyboard Right movements from no selection reached the same Industrial
  lot.
- Pointer selection through City Hall and back to Industrial retained correct
  hit identity and details.
- Building Industrial on the occupied lot was unavailable with the exact
  demolition reason.
- Open displayed block 16,12 was available at $3,200 plus $8/cycle.
- Return committed an Industrial construction site at 0%.
- Undo restored open land and treasury.
- Save followed by Load retained Day 53 paused truth.
- All five typed layers were exercised and retained:
  Land Value, Traffic, Utilities, Happiness, and Pollution.
- Focus City retained the selected Industrial and active Pollution truth.
- City, neighborhood, and block captures are distinct:
  - city: `d122c5d329ccbaa44c2d2300d9aa1d7a28cf3091ebe438c7218c154e6911842a`
  - neighborhood: `bd92286d37d423d1bd3c4445f7f8927c37d4842a600e5df88bf593f85a6d9894`
  - block: `c8afbf8d8843336a6a0499e32a0122795ec8cc43da6e5764a480f1fc4b054070`

## Regular

The uncropped decorated regular screenshots are 1,278×768.

- Day 53 loaded paused.
- Pointer selection resolved the same Industrial L1 south-road identity.
- City, neighborhood, and block LOD were captured.
- Land Value, Traffic, Utilities, Happiness, and Pollution layers were
  captured without obscuring the selected architecture.
- Focus City retained the Industrial/public-realm composition.
- LOD hashes are distinct:
  - city: `9e8fb005809d887b29ff6cfcf0562132a36d1f9d946714687990bc8edbca1a31`
  - neighborhood: `38324d8cf88df7b830f3a0dc4e90b807183806564894ffb8031f351419295f43`
  - block: `4471e5cb91d636af317e5e907b869e319c9c666fa103814de2fc69a282c08ba2`

## Reduce Motion

The exact candidate was relaunched once with
`CITYSIM_COMPACT_WINDOW=1 CITYSIM_REDUCE_MOTION_PROOF=1`.

- Bundle ID, candidate ID, executable, resource bundle, and product commit
  remained unchanged.
- Day 53 loaded paused.
- Pointer-selected Industrial L1 retained its silhouette, authored south
  frontage, selection meaning, and public-realm context.
- `live/reduce-motion/AX-TREE.txt` retains the full accessibility tree for the
  selected Industrial.
- Focused diagnostics report three normal motion actions and zero
  reduced-motion actions for the lifecycle proof.
- Live RSS was 135,696 KiB.

## Evidence boundaries

The packed color/grayscale matrices prove all four authored directions and all
three LODs. The staged interaction packet proves the real authoritative
south-road Industrial L1. It does not imply an unshipped higher Industrial
level or fabricate north/east/west gameplay state.
