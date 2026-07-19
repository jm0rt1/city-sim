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

The baseline journey is frozen in [critical-journey-v1.md](critical-journey-v1.md). [critical-journey-v2.md](critical-journey-v2.md) adds the accepted `CONTRACT-001` Town Charter rules for candidates after PLAY-010 integration. If a later accepted product contract makes a step obsolete, create another journey version and retain the previous versions. Never rewrite a completed or in-progress journey to make a candidate pass.

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

## Ownership boundaries

This lane may add fixtures, harnesses, focused reproduction tests, evidence records, and proof. Product defects are returned to the owning lane. Changes to package topology, public store/command contracts, snapshot contracts, save schemas, launch scripts, task authority, or traceability require integration approval before implementation.
