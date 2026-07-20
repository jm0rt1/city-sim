# CONTRACT-003: Deterministic session, save, recovery, and presentation boundary

**Status:** Approved in vertical-slice scope

**Date:** July 19, 2026

**Owner:** Integration for PLAY-040

## Player outcome

The accepted New Arcadia session can be fingerprinted, saved, resumed, undone, and recovered from a corrupt latest write without silently changing the city. Renderer and UI consumers receive immutable value snapshots rather than inventing or retaining their own simulation truth.

## Approved contract

1. Add a versioned canonical state fingerprint for `CityGameState`. Version 1 includes every persisted authoritative field in declaration order, including the distinction between `progression == nil` and an explicit zero-valued progression. It excludes speed, selection, open panels, focus, camera, preferences, and other UI-only state.
2. Use sorted-key JSON from an explicitly configured encoder as the canonical bytes and SHA-256 as the lowercase digest. Tests freeze representative digests; changing canonical bytes requires a new fingerprint version and integration decision.
3. Add a versioned save envelope containing only schema version, fingerprint version, authoritative `CityGameState`, and its digest. New saves use schema 1. Loading must continue to accept the existing bare `CityGameState` JSON as legacy schema 0.
4. `SaveGameService` accepts an injected root URL, with production defaulting to the current `Application Support/CitySimNative` directory. A test-only `CITYSIM_DATA_ROOT` override may select an isolated root when explicitly set; it must never change production defaults or read outside that root.
5. Saving writes and validates a temporary candidate, preserves the last known-good save as a backup, then atomically replaces the primary. Loading validates schema and digest, tries primary first, then the backup, preserves corrupt originals for diagnosis, and reports whether recovery occurred so the player receives truthful feedback.
6. The immutable presentation boundary is a value-owned `CityPresentationSnapshot` containing the authoritative `CityGameState` plus its fingerprint. It may expose derived, read-only analytics computed from that state. It must not contain SwiftUI/AppKit/SpriteKit objects, closures, mutable caches, or a second authority.
7. Existing construction undo continues to capture the exact whole `CityGameState` before a successful state-changing action. UI state, speed, and camera are not added to the undo record in this wave. Load clears undo history as it does today.
8. A narrow `CitySimulationCommand` may describe deterministic state-changing simulation intent needed by the PLAY-010 fixture (build, demolish, tax-rate change, and advance one daily boundary). It must not include UI commands, speed, panels, focus, camera, or raw arbitrary mutation.

## Required behavior and tests

- Identical fixtures produce identical fingerprints across repeated runs and speed groupings that represent the same number of ticks.
- Nil progression and explicit zero progression have distinct version-1 digests; legacy nil normalizes only at the accepted daily boundary.
- Schema-0 bare saves load unchanged; schema-1 round trips exactly.
- Digest mismatch rejects a primary file, preserves it, and recovers the validated backup with explicit feedback.
- Interrupted/failed writes leave the last known-good primary or backup readable.
- Injected roots isolate two simultaneous staged sessions; production default location remains unchanged.
- Undo restores the exact pre-command authoritative state and digest.
- Presentation snapshots are immutable values and do not change when the store later advances.
- Full native suite and measured vertical-slice save/fingerprint timing pass.

## Lane effects and adoption order

- **PLAY-040** implements fingerprint, save envelope/recovery, injection, snapshot, fixture commands, tests, and diagnostics as separate coherent commits.
- **PLAY-010** supplies the accepted scenario invariants and does not redesign progression.
- **PLAY-020** may consume approved snapshot values but may not require unapproved spatial analytics in this slice.
- **PLAY-030** may surface recovery feedback and consume snapshots; it does not own persistence behavior.
- **PLAY-050** uses isolated roots and frozen fingerprints for independent save/resume and multi-instance testing.

## Deferred expansion

No cloud saves, multiple user-facing save slots, cross-device migration, general replay file format, background simulation, arbitrary command scripting, or mature-city performance claim is authorized.

## Rollback

The loader retains schema-0 compatibility. Reverting the schema-1 writer leaves legacy saves readable; schema-1 files remain preserved and must not be deleted during rollback.
