# PLAY-095 Claim — Beta blocked-placement feedback

- **Title:** Make blocked placement feedback truthful
- **Lane:** UI and input
- **Lane owner:** Agent 301 — UI and Input Lead
- **Owning task:** `019fec92-42dc-7eb2-8993-c9fd8ffdf3bf`
- **Branch:** `codex/citysim-ui-input-play095-beta-current21e1`
- **Worktree:** `/private/tmp/citysim-play095-beta-current21e1`
- **Governance baseline:** the claim-bearing descendant of
  `21e1d5d024a9a0a4ae598c86423da694b60c5eae`
- **Accepted product candidate:** `65c0f4dd2054baa0446d4e9c9a3673dfb4a01521`
- **Allowed maximum surfaces:**
  `Native/CitySimNative/Sources/CitySimNative/Rendering/CitySceneView.swift`,
  `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`,
  `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`,
  `docs/production/evidence/PLAY-095/beta-blocked-placement/`, and
  `docs/production/completed/PLAY-095.ui-input-blocked-placement.md`.
- **Frozen paths:** simulation/services/models, `CityScene.swift`, command
  mappings, renderer composition, persistence, resources, and every path not
  listed above.
- **Dependency:** exact accepted Alpha product plus the existing public
  `BuildRejection.message` and map-action presentation contracts.
- **Validation/proof:** blocked occupied-road pointer action, stale-feedback
  replacement, success/failure tone and AX label agreement, keyboard parity,
  deterministic store state, focused `CityCommandCatalogTests`, and
  `git diff --check`. Integration owns later aggregate/staged-app proof and
  independent QA owns real-app acceptance.
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
Return one coherent commit and focused evidence. If the existing public reason
contract is insufficient, stop and report that exact missing contract rather
than editing a shared contract. Do not push,
integrate, self-score, self-accept, or pin.
