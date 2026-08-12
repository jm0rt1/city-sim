# PLAY-120 Completion — construction trajectory current b738

- **Outcome:** A completed utility or growth lot now posts a truthful `Construction Online` message at the existing first daily governed response, using already-calculated capacity, use, and pressure facts.
- **Authority/base:** `b738653470199e8c07f9d76336d3ddf156891d60`.
- **Changed product paths:** `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulation.swift` and `Native/CitySimNative/Tests/CitySimNativeTests/CitySimulationTests.swift`.
- **Focused proof:** `swift test --package-path Native/CitySimNative --filter CitySimulationTests` exited 0 on the one permitted identical host retry after the sandboxed invocation stopped before Package.swift evaluation on a module-cache permission boundary.
- **Behavior covered:** The deterministic test builds a road-connected Power Plant, proves no early capacity/message before completion, proves the first daily response activates its existing capacity and causal message, and compares a same-seed replay state for equality.
- **Evidence:** `docs/production/evidence/PLAY-120/currentb738/FOCUSED-PROOF.json`.
- **Compatibility:** No cadence, economics, save/schema, fingerprint, public command, UI, renderer, or other product contract changed. Aggregate build and independent acceptance remain Integration-owned.
