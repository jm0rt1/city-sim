# PLAY-012 Completion — Simulation Platform Fixture Companion

- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Status:** ready-for-integration
- **Integration authority base:** `cbcc6fd2b23cb08fc0b937ae1f236c630d499474`
- **Gameplay candidate:** `64587923b6d59fb585043aee97478b5276f968d2`

## Outcome

The accepted three-act gameplay candidate now has authoritative, repeated version-1 session fingerprints and Wave Three fixture identities. Industrial and commercial routes retain different treasury outcomes and authored message histories while both remain deterministic, saveable, undo-safe, and compatible with the accepted spatial presentation contract.

## Ordered platform commits

1. `8cb28272efaf689b0bd61e60d68b44dc46f8cbd7` — `PLAY-012: Merge gameplay candidate for platform validation`
2. `dff713566e8752ae27e3a489feb991173b77744d` — `PLAY-012: Freeze three-act session fingerprints`
3. completion/evidence commit containing this record

## Exact platform-owned changes

- `Native/CitySimNative/Tests/CitySimNativeTests/SessionPlatformTests.swift`
- `docs/production/evidence/PLAY-040/PLAY-012-fingerprint-companion.md`
- `docs/production/completed/PLAY-012.simulation-platform-companion.md`

The merge also carries the exact submitted gameplay candidate without rewriting it. The platform-authored product diff is test-only.

## Frozen checkpoints

- Industrial: tick 896, treasury `$56,433.20`, Day 25 warning, required three-act messages, digest `f8ecd67582597fc859ddc91c9de8b5b3842f702581161588d671ae06ec839e13`.
- Commercial: tick 888, treasury `$58,993.26`, Day 25 warning, required three-act messages, digest `65ce47a635ad3305afcc8871bafb0df1ba0cf245cca0548e1873c87224edb223`.
- Dense `dense-24x24-terminal-wave3-v4`: tick 44 / `.lost`, digest `ce5d912d97702c5a0a3b84149e432219fe9faca54dcb9b2fa98e0b5ba54f8ef7`.

The previous Wave Two / V3 values remain historical PLAY-011 evidence only.

## Validation

- Unrepaired suite reproduced exactly 9 expected fixture failures.
- Repaired `SessionPlatformTests`: 14/14 passed twice in 2.266 and 2.249 seconds.
- Complete native suite: 103/103 passed in 232.737 seconds; its platform subset passed 14/14 a third time.
- Dense performance: simulation 42.363 ms, fingerprint 1.209 ms, save 6.100 ms, load 2.925 ms, 136,590 bytes.
- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- Exact `./script/build_and_run.sh --verify`: passed at `dff713566e8752ae27e3a489feb991173b77744d`; PID 43867 confirmed alive at the isolated staged executable.

The complete command, output, compatibility, performance, and staged identity evidence is retained at `docs/production/evidence/PLAY-040/PLAY-012-fingerprint-companion.md`.

## Compatibility, limitations, and adoption

No fingerprint algorithm/version, save schema/service, model, snapshot, renderer, UI, command, package, script, or legacy Python change is introduced by the platform companion. Existing schema-0/schema-1, corrupt-save recovery, exact undo, equivalent speed grouping, and spatial derivation tests remain green.

This record does not replace hands-on gameplay or independent quality acceptance. Integration should land it with the exact PLAY-012 gameplay candidate before PLAY-022 and PLAY-032 adoption. Rollback requires no player-data migration. No push or integration to `master` was performed.
