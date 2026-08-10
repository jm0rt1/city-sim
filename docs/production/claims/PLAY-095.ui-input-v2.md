# PLAY-095 Claim — VS-001 pointer publication boundary

- **Title:** Make blocked placement feedback truthful across pointer, keyboard, and accessibility
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/citysim/ui-input`
- **Authority baseline:** The current Integration master commit containing this claim
- **Owning thread:** `019fe8fe-16e2-7640-8f89-65ac4605296a`
- **VS-001 slice:** A map-first build → diagnose → adjust interaction in which
  the latest authoritative result is coherent across pointer action, feedback,
  keyboard parity, compact layout, Full Keyboard Access, VoiceOver, and Reduced
  Motion.
- **Owned roots:**
  `Native/CitySimNative/Sources/CitySimNative/Rendering/CitySceneView.swift`,
  `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`,
  `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`,
  and `docs/production/evidence/PLAY-095/v2/`
- **Bounded deliverable:** Repair the occupied-road pointer publication boundary
  so a blocked target cannot retain stale positive feedback, while preserving
  cancellation, undo state, authoritative simulation state, and keyboard/AX parity.
- **Dependencies:** The current-master claim, the independent PLAY075-R4F-003
  defect packet, and existing map-action/feedback contracts. No new public
  contract or state is authorized by this packet.
- **Focused proof:** Success → blocked, fresh blocked, repeated blocked, and
  blocked → success sequences; pointer/keyboard/AX agreement; unchanged store
  state; focused tests; JSON validation; and `git diff --check`.
- **Independent/full gate:** Integration owns full Swift/staged verification;
  independent PLAY-075 Frontier QA owns the real-app disposition.
- **Stop/refill:** Stop on duplicate/detached identity, route or claim drift,
  path expansion, shared-contract need, save uncertainty, interaction ambiguity,
  or two failed repairs. Refill only with a disjoint UI evidence repair.
- **Forbidden:** CityGameStore truth, models/services, broad HUD redesign,
  renderer composition/camera/art, package/resources/build scripts, world art,
  admission, runtime/production selection, app launch, push, integration, and
  self-acceptance.
- **Status:** Fresh current-master claim; UI branch must be rebased to this
  authority before a worker route is issued.
