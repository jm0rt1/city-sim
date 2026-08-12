# PLAY-114 — Keep recovery actions self-explanatory in compact play

- **Lane / owner:** UI and input — Agent 301, UI/Input Lead.
- **Base:** `374b914a98c3b34ff735de28f7894e483f6d9ae2`.
- **Candidate:** the coherent `PLAY-114` commit containing this record.
- **Player-visible outcome:** compact and regular Strategy Command Center
  recovery routes now state where they go and their likely, non-guaranteed
  result instead of presenting a generic action label.
- **Changed product/test paths:**
  `Native/CitySimNative/Sources/CitySimNative/Views/StrategyCommandCenterView.swift`;
  `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`.
- **Focused proof:** 1 selected test passed, rendering compact `884 × 48` and
  regular `1240 × 52` command-center bounds, checking route wording and the
  unchanged Finance / map-focused Park intent handoffs.
- **Accessibility and input:** pointer and Full Keyboard Access retain the
  existing governed intents; VoiceOver receives destination, outcome, and the
  existing command hint. No command, store, simulation, renderer, or focus
  contract changed.
- **Deferred:** Integration owns aggregate, staged build, and independent
  real-app acceptance for any integrated candidate.
