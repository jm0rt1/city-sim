# PLAY-050-D004 Restart 2 Retest — Not Reproduced

## Same-lane, same-commit candidates

The current worktree and a disposable shared clone were both attached to `codex/citysim-playtest-quality` at exact commit `8f692625c6821285036d29cc6f65379c6fa2f8b1`.

| Field | Candidate A | Candidate B |
| --- | --- | --- |
| Root | current worktree | `/private/tmp/citysim-play050-isolation.gGRcpA/candidate-two` |
| Token | `wf967be0ab5b4` | `w9cb7fd3d73ba` |
| Candidate ID | `playtest-quality-wf967be0ab5b4` | `playtest-quality-w9cb7fd3d73ba` |
| Bundle/preference domain | `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4` | `com.jfmortensen.citysim.playtest-quality.w9cb7fd3d73ba` |
| Display | `CitySim [Quality wf967be0ab5b4]` | `CitySim [Quality w9cb7fd3d73ba]` |
| Harness PID | `89783` | `89983` |
| Preference/save proof PID | `90973` | `91154` |

The harness required distinct worktree token, candidate ID, bundle identifier, preference domain, display name, data root, bundle path, executable path, manifest path, and PID, and reported `CITYSIM_CANDIDATE_ISOLATION status=PASS`.

Opposite probes remained isolated:

- A: `PLAY050IsolationProbe=candidate-a`, onboarding seen, Reduce Motion false, diagnostics false.
- B: `PLAY050IsolationProbe=candidate-b`, onboarding seen, Reduce Motion true, diagnostics true.
- Legacy `com.jfmortensen.citysim.playtest-quality` values did not change.

Exact-bundle Save City actions produced:

- A root quicksave: 132,218 bytes, SHA-256 `dce114224abe06a7afc5a755f15dda07e8a1c460306155a240eedffccc019ce3`.
- B root quicksave: 132,218 bytes, SHA-256 `6d1a65f0f47e9c3d37ee080bd62e115753f633fe442067e866a20f40c47cdf6c`.

Both UI routes reported `City saved`. The saves appeared only under their own injected roots and differed because the simultaneously running sessions were at distinct ticks. External PID `59491` stayed alive at its original executable path and was never targeted. D004 is **not reproduced** for `c70321b`; candidate isolation passes.
