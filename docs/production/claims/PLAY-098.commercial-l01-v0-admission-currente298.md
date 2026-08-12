# PLAY-098 Commercial L1 v0 Admission Claim

- **Authority:** `e2980d664685cf0d7e0bd8082444763f77355d92`.
- **Owner:** Agent 006 — World Art Director.
- **Immutable inputs:** all four accepted source masters, prompts, provenance,
  contact sheet, and source-quality report under
  `Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/commercial_l01_v0/`.
- **Mutable roots:**
  - `Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/commercial_l01_v0/normalized/`
  - `Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/commercial_l01_v0/tools/build_commercial_l01_v0_admission.py`
  - `Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/commercial_l01_v0/tools/validate_commercial_l01_v0_admission.py`
  - `docs/production/evidence/PLAY-098/commercial-l01-v0-admission/`
  - `docs/production/completed/PLAY-098.commercial-l01-v0-admission.md`
- **Deliverable:** registered four-frontage normalized outputs with three LODs
  per frontage, deterministic hashes, a source-scale/game-scale contact sheet,
  and an immutable renderer handoff packet.
- **Proof:** validate geometry, direction distinction, alpha/chroma/frame
  safety, source and normalized hashes, and deterministic replay into two
  isolated roots. One local repair is permitted; a second failed proof stops.
- **Boundary:** no raw-source alteration, renderer/runtime/atlas/catalog change,
  product/UI/simulation/gameplay change, aggregate, build, app QA, push, or
  release. On PASS, commit the admission packet only and hand it to Renderer.
