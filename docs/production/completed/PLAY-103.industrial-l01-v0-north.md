# PLAY-103 — industrial_l01_v0 North source candidate

- **Direction / identity:** North / `industrial_l01_v0` only.
- **Stage:** `source_candidate`; candidate-ready for independent review.
- **Route:** `north-v3:play-103-currentd3be-industrial-l01-v0-recent-image-v1`.
- **Base / starting HEAD:** `cf3e27f75d033fcd5880b19337ada95030b5e1db` / `d3bed770eb3bf79194df7b15737a19bddafdcd42`.
- **Raw master:** `Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-103/north/raw/industrial_l01_v0/north-v01.png`, SHA-256 `81b1770d6e85f5f92a6a619ac55ddff29bab36358c074a6bbd57a6e434a151a7`, 1536x1024 RGB.
- **Generation provenance:** central `view_image` recent-image bridge; one closed ImageGen result, no worker regeneration. The canonical South anchor remains read-only and is recorded by path/hash in the packet.
- **Outputs:** deterministic block, neighborhood, and city North LODs; North source/game-scale/grayscale sheets; prompt, provenance, manifest, handoff, validator, and evidence.
- **Focused proof:** `validate_direction_source.py` passed with two fresh processes and identical replay hashes. Chroma/alpha/frame-edge gates passed.
- **Readiness:** `candidateReadyForIndependentReview=true`; `sourceReady=false`; `integrationAdmitted=false`; `rendererQuarantined=false`; `productionSelected=false`.
- **Acceptance boundary:** visual quality, literal-scale review, admission, renderer quarantine, family 4/4 selection, runtime, and shipping remain owned by later independent lanes. This worker does not self-accept.
- **Sibling inputs consumed:** none. No sibling, South, shared, renderer, runtime, or governance paths were modified.

Evidence: `docs/production/evidence/PLAY-103/industrial-l01-v0/validation.json`.
