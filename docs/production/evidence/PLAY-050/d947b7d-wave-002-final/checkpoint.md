# PLAY-050 Wave 002 Final — Retained Checkpoint

- **Status:** Incomplete evidence checkpoint; no disposition claimed
- **Frozen quality candidate:** `d947b7d660d5778dcf34c165e750db293e060236`
- **Exact integration product:** `1084ba6ef624f9928d80f30829fe9f651ed68166`
- **Branch:** `codex/citysim-playtest-quality`
- **Candidate ID:** `playtest-quality-wf967be0ab5b4`
- **Bundle identifier / preference domain:** `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4`
- **Staged bundle:** `dist/CitySim-playtest-quality-wf967be0ab5b4.app`
- **Executable:** `dist/CitySim-playtest-quality-wf967be0ab5b4.app/Contents/MacOS/CitySimNative-wf967be0ab5b4`
- **Data root:** `dist/test-data/playtest-quality-wf967be0ab5b4`
- **Manifest launch:** `2026-07-20T14:33:03Z`, PID `40734` (not running when resumed)

## Retained observations

- Default Welcome was captured at 1,229 x 768 at start and after more than 60 seconds. The visible authored values remained Day 1, $26,000, population 300, happiness 58%, utilities 100%, one notice, and 1x.
- Explicit compact Welcome was captured at 900 x 632 at start and after 60 seconds with the same visible authored values.
- A post-dismissal default frame and compact command-center frames were retained.
- Two compact post-dismissal frames were retained for a possible focus-routing defect: shortcuts appeared inert before map focus and Space worked after map focus. This is not yet a disposition; it requires a fresh controlled reproduction.

## Limitations at checkpoint

- The complete 87-test suite, candidate verification, D001/D002 variants, 32-command traversal, persistence/recovery, same-lane isolation, RSS comparison, and 20-minute journey are not credited by this checkpoint.
- AX tree, exact state fingerprint, command log, and fresh reproduction records remain required.
- No product code was changed.
