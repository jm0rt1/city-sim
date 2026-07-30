# PLAY-076 additive fixture-adoption packet

- **Frozen gameplay product:** `de6f477ca1a21d9dc9e825de0c7eba18055e3b7b`
- **Source baseline:** `227202371574f21f209a62153904b2f4c974dd4b`
- **External claim authority:** `20036691842b0fdd8485ad4a924d5949c4b2e2ec`
- **Disposition:** Observation only; no accepted fixture history was rewritten

## Authoritative changes consumers must adopt additively

- Opening roads change from 32 to 34 through `(8,10)` and `(8,11)`.
- Occupied places change from 8 to 12.
- Residential `(9,11)` relocates to `(9,10)`.
- Residential `(6,10)`, `(6,11)`, `(3,10)`, and `(17,10)` are added.
- Empty road-frontage build choices become exactly 40.
- Day 1 balance becomes `-$126.20/cycle`; starting treasury, population,
  jobs, happiness, approval, tax, capacities, and utility use are unchanged.
- Industrial demand uses current employment/job-capacity pressure; utility
  reserve forecasting uses the private warning-window population potential.

## Full-corpus adoption classes

The following integration-owned consumers retain fixed coordinates, renderer
references, or frozen digests from the eight-place opening and therefore
failed against the frozen gameplay product:

- `CitySimulationTests`
- `ProductionStoryStateFixtureTests`
- `VisibleCityStateFixtureTests`
- `SessionPlatformTests`
- `WorldRenderingTests`
- `SpatialConsequenceTests`
- `StrategyResolutionPlatformTests`
- `TerminalVictoryPlatformTests`

The additive adoption should preserve old fixture versions and introduce new
versions derived from the exact product checkpoint. It must not edit gameplay
to reproduce obsolete bytes.

## Observed new terminal state digests

The complete worker run retained these exact candidate observations:

| Route | Regional tick | State digest |
|---|---:|---|
| Commercial tax relief | 1024 | `034d788b7e0e8685e3ab32afcf924f9fce12e67e06cdaa756962489cf61a2d9d` |
| Commercial public realm | 1024 | `a0c5c5fcfe0d9d5f114ff1c80e1fa010a9e9f2c9497cb77055ebf9700a0c812e` |
| Industrial utility expansion | 1036 | `35ea7b790487e76f1dd6db8014db978b64ebb11e354db3ff4efe3ca55dd2fc9b` |
| Industrial green buffer | 1040 | `be55197b95550c6c25c716cffc3cff1bd973b7b3f44faf71dae2b7daf499ac17` |

These are adoption inputs, not integration acceptance. Simulation/platform
must independently regenerate state, spatial, replay, and manifest artifacts
from the exact candidate and validate candidate identity before publication.

## Renderer disposition

The same complete run measured average renderer update time at `2.739 ms`
against the `2.1 ms` budget. This lane did not alter rendering code or
references and does not classify the budget failure as passed. Rendering owns
profiling and any renderer-only remediation after consuming the authoritative
12-place state.
