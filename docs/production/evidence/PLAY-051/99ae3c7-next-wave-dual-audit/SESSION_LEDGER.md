# PLAY-051 hands-on session ledger

The governed journey ran for 18:09.178 wall-clock, from session zero at `2026-07-22T01:08:04.604Z` to the bounded compact recovery outcome at `2026-07-22T01:26:13.782Z`. It covered Day 1 through Day 159 across default and exact compact launches.

| Checkpoint | Observed outcome | Evidence |
|---|---|---|
| Fresh opening | Welcome dismissed into a new Day 1 city | `visuals/01-default-welcome-fresh.png`, `02-default-session-zero.png` |
| First authored route | Cashflow -> Notices -> Act -> Commercial | `03-default-notices-opening.png`, `04-default-commercial-tool.png` |
| First committed decision | Commercial committed at 02:16.254 / Day 52; the Day 25 deadline had expired during the visible route | `05-default-first-build-paused.png` |
| Consequence | Cashflow moved from -89 to +101 with jobs 249/21 and only 1/1 utility spare by Day 58; visible wall latency was about 15.3 seconds | `06-default-commercial-consequence-running.png` |
| Strategy setback/recovery | Storefront Slump explained the <=9% tax or park remedy; 9% tax produced Main Street Rebound and +$1,500 | `07-default-critical-notices-paused.png`, `08-default-tax-relief-9pct.png` |
| Utility pressure | Day 85 reached 90% service with zero power/water spare; direct warning actions exposed builds | `09-default-day85-utility-failure.png`, `10-default-water-recovery-build.png` |
| Tradeoff | Restoring utilities created a budget crisis; the route later used 15% tax to fund power, then 13% plus a second commercial site to recover | `11-default-utility-recovered-budget-crisis.png`, `22-compact-tax-15-recovery.png` through `27-compact-growth-ready.png` |
| Undo | Cmd-Z restored the exact visible Day 98 snapshot: $13,123, +$95, 397 residents, 53% happiness, jobs 270/0, 90% utilities, P0/W0 | `12-default-undo-power-plant.png` |
| Save/relaunch/load | Cmd-S sealed the schema-1 file; the exact staged bundle was terminated and relaunched; Cmd-O restored Day 98 paused with the same visible snapshot | `13-default-saved-paused.png`, `14-default-loaded-paused.png` |
| Command guide | Guide opened and search received keyboard focus; `tax` returned no result despite the active tax remedy | `15-default-command-guide.png` |
| Exact compact | Day 98 loaded paused into 900x600; objectives, command details, inspector, warnings, and catalog were exercised by pointer and keyboard | `16-compact-900x600-fresh.png` through `21-compact-power-warning-details.png` |
| Bounded outcome | Day 159: $9,831, +$188, 417 residents, 57% happiness, 35% approval, jobs 291/59, utilities 100%; Balance Books and Prepare Growth complete (2/3) | `27-compact-growth-ready.png` |

Town Charter was not reached: the city remained 83 residents short and treasury had briefly fallen below $10,000. The session stopped at this clear recovery outcome per integration direction.

## AX and input evidence

The live accessibility tree exposed named metrics, current values, action buttons, selected coordinates, costs/upkeep, availability, disabled reasons, pause/load feedback, and inspector actions. Real keyboard input exercised Space, Cmd-S, Cmd-O, Cmd-Z, Escape, command-guide search, arrows, Return, and tool routing; pointer input exercised the corresponding warning, policy, catalog, placement, objective, and inspector paths.

One critical contradiction repeated during placement:

1. On occupied block 14,9, AX correctly reported Commercial unavailable/occupied while the in-world overlay displayed `VALID · COMMERCIAL`.
2. On open blocks without direct road access, AX correctly reported unavailable/direct-road-required while the overlay remained `VALID`.
3. Later, open block 15,11 was AX-available while the overlay displayed `BLOCKED`; Return successfully built there.

This is retained as a cross-lane command-truth defect and is not a score of the active world-rendering work.

## Validation limitations

- The authoritative native test runner was given one bounded attempt. Build completed, but no test summary appeared after 3:05; redundant waiters and then the bounded runner were terminated. Result: **incomplete**, not pass or fail.
- Spoken VoiceOver and macOS global Full Keyboard Access were not enabled. AX structure and real keyboard paths were inspected; no claim is made about spoken order or FKA-only traversal.
- The Industrial strategy, corrupt-primary recovery, Reduce Motion, long soak, and Town Charter award were not exercised in this bounded audit.
- `Shift-2` tool routing was not reproduced under Computer Use; the input mapping was not treated as a defect without a physical-key/FKA reproduction.
- No renderer score, asset-quality judgment, or product mutation was performed.
