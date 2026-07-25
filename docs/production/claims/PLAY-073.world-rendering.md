# PLAY-073 Claim

- **Title:** Replace the board with an authored district
- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Worktree:** `/Users/James/.codex/worktrees/cac1/city-sim`
- **Base authority:** Published Wave 008 product candidate
  `87e1e682566b68d20deb1a9e2028e2b885e0423a`; iteration-two branch authority
  is the clean rejected-evidence checkpoint
  `b11391891d412c40741c8466c3e4bd5d6026ab1c`, whose product ancestor
  `1c590e446e718024f4848d22b33b05db4c73555a` is integrated on local
  integration candidate `fbbff0c7a633be81ae7779709a76ff3202d928fb`
- **Planned surfaces:** renderer-owned camera composition, terrain/public-realm/parcel/place/activity rendering, deterministic variation and collision tooling, renderer tests/diagnostics, staged proof, and `docs/production/evidence/PLAY-073/`
- **Dependencies:** accepted PLAY-024/062/065/066 product; PLAY-072 fixtures when available; separately accepted PLAY-027 art only
- **Validation/proof:** same-state regular/compact early/pressure/recovery/upgraded/terminal comparisons at all LODs; developed-district occupancy; light/shadow/material/value/outline coherence; repetition ledger; zero seams/overlaps/fallback; pointer/keyboard/AX/Reduce Motion; pack parity; residency/RSS/frame budgets; PLAY-075
- **Status:** returned after integration's real-app visual rejection; focused
  iteration two is authorized on exact clean branch checkpoint `b113918`

Recompose the visible world as one authored district. The developed city must
dominate the intended camera while retaining useful buildable context. Roads,
curbs, sidewalks, parcels, entrances, parks, service yards, terrain,
vegetation, props, activity, and buildings must share one coherent visual
language and ground plane.

Do not invent simulation facts, ingest unaccepted PLAY-027 art, mirror/rotate
or alias buildings, hide interaction, change gameplay/UI/persistence rules, or
trade compact/LOD quality for one hero frame. Stop on mixed fidelity, obvious
adjacent repetition, broken seams, floating/detached places, fallback,
collision, or resource regression. Do not push, integrate, self-score,
self-accept, or pin.

## Iteration-two return authority

The first returned product is technically admissible but visually rejected.
Integration operated exact staged master `fbbff0c` at the default Day 11
opening and exact compact size. The developed district occupied only
`0.3689999848900444` of regular safe width and `0.5100866307358453` of compact
safe width. A seven-building crossroads remained surrounded by the largest
visual mass: repetitive undifferentiated green. Roads still read as isolated
black strips, while building, park, utility, outline, material, shadow, and
ground-contact fidelity remained mixed.

Iteration two must correct that exact production opening systemically:

- the connected authored district and public-realm envelope occupies at least
  `0.60` of safe map width at both regular and compact sizes;
- useful expansion context remains visible, including at least one complete
  buildable parcel band beyond the developed edge, so the result is not a
  crop-only improvement;
- no single plain-grass region is the largest authored visual mass or exceeds
  `0.25` of the safe map aperture;
- every occupied place has continuous road, curb, sidewalk or service-edge,
  entrance/frontage, parcel-ground, and contact-shadow geometry;
- roads no longer read as isolated black strips at any governed LOD;
- the same early, pressured, recovered, upgraded, and terminal states prove
  one coherent value, outline, material, light, shadow, and ground-contact
  language in color and grayscale;
- city, neighborhood, and block LODs remain materially composed at regular
  and compact sizes, with zero fallback, overlap, clipped interaction,
  adjacent aliasing, or invented simulation truth; and
- pointer and keyboard targeting, placement preview, invalid placement,
  overlays, selection, Focus City, Reduce Motion, AX, frame time, node/draw
  count, RSS, residency, and deterministic two-build identity remain exact.

Start with an exact candidate-bound audit of the default Day 11 opening, not a
fixture-only hero state. Preserve the first iteration and its rejection packet.
Commit a corrected renderer product before evidence, then retain real staged
regular/compact default-opening proof plus the full authoritative state/LOD
matrix. Return the slice if any automatic reject remains; do not describe
technical green as visual acceptance.
