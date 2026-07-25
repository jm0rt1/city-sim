# PLAY-028 Claim

- **Title:** Ship the directional residential skyline
- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Worktree:** `/Users/James/.codex/worktrees/cac1/city-sim`
- **Base commit:** First published integration authority containing this claim and accepted PLAY-027 Residential source catalog
- **Claimed:** July 25, 2026
- **Planned surfaces:** `Native/CitySimNative/Sources/CitySimNative/Rendering/`, generated-v4 production manifest and task-owned pack inputs/outputs under `Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/`, renderer tests, pack/validation tooling required by the existing generated-v4 pipeline, and `docs/production/evidence/PLAY-028/`
- **Dependencies:** accepted PLAY-023; accepted PLAY-024; integrated PLAY-027 Residential source catalog through `32e5d1dec2857f8617ecc3cd3c194c98d35b2d6b`; CONTRACT-006, CONTRACT-010, and CONTRACT-011
- **Validation/proof:** source-to-pack hash inventory; 16/16 level/direction selection matrix; zero alias/mirror/rotation/fallback report; deterministic two-build pack identity; pivot/footprint/frontage/alpha/padding validation; staged default/compact and N/E/S/W road-adjacency proof; construction/condition/selection/preview/undo/save-load/Reduce Motion/pointer/keyboard/AX checks; LOD/residency/performance diagnostics; full suite; independent PLAY-053 successor review
- **Status:** ready for independent quality review — exact product
  `a08414c591b0f3600da5588d8c771e74d237727f`, evidence
  `61b20d47df5a1118e2ca83f06bc8fa91af3cb75c`, and checksummed packet
  `docs/production/evidence/PLAY-028/candidate-a08414c/`

Ingest only the accepted Residential L1–L4 variant-zero N/E/S/W source set.
The renderer lead owns production selection, deterministic normalization and
packing, generated-v4 manifest entries, stable level/frontage lookup, runtime
loading, diagnostics, and real-app evidence. The accepted art remains the pixel
authority: do not repair or reinterpret it inside shipping resources.

Direction must derive from authoritative road adjacency and the established
frontage socket, never from camera orientation. Each direction is an authored
source identity. Runtime mirroring, rotation, cross-level aliasing, and legacy
or cross-family fallback are forbidden. Deterministic selection must preserve
the same bytes through unchanged pulses, save/load, undo, camera changes, and
LOD cycling.

This claim explicitly authorizes the renderer lane to update the generated-v4
shipping manifest and atlas pack for the Residential slice. It does not
authorize a public model/store/save/command contract change, `Package.swift`,
Commercial or Industrial ingestion, new source generation, or unrelated
environment/HUD work. Propose any required shared public contract to
integration before mutation.

Commit coherent product, evidence, and completion outcomes separately. Do not
push, integrate, self-score, or declare acceptance. Handoff the exact clean
candidate and retained staged proof for independent review.
