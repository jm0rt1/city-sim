# CONTRACT-009: Durable strategy recovery resolution

**Status:** Approved

**Date:** July 22, 2026

**Owner:** Integration, implemented first by gameplay and adopted by simulation platform

## Player problem

The current strategy story remembers Commercial versus Industrial and its phase, but does not retain which recovery the player actually earned. Tax relief and public-realm investment collapse into one Commercial completion; utility expansion and green buffering collapse into one Industrial completion. This weakens consequence, replayability, save trust, analytics, and later world/UI presentation.

## Approved contract

Add one `Codable`, `Equatable`, `Sendable` enum with exactly four values:

- Commercial tax relief
- Commercial public-realm investment
- Industrial utility expansion
- Industrial green buffer

Add one optional recovery-resolution field to `CityStrategyProgression`. Missing legacy data decodes as `nil`. The simulation captures the first qualifying resolution at the governed daily setback/recovery boundary, never rewrites it from later city changes, and uses it for distinct payoff consequences and typed analytics.

## Boundaries

- No save schema identifier bump is authorized.
- No UI command, renderer inference, message-prose parsing, or parallel progression owner is authorized.
- Gameplay owns enum/model introduction, qualification rules, balance, messages, and analytics.
- Simulation platform subsequently owns legacy decoding evidence, fingerprints, fixtures, replay, undo, recovery, snapshots, and measured persistence consequences.
- UI and rendering may consume the typed value only after integration accepts both implementations.

## Compatibility and rollback

Legacy saves without the field must load with `nil`; pre-resolution states remain valid. New saves may contain one additive optional key. Rollback is removal of the optional field and resolution-dependent consequences; existing schema identifiers remain unchanged. Contract tests must cover missing-field decode, all four round trips, first-choice monotonicity, undo exactness, save/replay equality, and deterministic payoff.
