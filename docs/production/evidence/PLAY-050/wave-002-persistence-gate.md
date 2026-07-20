# PLAY-050 Wave 002 Fingerprint, Save, and Recovery Gate

**Status:** Frozen before Wave 002 candidate execution

**Authority:** `CONTRACT-003` at `efe23eeeaf0eec6c975dfead07fd8b8394f840e3`

This gate consumes candidate-supplied fixture IDs, schema field names, and frozen digest constants. PLAY-050 does not invent or update expected digests after seeing actual output. Any approved canonical-byte change requires a new fingerprint version and integration decision before retest.

## Canonical fingerprint assertions

1. Fingerprint version 1 includes every persisted authoritative `CityGameState` field in declaration order and excludes speed, selection, open panels, focus, camera, preferences, and other UI-only state.
2. Canonical bytes are produced by the explicitly configured sorted-key JSON encoder; the digest is lowercase SHA-256.
3. Repeated construction of the same fixture produces byte-identical canonical data and the accepted frozen digest.
4. Speed groupings that execute the same total ticks produce the same digest.
5. `progression == nil` and explicit zero progression produce different version-1 digests. Legacy nil remains nil through ticks 1–3 and changes only at the accepted tick-4 daily boundary.
6. A presentation snapshot records the authoritative value state and its matching digest. Later store mutation cannot change either captured value.

The candidate completion record must supply accepted expected digests for at least: fresh explicit-zero New Arcadia; decoded legacy-nil before tick 4; the same state after tick-4 normalization; partial Town Charter progress; awarded Town Charter; the pre-command undo checkpoint; both reference strategies at exactly tick 2,800 / Day 701; and any Wave 002 strategy-arc checkpoints integration requires.

## Schema and round-trip assertions

| Checkpoint | Required result |
| --- | --- |
| Legacy schema 0 | Existing bare `CityGameState` JSON loads unchanged, including nil progression semantics. |
| Schema 1 envelope | Contains only the candidate's approved schema version, fingerprint version, authoritative state, and digest fields; exact names/bytes are recorded. |
| Schema 1 round trip | Loaded authoritative state equals the saved state and recomputes to the stored digest. |
| Unknown schema/fingerprint | Rejected with truthful, actionable feedback; source bytes remain preserved. |
| Digest mismatch | Primary is rejected rather than partially loaded or silently normalized. |
| UI-only changes | Speed, panels, focus, camera, and preferences do not alter the state digest. |

## Isolated save/leave/resume journey

1. Preflight the exact candidate using `wave-002-candidate-manifest-template.md`; start with an empty lane-owned data root.
2. Reach a named partial-progression checkpoint and record the authoritative digest, day/tick, critical metrics, message count, and progression value.
3. Save through a visible player route. Success feedback may appear only after the candidate file validates and the primary/backup state is recorded.
4. Inventory and hash every file in the isolated root. No file may appear in the production Application Support location or another candidate root.
5. Leave by quitting the exact PID/bundle, then prove that the other isolation-control candidate remains alive.
6. Relaunch the exact bundle/root and load through a visible player route. The loaded simulation must be paused and safe to inspect.
7. Within one minute, the player identifies the active pressure, objective/progression, and next action without the previous session record.
8. The loaded authoritative state and digest equal the saved checkpoint exactly; UI-only launch state is not represented as authoritative persistence.

## Undo digest journey

At a named checkpoint, record digest A; perform one successful construction action through an approved route and record different digest B; invoke undo; require full authoritative equality and digest A. Undo must not claim success when unavailable, and load must clear undo history.

## Corrupt-primary recovery journey

All manipulation is confined to the manifest's isolated root.

1. Save known-good checkpoint A and record its primary digest/file hash.
2. Advance to distinct checkpoint B and save again, proving the last known-good generation is preserved as the candidate's backup.
3. Corrupt only the isolated primary using a recorded deterministic byte mutation; record corrupt file size and SHA-256 before launch.
4. Relaunch/load through the player route. The primary digest mismatch must be rejected, the validated backup must load exactly, and player feedback must explicitly state that recovery occurred.
5. Record the recovered authoritative digest and require equality with checkpoint A's accepted backup state, not checkpoint B or a fresh city.
6. Prove the corrupt original remains preserved for diagnosis with its pre-load corrupt hash or a documented preservation copy.
7. Prove a subsequent valid save remains possible and does not overwrite another candidate's root.

Automated coverage must separately prove interrupted/failed writes leave a valid primary or backup readable. A hands-on recovery screenshot without file hashes and authoritative digests is insufficient.

## Performance evidence

Record canonical-byte length, fingerprint latency, schema-1 save latency, primary-load latency, backup-recovery latency, and snapshot construction latency on the declared fixture. Report sample count, statistic used, build configuration, machine context, and any warm-cache limitation. No mature-city claim may be inferred from the vertical slice.

## Critical failures

Reject the candidate for a digest mismatch on an unchanged fixture; nil/zero collapse; schema-0 incompatibility; unversioned canonical-byte change; silent fallback; success feedback before a validated write/load; corrupt-original loss; backup state different from the declared known-good generation; undo digest mismatch; mutable snapshots; data-root escape; production-state access; cross-candidate leakage; ambiguous exact process; or required coaching to understand save/recovery outcome.
