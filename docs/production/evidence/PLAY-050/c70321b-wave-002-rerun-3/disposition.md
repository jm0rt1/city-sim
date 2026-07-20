# PLAY-050 Wave 002 Restart 2 Disposition — Rejected

- Exact product candidate: `c70321b7c61465efe77f600878f74b8093013cb7`
- Exact playtest merge HEAD: `8f692625c6821285036d29cc6f65379c6fa2f8b1`
- Exact evidence commit: `c97030ef566134bbeca9d6623fcf2b2dd982acb1`
- Disposition: **REJECTED**
- PLAY-050 claim: remains active

## Gates that passed

- Candidate `c70321b`, fingerprint parent `f9b54fc`, and management authority `b8cb474` are ancestors.
- Static checks, both build-script syntax checks, tokenized identity, staged launch, executable/manifest hashing, and 78/78 tests passed.
- Dense v2 ended at tick 44 / `.lost` with frozen digest `7b6454ecbe83aeb3bdc88de4fb1d6cb23ef67ce81849123e907d3147c6c52a77`.
- D004 is not reproduced: same-lane/same-commit candidates received distinct tokens, domains, displays, executables, roots, manifests, and PIDs; opposite preference probes and exact-bundle saves remained isolated; external PID `59491` was preserved.
- D001 authoritative values and welcome remained stable through 0/10/30/60 seconds. Pointer dismissal preserved Day 1 immediately and simulation changed only afterward.

## Critical failure

In a separate reset run, `Space`, `1`, `2`, `3`, `B`, `V`, `Escape`, and `⌘/` were sent while the blocking welcome remained open. The underlying speed selection changed from `1×` to `3×`, and `⌘/` opened the command-guide sheet with search focused. After closing the guide, the welcome was still present with `3×` selected.

This is critical D005: gameplay and catalog shortcuts leak through onboarding. It breaks modal containment, changes the future first-pulse pace without acknowledgement, and creates an unexpected nested focus surface for keyboard/accessibility users. The D001 run also opened at an observed 900×652 full-window frame instead of the frozen default 1440×900 requirement.

## Unexecuted after rejection

D001 keyboard dismissal/decision timing, D002 compact/FKA/VoiceOver/Reduce Motion, the remaining 32-command live routes, journey persistence/recovery/undo, and the coached 20-minute journey were not executed or credited after the critical failure. Return D005 to UI/Input. No product repair, push, or integration was performed by PLAY-050.
