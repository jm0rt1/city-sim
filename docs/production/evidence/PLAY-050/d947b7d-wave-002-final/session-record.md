# PLAY-050 Final Wave 002 Session Record — Rejected at live focus gate

## Disposition matrix

| Gate | Result | Evidence |
| --- | --- | --- |
| Candidate identity and exact PID | passed | `manifest.md` |
| Fresh independent native suite | passed, 87/87 | `automated-validation.md` |
| D001 default containment for at least 60 seconds | passed | `d001-d002-retest.md` |
| D001 compact containment for at least 60 seconds | passed | `d001-d002-retest.md` |
| Keyboard and pointer Welcome dismissal | passed | `d001-d002-retest.md` |
| Commands operate immediately after dismissal | **failed** | D006 |
| D002 compact simultaneous Objectives + Details | passed for executed route | `d001-d002-retest.md` |
| Controlled map-focus comparison | failed pre-focus; passed after map click | D006 |
| Remaining 32-row live command reconciliation | blocked by critical rejection | not credited |
| Full Keyboard Access / VoiceOver / Reduce Motion | blocked by critical rejection | not credited |
| World selection/build/invalid/commit/undo/overlay/pan/zoom matrix | blocked by critical rejection | not credited |
| Save/load/corruption/undo/isolation live matrix | blocked by critical rejection | automated contracts only; not credited live |
| Coached pointer + keyboard 20-minute journey | blocked by critical rejection | not started |
| Regular and Reduce Motion settled RSS comparison | partial / blocked | compact settled 111,968 KiB; Reduce Motion not run |

## Stop rationale

The frozen journey rejects for an inaccessible required catalog action, focus trap, shortcut route disagreement, or required coaching. D006 is reproducible after both permitted Welcome dismissal routes and disappears only after an undisclosed manual map click. Continuing the long journey would create evidence after the starting keyboard/focus contract had already failed, so PLAY-050 stopped and did not represent later gates as passed.

No product source, test, shared contract, task authority, build script, preference outside the unique candidate domain, production data, or another owner's process was changed.
