# PLAY-095 Claim

- **Title:** Make blocked placement feedback truthful
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/citysim/ui-input`
- **Base authority:** Published master containing the exact PLAY-075 R4-F
  return packet and this claim
- **Planned surfaces:**
  `Native/CitySimNative/Sources/CitySimNative/Rendering/CitySceneView.swift`,
  `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`,
  `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`,
  and `docs/production/evidence/PLAY-095/`
- **Dependency:** Exact independent defect `PLAY075-R4F-003`
- **Validation/proof:** blocked occupied-road pointer action, stale-feedback
  replacement, success/failure tone and AX label agreement, keyboard parity,
  deterministic store state, aggregate staged-app proof, independent PLAY-075
- **Status:** Active at the pointer/view boundary. The integrated store-boundary
  diagnostic proved that `CityGameStore.primaryAction(at:)` already replaces
  stale approval with the correct caution result. Mutation is authorized only
  through the separately published successor PLAY-095 route.

Repair the reproduced contradiction where pointer-selecting occupied block
`6,8` for Road correctly exposes a blocked build decision and unavailable map
action while the feedback announcement says `Road construction approved`.
The action update, tone, accessibility label/value, decision card, and actual
simulation outcome must always describe the same latest attempted action.

Do not change build rules, costs, simulation state transitions, world renderer,
camera, HUD information architecture, persistence, command mappings, or shared
contracts. The candidate/pointer publication and the corresponding attempted
primary action must present one coherent latest result; no intermediate blocked
target may remain paired with stale positive feedback.
Return one coherent commit and focused evidence. Integration owns full/staged
gates; independent PLAY-075 owns final real-app disposition. Do not push,
integrate, self-score, self-accept, or pin.
