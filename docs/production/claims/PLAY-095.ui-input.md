# PLAY-095 Claim

- **Title:** Make blocked placement feedback truthful
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/citysim/ui-input`
- **Base authority:** Published master containing the exact PLAY-075 R4-F
  return packet and this claim
- **Planned surfaces:**
  `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`,
  `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`,
  and `docs/production/evidence/PLAY-095/`
- **Dependency:** Exact independent defect `PLAY075-R4F-003`
- **Validation/proof:** blocked occupied-road pointer action, stale-feedback
  replacement, success/failure tone and AX label agreement, keyboard parity,
  deterministic store state, aggregate staged-app proof, independent PLAY-075
- **Status:** Active. Mutation is authorized only through the separately
  published PLAY-095 route.

Repair the reproduced contradiction where pointer-selecting occupied block
`6,8` for Road correctly exposes a blocked build decision and unavailable map
action while the feedback announcement says `Road construction approved`.
The action update, tone, accessibility label/value, decision card, and actual
simulation outcome must always describe the same latest attempted action.

Do not change build rules, costs, simulation state transitions, renderer,
camera, HUD information architecture, persistence, command mappings, or shared
contracts. Preserve prior feedback history only when no newer attempted action
has occurred; a blocked attempt must atomically replace stale positive text.
Return one coherent commit and focused evidence. Integration owns full/staged
gates; independent PLAY-075 owns final real-app disposition. Do not push,
integrate, self-score, self-accept, or pin.
