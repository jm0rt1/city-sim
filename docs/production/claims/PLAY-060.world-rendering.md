# PLAY-060 Claim

- **Title:** Ship the directional commercial skyline
- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Worktree:** `/Users/James/.codex/worktrees/cac1/city-sim`
- **Base authority:** First published integration authority containing this claim and the accepted PLAY-027 Commercial source handoff
- **Claimed:** July 25, 2026
- **Planned surfaces:** renderer-owned generated-v4 production selection, manifests, atlas inputs/outputs, Commercial level/frontage lookup, renderer tests and diagnostics, staged proof, and `docs/production/evidence/PLAY-060/`
- **Dependencies:** accepted PLAY-028 pipeline; clean PLAY-027 Commercial L1–L4 source candidate `bf3e24b2b465870f131ac0a01a2327ac4969d5d5`; CONTRACT-006, CONTRACT-010, CONTRACT-011; exact published claim baseline
- **Validation/proof:** source-to-pack hash inventory; 16/16 level/direction matrix; zero alias/mirror/rotation/fallback; deterministic two-build pack identity; pivot/footprint/frontage/alpha/padding; Commercial-versus-Residential and cross-level comparisons; staged regular/compact and N/E/S/W road-adjacency proof; three LODs; construction/condition/selection/preview/undo/save-load/Reduce Motion/pointer/keyboard/AX; residency/RSS/frame budgets; full suite; independent PLAY-061 review
- **Status:** ready for renderer dispatch after publication

Ingest only the independently accepted Commercial L1–L4 variant-zero N/E/S/W
source set through `bf3e24b2b465870f131ac0a01a2327ac4969d5d5`.
The source art remains the pixel authority. The renderer lane may select,
normalize, pack, manifest, load, and present it, but may not repair,
reinterpret, recolor, rotate, mirror, or substitute any source.

Direction derives from authoritative road adjacency and the accepted frontage
socket, never camera orientation. Level derives from authoritative building
state. Commercial may never fall back to Residential or alias another
Commercial level. Selection must remain byte-stable through unchanged pulses,
camera/LOD changes, undo, save/load, and staged bundle reconstruction.

Do not ingest Industrial, edit source scenes, change gameplay/simulation/save/
command/UI contracts, modify `Package.swift`, or broaden generated-v4 manifest
types without integration approval. Commit product, evidence, and completion
outcomes separately. Do not push, integrate, self-score, self-accept, or pin.
