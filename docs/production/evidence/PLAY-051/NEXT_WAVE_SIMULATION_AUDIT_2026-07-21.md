# PLAY-051 next-wave simulation and gameplay audit — 2026-07-21

## Disposition

- **Gameplay loop: REJECT for next-wave player readiness.** The commercial route demonstrates meaningful tradeoffs and recovery, but the authored opening misses its own deadline during normal UI reading, and the bounded 18:09 journey did not reach Town Charter.
- **Simulation platform substrate: APPROVE with disclosed limits.** Deterministic visible undo, schema-1 save/relaunch/load, paused restoration, isolated identity, and bounded RSS held. No platform-owned defect was reproduced. The native suite result is incomplete, not green.

Exact candidate and staged-app identity are frozen in `99ae3c7-next-wave-dual-audit/CANDIDATE_IDENTITY.md`. Product authority is `99ae3c7925825cfb8eccb47a678405c6e58d2a46`; the audited build HEAD is `e9e429ce26244bd6571c1d2920b1a4e30c3e79a9`.

## Player journey covered

A fresh player followed the authored Cashflow -> Notices -> Act route, chose Commercial, observed its job/cashflow/utility consequences, handled Storefront Slump through tax policy, hit utility exhaustion, built water and power capacity, undid a destructive fiscal step, saved, left, relaunched, resumed paused, and recovered in exact compact mode with tax and a second commercial site. Day 1 progressed to Day 159. The final city was stable and growing at +$188/day with 100% utilities, but Town Charter remained incomplete.

The detailed journey, timings, persistence hashes, screenshots, AX evidence, and limitations are in `99ae3c7-next-wave-dual-audit/SESSION_LEDGER.md`.

## Prioritized findings

### P1 — The authored opening consumes its own strategy deadline

- **Owner:** Gameplay loop. UI/input is a contract dependency only if panel-reading time is to pause or suspend the countdown.
- **Evidence:** The player opened Cashflow at +00:09.848, Notices at +00:31.784, Act at +00:45.615, and Commercial at +00:51.703. A pointer placement attempt failed; the first successful keyboard placement was +02:16.254 at Day 52. The visible Day 25 strategy deadline had already expired.
- **Reproduction:** Delete the lane defaults/data root; launch the staged bundle; dismiss Welcome; follow Cashflow -> Notices -> Act without prior coaching; read the presented copy; choose Commercial and place the first valid site. Record wall time and simulation day.
- **Desired player outcome:** A new player understands and commits the first meaningful strategic choice before the authored deadline, without guessing that they must pause before reading.
- **Acceptance test:** In five fresh no-coaching runs, at least four players make a valid strategy commitment within 2:00 wall-clock and no later than Day 25 by following visible affordances. The route must not require hidden pause knowledge.

### P1 — The three-act route does not yet close inside the target session

- **Owner:** Gameplay loop, not simulation platform.
- **Evidence:** The commercial path produced clear recovery at Day 159 / 18:09, but Town Charter was still 83 residents short and treasury had briefly fallen below $10,000. The player had to cycle 9% -> 15% -> 9% -> 13% tax while funding water/power and a second commercial site. This is a compelling tradeoff, but not a completed 20-minute outcome.
- **Reproduction:** Start fresh; choose Commercial; respond only to visible objective/notices and their direct actions; recover Storefront Slump and utility pressure; stop at 20:00 or Town Charter.
- **Desired player outcome:** The first session ends in tangible strategic success or an explicit, understandable failure state—not an unresolved near-milestone.
- **Acceptance test:** Each reference strategy completes Town Charter or reaches a named terminal failure within 20:00 in three deterministic no-coaching runs, with at least one recoverable setback and no debug/harness intervention.

### P2 — Stale opening guidance competes with current decisions

- **Owner:** Gameplay loop messaging/objectives.
- **Evidence:** At Day 98, the journal still showed `Choose a Growth Engine` with `Before Day 25`, long after Commercial was chosen and the deadline had passed. The history is capped, so obsolete guidance consumes scarce attention.
- **Reproduction:** Choose Commercial after the deadline; advance through Storefront Slump and utility warnings; reopen Notices at Day 98.
- **Desired player outcome:** Current pressure and recovery guidance outrank resolved or expired onboarding copy.
- **Acceptance test:** A resolved/expired opening prompt is retired or visibly classified as history within one daily evaluation; the top actionable entries at Day 98 concern current fiscal/utility conditions.

## What already works

- Commercial placement changed employment/cashflow within roughly six simulated days, with understandable utility pressure.
- Storefront Slump gave two concrete remedies; tax relief produced an explicit Main Street Rebound and reward.
- Utility warnings exposed capacity/use/spare and direct build actions.
- Cmd-Z restored an exact visible snapshot; save/relaunch/load restored it paused from the sealed schema-1 file.
- Bounded settled RSS fell from 82,912 KiB default to 79,696 KiB compact and 67,024 KiB at session end; no continuing growth was seen.

## Non-goals and contract implications

- Do not route balance, objective lifetime, opening pacing, or strategy content to simulation platform.
- No save schema, snapshot, determinism, or performance contract change is indicated by this audit.
- If the remedy changes how panel-reading time affects deadlines, gameplay and UI/input need an integration-approved active-time contract; do not silently alter the shared tick boundary.
- This audit does not score world assets and does not establish Industrial-path viability, corrupt-save recovery, Reduce Motion, soak stability, or Town Charter persistence.

## Recommended first coherent implementation slice

Make the first strategy decision fair and self-contained: keep the authored strategy opportunity active until a real player can read and commit it, retire the prompt after resolution/expiry, and add a deterministic fresh-start journey proving the commitment lands by Day 25 and within two minutes. Keep simulation tick semantics unchanged unless integration approves a cross-lane active-time contract.
