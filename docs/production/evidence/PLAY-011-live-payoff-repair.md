# PLAY-011 Sustained-Session Payoff Repair

- **Frozen gameplay product:** `dd49ea5f6d5d2ea13d726e4b5083b4b52bbefb2d`
- **Accepted integration:** `f75ab91`
- **Disposition:** accepted after PLAY-040 companion review and independent PLAY-050 retest

## Reproduced failure

The rejected live route ended Day 128 / tick 509 with positive `+$123/cycle` cashflow but only 409 residents, 39% happiness, zero water spare, and Town Charter `0/12`. The deterministic regression reproduces the equivalent causal state after a late commercial choice, power expansion, and 14% recovery tax: operating cashflow is positive and a Water Tower is affordable, but water is exhausted and the old objective text reports only missing population.

## Accepted causal repair

1. One visible zoning decision identifies commerce or industry; a late Day 38 choice receives the strategy warning before the Day 41 opportunity.
2. The Journal announces every Charter standard. The objective prioritizes exhausted water/power and low happiness, then forecasts the derived 315-job capacity needed for 90% employment at 500 residents.
3. Reserve utility units retain 75% of normal upkeep. First-unit and opening economics are unchanged; overextension remains costly, but a second power/water pair can coexist with a valid added job base.
4. Recovery remains a decision: add water, add enough job capacity, unwind emergency tax, and sustain every standard for 12 daily checks.

## Deterministic outcomes

| Route | Strategy response | Durable award | Distinct consequence |
| --- | --- | ---: | --- |
| Commercial | Second park, reserve utilities, commercial job capacity | Tick 900 | Higher happiness, lower pollution, lower job capacity |
| Industrial | Second power/water pair, industrial job capacity | Tick 848 | Higher job capacity and pollution, faster infrastructure payoff |

Both fixtures find the first valid visible placement instead of embedding a test-only coordinate sequence. The original 2,800-tick survivability horizon remains deterministic and awarded for both routes. Failed Charter standards still reset only on the next daily boundary; the award remains one-time and durable; undo and JSON round trips remain exact.

## Evidence trail

- Focused gameplay: 16/16 passed on `dd49ea5`.
- Gameplay-branch full suite before companion: 88/91 passed; only the three intentionally frozen PLAY-040 digests changed.
- PLAY-040 approved authoritative digests:
  - industrial `11adf523ca4af342d3a1126c04d3469bf3e02ddd30c8b77ea22e21c70420c5ff`;
  - commercial `65c11403d0876fc9af27782e240a4e98b2806b55b8953aa81490934bb860f68c`;
  - dense terminal `d18afceb9c8ccc09eaf54d7316abc960c6b560baa1bc7d92fa6416c9776556d8`.
- Integration `f75ab91`: full 91/91 and exact staged verify passed, with no schema/version/contract change.
- Independent PLAY-050: accepted no-coaching route in 9:56 with Town Charter 12/true.
