# CONTRACT-015: Durable post-Charter progression

**Status:** Approved for PLAY-064

**Date:** July 25, 2026

**Owner:** Integration

## Player outcome

The Town Charter opens a strategy-specific second act instead of ending the
game. A player who survives a warned regional pressure, makes a recovery, and
sustains a healthy growing city can earn one durable Regional Capital
recognition.

## Approved contract

1. Add one optional `secondAct: CitySecondActProgression?` field to the
   gameplay-owned `CityProgressionState`.
2. `CitySecondActProgression` is `Codable`, `Equatable`, and `Sendable` and
   contains only:
   - a typed phase;
   - the next scheduled tick when a warned phase is pending;
   - consecutive qualifying daily checks; and
   - the one-time Regional Capital awarded flag.
3. The typed phase may represent mandate, warned pressure, recovery,
   qualification, and completion. The already durable committed strategy and
   recovery resolution determine Commercial-versus-Industrial narrative and
   standards; do not duplicate those choices.
4. Missing `secondAct` decodes as `nil`. New cities leave it `nil` until the
   Town Charter is awarded. No save schema identifier, filename, package,
   migration, command, or `SaveGameService` change is authorized.
5. Initialization, phase changes, and qualification occur on deterministic
   simulation boundaries. Every adverse outcome is warned at least one
   existing strategy interval before it applies.
6. Qualification requires consecutive daily checks after recovery. A failed
   standard resets only the qualifying counter. Regional Capital is awarded
   exactly once and is never revoked.
7. The existing objective and message mappings may switch from the completed
   Charter chapter to the second act and route existing messages to current
   overview, objective, or diagnostic surfaces. No new public store type,
   view architecture, or command is authorized.
8. Existing undo snapshots restore the exact second-act value. Canonical
   fingerprinting, save/load, backup recovery, and replay include the additive
   state naturally and must remain deterministic.

## Required proof

- legacy payloads with no `secondAct` decode and continue exactly;
- new, active, recovered, qualifying, and completed states round-trip;
- no second act starts before the Charter;
- both strategies receive distinct warned pressure, recovery, standards, and
  payoff without one becoming a dominant trivial route;
- transient metric spikes cannot advance a daily qualification counter;
- failed standards reset the counter and later recovery succeeds;
- recognition and its message occur once only;
- undo, save/relaunch/load, backup recovery, and deterministic continuation
  preserve exact state; and
- objectives/messages tell the current requirement and a concrete remedy.

## Rejected expansion

This contract does not authorize policies, a technology tree, new currencies,
an event bus, renderer-owned rules, UI-only progression, schema migration,
audio, network state, or Industrial L2–L4 production selection.
