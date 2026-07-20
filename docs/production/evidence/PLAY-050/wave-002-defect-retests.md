# PLAY-050 Wave 002 D001 and D002 Retest Checkpoints

**Status:** Frozen while defects remain open

**Candidate:** Not supplied; integration must name the exact integrated commit before execution

These are independent closure gates, not implementation instructions. Retain the prior failed records and create candidate-specific reproductions. A lane completion record or automated test cannot close either defect.

## PLAY-050-D001 — Blocking onboarding advances the city

### Controlled start

- Validate the exact isolated bundle, preference domain, data root, PID, branch, and commit using the Wave 002 manifest.
- Use a clean lane-specific preference domain with onboarding not seen and an empty lane-specific data root.
- Record the candidate's authoritative authored-start fixture ID, version, seed, expected fingerprint, day, tick, treasury, population, happiness, approval, jobs, utilities, demands, progression, speed, and message count.
- Launch at the default 1440×900 window. The welcome surface must be visible and keyboard/VoiceOver reachable.

### Fixed checkpoints

| Checkpoint | Action | Required invariant |
| --- | --- | --- |
| T+0 after welcome settles | Capture screen, AX tree, state/fingerprint diagnostic, and process identity. | Welcome visible; authoritative state equals the authored start. |
| T+10 seconds | Read without input; capture state/fingerprint and HUD/notice values. | Tick/day/digest/metrics/progression/messages unchanged. |
| T+30 seconds | Continue reading; attempt no player action. | Exact authored state still unchanged; no hidden warning or construction progress. |
| T+60 seconds | Continue reading; capture final pre-dismissal proof. | Exact authored state still unchanged; no dead-time penalty caused by silent simulation. |
| Modal-input check | While welcome is open, press `Space`, `1`, `2`, `3`, `B`, `V`, Escape, and catalog-guide shortcuts in a separate reset run. | No game command leaks through; welcome remains operable and state unchanged. |
| Pointer dismissal | Activate `Start Building` with pointer. | First post-dismissal state/digest still equals T+0; focus enters the playable surface predictably. |
| Keyboard/FKA dismissal | Repeat from reset and activate Start Building without pointer. | Same exact post-dismissal state; no focus trap or coaching. |
| First pulse | Start/observe one declared simulation pulse after dismissal. | Mutation begins only now and matches the accepted tick/day rule. |
| First decision clock | Begin timing at successful dismissal. | Meaningful decision committed by 02:00 from the identical authored start. |

### Closure rule

Mark D001 `not reproduced` only if every 0/10/30/60-second invariant passes in pointer and keyboard-accessible runs, modal shortcuts do not leak, dismissal preserves the exact start, and the subsequent pulse begins correctly. Any tick, digest, metric, construction, progression, or notice change before dismissal fails the candidate.

## PLAY-050-D002 — Compact objectives obstruct command-center diagnosis

### Controlled start

- Launch the exact isolated candidate at 900×600 points and record the actual content-frame dimensions and display scale.
- Pause at a named fixture/digest; enable Reduce Motion in the lane-specific preference domain.
- Begin with Objectives and Command Center closed and a known keyboard focus target.

### Fixed checkpoints

| Checkpoint | Action | Required invariant |
| --- | --- | --- |
| Pointer open | Open Objectives, then Command Center details using visible controls. | Layout deliberately arbitrates the surfaces or keeps both fully operable; no content is below/behind the window. |
| Keyboard open | Reset; use `⌘J` and `⌥⌘I`. | End state and information equal the pointer route; focus is visible and predictable. |
| Minimum-frame screenshot | Capture the entire 900×600 content frame with AX tree. | Objective title/progress, command-center title, current section, critical values, close/back controls, and any scroll affordance are visible/non-color-only. |
| Full traversal | With Full Keyboard Access, traverse from Objectives through every visible command-center control and back out. | Every critical value/action is reachable once in logical order; no focus trap or off-window target. |
| Scroll proof | If scrolling is used, move to first and last diagnostic items by pointer, keyboard, and AX action. | Visible content actually moves; first/last items and return path are perceivable. An AX action with no visible movement fails. |
| Escape order | With nested transient content open, press Escape repeatedly. | Topmost transient closes first; active tool is cancelled only after transients close. |
| Resize boundary | Open affected surfaces at 1440×900, resize to 900×600, then return to default. | No lost state/focus, overlap, clipped body, or inaccessible close route in either direction. |
| VoiceOver/Reduce Motion | Read both surfaces and execute the critical close/navigation actions. | Equivalent labels, values, ordering, disabled reasons, and no motion-only truth. |

### Closure rule

Mark D002 `not reproduced` only when pointer, keyboard, Full Keyboard Access, VoiceOver, Reduce Motion, scrolling (if present), and default↔compact resize all pass with retained full-window and focus/AX evidence. A populated AX tree alone cannot compensate for visually inaccessible content; a screenshot alone cannot prove focus or scrolling.

## Required candidate record

For each defect, record `passed`, `failed`, `partial`, `blocked`, or `not-reproduced`; exact candidate and evidence commits; fixture/digest; isolated app identity; step-by-step timestamps; screenshots; AX/focus output; actual/expected values; and owner-lane return. Do not edit the prior failed records.
