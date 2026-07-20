# Sustained Session Record

## Method and timer

This was a fresh, no-coaching primary journey against exact staged commit `f75ab91`. Decisions used only the visible HUD, objectives, journal, map previews, placement feedback, and advertised keyboard shortcuts. No fixture coordinates, hidden state, scripted command sequence, or product-code inspection guided play.

- Journey start: `2026-07-20T16:40:14.525Z`
- First successful meaningful placement: 96.784 seconds, under the two-minute gate
- Final save, exact-process stop, verified relaunch, and load: 595.966 seconds wall time
- Explicitly measured accelerated simulation intervals: 125.537 seconds
- Timer result: 9 minutes 55.966 seconds, under the 20-minute cap

The wall time includes player reading, diagnosis, invalid placement feedback, policy changes, saving, process verification, relaunch, and load. A few short 1x observation intervals before the first pause were not separately instrumented, so 125.537 seconds is deliberately reported only as the measured accelerated portion, not total simulation-active time.

## Player journey

The city opened on Day 1 with $26,000, negative $61 cashflow, population 300, happiness 58%, 190 filled jobs, no openings, and tight starting utilities. The Journal visibly explained the Town Charter standards: 500 residents, $10,000 treasury, non-negative cashflow, 90% employment, full utilities with 15% reserve, 52% happiness, every zone active, sustained for 12 days.

The player chose commerce because visible commercial demand was high and the city lacked job openings. Several preview-rejected placement attempts were corrected from visible map feedback before a road-served Commercial zone was placed at Day 24. That was the first committed decision at 96.784 seconds.

The Day 24 `Utility Reserve Tight` notice showed 36 power and 32 water spare and explicitly recommended a Water Tower before more homes or jobs. The player built it. At Day 41 the visible `Market Weekend` awarded $1,800, while the earlier `Main Street Crossroads` notice had warned of a later slump.

The Day 41 objective exposed a power blocker (`Need J80 · P110 · W0`), so the player built a second Power Plant. At Day 57 the city had $1,045, negative $122 cashflow, population 356, happiness 62%, 249 filled jobs, 21 openings, and strong utility capacity. The player temporarily raised tax from 10% to 14%, turning projected operations positive.

On Day 81/82, `Storefront Slump` removed $3,000 and reduced confidence. Its visible recovery rule said to lower tax to 9% or less or build a second park before the 40-day review. The player lowered tax to 9%. Day 121's `Main Street Rebound` explicitly credited the tax relief and awarded $1,500 plus confidence. The player then raised tax to restore solvency, briefly using 15% before returning to 14% for happiness.

By Day 196 the city held $3,054, positive $150 cashflow, population 495, happiness 51%, and 79% high commercial demand. The visible job objective still blocked progress, so a second Commercial zone was placed at 488.309 seconds. By Day 222 the city had $9,620, positive $360 cashflow, population 521, happiness 55%, 350 filled jobs, no openings, and healthy utility reserves. Day 225 crossed $10,000 and showed 2 of 12 qualifying days.

The Town Charter was awarded on Day 235. At Day 236 the HUD reported all objectives achieved, and the objective detail read `Town Charter secured permanently`. The top journal item read `TOWN CHARTER AWARDED` and explained that New Arcadia had sustained healthy finances, employment, utilities, and livability for 12 consecutive days.

## Exact final state and resume

- Day 236, tick 941
- Treasury: `14702.455475685274` (`$14,702` HUD)
- Cashflow: `+$366 / cycle`
- Population: 535
- Happiness: `54.96407514974004` (55% HUD)
- Employment: 350 filled jobs, 0 openings
- Power: 452 used / 600 capacity, 148 spare
- Water: 405 used / 540 capacity, 135 spare
- Tax rate: 0.14
- Progression: `townCharterAwarded = true`, `townCharterQualifyingCycles = 12`
- Schema version: 1
- Fingerprint version: 1
- State digest: `2dfb6b084ec13b9fb8d2048d8908bf66efee2022d09cbe339b3ce63afcd8adb4`

`Command-S` produced `City saved`. PID 83028 was stopped only after that feedback. The verified launcher then started the same exact identity as PID 86448 from the same isolated root. `Command-O` restored the exact digest and state, reported `City loaded · Simulation paused`, selected Pause, and returned accessibility focus to the real `SKView`. PID 86448 was stopped after the retained resume, objective, and journal evidence was captured.
