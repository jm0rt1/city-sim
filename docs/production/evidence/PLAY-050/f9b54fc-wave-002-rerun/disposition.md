# PLAY-050 Wave 002 Repaired-Candidate Disposition — Rejected

- Exact product candidate: `f9b54fc77a3d78fd4d8d5c80c8661d8d8852e209`
- Exact playtest candidate merge HEAD: `85ad9e266cfa0597d5d422008ebd2ef448fb25b3`
- Exact rerun evidence commit: `ca6c26a2ada2c3d3afef1bf1073620483f3447dc`
- Disposition: **REJECTED**
- PLAY-050 claim: remains active

## Accepted portions of the rerun

- Repaired candidate ancestry and clean merge passed without rewriting the prior rejection evidence.
- `git diff --check`, build-script syntax, identity printing, staged `--verify`, executable/Info.plist hashing, and exact process verification passed.
- The complete native suite passed 78/78.
- Corrected `dense-24x24-terminal-wave2-v2` assertions passed in the full suite and two focused repeats: 400 step attempts, tick 44, `.lost`, fingerprint `7b6454ecbe83aeb3bdc88de4fb1d6cb23ef67ce81849123e907d3147c6c52a77`.
- The repaired candidate's generated data root remained empty and the production quicksave remained byte-identical.

## Critical rejection

An already-running external quality candidate at commit `822755cbad5431d868547e3d38d41e8df14e715f`, exact PID `59491`, declares the same `com.jfmortensen.citysim.playtest-quality` bundle identifier, `CitySim [Quality]` display name, and preference domain as the repaired candidate. The candidates have different executable hashes and roots but share onboarding, Reduce Motion, diagnostics, and window preferences.

The frozen CONTRACT-004 manifest blocks interaction when another active candidate has the same preference domain. Candidate A's exact PID `32451` was stopped; external PID `59491` was left alive and untouched. No shared preference was reset.

## Unexecuted gates

D001, D002, live 32-command traversal, Full Keyboard Access, VoiceOver, Reduce Motion, text/modal leakage, save/resume/undo/corrupt recovery, and the 20-minute journey remain open and were not credited. Running them after the identity collision would produce non-attributable evidence and violate the frozen stop condition.

Return `PLAY-050-D004` to Simulation Platform / Integration. A fresh candidate rerun requires no active bundle sharing the supplied candidate's preference domain, or an integration-approved per-candidate identity contract. No product repair, push, or integration was performed by PLAY-050.
