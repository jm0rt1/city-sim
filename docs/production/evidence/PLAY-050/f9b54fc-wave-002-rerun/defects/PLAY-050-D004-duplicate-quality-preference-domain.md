# PLAY-050-D004 — Two Active Quality Candidates Share One Preference Identity

- Repaired product candidate: `f9b54fc77a3d78fd4d8d5c80c8661d8d8852e209`
- Playtest merge HEAD: `85ad9e266cfa0597d5d422008ebd2ef448fb25b3`
- Conflicting active candidate: `822755cbad5431d868547e3d38d41e8df14e715f`, PID `59491`
- Severity: critical acceptance blocker
- Owner return: Simulation Platform / Integration candidate-isolation contract
- Requirement impact: CONTRACT-004; Wave 002 manifest; D001/D002 preference and window isolation; two-candidate gate
- Disposition: reproduced before interaction; candidate rejected

## Reproduction

1. Merge exact repaired local `master` into the clean PLAY-050 evidence branch and build with `./script/build_and_run.sh --verify`.
2. Record candidate A as bundle `com.jfmortensen.citysim.playtest-quality`, display `CitySim [Quality]`, exact current-worktree executable, and PID `32451`.
3. Inventory running CitySim processes by exact executable path, without global process-name targeting.
4. Observe PID `59491` at `/private/tmp/citysim-play040-two-app.6S3Zi1/quality-candidate/dist/CitySim-playtest-quality.app/Contents/MacOS/CitySimNative`.
5. Read that candidate's retained manifest, Git identity, and `Info.plist`.

## Expected

Every simultaneously active candidate must have an unambiguous bundle/display identity and a preference domain not used by another candidate. Resetting onboarding, Reduce Motion, renderer diagnostics, or the window frame for one candidate must not alter another candidate.

## Actual

Candidate A (`f9b54fc…`) and candidate B (`822755cb…`) are different executables and commits but both declare:

- `CFBundleIdentifier = com.jfmortensen.citysim.playtest-quality`
- `CFBundleDisplayName = CitySim [Quality]`
- preference domain `com.jfmortensen.citysim.playtest-quality`

The external candidate remained alive throughout verification. Candidate A's exact PID was stopped; candidate B was not modified or terminated. Because macOS UserDefaults is keyed by the shared bundle domain, a D001/D002 reset for A cannot be proven lane-local while B is active.

## Impact

Candidate identity is visually and preference-wise ambiguous despite distinct executable paths and data roots. The frozen manifest names an aliased active preference domain as a pre-interaction stop condition and rejects root/preference/process cross-contamination. Starting the live gate would create evidence that cannot be attributed to the repaired candidate alone.

No product code, build script, external candidate, or shared preference value was changed by PLAY-050.
