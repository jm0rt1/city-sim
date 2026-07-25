# PLAY-064 completion

- **Title:** Make the Town Charter the midpoint
- **Lane:** Gameplay loop
- **Branch:** `codex/citysim-gameplay-loop`
- **Published authority:** `0ed9f3a8ad28d6b29f734c97f3dd3111fd118cc6`
- **Ordered candidate commits:**
  1. `70efccfd30b6e2318998f02cb36a1cd37def9fe3` — durable
     strategy-specific Regional Capital product, mappings, and deterministic
     tests;
  2. `1241bf308e8888af4cd06685347c87108ed3a014` — legacy Charter
     completion analytics compatibility repair;
  3. `fdf0e6a9599c57c174c00ace6825f9553a27c752` — repaired-HEAD
     validation and staged Commercial journey evidence.
- **Status:** Frozen candidate for integration-controlled consumer adoption
  and independent playtest; not self-accepted

## Player-visible outcome

The permanent Town Charter now opens a warned Regional Capital second act
instead of ending the city. Commercial and Industrial cities receive
different pressure, recovery economics, qualifying standards, and payoff.
The existing first-act recovery identity remains consequential in the
second act. The city wins only after 12 consecutive governed daily checks;
one bad day resets the run without erasing the Charter or story.

Objectives and messages state the cause, timing, and exact remedy. Regional
recognition enters the existing terminal victory state once and remains
immutable through later simulation attempts.

## Changed surfaces

- `Native/CitySimNative/Sources/CitySimNative/Models/CityGameState.swift`
- `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulation.swift`
- `Native/CitySimNative/Sources/CitySimNative/Support/CityAnalytics.swift`
- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/GameplayLoopTests.swift`
- `docs/production/evidence/PLAY-064/IMPLEMENTATION-CHECKPOINT.md`
- `docs/production/completed/PLAY-064.gameplay-loop.md`

## Validation

- Focused gameplay: **36/36 passed** at repaired product HEAD.
- Both strategies and all four durable recovery identities: Regional
  recognition or explicit terminal failure by tick 2,800.
- Daily-only qualification, failed-day reset, recovery, exact-once award and
  message, terminal immutability: passed.
- Legacy nil decode, awarded legacy next-boundary normalization, all-phase
  model round trip, save/load/backup/replay, fingerprint identity, exact
  Undo, and objective/message routing: passed.
- Exact repaired app build and staging verification: passed.
- Real repaired-HEAD pointer/keyboard Commercial route: rejected placement,
  warned first-act choice, durable tax recovery, Charter midpoint, warned
  Regional pressure, named remedy, and terminal recognition at visible Day
  262 with 561 residents, `$24,529`, `+$200/cycle`, 68% happiness, and full
  utilities.
- Full worker suite: 231 tests executed; 121 integration-controlled
  pre-adoption assertions failed, 13 unexpected. Gameplay remained 36/36
  green.
- Full retained details:
  `docs/production/evidence/PLAY-064/IMPLEMENTATION-CHECKPOINT.md`.

## Contract impact

Implementation follows `CONTRACT-015` without expansion:

- optional `CitySecondActProgression?` only;
- typed phase, optional next scheduled tick, consecutive qualifying daily
  checks, and permanent recognition bit only;
- no schema identifier, migration, filename, package, command, public store
  type, general event system, renderer contract, SpriteKit, SwiftUI
  composition, or legacy Python change;
- missing legacy key decodes nil and causes no load-time mutation;
- legacy awarded saves preserve their permanent Charter terminal semantics
  and truthful completion analytics.

## Integration handoff

Integration-controlled consumers must adopt the new post-Charter
authoritative state:

- PLAY-047 story corpus and terminal/session/spatial fingerprints currently
  freeze Charter `completed/won` at tick 844;
- the notice catalog needs explicit dispositions for the four new Regional
  warning/pressure titles;
- the terminal overlay currently renders the Regional Capital gameplay win
  as `Town Charter Secured` with the first-act Charter story.

This lane did not modify those fixture, UI, command, renderer, or
presentation surfaces. Industrial and all four recovery identities are
deterministically proven; a separate live Industrial run and integrated
both-strategy no-coaching presentation remain independent quality gates.
