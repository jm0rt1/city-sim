# PLAY-073 Claim

- **Title:** Replace the board with an authored district
- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Worktree:** `/Users/James/.codex/worktrees/cac1/city-sim`
- **Base authority:** Published Wave 008 product candidate `87e1e682566b68d20deb1a9e2028e2b885e0423a`
- **Planned surfaces:** renderer-owned camera composition, terrain/public-realm/parcel/place/activity rendering, deterministic variation and collision tooling, renderer tests/diagnostics, staged proof, and `docs/production/evidence/PLAY-073/`
- **Dependencies:** accepted PLAY-024/062/065/066 product; PLAY-072 fixtures when available; separately accepted PLAY-027 art only
- **Validation/proof:** same-state regular/compact early/pressure/recovery/upgraded/terminal comparisons at all LODs; developed-district occupancy; light/shadow/material/value/outline coherence; repetition ledger; zero seams/overlaps/fallback; pointer/keyboard/AX/Reduce Motion; pack parity; residency/RSS/frame budgets; PLAY-075
- **Status:** authorized on the exact published product candidate

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
