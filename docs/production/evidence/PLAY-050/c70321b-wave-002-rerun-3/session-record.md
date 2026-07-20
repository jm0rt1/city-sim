# PLAY-050 Wave 002 Restart 2 Session Record — Rejected During D001

- Exact product candidate: `c70321b7c61465efe77f600878f74b8093013cb7`
- Exact playtest candidate merge HEAD: `8f692625c6821285036d29cc6f65379c6fa2f8b1`
- Overall disposition: **REJECTED**
- Product changes: none
- Push/integration: none

| Gate | Result | Evidence |
| --- | --- | --- |
| Candidate and authority ancestry | passed | `manifest.md` |
| Static/build identity | passed | `automated-validation.md` |
| Full native suite | passed | 78/78, 37.210 seconds |
| Dense v2 contract | passed | tick 44 / `.lost` / exact digest |
| D004 same-lane isolation | not reproduced / passed | two roots, tokens, domains, processes, probes, saves; `d004-isolation-retest.md` |
| D001 0/10/30/60 authored-state stability | partial | values and welcome were stable, but observed frame was 900×652 rather than required default 1440×900 |
| D001 pointer dismissal and post-dismiss pulse | passed | immediate Day 1 equality; Day 2 after 2.2 seconds |
| D001 modal shortcut containment | **failed — critical** | 3× selection and command guide leaked through welcome; D005 |
| D001 keyboard dismissal / decision clock | not credited | stopped after critical leakage |
| D002 compact/FKA/VoiceOver/Reduce Motion | unexecuted | immediate rejection after D001 |
| Full 32-command live traversal | partial only | automated 8/8 passed; modal leak disproves containment |
| Save/resume/undo/corrupt recovery | unexecuted | isolation-only saves were proof controls, not journey acceptance |
| 20-minute coached pointer/keyboard journey | unexecuted | timer not started after critical D001 failure |

The repaired candidate solves the prior dense-fixture and same-lane identity defects, but it cannot pass the playable-session gate. The welcome freezes authoritative state yet does not contain gameplay and guide shortcuts. Integration should return D005 to UI/Input and retain D001 as open. D002 and the remaining Wave 002 routes require a new exact candidate.
