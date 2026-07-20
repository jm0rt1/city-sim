# PLAY-050 Integrated PLAY-010 Evidence Manifest

## Candidate identity

- Accepted product baseline: `f96ff8022ee12e0ac32f0250621993d23f2f0d23`
- PLAY-050 synchronization merge: `a5ba2acd471218c0f4697a814b8862001e8b344d`
- Evaluated branch commit: `831cb1c11d3a26883cf40a11a5af87f7e94176d0`
- Journey contract: `critical-journey-v3.md`, frozen in the evaluated commit
- Staged executable: `dist/CitySim.app/Contents/MacOS/CitySimNative`
- Staged executable SHA-256: `f05931d5e7d03e8be68472719119c12d337f6fcead7c248412811a14e9d4d0eb`
- Product source changes by PLAY-050: none
- Legacy Python changes: none

## Overall disposition

`failed` for integrated-wave playability. The authoritative Town Charter and exact-horizon checks pass, but the real staged-app journey reproduces two critical player-facing defects. The first-run overlay allows the city to mutate before player agency, and the simultaneous compact objectives/details state hides the diagnosis body below the 900×600 window. The later save/resume attempt was stopped as `blocked` after Computer Use reported an external staged-app change and the same window jumped to unrelated state.

## Validation summary

| Gate | Result | Evidence |
| --- | --- | --- |
| Focused `GameplayLoopTests` | Passed: 10 tests, 0 failures, 5.406 seconds | Independent run on July 19, 2026; exact-horizon strategy test passed in 4.704 seconds. |
| Full native suite | Passed: 45 tests, 0 failures, 27.081 seconds | Includes 35 baseline tests and 10 gameplay-loop tests. |
| Exact strategies | Passed deterministically | Both paths reached exactly tick 2,800 / Day 701, had one durable Charter, were not lost, and retained positive treasuries. |
| Town Charter timing | Passed deterministically | No evaluation/normalization through ticks 1–3; tick 4 boundary; no award at 11 days; award at 12; failure reset at next boundary; later recovery awards once. |
| Persistence/undo rules | Passed deterministically | Legacy decode, new/awarded JSON round trips, exact undo restoration, and objective/message routing passed. |
| `git diff --check` | Passed | No output. |
| `bash -n script/build_and_run.sh` | Passed | No output. |
| Staged build/launch | Passed | `./script/build_and_run.sh --verify` exited 0 after staging and launching the app. |
| Renderer diagnostic | Passed | Ten pulses averaged 1.764 ms; 5,760 tile roots reused; 0 updated. |
| Real first-run journey | Failed | `PLAY-050-D001`; city advanced behind blocking onboarding. |
| Compact 900×600 | Failed | `PLAY-050-D002`; diagnosis body remained below the window with objectives open. |
| Keyboard/Reduce Motion focused routes | Partial | Pause, `⌘J`, `⌥⌘I`, `B`, and Escape changed the labeled state; Reduce Motion was enabled for the compact run and restored. |
| Save/resume | Blocked | Save emitted success and created a 117,136-byte file, but external state changed before a trustworthy load assertion. |

## Retained artifacts

| Artifact | SHA-256 | Provenance and meaning |
| --- | --- | --- |
| `visuals/first-run-day17-onboarding.jpeg` | `f5e45e1911c711a7074f49fc9cdf2b403088aeea8c8df984ea1fb628a9b750e4` | Real staged-app capture. The blocking welcome surface remains present while the HUD has reached Day 17, with five notices and changed finances/utilities. |
| `visuals/compact-objectives-details.jpeg` | `c76a195b484786f1d89dbbbd9bcef7d494d4971645e691cf025b2131ebc475aa` | Real staged 900×600 capture. Objectives consume the left side while only the command-center header and card tops are visible at the bottom edge. |
| `confusion-dead-time.csv` | Recorded with this manifest | Simulation-state checkpoints for the invalid first-run clock and compact obstruction. |
| `session-record.md` | Recorded with this manifest | Criterion dispositions, live observations, contamination stop, and state restoration. |
| `defects/PLAY-050-D001-onboarding-advances-city.md` | Recorded with this manifest | Integrated reproduction of the baseline onboarding defect. |
| `defects/PLAY-050-D002-compact-details-clipped.md` | Recorded with this manifest | Integrated reproduction of the baseline compact-layout defect. |

## Environment hygiene

The local preference domain began with `hasSeenCitySimWelcome=1` and `reduceGameMotion=0`; both exact values were restored. No user quicksave existed before the run. The 117,136-byte test-created quicksave was moved out of `Application Support/CitySimNative` to `/private/tmp/citysim-play050-controlled-quicksave.json` (SHA-256 `b055652c9c47bcbe677538f50c3168da8c4e3fab37170560142cf58574cce8c1`) after UI execution stopped. It is not repository evidence and cannot establish resume success.

## Evidence limitations

- Computer Use identified an external change to the staged app during the save/resume sequence. The observed jump from controlled paused Day 5 state to unrelated Day 74 / 3× state is treated as harness contamination, not a CitySim product defect.
- The live run therefore stopped before a trustworthy resumed-state comparison, real Charter award, Full Keyboard Access soak, or VoiceOver participant journey.
- The Town Charter rule and exact strategy findings are deterministic harness evidence. They do not prove fresh-player discoverability or comprehension.
