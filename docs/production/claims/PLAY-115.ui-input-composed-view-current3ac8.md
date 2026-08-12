# PLAY-115 UI/Input Claim — Restore Map-First Composed View

- **Lane / owner:** UI/Input — Agent 301, UI/Input Lead.
- **Authority / base:** `3ac8e34733be8795787242d310d50058058e5c4b`.
- **Player outcome:** At regular and true 900 × 600 content sizes, the map is
  the primary surface: at most one contextual guidance layer is visible and
  Diagnostics/Details are contextual or collapsible without obscuring the city.
- **In scope:** `ContentView.swift`, `TopHUDView.swift`,
  `StrategyCommandCenterView.swift`, `InspectorView.swift`,
  `OverlayPickerView.swift`, focused `HUDConsequenceFeedbackTests.swift` and
  `CityCommandCatalogTests.swift`, plus
  `docs/production/evidence/PLAY-115/composed-view/` and completion.
- **Frozen contracts:** Existing commands, AX map selection/custom actions,
  pointer/keyboard/FKA routes, Escape behavior, and PLAY-114 recovery wording
  must remain truthful and usable. Do not change simulation, saves, renderer,
  source art, package/build, or shared command/store contracts.
- **Proof / stop:** Capture before/after regular and true 900 × 600 composition
  evidence, measure unobscured map aperture, and run focused compact/regular
  layout plus input/AX proof. Stop on a shared contract requirement, map
  selection/keyboard regression, control overlap/clipping, unrelated path, or
  second focused failure. One bounded local repair is allowed. On PASS commit
  only the coherent UI packet; no aggregate, stage, QA, push, or release.
