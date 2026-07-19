# PLAY-050 Critical Journey v1

**Status:** Frozen before first execution

**Task:** `PLAY-050`

**Baseline candidate:** `c4460255ca810ce4de878f20f98a883983cf3dbd`

**Target duration:** 20 minutes wall-clock

**Coaching:** None after the session timer starts

## Player brief

You are the mayor of New Arcadia. Understand the city's immediate pressure, make a meaningful first decision, observe what changes, diagnose a worsening condition, recover through a second decision, reach a clear outcome, save, leave, and resume.

The player may use information discoverable in the staged app. Source code, developer logs, hidden state, scripted coordinates, and verbal hints are prohibited during the timed journey.

## Starting fixture

Wave acceptance requires the authoritative golden starting city supplied by PLAY-010 and PLAY-040, including a stable fixture ID, version, seed, initial state hash, expected invariants, and safe save location. Until that contract lands, the baseline's normal fresh-city launch may be evaluated only as a baseline finding; it cannot pass the integrated wave.

The fixture must expose:

- one legible, non-terminal treasury-demand-utilities-happiness-employment pressure;
- at least two viable first strategies with different tradeoffs;
- one warned, recoverable overextension;
- at least two valid recovery approaches;
- a durable Town Charter milestone with explicit pass, fail, and persistence rules.

## Timed primary journey

| Window | Player outcome | Required signal |
| --- | --- | --- |
| 00:00–02:00 | Orient and commit the first meaningful decision. | Pressure, objective, cost, legality, and at least two affected outcome dimensions are discoverable. |
| 02:00–06:00 | Observe commitment and first-order response. | Preview, authoritative commit, process, and immediate outcome agree across world and interface. |
| 06:00–10:00 | Read a second-order consequence. | Affected system and trend can be located without developer explanation. |
| 10:00–14:00 | Diagnose the worsening condition. | Place/system, leading cause, consequence if ignored, and next diagnostic action are understandable within two minutes. |
| 14:00–18:00 | Recover through a second meaningful decision. | Recovery produces visible and numerical improvement before minute 18. |
| 18:00–20:00 | Reach an outcome, save, leave, resume, and reorient. | Milestone/failure is explicit; resumed state preserves invariants and active pressure is understood within one minute. |

A meaningful decision must change and communicate at least two of: physical form, access/capacity, treasury/cost, household/business opportunity, service outcome, environment/resilience, or sentiment/progression.

## Critical variants

1. **Pointer/default:** entire journey in the default 1440×900 window.
2. **Keyboard:** all declared non-spatial actions, panels, alerts, simulation controls, save/load, and focus recovery without pointer use. Spatial construction follows the approved PLAY-030 scope; any required pointer handoff is recorded explicitly.
3. **Compact:** affected path at 900×600 with no clipped critical control, lost focus, unreadable text, or unusable map context.
4. **Accessibility:** Reduce Motion plus non-color/non-sound verification; VoiceOver/Full Keyboard Access coverage is recorded for the declared critical path.
5. **Resume:** save, quit, relaunch, load, and identify active pressure within one minute without relying on the prior session record.

The primary 20-minute run is not duplicated merely to inflate run count. Focused variants start from the same authoritative checkpoint unless a variant-specific fixture is documented.

## Objective pass/fail rules

| Measure | Pass | Critical failure |
| --- | --- | --- |
| First decision | Meaningful decision committed by 02:00. | No meaningful decision by 02:00 or coaching required. |
| Blocking confusion | No single unresolved episode exceeds 30 seconds. | Any unresolved critical-path confusion over 30 seconds. |
| Dead time | No involuntary wait/search interval exceeds 60 seconds; cumulative non-observation dead time is at most 120 seconds. | Progress depends on unexplained waiting or searching beyond either limit. |
| False feedback | Zero contradictions or premature success signals. | Any command, world, HUD, objective, notice, audio, or persistence surface reports a materially false state. |
| Cause/effect | Player identifies place/system, leading cause, consequence, and useful next step. | Player cannot explain any one of these without coaching. |
| Diagnosis | Pressure diagnosed within two minutes of becoming observable. | Diagnosis exceeds two minutes or points to a false cause. |
| Recovery | Declared recovery invariants restored before 18:00. | Recovery is impossible, opaque, single-solution without true dependency need, or completes after 18:00. |
| Strategy | Two distinct approved paths can succeed and expose different tradeoffs. | One path is strictly superior across time, treasury, wellbeing, and recovery cost, or only one unexplained build order works. |
| Keyboard/accessibility | 100% of the declared critical path passes with equivalent information and no focus trap. | Inaccessible critical action/state, color/sound/motion-only truth, or focus trap. |
| Compact | Critical path remains operable at 900×600. | Clipped/overlapped critical control, unreadable status, lost input, or unusable viewport. |
| Save/resume | State and declared invariants survive; active pressure understood within one minute. | False save success, lost/changed authoritative state, load failure, or reorientation over one minute. |
| Outcome | Pass/fail/milestone and next action are explicit. | Session ends without a comprehensible disposition. |

## Observation definitions

- **Confusion:** the player cannot identify what a control/state means, why an outcome happened, or what action advances the goal.
- **Blocking confusion:** confusion prevents the next critical action or causes an action based on a materially false model.
- **Dead time:** time spent waiting or searching with no useful new state to observe. Deliberate observation of a signaled simulation process is not dead time.
- **False feedback:** presentation claims success, failure, cause, availability, cost, consequence, or persistence that disagrees with authoritative behavior.
- **Coaching:** any instruction not discoverable through the staged app after the timer begins.

## Stop conditions

Stop and classify the run `blocked` when the authoritative fixture/save/hash contract is missing for an integrated candidate, the staged app differs from the declared commit, proof cannot be retained, unrelated local state contaminates the run, or a shared contract is required but unapproved.

Stop and classify the run `failed` when a critical-failure condition is reproduced. Continue only as needed to retain safe reproduction evidence; do not revise the journey.
