# CONTRACT-001: Town Charter progression persistence

**Status:** Approved with required adjustments

**Date:** July 19, 2026

**Proposer:** PLAY-010 gameplay loop

**Checkpoint:** `d8c20ff6a27d672cf72f089f1f5f1aa04f906201`

## Player outcome

Town Charter becomes a durable, one-time milestone that requires sustained healthy city conditions instead of completing from a transient metric spike. Existing quicksaves remain readable.

## Approved contract

1. Add `CityProgressionState`, conforming to `Codable`, `Equatable`, and `Sendable`, in the gameplay model surface. Its only fields are `townCharterQualifyingCycles: Int` and `townCharterAwarded: Bool`.
2. Add `var progression: CityProgressionState?` to `CityGameState`. `newCity` initializes it explicitly. Decoding a legacy payload with no key yields `nil`; no `SaveGameService`, save filename, schema identifier, package, or migration change is authorized.
3. On the next daily simulation boundary, `nil` normalizes to zero/not-awarded. Qualification is evaluated only at daily boundaries.
4. The persistence window is **12 consecutive qualifying daily checks**. A failed standard resets the counter to zero. Once awarded, the flag remains true and no later failure revokes it.
5. Award exactly once. Emit one existing `CityMessage` with the stable title `Town Charter Awarded` and player-facing detail that states the sustained achievement. `CityMessage` remains the existing title-routed presentation mechanism; this decision does not characterize it as a typed domain-event contract.
6. `CityGameStore.objectives`, `openObjective`, and `openMessage` may receive the smallest mapping changes needed to show readiness, persistence progress, the durable awarded state, and route the award to the existing overview/objective context. No new public store type, command, view architecture, or renderer contract is authorized.
7. Undo must restore the exact progression value captured by the existing state snapshot. No special-case progression rewind logic is allowed.

## Required tests

- Legacy JSON without `progression` decodes successfully and normalizes on a daily boundary.
- New-state and awarded-state round trips preserve exact progression values.
- A qualifying run shorter than 12 daily checks does not award.
- Any failed check resets the counter; a later 12-check run can award.
- Award and award message occur once only.
- Existing undo restores exact progression state.
- Objective opening and `Town Charter Awarded` message routing reach the intended existing context.
- Full native suite remains green.

## Lane effects and adoption order

- **PLAY-010:** Implements the contract after checkpoint `d8c20ff`; keep the contract change in a separate coherent commit.
- **PLAY-040:** Must include the optional field in future authoritative state hashing/versioning and preserve missing-field compatibility. It must not redesign this field before PLAY-010 integration.
- **PLAY-030:** May later improve presentation but receives no new command or public store contract from this decision.
- **PLAY-020:** Continues on existing state. No renderer/snapshot field is approved here.

## Rejected expansion

This approval does not authorize a general typed event system, save-schema migration, new UI component, command change, renderer input, or unrelated progression framework.
