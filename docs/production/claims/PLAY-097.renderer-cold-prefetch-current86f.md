# PLAY-097 Renderer Cold Prefetch Claim

- **Player outcome:** Residential L1 variant-two remains responsive when the city first enters the golden neighborhood; renderer cold-update latency stays within the accepted `<= 6.03 ms` gate without weakening integrity or residency limits.
- **Owner:** Agent 404 — Renderer Asset Intake Engineer.
- **Authority:** Product baseline `86f92e28214e8913a90f0b5b6c982cc1c3e6d00e` after the PLAY-097 v02 activation aggregate returned one cold-update failure: `6.515958346426487 ms > 6.03 ms` in `testGoldenNeighborhoodShippingRendererExportsThreeLODsAndCompact`.
- **Mutable maximum:**
  - `Native/CitySimNative/Sources/CitySimNative/Rendering/WorldAssetCatalog.swift`
  - `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
- **Deliverable:** Keep SHA verification, active-plus-next residency semantics, and the `128 MiB` guard. Prefetch only adjacent-LOD pages selected by the current scene logical IDs and road masks; do not synchronously decode every manifest page for that adjacent LOD.
- **Immutable boundaries:** All source art, generated atlas PNG bytes, manifests, selection identities, gameplay, UI, simulation, camera behavior, build/package paths, and protected local dirt remain unchanged. The `<= 6.03 ms` threshold is frozen.
- **Proof:** Run one focused invocation covering variant-two four-frontage/three-LOD selection and `testGoldenNeighborhoodShippingRendererExportsThreeLODsAndCompact`. Stop on any new focused failure, integrity/residency regression, path expansion, or candidate identity mismatch.
- **Commit boundary:** Stage only actual changed allowed paths, inspect the complete staged diff, and create one coherent `PLAY-097:` renderer candidate. No aggregate, build, QA, launch, push, release, or self-acceptance.
