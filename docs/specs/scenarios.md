# Scenario Catalogue

Define baseline scenarios with fixed seeds and expected qualitative trends.

## Fields
- `name`, `seed`, `duration_ticks`, `policies`, `expected_trends`

## Baseline Scenarios
- `baseline-stability`:
  - `seed`: 42
  - `duration_ticks`: 100
  - `policies`: []
  - `expected_trends`: budget stable, population slow growth, happiness steady

- `growth-push`:
  - `seed`: 1337
  - `duration_ticks`: 200
  - `policies`: tax incentives, infrastructure investment
  - `expected_trends`: population growth, budget deficit then recovery, happiness improves

- `austerity`:
  - `seed`: 7
  - `duration_ticks`: 150
  - `policies`: spending cuts
  - `expected_trends`: budget surplus, slowed population growth, happiness may dip

## Traffic Scenarios
- `rush-hour-city`:
  - `seed`: 2026
  - `duration_ticks`: 120
  - `policies`: signal timing optimization
  - `expected_trends`: congestion index rises then stabilizes; throughput increases with optimized signals

- `highway-incident`:
  - `seed`: 84
  - `duration_ticks`: 180
  - `policies`: ramp metering
  - `expected_trends`: temporary congestion spike; rerouting reduces travel times; throughput recovers

- `network-expansion`:
  - `seed`: 512
  - `duration_ticks`: 200
  - `policies`: infrastructure investment (new road segments)
  - `expected_trends`: improved avg speed and throughput; lower congestion index
