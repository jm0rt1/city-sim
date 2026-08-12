# PLAY-114 Claim — Keep recovery actions self-explanatory in compact play

- **Lane / owner:** UI and input — Agent 301, UI/Input Lead.
- **Authority / base:** `b7580a580b9c85f63e7686b2f948af5978a6582b`.
- **Observed player friction:** The accepted Day-4 pressure journey exposed
  `Review tax policy` and `Build a park` as recovery routes. At compact HUD
  height the next action must state its immediate destination/effect without
  hiding the map or changing simulation truth.
- **Maximum paths:**
  `Native/CitySimNative/Sources/CitySimNative/Views/StrategyCommandCenterView.swift`,
  `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`,
  `docs/production/evidence/PLAY-114/currentb758/`, and
  `docs/production/completed/PLAY-114.ui-input-recovery-actions-currentb758.md`.
- **Deliverable:** The smallest compact and regular command-center correction
  making the current recovery action, its destination, and its non-guaranteed
  result legible and truthful for pointer, Full Keyboard Access, and VoiceOver,
  while retaining the map aperture and existing command/store behavior.
- **Proof / stop:** Focused regular and 900×600 compact behavior verifies the
  actionable label/value, activation parity, focus and Escape preservation.
  One local repair is allowed. Stop if the current surface already satisfies
  the stated outcome, a shared command/store contract is required, or any
  path outside this claim is needed.
