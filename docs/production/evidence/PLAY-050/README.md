# PLAY-050 Playable-Session Evidence

This directory contains independent playtest-quality evidence for `PLAY-050`. It does not grant acceptance, advance requirements, or define gameplay, renderer, command, or persistence authority. Integration owns final disposition.

## Evidence contract

Every candidate run must identify:

- the exact candidate commit and staged application build;
- the starting fixture, content version, seed, and state hash when supplied by the owning lanes;
- the player's goal and allowed prior knowledge;
- the frozen journey version used before the run began;
- timestamps for decisions, consequences, confusion, dead time, diagnosis, recovery, outcome, save, and resume;
- pointer, keyboard, compact, accessibility, and save/resume variants attempted;
- proof paths and any disclosed capture limitations;
- every criterion disposition as `passed`, `failed`, `partial`, `blocked`, or `not-reproduced`.

Critical failures reject the candidate. Passing automated tests, producing a screenshot, or launching the app cannot compensate for a failed player outcome.

## Versioned journey

The baseline journey is frozen in [critical-journey-v1.md](critical-journey-v1.md). [critical-journey-v2.md](critical-journey-v2.md) recorded the approved `CONTRACT-001` rules before implementation landed. [critical-journey-v3.md](critical-journey-v3.md) is the execution contract for the accepted PLAY-010 baseline and makes its four-ticks-per-day timing and exact 2,800-tick strategy horizon explicit. If a later accepted product contract makes a step obsolete, create another journey version and retain the previous versions. Never rewrite a completed or in-progress journey to make a candidate pass.

[critical-journey-v4.md](critical-journey-v4.md) is frozen for the future Wave 002 integrated candidate. It consumes the approved command, persistence, and app-isolation contracts through [wave-002-command-inventory.md](wave-002-command-inventory.md), [wave-002-persistence-gate.md](wave-002-persistence-gate.md), [wave-002-candidate-manifest-template.md](wave-002-candidate-manifest-template.md), and [wave-002-defect-retests.md](wave-002-defect-retests.md). D001 and D002 remain open until that exact integrated candidate independently passes the retests.

## Candidate layout

Each evaluated commit receives a directory named `<short-sha>-<purpose>/` containing:

```text
manifest.md
session-record.md
confusion-dead-time.csv
defects/
visuals/
logs/
```

Binary proof must be directly traceable from `manifest.md`. Generated build products and private user saves do not belong in this directory.

For Wave 002 and later, every run manifest must record the branch, full commit, accepted base, bundle identifier, display name, preference domain, isolated data root, launch time, staged bundle path, executable path and SHA-256, exact process identity, build invocation, journey version, fixture IDs, expected/actual fingerprints, and repository cleanliness. Missing or ambiguous candidate identity blocks the run.

## Candidate runs

- `c446025-baseline/`: initial accepted-baseline rejection and the first reproductions of `PLAY-050-D001` and `PLAY-050-D002`.
- `831cb1c-play010-integrated/`: accepted PLAY-010 rule/horizon verification plus staged-app reproduction of both defects against the integrated candidate.

## Ownership boundaries

This lane may add fixtures, harnesses, focused reproduction tests, evidence records, and proof. Product defects are returned to the owning lane. Changes to package topology, public store/command contracts, snapshot contracts, save schemas, launch scripts, task authority, or traceability require integration approval before implementation.
