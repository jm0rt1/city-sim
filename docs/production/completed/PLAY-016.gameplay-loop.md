# PLAY-016 completion

- **Title:** Author a believable starter district
- **Lane:** Gameplay loop
- **Branch:** `codex/citysim-gameplay-loop`
- **Published authority:** `e3ba50cd478f185265c9ddaad1e319ddb9475942`
- **Authority merge:** `f09fdd911ae893df532fa7f485e63b145a311009`
- **Ordered task commits:**
  1. `a0ce861f7b7b5f5acbed5db63f44c18981c7f140` — authoritative two-block starter district, opening balance, and deterministic regression coverage;
  2. `274d3717ebb4b148a9af79143dc4327c12a3e5ad` — exact staged fresh-start evidence and downstream adoption disposition.
- **Status:** Frozen for PLAY-048 adoption and integration review

## Player-visible outcome

New Arcadia now starts with a connected, occupied two-block district instead
of one road cross. The authoritative state contains 32 connected road cells
with no dead ends, eight road-adjacent occupied lots across both blocks, and
46 valid Commercial or Industrial growth frontages.

The opening remains consequential: it runs a `-$90.20/cycle` deficit with 54
power and 48 water spare. Either first eligible zone commits the corresponding
strategy at the next daily boundary. Commercial and Industrial remain
numerically distinct, all four recovery identities remain viable, and all
four deterministic routes still earn the Town Charter at exact tick 844.

## Files changed

- `Native/CitySimNative/Sources/CitySimNative/Models/CityGameState.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CitySimulationTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/GameplayLoopTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/StarterDistrictTests.swift`
- `docs/production/evidence/PLAY-016/IMPLEMENTATION-CHECKPOINT.md`
- three retained staged JPEGs under `docs/production/evidence/PLAY-016/`
- `docs/production/completed/PLAY-016.gameplay-loop.md`

## Validation and proof

- Starter-district plus gameplay suites: **36/36 passed**.
- Ordinary simulation plus spatial suites: **45/45 passed**.
- Exact topology: 32 connected roads, no road dead ends, eight
  road-adjacent occupied lots across two blocks, and 46 valid growth
  frontages.
- Determinism: repeated seed identity, JSON round trip, and repeated
  version-one fingerprint identity passed without a schema or fingerprint
  version change.
- Recovery/victory: retained Day-25 late choice, rejected placement,
  ignored-recovery compatibility, Undo, both strategies, four recoveries,
  and exact tick-844 Charter victory passed.
- Complete worker suite: **199 tests executed; 103 downstream pre-adoption
  assertions failed; 0 unexpected failures**. Failures are confined to
  PLAY-047/platform corpus and digest adoption assigned to PLAY-048 and
  renderer framing/reference adoption assigned to PLAY-024.
- Build-script syntax, exact staged bundle verification, resource-bundle
  presence, and `git diff --check`: passed.
- Exact staged candidate:
  `a0ce861f7b7b5f5acbed5db63f44c18981c7f140`.
- Real fresh Commercial opening: visible fork, keyboard-selected valid
  frontage, successful construction, and authoritative strategy commitment
  in **49 seconds**, from Day 6 to Day 34 while running at 1x.
- Full evidence:
  `docs/production/evidence/PLAY-016/IMPLEMENTATION-CHECKPOINT.md`.

## Compatibility and boundaries

- `CityGameState` remains deterministic, `Codable`, `Equatable`, and
  `Sendable`; no persisted shape was added.
- Save schema and fingerprint version remain unchanged.
- Legacy saves, commands, public store contracts, SpriteKit, SwiftUI,
  platform fixture/digest sources, and build scripts are unchanged.
- The richer road network increases upkeep. The opening reserve was raised
  to `$32,000` while preserving a larger operating deficit and the accepted
  recoverable pressure.
- PLAY-048 owns fixture, fingerprint, replay, snapshot, and production story
  adoption from the frozen product commit.
- PLAY-024 owns renderer framing/reference adoption and must consume the
  authoritative state without decorative roads or occupied parcels.

## Known live-evidence limitation

This lane operated one exact staged Commercial opening. Industrial, all four
complete recovery stories, save/relaunch, and Charter victory were proved
deterministically but were not re-operated live for PLAY-016. Final
integrated both-strategy, all-recovery, persistence, and 20-minute acceptance
remains with integration and quality after PLAY-048 and PLAY-024 adoption.
