# PLAY-098 Commercial L1 v0 Renderer Intake Claim

- **Authority:** `846fffe4146ae355d154dcae37a657ece4a62d49`.
- **Owner:** Agent 404 — Renderer Asset Intake Engineer.
- **Immutable inputs:** the admitted Commercial L1 v0 raw, normalized, receipt,
  and handoff packet under `Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/commercial_l01_v0/`.
- **Mutable maximum:** the Commercial L1 v0 generated-v4 catalog and pack tool,
  generated-v4 manifest and atlas page outputs, `WorldAssetCatalog.swift`,
  directly affected `WorldRenderingTests.swift`, and task-local PLAY-098
  renderer evidence/completion.
- **Deliverable:** package and register all four frontages and three LODs for
  runtime production selection with deterministic pack replay and zero fallback.
- **Proof:** build two isolated packs with byte-identical manifests/pages; retain
  exact admitted source/normalized hashes; run one focused four-frontage ×
  three-LOD production-selection and fallback-zero renderer test.
- **Boundary:** no raw/normalized source mutation, gameplay/UI/simulation/camera
  change, unrelated art family, aggregate, stage build, app QA, push, or release.
  Stop on integrity/residency regression, unexpected path, selection ambiguity,
  or focused failure.
