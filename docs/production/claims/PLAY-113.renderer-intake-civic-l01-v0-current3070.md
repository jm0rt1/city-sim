# PLAY-113 Renderer Intake Claim — Civic L1 v0

- **Lane / owner:** World rendering — Agent 404, Renderer Asset Intake Engineer.
- **Authority / base:** `8acbf6ae4e39e0e1cf54b43d6366582eeac98cc0`.
- **Immutable source packet and admission authority:**
  `Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/civic_l01_v0/` and
  `docs/production/evidence/PLAY-113/civic-l01-v0-family/RENDERER-HANDOFF.json`
  remain immutable historical candidate-only source bytes. Integration admits
  that exact packet solely through
  `docs/production/evidence/INTEGRATION/PLAY-113-CIVIC-L01-V0-SOURCE-ADMISSION-CURRENT8AC.json`.
  All raw, normalized, prompt, provenance, contact-sheet, handoff, and
  validation bytes are frozen.
- **Deliverable:** Mechanically register the exact four civic L1 frontages and
  their three LODs into the generated-v4 resource pack and runtime selector;
  update only required generated manifest/atlas resource outputs and focused
  renderer proof/evidence so civic selection has zero fallback.
- **Maximum mutable surfaces:** the civic GeneratedV4 catalog descriptor,
  `Native/CitySimNative/WorldArt/GeneratedV4/tools/build_world_asset_pack.py`,
  generated-v4 atlas pages and manifest,
  `Native/CitySimNative/Sources/CitySimNative/Rendering/WorldAssetCatalog.swift`,
  `Native/CitySimNative/Sources/CitySimNative/Rendering/LotRenderer.swift`,
  focused `WorldRenderingTests.swift`, and
  `docs/production/evidence/PLAY-113/civic-l01-v0-renderer/` plus completion.
- **Proof / stop:** Two isolated pack runs must be byte-identical; every source
  and normalized handoff hash remains exact; one focused four-frontage ×
  three-LOD civic production-selection proof shows zero fallback. Stop on any
  raw/normalized/admission byte drift, pack nondeterminism, atlas integrity or
  residency regression, source/catalog ambiguity, unexpected path, or focused
  failure. On PASS commit only the coherent renderer intake candidate. No
  aggregate, staged build, player QA, push, or release in this lane.
