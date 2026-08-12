# PLAY-112 Claim

- **Title:** Make build-mode map selection deterministically accessible
- **Lane:** UI and input
- **Base authority:** `5ac902d92152458ce634b449a297f3f100001635`
- **Owner:** Agent 301 — UI/Input
- **Allowed product paths:**
  `Native/CitySimNative/Sources/CitySimNative/Rendering/CitySceneView.swift` and
  `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`.
- **Player outcome:** When no block is selected in build mode, expose exactly one
  `Select buildable block` accessibility custom action. It selects the first
  row-major empty tile accepted by existing `CitySimulation.validateBuild`, using
  the existing pointer-selection path, and updates the map accessibility value.
- **Focused proof:** In a fresh seed-42 city with Commercial selected, the action
  selects grid `(4,8)` / displayed block `5,9`, names that block in accessibility,
  and the existing primary action builds Commercial.
- **Frozen boundaries:** No CityGameStore, simulation, camera, renderer, art,
  gameplay, keyboard mapping, build scripts, aggregate, stage, QA, push, or release
  changes. Stop on a second failed focused proof, a required public-contract change,
  or any path outside this claim.
