# PLAY-052 Played Journey Ledger

Both journeys began with `New Region`, used only visible product language and
available app controls, and ran against fresh isolated data roots. No fixture,
save-state seed, product source, or external strategy instruction was used to
choose the played actions.

## Commercial — default, pointer-first

Start: `2026-07-23T23:37:22-0400`

Charter: `2026-07-23T23:45:51-0400`

Elapsed player/evidence clock: **8:34**

| Elapsed | Meaningful decision / evidence | Immediate or bounded consequence |
|---:|---|---|
| `0:00` | Fresh Day 1 authored city. Treasury `$26,000`; cashflow `-$61`; Commercial demand `68% High`. `live-commercial/01-fresh-day1.jpeg` | The first objective disclosed the operating gap and the map accepted pointer and keyboard focus. |
| `1:23` | Commit Commercial at the visibly available target. `02-commercial-committed.jpeg` | Construction and the `$2,400` treasury charge appeared immediately; completed commerce later lifted cashflow to `+$95`. |
| `1:51` | Commit Power Plant after Prepare for Growth disclosed `P 110`. `03-power-decision.jpeg` | Construction was acknowledged immediately; completion reduced the objective from `P 110` to `P 0`. |
| `2:26` | Attempt Water Tower after the objective disclosed `W 100`. `04-water-decision.jpeg` | Exact insufficient-funds feedback remained visible, Water Tower stayed selected, and the chosen target did not silently move. |
| `5:54` | Recover the treasury with a second Commercial build at block `14,11`. `05-commercial-recovery.jpeg` | Construction was immediate; within five seconds of resumed simulation, cashflow moved from `+$9` to `+$154`. |
| `7:11` | Fund and commit Water Tower at block `12,9`. `06-water-recovery.jpeg` | Completion produced `P 242 / W 220 spare` and changed the objective to resident growth. |
| `7:49` | Commit Residential at block `12,17` in response to `Next: grow 44 residents`. `07-growth-decision.jpeg` | Construction was immediate; population growth began without an unexplained wait. |
| `8:34` | Town Charter victory. `08-charter-victory.jpeg` | Result: 511 residents, `$11,618`, `+$126`, 61% happiness; story identity **Commercial Stewardship**. |

The `2:26` to `5:54` wall-clock interval was active, paused AX inspection and
keyboard target traversal, not passive simulation wait. All deliberate
simulation waits were observed in chunks of ten seconds or less. There was no
unexplained player dead time above 30 seconds and every material action gave
spatial or numeric feedback inside 15 seconds.

## Industrial — exact compact, keyboard-first

Start: `2026-07-23T23:49:11-0400`

Charter: `2026-07-23T23:53:53-0400`

Elapsed player/evidence clock: **4:42**

| Elapsed | Meaningful decision / evidence | Immediate or bounded consequence |
|---:|---|---|
| `0:00` | Fresh exact compact region. `live-industrial/01-fresh-compact.jpeg` | Semantic map was focused; compact HUD exposed treasury, objective, speed, notices, and build catalog. |
| `0:09` | Open Command Guide with Command-/, search `Industrial`, and execute the sole result with Return. `02-command-guide.jpeg` | Search result disclosed `$3,200`, `$8/cycle`, shortcut `I`, and availability before execution. |
| `0:46` | Commit Industrial at block `14,11` by keyboard. `03-industrial-commit.jpeg` | Construction was immediate; after completion cashflow changed from `-$90` to `+$131`, with jobs and utility draw visible. |
| `1:23` | Commit Power Plant at block `12,17`. `04-power-decision.jpeg` | Immediate construction acknowledgment; power reserve later rose to 284. |
| `1:43` | Commit Water Tower at block `14,17`. `05-water-decision.jpeg` | Immediate construction acknowledgment; water reserve later rose to 261. |
| `2:17` | Recover the resulting `-$57` infrastructure burden with a second Industrial build at block `12,9`. `06-industrial-recovery.jpeg` | After completion, cashflow became `+$127` and the objective advanced to resident growth. |
| `3:04` | Commit Residential at block `14,9`. `07-housing-decision.jpeg` | Population advanced while reserves remained positive. |
| `3:46` | Commit a second Residential at block `14,10`. `08-second-housing.jpeg` | Cashflow rose to `+$177`; growth continued without a dead interval. |
| `4:42` | Town Charter victory. `09-charter-victory-compact.jpeg` | Result: 511 residents, `$29,709`, `+$240`, 55% happiness; story **Industrial Expansion**, recovery **Utility Expansion**. |

The first meaningful decision occurred at 46 seconds. All passive simulation
observations were ten seconds or less, material consequences appeared inside
15 seconds, six decisions were made, and recovery completed well before
minute 18.

## Cause/effect and warning-to-action findings

- Commercial: high Commercial demand led to a storefront build; its completed
  cashflow paid for the disclosed water shortfall.
- Industrial: the first factory closed the operating gap but consumed utility
  reserves; Power Plant and Water Tower restored capacity, their upkeep
  reopened the budget gap, and a second factory closed it.
- Objectives changed from balance, to exact `J/P/W` deficits, to resident
  growth, to the 12-day Charter count. Each state named a corrective next
  action.
- The selected map target, AX value/help, Return action, cost, rejection, and
  resulting coordinate remained one identity throughout both routes.

## Compact input/focus evidence

- Command-/ opened the searchable guide from map focus.
- `Industrial` and the utility/housing tools were searched and executed with
  Return.
- Escape closed the guide and restored focus to the semantic City map:
  `live-industrial/10-escape-restores-map-focus.jpeg`.
- The exact compact map, selected target, objective, speed, notices, and
  command controls remained reachable without clipping.
