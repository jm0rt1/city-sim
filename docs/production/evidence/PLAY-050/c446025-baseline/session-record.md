# PLAY-050 Baseline Session Record

## Candidate

- Product commit: `c4460255ca810ce4de878f20f98a883983cf3dbd`
- Build command: `./script/build_and_run.sh --verify` with writable Swift module-cache paths
- Staged app: `dist/CitySim.app`
- Journey version: `critical-journey-v1`
- Fixture: no authoritative PLAY-010/040 fixture available; baseline fresh city only
- Variants: regular pointer/AX inspection, keyboard shortcuts, 900×600 compact, Reduce Motion, save/resume
- Tester allowed knowledge: staged-app surfaces only during interaction
- Overall disposition: `failed`; full 20-minute integrated journey `blocked`

## Timeline

| Observation | Player action/observation | Expected signal | Actual signal | Finding |
| --- | --- | --- | --- | --- |
| First-run preflight | Exposed the welcome overlay before player action. | Starting city remains stable while blocking onboarding is read. | Welcome was visible at Day 19; it continued advancing and reached Day 42 before dismissal/pause. | `PLAY-050-D001`, failed precondition |
| Pause | Selected Start Building, then pressed Space using the shortcut disclosed in onboarding. | Simulation pauses and selected state is perceivable. | Pause became selected and values stopped changing. | Passed focused route |
| Diagnosis | Opened Jobs open from City Pulse. | Relevant detail explains present state and useful next action. | Employment showed 410/410 filled, 0 openings, 86% coverage, demand, and Build commercial/industrial actions. | Partial cause/effect pass; no authored pressure |
| Save | Pressed ⌘S while paused at Day 42. | Success only after persistence succeeds. | `City saved` appeared and a 118,370-byte quicksave was created. | Passed focused route |
| Resume | Quit, relaunched the staged bundle, pressed ⌘O. | Saved values return and simulation is safe to inspect. | Day 42, treasury $402,781, residents 679, happiness 69%, jobs 410, utilities 100%, and nine notices returned; load message said simulation paused. | Partial pass; no authoritative state hash/schema |
| Compact | Relaunched with `CITYSIM_COMPACT_WINDOW=1`, loaded, opened details. | 900×600 remains usable. | Command center alone was visible and accessible. | Passed focused surface |
| Keyboard | Pressed B, Escape, ⌘J, and ⌥⌘I. | Shortcut routes match visible intents and retain focus. | Bulldoze activated, Escape canceled, objectives opened, and details opened. | Partial pass; inventory/Full Keyboard Access not yet authoritative |
| Compact collision | Kept objectives and details open together at 900×600. | Both critical surfaces remain operable. | Details content fell below the window; screenshot shows only its header and AX exposed an empty content collection. | `PLAY-050-D002`, critical compact failure |
| Reduce Motion | Opened Settings, enabled Reduce ambient animation, restarted app. | Setting is accessible, persists, and does not remove critical information. | Switch was AX-labeled, persisted across restart, and compact HUD information remained present. | Partial; VoiceOver/Full Keyboard Access participant path not run |

## Criterion dispositions

| Criterion | Disposition | Evidence | Notes |
| --- | --- | --- | --- |
| Decision by 02:00 | `blocked` | Missing authoritative fixture | A valid timer could not start from a stable golden city. |
| Blocking confusion | `blocked` | `confusion-dead-time.csv` | No valid uncoached timed run. |
| Dead time | `blocked` | `confusion-dead-time.csv` | No valid uncoached timed run. |
| False feedback | `partial` | Save/load AX state | No false persistence success observed; silent onboarding mutation remains a causal-integrity defect. |
| Cause/effect comprehension | `partial` | Employment detail AX state | Useful state/action path exists, but no authored pressure or historical causal chain. |
| Diagnosis within two minutes | `blocked` | Missing PLAY-010 pressure | Baseline has no qualified worsening condition. |
| Recovery before 18:00 | `blocked` | Missing PLAY-010/040 contracts | No declared recovery invariants. |
| Strategy variety | `blocked` | Missing PLAY-010 strategies | Not safe to infer balance from baseline sandbox behavior. |
| Keyboard critical path | `partial` | B, Escape, ⌘J, ⌥⌘I, ⌘S, ⌘O observations | Focused shortcuts worked; full inventory and spatial scope remain dependencies. |
| Accessibility critical path | `partial` | AX tree and Reduce Motion setting | Labels and non-color text were present; VoiceOver and Full Keyboard Access were not qualified. |
| Compact 900×600 | `failed` | `visuals/compact-objectives-details-clipped.jpg` | Critical simultaneous surfaces are not operable. |
| Save/resume | `partial` | `visuals/save-resume-day42.jpg` | Visible values round-tripped and load paused; schema/hash/recovery contract missing. |
| Clear outcome | `blocked` | Missing PLAY-010 milestone | Baseline objective is not the first-wave Town Charter outcome. |

## Outcome

The baseline is a useful visual and interaction foundation, but it does not pass PLAY-050. The wave remains dependent on authoritative scenario, visual-state, command/focus, and deterministic save/hash outputs. The two reproduced UI/input defects should return to PLAY-030; the isolated save-root proposal requires integration and PLAY-040 review.
