# Automated Validation

## Accepted integration evidence

Integration's exact `f75ab91` candidate passed the complete native suite: 91 tests, 0 failures, in 221.992 seconds. The staged `./script/build_and_run.sh --verify` run exited 0. The renderer soak remained stable, and the accepted PLAY-040 fingerprint companion covers save schema 1, fingerprint version 1, recovery, undo, candidate isolation, and the Wave 002 deterministic fixtures.

## Independent quality-lane attempts

The first independent SwiftPM attempt was discarded because default module-cache paths were not writable. Two fresh attempts using explicit writable `/private/tmp` build and module caches compiled the candidate, then the XCTest host exited with signal 11 at `CityCommandCatalogTests.testQueuedWelcomeFocusHandoffCancelsWhenModalReblocksOrMapDetaches`. Earlier command-catalog cases passed. The crash reproduced at the same test and is disclosed as an independent harness/host limitation; it is not counted as a passing independent suite.

The equivalent player-facing D006 behavior passed in the staged app:

- Fresh Welcome exposed only `welcome.start-building`.
- `Space`, `3`, `B`, `V`, and `Command-/` remained quarantined while Welcome owned focus.
- Pointer dismissal transferred focus directly to the real `SKView` without a sacrificial map click.
- Map-focused `Space` subsequently controlled simulation as advertised.

The live sustained-session journey, exact schema-1 save, exact digest load, paused resume, and retained accessibility trees provided direct coverage of the risky path that the independent XCTest host could not complete.

Final documentation validation requires `git diff --check`, explicit-path staging, and clean status after commit.
