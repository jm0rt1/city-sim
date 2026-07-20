# PLAY-050 Repaired Wave 002 Session Record — Rejected at D006

| Gate | Result | Evidence |
| --- | --- | --- |
| Exact candidate, isolated identity, and PID | passed | `manifest.md` |
| Staged build/verify | passed | `automated-validation.md` |
| D001 default 60-second quarantine | passed through 77 seconds | `d006-retest.md` |
| Only `welcome.start-building` exposed in game AX | passed | complete live AX tree |
| Return dismissal removes Welcome | passed | `d006-after-return-day1.jpeg` |
| D006 immediate Space after Return | **failed** | Day 6, Pause not selected |
| D006 repeated Space without extra click | **failed** | Day 13, Pause not selected |
| D006 pointer dismissal / compact | blocked by first-route rejection | not run |
| D002 world/default/compact matrix | blocked by D006 | not run |
| All 32 commands and focus precedence | blocked by D006 | not run |
| Save/load/corruption/undo/isolation | blocked by D006 | not run |
| Regular and Reduce Motion settled RSS | blocked by D006 | only rejection-time RSS recorded |
| Coached pointer + keyboard 20-minute journey | blocked by D006 | not started |

No product code or test was changed by PLAY-050. The independent test process and exact staged app process were stopped after the critical failure.
