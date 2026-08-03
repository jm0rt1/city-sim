# PLAY-094 Residential L1 variant-one intake handoff

The renderer-owned prelock slice is `intake_ready` and remains entirely
non-shipping. `WorldRenderingTests` now exercises a synthetic four-direction
quarantine graph for `residential_l01/variant-1`, validates unique logical and
source identities, preserves the authoritative 72x36 registration and
directional socket mapping, derives the opening fixture from the truthful
`CityGameState.newCity(seed: 42)`, and rejects alias, fallback, mirror, rotate,
and registration-drift inputs.

No source packet, normalized payload, pixel, atlas, manifest, runtime mapping,
production selection, or atomic assembly was created. All four directions stay
at `intake_preparing`; the next legal transition requires exact Integration
source-admission receipts and independent direction quarantine.

## Focused proof

`swift test --package-path Native/CitySimNative --filter WorldRenderingTests`
passed: 68 tests, 0 failures. `git diff --check` passed. The full Swift suite,
staged app, DCC, pixel production, normalization, shipping activation, and
independent QA were not run.

## Owned paths

- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
- `docs/production/evidence/PLAY-094/`

No other paths are part of this handoff.
