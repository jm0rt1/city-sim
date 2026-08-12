# PLAY-116 World Rendering Claim — Normalize the Composed City

- **Lane / owner:** World rendering — Agent 404, Renderer Asset Intake Engineer.
- **Authority / base:** `3ac8e34733be8795787242d310d50058058e5c4b`.
- **Player outcome:** Existing Civic, Commercial, Residential, and Industrial
  assets read as one grounded isometric game at city, neighborhood, and block
  scales, rather than mixed scales, perspectives, or floating/competing props.
- **In scope:** `LotRenderer.swift`, `WorldAssetCatalog.swift`,
  `WorldVisualStyle.swift`, `TerrainRenderer.swift`, the generated-v4 pack
  builder and manifest only when required for deterministic runtime metadata,
  focused `WorldRenderingTests.swift`, and
  `docs/production/evidence/PLAY-116/composed-view/` plus completion.
- **Frozen contracts:** Accepted source/raw/normalized/provenance bytes, atlas
  pixels unless pack metadata requires a deterministic derived update, normal
  selection/fallback/residency contracts, CityScene camera behavior, gameplay,
  UI, saves, package/build, and source generation are out of scope.
- **Proof / stop:** Prove deterministic pack/resource behavior and zero
  fallback, then retain before/after mixed-family city/neighborhood/block
  captures or contact sheet showing normalized scale, isometric presentation,
  and ground contact. Stop on source/provenance drift, fallback/residency
  regression, camera/selection/gameplay impact, atlas regeneration need,
  unrelated path, or second focused failure. One bounded local repair is
  allowed. On PASS commit only the coherent renderer packet; no aggregate,
  stage, QA, push, or release.
