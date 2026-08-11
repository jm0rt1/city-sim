# PLAY-097 Renderer Runtime Activation Claim — Residential L1 Variant Two

- **Player outcome:** The accepted Residential L1 variant-two family becomes an honest third opening-home runtime choice across North/East/South/West and block/neighborhood/city LODs, with no alias, fallback, blank payload, or frontage mismatch.
- **Owner:** Agent 404 — Renderer Asset Intake Engineer, task `019fe1b1-71b8-7aa2-b13d-04d10cffb3d9`.
- **Authority:** Integrated source/quarantine checkpoint `46af2b55a07f99453f4750b6665f792b0793078c`; source candidate `ac392317f599ee9f9a5af53771ff5d0acd573c15`; quarantine receipt SHA-256 `218fec1ea07456909ef77234d7a56e359f54c8b3482783320974a21edaced150`.
- **Mutable maximum:**
  - `Native/CitySimNative/WorldArt/GeneratedV4/catalog/play-097-residential-l01-v2-directions.json`
  - `Native/CitySimNative/WorldArt/GeneratedV4/tools/build_world_asset_pack.py`
  - `Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/generated-v4-manifest.json`
  - `Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/pages/`
  - `Native/CitySimNative/Sources/CitySimNative/Rendering/WorldAssetCatalog.swift`
  - `Native/CitySimNative/Sources/CitySimNative/Rendering/LotRenderer.swift`
  - `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
  - `docs/production/evidence/PLAY-097/residential-l01-v2-runtime-activation/`
  - `docs/production/completed/PLAY-097.residential-l01-v2-runtime-activation.md`
- **Runtime boundary:** Extend the existing generated-v4 pack and authoritative Residential L1 selection only enough to bind the exact admitted variant-two quartet and its twelve LOD payloads. Preserve variants zero/one, all other families, page-format/padding/extrusion/residency guards, frontage sockets, pivots, geometry, hit testing, camera, occupancy, fallback behavior, and deterministic selection contracts. The allowlist is a maximum, not a required touched-file count.
- **Immutable inputs:** Every byte under `Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-101/residential_l01_v2/` and `docs/production/evidence/PLAY-097/residential-l01-v2-family/`, the quarantine receipt/completion, all prior source/admission evidence, and all unrelated product, UI, simulation, gameplay, save, package, build, and protected files.
- **Proof:** Build the generated-v4 atlas twice into two fresh isolated roots; manifests and all page payloads must be byte-identical across runs. Require exact source/LOD hashes, exact manifest inventory/page consistency, no blank/alias/fallback asset, and unchanged non-PLAY-097 family inputs. Then run one focused `WorldRenderingTests` invocation covering variant-two four-direction/three-LOD resource resolution, deterministic selection, and fallback zero. One bounded local repair is permitted; a second failure stops.
- **Commit boundary:** On PASS, stage only actual changed paths inside the mutable maximum, inspect the full index, and create one coherent `PLAY-097:` commit. No aggregate, stage-only app build, real-app QA, PID action, source-art edit, camera repair, packaging, push, release, or self-acceptance.
- **Status:** Active for one validated renderer-runtime outcome lease.
