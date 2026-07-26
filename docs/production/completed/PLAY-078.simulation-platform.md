# PLAY-078 Completion — Starter-Town Platform Adoption

- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Status:** platform adoption ready for integration; renderer adoption remains external
- **Published authority:** `e6ba5ef7018030dcb3419b79ec19104a1c70e8e2`
- **Frozen gameplay source:** `de6f477ca1a21d9dc9e825de0c7eba18055e3b7b`
- **Unmodified local gameplay commit:** `85b8963193fde123be6e3e9321860c19aa61969c`
- **Platform adoption:** `05c1291866d047cfc995c82fb69a465210561119`
- **Fixture/test adoption:** `30bbf2fefea4868b65fb9fa5a280873912d7b525`
- **Evidence:** `eda052b915464e40c7770c7d0816fabc2887bac8`
- **Evidence identity correction:** `fc58f1984bbf00d958512bcacd78848e5cade88b`
- **Completion disposition:** this commit

## Outcome

PLAY-078 adopts the accepted PLAY-076 starter town into deterministic platform
truth without rewriting history. The gameplay input remains a distinct,
unmodified commit. Platform-owned commands use the approved row-major
road-accessible coordinates, and current session, strategy, terminal, dense,
spatial diagnostic, and local-activity expectations now freeze the accepted
product.

StoryStates v1-v3 and VisibleCityStates v1-v2 remain byte-exact. Additive
StoryStates v4 contains twelve current story identities; additive
VisibleCityStates v3 contains fourteen current lifecycle identities across
both strategies.

Compact current corpus identities:

```text
StoryStates v4        cfbff099a9064f83cbf1a279987722191ec23acc1f03b915bba816169543003a
VisibleCityStates v3  9eed6405adc84b8bdf025bb2ac1365b327c8659bdbf0384bc6f172d6c9a2aace
```

Both corpora were generated in two independent temporary roots and compared
recursively with no byte difference.

## Compatibility

- Save schema remains 1.
- Fingerprint version and canonical algorithm remain 1.
- Authentic schema-0/schema-1 bytes remain unchanged.
- StoryStates v1-v3 and VisibleCityStates v1-v2 remain unchanged.
- Old saves continue to decode without load-time mutation.
- No model/Codable field, public snapshot shape, persisted presentation
  state, command type, package topology, build script, gameplay rule, UI,
  renderer, art, or legacy Python file changed in platform-owned commits.
- Rollback removes only the gameplay input commit, current platform
  expectations, and additive v4/v3 resources; it requires no player-data
  migration or repair.

## Validation

- Focused platform matrix: **54/54 passed** in 64.004 seconds.
- Complete non-renderer suite: **198/198 passed** in 173.504 seconds.
- Complete native inventory: **271 tests; 59 assertions failed in 13
  renderer-owned tests** in 212.406 seconds.
- Staged isolated `./script/build_and_run.sh --verify`: passed at
  `30bbf2fefea4868b65fb9fa5a280873912d7b525`.
- `git diff --check` and `bash -n script/build_and_run.sh`: passed.
- Primary save/load, corrupt-primary backup recovery, paused load, cleared
  Undo, replay, grouped speed, save/resume, immutable snapshots, all four
  terminal routes, terminal rejection, historical hashes, and existing
  time/size/memory budgets: passed.

The exact commands, metrics, hashes, drift classification, staged identity,
and renderer failures are recorded in
`docs/production/evidence/PLAY-078/30bbf2f/VALIDATION.md`.

## External renderer handoff

PLAY-078 intentionally preserves thirteen renderer-owned failures covering old
32-road topology assumptions, old invalidation coordinates, old developed
bounds, contextual/camera scale goldens, and the unchanged 2.1 ms pulse
budget. Full-run telemetry measured 2.728 ms. No renderer expectation or
threshold was relaxed or re-blessed.

The simulation-platform candidate is ready for integration review once the
renderer owner adopts or corrects those contracts on the combined product.
