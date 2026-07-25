# PLAY-024 Claim

- **Title:** Replace terrain, streets, and environmental structure
- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Worktree:** `/Users/James/.codex/worktrees/cac1/city-sim`
- **Base commit:** Published Wave 006 integration baseline containing this claim
- **Claimed:** July 24, 2026
- **Planned surfaces:** generated-v4 authored terrain/street/environment sources and descriptors, deterministic road/terrain grammar, SpriteKit world presentation, renderer tests, performance diagnostics, and exact staged evidence
- **Dependencies:** accepted PLAY-023; existing CONTRACT-005/006 geometry and asset contracts; immutable PLAY-041 spatial truth
- **Validation/proof:** deterministic pack builds, 16-mask reciprocal roads, 3 x 3 seam mosaics, overlap/ground-contact checks, same-seed before/after, city/neighborhood/block LOD, default/compact, construction/strain/recovery, Reduce Motion, pointer/keyboard/AX hit truth, full suite, and independent PLAY-053 handoff
- **Status:** active — returned for focused repair by independent PLAY-053 evidence commit `6803f61`; exact integrated candidate `91438bf` scored 14/20 and triggered the composition/coherence automatic rejects below

Make the playable world itself excellent. Replace the current crossroads
diorama, abrupt road stubs, empty green board, and mixed-fidelity surroundings
with one connected, inhabited, coherent city fabric. The result must be
systemic across normal play, not a special hero plate.

Follow `docs/production/WAVE-006-WORLD-EXCELLENCE.md`. Use image generation
only as an authored-source tool inside the deterministic generated-v4 pipeline.
Do not let generated pixels define connectivity, geometry, anchors, truth, or
acceptance. Do not change gameplay, save, commands, SwiftUI HUD composition, or
public contracts. Commit product, evidence, and completion separately; do not
push, self-integrate, or self-score.

The completed renderer candidate improves terrain/material hierarchy, ground
contact, all 16 existing-road masks, authenticated termini, truthful vacant
land, public-realm density, LOD coherence, overlap prevention, and cold-launch
framing without inventing any road or occupied parcel outside `CityGameState`.
The generic adoption at `a1e589e` consumes the authoritative 32-road,
two-block, eight-lot starter state and passes the combined 199-test suite. The
retired-cross same-state packet remains under
`docs/production/evidence/PLAY-024/candidate-20edac8/`; the changed-state
fresh-start packet is explicitly labeled Comparison B under
`docs/production/evidence/PLAY-024/candidate-a1e589e/`. The completion record
does not claim PLAY-053 acceptance.

## Independent return contract

The blocking evidence is
`docs/production/evidence/PLAY-053/final-91438bf/DISPOSITION.md`, especially
`live/current-industrial-strain-default.jpeg`. The next renderer candidate
must:

1. make deterministic `0` framing prioritize the developed/pressured district
   rather than the full mostly empty road loop, without hiding an authoritative
   defect or changing hit geometry;
2. replace conspicuous dark macro-terrain cell boundaries with a continuous,
   richer terrain/public-realm composition at default and compact sizes;
3. add truth-safe environmental depth and LOD meaning so high-detail buildings
   and roads no longer sit on broad low-detail polygonal green fields;
4. reduce pollution-overlay coverage of building silhouettes while preserving
   non-color truth and the accepted AX legend; and
5. retain all accepted PLAY-053 results: authoritative road/lot truth,
   deliberate termini, HUD aperture, selection/preview/construction/undo,
   pointer/keyboard/FKA/AX routes, Reduce Motion, zero fallback, bounded
   residency/RSS, and the 199-test baseline.

No gameplay topology, save, public store, SwiftUI HUD, command, or simulation
contract change is authorized. Product, retained real-app evidence, and the
updated completion record must be committed separately before a new exact
integration handoff.
