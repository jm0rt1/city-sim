# PLAY-050 Integrated PLAY-010 Session Record

## Candidate

- Product baseline: `f96ff8022ee12e0ac32f0250621993d23f2f0d23`
- Evaluated commit: `831cb1c11d3a26883cf40a11a5af87f7e94176d0`
- Build command: `./script/build_and_run.sh --verify` with writable Swift module-cache paths
- Staged app: `dist/CitySim.app`; executable SHA-256 `f05931d5e7d03e8be68472719119c12d337f6fcead7c248412811a14e9d4d0eb`
- Journey version: `critical-journey-v3`
- Deterministic starting scenario: seed 42 in accepted `GameplayLoopTests`
- Live fixture: normal fresh city; no authoritative UI-selectable fixture ID/state hash exists
- Variants attempted: regular first-run, pointer/AX, keyboard shortcuts, 900×600 compact, Reduce Motion, save/resume
- Coaching: none during the controlled observations
- Overall disposition: `failed`; full real 20-minute session also `blocked` by first-run mutation and later external app-state contamination

## Deterministic golden-session result

The independent focused suite passed all ten accepted gameplay tests. Progression remained unchanged or `nil` through ticks 1–3 and evaluated at tick 4. Eleven full qualifying days did not award; the twelfth did. A failed standard left the prior count intact until the next daily boundary, then reset it to zero; a later 12-day run awarded exactly once. Legacy decode, JSON round trips, undo, and existing objective/message routes passed.

Both accepted reference strategies reached exactly tick 2,800 / Day 701. Each retained a one-time durable Town Charter, non-lost status, and positive treasury. Industry first retained greater pollution pressure; commerce plus tax retained the higher tax rate. This passes authoritative viability but not live discoverability.

## Live timeline

| Checkpoint | Player action/observation | Expected | Actual | Disposition |
| --- | --- | --- | --- | --- |
| Controlled first-run launch | Stopped the app, set only `hasSeenCitySimWelcome=false`, and launched the repository-staged bundle. | Welcome blocks play while authored start remains stable. | First full AX state already reported Day 4 while `Start Building` remained visible. | Failed precondition. |
| Onboarding reading | Left the blocking welcome surface open. | No authoritative mutation before agency. | Retained capture showed Day 17 and five notices; a later AX state reached Day 27 and eight notices. | `PLAY-050-D001`. |
| Dismiss/pause | Selected `Start Building`, then selected Pause. | First-decision clock begins from authored start and pauses immediately. | Dismissal returned at Day 31; Pause became selected at Day 36. Treasury, residents, cashflow, utility spare, objective progress, and notices had changed. | Failed. |
| Opening cause/effect | On a controlled paused Day 5 compact launch, opened Journal. | Pressure, cause, tradeoff, and next action are readable. | `Budget Gap` explained the $61/cycle deficit and taxable-activity/tax choice. `A Town at the Crossroads` explained the deficit, 54 power/48 water spare, and jobs/revenue versus utility-headroom responses. | Passed focused comprehension surface. |
| Compact collision | Opened Objectives and Command Center details at declared 900×600. | Both critical surfaces remain operable or arbitrate safely. | Objectives stayed open; the details body extended below the window. AX exposed the collection's values, but the declared scroll-to-bottom action produced no visible movement. | `PLAY-050-D002`, failed. |
| Keyboard/Reduce Motion | Enabled app Reduce Motion; exercised Pause, `⌘J`, `⌥⌘I`, `B`, and Escape. | Equivalent labeled actions and recoverable focus/state. | Pause selected; panels toggled; B selected labeled Bulldoze mode; Escape returned to Inspect with `Action cancelled`. | Partial pass; no full inventory/FKA/VoiceOver soak. |
| Save | Pressed `⌘S` in a controlled paused state with no pre-existing quicksave. | Success only after a valid file exists. | `City saved` appeared and a 117,136-byte quicksave existed. | Focused save pass. |
| Resume attempt | Stopped/relaunched the staged bundle and prepared to press `⌘O`. | Load returns the saved state paused for inspection. | Computer Use reported that the staged app had changed externally; the same observed window later jumped to unrelated Day 74 / 3× state. | Blocked; no product assertion made. |

## Criterion dispositions

| Criterion | Disposition | Evidence | Notes |
| --- | --- | --- | --- |
| Town Charter ticks 1–4 | `passed` | Focused gameplay suite | Evaluates/normalizes only at tick 4. |
| Eleven versus twelve days | `passed` | Focused gameplay suite | No award at 11; one durable award at 12. |
| Failed-standard reset/recovery | `passed` | Focused gameplay suite | Reset occurs at next daily boundary; later 12-day run awards. |
| Exact tick 2,800 / Day 701 strategies | `passed` | Focused and full suites | Both distinct strategies remain viable at the exact horizon. |
| Decision by 02:00 | `failed` | `PLAY-050-D001` | The city begins changing before the player can act, invalidating the timer and starting fixture. |
| Blocking confusion | `blocked` | First-run mutation | No trustworthy fresh-player timing window exists. |
| Dead time | `blocked` | `confusion-dead-time.csv` | Reading mandatory onboarding silently consumes simulation days; wall-clock timing was not trusted after external interference. |
| False feedback | `failed` | First-run screenshot and AX states | The apparent start surface covers a city already accruing consequences without player agency. |
| Cause/effect comprehension | `partial` | Day 5 Journal AX state | Two clear causal notices exist; full live consequence/recovery chain was not safe to complete. |
| Diagnosis within two minutes | `partial` | Journal text | The opening causes and two response directions were immediately readable; no valid timed worsening-condition run completed. |
| Recovery before minute 18 | `partial` | Deterministic recovery test | Authoritative recovery succeeds; real-player timing remains unproved. |
| Strategy variety | `partial` | Exact-horizon deterministic test | Two paths are viable and distinct; discoverability/dominance under real play remains unproved. |
| Keyboard critical path | `partial` | Live shortcut observations | Focused routes worked; full command inventory and spatial keyboard scope are not integrated. |
| Accessibility critical path | `partial` | AX labels and Reduce Motion run | Critical labels are present; compact failure remains, and VoiceOver/FKA participant path was not completed. |
| Compact 900×600 | `failed` | `PLAY-050-D002` and retained capture | Simultaneous objectives/details obscure diagnostic content. |
| Save/resume | `blocked` | Save file plus contamination stop | Save succeeded; load comparison is not trustworthy. |
| Clear outcome | `partial` | Objective routing tests and live objective labels | Award routing is deterministic; real live Charter comprehension was not reached. |

## Defects and owner return

- `PLAY-050-D001`: Priority 2, UI and input. Pause or defer simulation while blocking onboarding is active, then rerun from an uncontaminated fresh profile.
- `PLAY-050-D002`: Priority 1, UI and input. The declared minimum compact layout must arbitrate objectives/details or expose an operable diagnosis viewport.

No product fix was made in the playtest-quality lane. No shared contract proposal is required for these reproductions. A future clean-profile/save-root harness remains a candidate shared-contract proposal for integration plus PLAY-040/PLAY-030 review; this run does not invent it.
