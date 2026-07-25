# PLAY-071 baseline density audit

- **Authority:** `e38059e721dae05c8df421754e3cb63ddf3fa153`
- **Branch:** `codex/citysim-gameplay-loop`
- **Claim:** `PLAY-071`
- **Source:** accepted production story fixtures under
  `Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/StoryStates/`
- **Mutation:** none

## Player problem

The accepted city records growth, warned pressure, recovery, Charter, and
Regional Capital numerically, but its authoritative lots do not carry the
same history. Residential buildings race to level 4 while every Commercial
and Industrial building remains level 1. Pressure and recovery never change
`CityTile.condition`, so a recovered terminal city is indistinguishable from
an untouched city through the existing lifecycle contract.

This audit reads the accepted production fixtures only. It does not inspect
or interfere with the active PLAY-068 independent retest.

## Deterministic fixture matrix

| Route / state | Tick | Zone lots | Level distribution | Strategy-family levels | Condition bands |
|---|---:|---:|---|---|---|
| Commercial early | 64 | 5 | L1 4, L4 1 | Commercial: 2 × L1 | 5 maintained |
| Commercial opportunity | 128 | 5 | L1 3, L4 2 | Commercial: 2 × L1 | 5 maintained |
| Commercial recovery | 256 | 5 | L1 3, L4 2 | Commercial: 2 × L1 | 5 maintained |
| Commercial Charter midpoint | 844 | 6 | L1 4, L4 2 | Commercial: 3 × L1 | 6 maintained |
| Commercial Regional terminal, tax relief | 1,040 | 8 | L1 6, L4 2 | Commercial: 5 × L1 | 8 maintained |
| Commercial Regional terminal, public realm | 1,060 | 8 | L1 6, L4 2 | Commercial: 5 × L1 | 8 maintained |
| Industrial early | 64 | 5 | L1 4, L4 1 | Industrial: 2 × L1 | 5 maintained |
| Industrial opportunity | 128 | 5 | L1 3, L4 2 | Industrial: 2 × L1 | 5 maintained |
| Industrial recovery | 256 | 5 | L1 3, L4 2 | Industrial: 2 × L1 | 5 maintained |
| Industrial Charter midpoint | 844 | 6 | L1 4, L4 2 | Industrial: 3 × L1 | 6 maintained |
| Industrial Regional terminal, utilities | 1,036 | 7 | L1 5, L4 2 | Industrial: 4 × L1 | 7 maintained |
| Industrial Regional terminal, green buffer | 1,236 | 7 | L1 5, L4 2 | Industrial: 4 × L1 | 7 maintained |

The terminal fixtures contain the accepted strategy warnings, setbacks,
recoveries, and Regional payoff messages. Nevertheless, every zone has
condition `1.0`; there is no current authoritative recovery scar.

## Root cause

`CitySimulation.maybeUpgrade` runs every 20 ticks, upgrades only one lot, and
requires raw occupancy above 150. Residential occupancy reaches that
threshold immediately, so the first two Residential lots consume every
eligible upgrade until each is level 4. Commercial base capacity is 80 and
Industrial base capacity is 110; their distributed occupancy cannot
legitimately satisfy the same raw `> 150` threshold in the accepted routes.

The upgrade adds capacity and upkeep, but current zone utility load and
pollution count lots rather than developed levels. Pressure and recovery
change treasury, happiness, and approval only.

## Smallest gameplay-owned correction

The claimed correction should:

1. evaluate development by kind-relative occupancy and demand rather than one
   impossible raw threshold;
2. distribute upgrades deterministically so the city retains several levels
   instead of converging one family to level 4 first;
3. make developed levels carry proportionate utility, upkeep, revenue, and
   pollution consequences so automatic density is not free or dominant;
4. apply strategy pressure to existing route-family lot condition and repair
   it only partially, leaving a weathered but recovered terminal history;
5. use only existing `level`, `constructionProgress`, `condition`, strategy,
   objective, and message contracts.

No new persisted field, renderer state, public store contract, command,
schema identifier, fixture format, SwiftUI, SpriteKit, package, build script,
art selection, or legacy Python change is required.
