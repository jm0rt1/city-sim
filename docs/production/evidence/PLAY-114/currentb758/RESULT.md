# PLAY-114 focused result

- **Base:** `374b914a98c3b34ff735de28f7894e483f6d9ae2`
- **Outcome:** The Strategy Command Center now exposes an immediate recovery
  destination and a likely, non-guaranteed outcome in its primary route and
  recovery menu. Compact wording remains concise while VoiceOver receives the
  full destination, outcome, and existing command hint.
- **Focused proof:**
  `swift test --package-path Native/CitySimNative --scratch-path /private/tmp/CITYSIM-PLAY114-scratch --filter CityCommandCatalogTests/testStrategyHUDRecoveryRoutesStateDestinationAndUncertainOutcomeAtCompactAndRegularSizes`
  — 1 executed, 0 failures.
- **Rendered bounds:** compact `884 × 48`; regular `1240 × 52`.
- **Interaction:** existing Finance action still opens Finances; existing Park
  action still requests map focus and selects Park build mode.
- **Accessibility:** recovery actions identify their destination and likely
  outcome; the original command explanation remains the activation hint.
