# CONTRACT-022: Durable storm-recovery ownership

**Status:** Approved for PLAY-085 repair

**Date:** July 30, 2026

**Owner:** Integration

## Player outcome

A Severe Storm visibly damages exact homes and sustained healthy operation
restores only that storm damage. Dismissing or overflowing the message feed,
pre-existing Residential wear, demolition, and later construction cannot
silently change which damage the recovery system owns.

## Approved contract

1. Add one optional `stormRecovery: CityStormRecoveryState?` field to
   gameplay-owned `CityGameState`.
2. `CityStormRecoveryState`, `CityStormRecoveryTarget`, and the typed
   active/recovered disposition are internal `Codable`, `Equatable`, and
   `Sendable` values in `CityGameState.swift`.
3. The state contains only:
   - the tick and post-roll seed of the latest damaging Severe Storm;
   - a row-major array of exact target coordinates and each target's remaining
     storm-owned condition damage; and
   - whether that recovery ledger is active or recovered.
4. A storm records the actual condition decrement after clamping, never the
   formula's nominal damage. Zero-delta or zero-target storms do not create or
   replace recovery authority.
5. A second damaging storm merges unresolved damage by coordinate, updates the
   latest event identity, and preserves deterministic row-major order. A new
   storm after a recovered ledger replaces it with one new active ledger.
6. Daily repair reads only the active ledger. Before applying repair, clamp
   each remaining amount to the current recoverable deficit so unrelated
   healing cannot cause over-restoration. Apply at most the daily rate, the
   remaining storm-owned amount, and the available condition headroom.
7. A target that is no longer a completed Residential lot is retired without
   healing. Recovery may never transfer to a demolished, rezoned, or later
   replacement building at the same coordinate.
8. When every retained target reaches zero remaining storm damage, set the
   ledger to recovered and emit `Storm Recovery Complete` once. Messages are
   presentation only and never create, continue, complete, or suppress
   recovery authority.
9. Missing legacy `stormRecovery` decodes as `nil`; new cities initialize it
   explicitly to `nil`. Synthesized optional encoding omits `nil`, preserving
   existing canonical fixture bytes and version-1 fingerprints for states
   without storm recovery.
10. Active and recovered ledgers participate in the existing version-1
    fingerprint, save/load, backup recovery, deterministic replay, snapshots,
    and Undo. No save schema identifier, fingerprint version, filename,
    `SaveGameService`, package, store, renderer, UI, command, fixture, or
    message-cap change is authorized.

## Required proof

- legacy JSON without `stormRecovery` decodes to `nil` and re-encodes with
  unchanged canonical bytes;
- new-city canonical bytes and all frozen fixtures remain unchanged;
- only exact recorded storm deltas are repaired and pre-existing Residential,
  Commercial, and Industrial scars remain unchanged;
- message dismissal and at least twelve newer messages cannot stop or restart
  recovery;
- a demolished or non-Residential target is retired and no replacement is
  healed;
- a second storm merges only actual new damage in stable row-major order;
- zero-target and zero-delta storms do not fabricate recovery completion;
- condition never exceeds `1`, and unrelated healing cannot leave an active
  ledger stuck or cause over-restoration;
- recovery completion and its message occur once;
- active and recovered states round-trip through save/load and backup recovery;
- replay, fingerprint repetition, snapshots, and Undo remain exact; and
- all existing storm schedule, title, seed, treasury, happiness, strategy,
  progression, and four-route tests remain green.

## Rejected expansion

This contract does not authorize generic building repair, a message-derived
migration, durable UI state, renderer logic, new commands, new save or
fingerprint versions, event cadence changes, fixture rewrites, or recovery of
damage whose source was not recorded.
