# PLAY-012 Platform Fingerprint Companion

**Status:** Ready for integration review

**Integration authority base:** `cbcc6fd2b23cb08fc0b937ae1f236c630d499474`

**Exact gameplay candidate:** `64587923b6d59fb585043aee97478b5276f968d2`

**Validation merge:** `8cb28272efaf689b0bd61e60d68b44dc46f8cbd7` — `PLAY-012: Merge gameplay candidate for platform validation`

**Fixture commit:** `dff713566e8752ae27e3a489feb991173b77744d` — `PLAY-012: Freeze three-act session fingerprints`

## Invariant and scope

PLAY-012 intentionally changes persisted treasury and message history through its authored three-act strategy outcomes. Canonical fingerprint version 1 must therefore change for the affected strategy and dense checkpoints even though fingerprint encoding, save schema, command arrays, seeds, tick boundaries, and fixture generators remain unchanged.

The platform companion modifies only `SessionPlatformTests.swift`. It freezes the accepted gameplay semantics under consistent Wave Three / V4 fixture identities. No gameplay rule, public model, snapshot field, save service, schema identifier, fingerprint implementation/version, renderer, UI, package, script, or legacy Python file changes.

## Independent reproduction before repair

Against the exact clean gameplay candidate and the unchanged prior platform expectations, `SessionPlatformTests` produced exactly 9 expected failures and no unexpected failures:

- industrial treasury: actual `$56,433.20`, prior `$49,433.20`;
- commercial treasury: actual `$58,993.26`, prior `$58,393.26`;
- two stale Day 41 message-detail assertions;
- industrial digest direct and repeated-set assertions;
- commercial digest direct and repeated-set assertions;
- dense digest assertion.

The diagnostic checkpoint output independently matched integration's reproduced values before any platform expectation changed.

## Frozen Wave Three checkpoints

### Industrial strategy

- tick 896, `.playing`;
- treasury `$56,433.20`;
- population 524, jobs 366;
- happiness 54.500, approval 100;
- power 468 / 600, water 411 / 540;
- projected balance `$310.25`, utility reserve 0.220;
- Town Charter awarded after 12 qualifying days;
- authored messages include `Choose a Growth Engine`, `Freight Contract Watch` with `by Day 25`, `Freight Load Forecast`, and `Industrial Load Absorbed`;
- fingerprint `f8ecd67582597fc859ddc91c9de8b5b3842f702581161588d671ae06ec839e13`.

### Commercial strategy

- tick 888, `.playing`;
- treasury `$58,993.26`;
- population 522, jobs 350;
- happiness 55.349, approval 100;
- power 441 / 600, water 395 / 540;
- projected balance `$403.49`, utility reserve 0.265;
- Town Charter awarded after 12 qualifying days;
- authored messages include `Choose a Growth Engine`, `Main Street Crossroads` with `by Day 25`, and `Chain Store Rumor`;
- fingerprint `65ce47a635ad3305afcc8871bafb0df1ba0cf245cca0548e1873c87224edb223`.

### Dense persisted fixture

The unchanged dense generator is now named `dense-24x24-terminal-wave3-v4`:

- 400 step attempts, terminal tick 44 / `.lost`;
- treasury `$6,602,062.55`, population 46,459, jobs 32,739;
- schema-1 envelope 136,590 bytes;
- fingerprint `ce5d912d97702c5a0a3b84149e432219fe9faca54dcb9b2fa98e0b5ba54f8ef7`.

The prior `dense-24x24-terminal-wave2-v3` digest `d18afceb9c8ccc09eaf54d7316abc960c6b560baa1bc7d92fa6416c9776556d8` remains valid historical evidence for accepted PLAY-011 semantics. It is not the PLAY-012 golden state.

## Repeated determinism and compatibility

Two post-repair focused runs passed 14/14 `SessionPlatformTests` in 2.266 and 2.249 seconds. A third reproduction inside the full suite passed 14/14 in 2.176 seconds. Every run emitted the exact industrial, commercial, and dense digests above. The strategy test additionally calculates each strategy fingerprint five times in-process and requires a one-value set.

The complete native suite passed 103/103 in 232.737 seconds. It includes:

- 19/19 gameplay tests, including Day 25 warning cadence, complications, avoidable setbacks, recoveries, and two viable horizons;
- schema-0 and schema-1 load compatibility;
- canonical nil-progression distinction;
- corrupt-primary backup recovery and interrupted-write safety;
- exact whole-state undo and equivalent speed grouping;
- immutable spatial maps, exact save/load/undo derivation, and transient-event suppression;
- command/onboarding/focus, responsive UI, and renderer suites.

No migration is required. Existing saves continue to decode under schema 1; only states that contain the new accepted treasury/message outcomes naturally hash to new version-1 digests.

## Measured full-suite diagnostics

- dense simulation: 42.363 ms;
- fingerprint: 1.209 ms;
- schema-1 save: 6.100 ms;
- validated load: 2.925 ms;
- envelope size: 136,590 bytes;
- spatial derivation: 1.220 ms average, 1.382 ms maximum;
- spatial transition diff: 0.127 ms;
- unchanged renderer pulses: 5,760 tile reuses, 0 updates, 1.698 ms average;
- 30-minute-equivalent renderer soak: 4,286 pulses, 0.9075 ms average, stable node/drawable/action counts.

`git diff --check` and `bash -n script/build_and_run.sh` passed.

## Exact staged candidate

`./script/build_and_run.sh --verify` built and launched exact fixture commit `dff713566e8752ae27e3a489feb991173b77744d`:

- candidate `simulation-platform-w8bb1822a1e25`;
- bundle/preference domain `com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`;
- isolated data root `dist/test-data/simulation-platform-w8bb1822a1e25`;
- staged bundle `dist/CitySim-simulation-platform-w8bb1822a1e25.app`;
- exact executable `dist/CitySim-simulation-platform-w8bb1822a1e25.app/Contents/MacOS/CitySimNative-w8bb1822a1e25`;
- PID 43867, confirmed alive at that exact executable after launch.

The platform companion claims staged runtime identity and automated compatibility only. PLAY-012's retained gameplay evidence owns its authored journey; PLAY-051 still owns independent no-coaching acceptance.

## Adoption and rollback

Integration should take the exact PLAY-012 gameplay candidate, this validation merge lineage, the fixture commit, and the companion record in order before downstream PLAY-022/PLAY-032 adoption. The merge commit preserves both accepted authority and gameplay ancestry without rewriting submitted commits.

Rollback removes the gameplay candidate plus this single test expectation commit. No persisted data repair, schema migration, or fingerprint-version rollback is required. The worker has not pushed or integrated to `master`.
