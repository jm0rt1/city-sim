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
- **Acceptance:** `APPROVE_PLAY112_AFFECTED_JOURNEY` for exact integrated product
  `a58bd52653536505c7c3b675555f0d861fd656ff`. The sealed staged app passed fresh
  Day 1/tick 0 startup; AX Commercial selection through `Select buildable block`
  at displayed block `5,9`; construction, visible stewardship recovery, explicit
  save, exact-PID termination, and same-root Day 4 paused load. Receipt:
  `/private/tmp/CITYSIM-PLAY112-A58B-QA-RESULT.txt`, SHA-256
  `eac586f4bb8184991ee5526ce1776003456ee8a522b38d0b6203e32d8eb70f32`.
  Accepted PID `57592` remains paused and running. This is not release or push
  authority.
