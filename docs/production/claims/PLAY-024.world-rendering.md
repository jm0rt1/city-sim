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
- **Status:** renderer candidate ready for integration — product `20edac8`, same-state staged evidence `4e0bb39`, and bundled-Python validation `108878f` are complete; final Wave acceptance still awaits the accepted PLAY-016/PLAY-048 fresh-start composition and independent PLAY-053 scoring

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

The current renderer checkpoint improves terrain/material hierarchy, ground
contact, all 16 existing-road masks, authenticated termini, truthful vacant
land, public-realm density, LOD coherence, overlap prevention, and cold-launch
framing without inventing any road or occupied parcel outside `CityGameState`.
Its exact product and validation are recorded under
`docs/production/evidence/PLAY-024/candidate-20edac8/`. The renderer completion
record preserves the exact same-state product and hands off the remaining
integrated fresh-start proof; it does not claim the pending PLAY-053 acceptance.
