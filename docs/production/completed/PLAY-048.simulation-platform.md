# PLAY-048 Completion — Believable Starter District Runtime Trust

- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Status:** ready for integration
- **Authority:** `e3ba50cd478f185265c9ddaad1e319ddb9475942`
- **Gameplay product:** `a0ce861f7b7b5f5acbed5db63f44c18981c7f140`
- **Gameplay evidence:** `274d3717ebb4b148a9af79143dc4327c12a3e5ad`
- **Gameplay completion:** `f84c1bfd73d8aa01badef4064cb1b1b84a826bbe`
- **Platform gameplay merge:** `461d39f5dd4fec253b261efcdb2cea5259b7ef07`
- **Platform fixture/fingerprint adoption:** `29cfc272ad74ecd4de741ffe6903e09fc952d875`
- **Platform drift evidence:** `60bf0c066cd7a5d75e399b518ae697fbd73690eb`
- **World topology product:** `a1e589e68783e25dc5788b055b3b9e786acb4b69`
- **World fresh-start evidence:** `9791621c7f3a8109500d2c8567e7b2db8fa4d9b7`
- **World final candidate:** `002ed20a5419ffcdaee7adb8e7e329bff781f786`
- **Combined closure evidence:** `4a9b6b3370b048ec99b98d79a45e6a11f9b73ac9`
- **Completion-record commit:** reported in the platform handoff

## Outcome

The richer authoritative New Arcadia starter district remains exact across
save/load, backup recovery, uninterrupted simulation, typed-command replay,
undo, grouped speeds, immutable presentation/spatial snapshots, all eight
production story moments, terminal victory, legacy compatibility, and the
dense performance fixture.

The platform adopted rather than redesigned PLAY-016. Current version-1
fingerprints and test-owned schema-1 story resources changed because the
authoritative root now contains 32 connected road cells, the accepted opening
treasury/message, and a relocated water source. Every changed digest is
documented in
`docs/production/evidence/PLAY-048/29cfc27/ADOPTION-CHECKPOINT.md`.

PLAY-024 then adopted the same topology in its renderer-owned camera, road,
terrain, ambient-life, and proof assumptions. The combined candidate passes
the platform and complete native gates without a parallel state authority or
runtime dependency on test resources.

## Changed surfaces

Frozen gameplay input merged without modification:

- `Native/CitySimNative/Sources/CitySimNative/Models/CityGameState.swift`
- gameplay-owned starter-district and scenario tests

Platform-owned adoption:

- `Native/CitySimNative/Tests/CitySimNativeTests/SessionPlatformTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/StrategyResolutionPlatformTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/TerminalVictoryPlatformTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/StoryStates/`

Platform evidence and disposition:

- `docs/production/evidence/PLAY-048/29cfc27/ADOPTION-CHECKPOINT.md`
- `docs/production/evidence/PLAY-048/002ed20/COMBINED-CLOSURE.md`
- `docs/production/claims/PLAY-048.simulation-platform.md`
- `docs/production/completed/PLAY-048.simulation-platform.md`

The resume merged exact world final `002ed20` normally and made no new product
edit. No gameplay rule, balance, message, HUD, command, save service, schema,
fingerprint algorithm/version, authentic legacy input, build script, or
legacy Python file changed in the platform adoption.

## Deterministic identities and fixture corpus

The adopted current fingerprints include:

- explicit seed-42 opening:
  `28b567b4e0da5302aeb28d81f3644bb6c07c44005b70d4f3dce146494a4ce1e5`;
- current nil-progression opening:
  `0e966e432ec6eff89e9a3785f2d083d74ccb4a32d6155a55e54eb64de788a888`;
- industrial/commercial tick-840:
  `29c10ada386a509c5c88db8d6390f94bb3c048da220f07cd04707151990102e1`
  and
  `7484cc20bb484b8c2b039341017a35cf302d98e33102f308718896a7d1bc17b2`;
- industrial/commercial tick-844 victory:
  `b79feac6f0f9de85201f4605de76d97401361e5cb3140ac11e86811c903a5d16`
  and
  `663f1f4b32660ba8e478e1f75edc9e599464530e2494c26f743d35dfde83ba12`;
- dense Wave 006 fixture:
  `113cce93fcbef4327d3e39665690dbf2fc6613683db6e1d362af8fa99c88b296`.

The eight-state story manifest SHA-256 is
`3614c6f7cd6eeed473c499f05a29c122aa92858744a717cc2e34bdb98f72fef0`.
Two new explicit exports, each already guarded by two internal corpus builds,
were byte-identical to one another and to every committed story resource.

Authentic inputs retain their original SHA-256 values:

- schema 0:
  `28c41c2a8c44adc0de49110ebb05ba0952f9deb4f9cb59c3f10035e7a925e908`;
- schema 1:
  `56ea7704735540d2a573aea7d96575d34d363e3583b5c90bb81ceb8b620e01b9`.

Save schema remains 1 and fingerprint version remains 1. No migration or
load-time mutation was introduced.

## Persistence, replay, undo, and snapshots

The focused matrix proves:

- schema-1 primary save/load preserves exact state and digest;
- authentic schema-0/schema-1 bytes decode and continue without regeneration;
- corrupt primary bytes are preserved and a validated last-known-good backup
  is returned with explicit recovery identity;
- interrupted primary replacement leaves the known-good session readable;
- backup-only load pauses, clears undo, retains backup bytes, and continues to
  the exact uninterrupted state;
- typed-command replay, save/resume, and all non-paused speed groupings produce
  the same logical outcome and version-1 digest;
- undo restores the exact pre-command authoritative state and fingerprint;
- immutable `CityPresentationSnapshot`, analytics, and spatial samples retain
  exact values after the source/store advances;
- all four recovery routes retain exact resolution identity through completion
  and tick-844 terminal victory;
- post-victory commands and simulation steps reject or remain immutable;
- legacy awarded-playing state normalizes at tick 4 rather than during load.

## Validation

- Focused platform matrix: 42/42 passed in 25.248 seconds.
- Independent explicit fixture writers: 1/1 passed in 3.068 seconds and
  1/1 passed in 3.072 seconds.
- Fixture-root and committed-resource `diff -ru`: no differences.
- Complete native suite: 199/199 passed in 92.923 seconds.
- `WorldRenderingTests`: 41/41 passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed for every platform commit.
- `bash -n script/build_and_run.sh`: passed.
- `bash -n script/persistence_relaunch_gate.sh`: passed.
- Exact staged `./script/build_and_run.sh --verify`: passed at product commit
  `002ed20a5419ffcdaee7adb8e7e329bff781f786`.

The staged candidate was:

- candidate `simulation-platform-w8bb1822a1e25`;
- bundle/preference domain
  `com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`;
- isolated data root
  `dist/test-data/simulation-platform-w8bb1822a1e25`;
- manifest
  `dist/manifests/simulation-platform-w8bb1822a1e25.manifest`;
- PID `64151`, confirmed alive at the exact staged executable;
- manifest status `verified-running`.

No separate platform UI behavior was introduced. PLAY-024 retains the exact
fresh-start default/compact, pointer, keyboard, placement, selection, overlay,
and reduced-motion evidence for the merged renderer product.

## Budgets

From the complete 199-test run:

- corpus generation: 1,516.029 ms and 1,517.339 ms;
- story envelopes: 131,964–133,231 bytes;
- story fingerprints: 1.145–1.247 ms;
- immutable story snapshots: 2.212–2.403 ms;
- story saves: 9.062–9.561 ms;
- story loads: 2.809–2.967 ms;
- dense simulation: 41.397 ms;
- dense fingerprint/snapshot/save/load:
  1.199 / 2.459 / 6.103 / 2.919 ms;
- dense envelope: 136,335 bytes;
- retained spatial samples: 46,080 bytes;
- spatial derivation: 1.152 ms average, 1.220 ms maximum;
- spatial diff: 0.102 ms;
- load availability: 2.086–2.179 ms for 1,000 checks and exactly 2,000
  existence probes per case.

All remain below the existing 5,000 ms dense/corpus, 500 ms
fingerprint/snapshot, 1,500 ms save/load, 2 MB envelope, 128 KiB retained
spatial, and 100 ms availability ceilings.

## Limitations and integration notes

The deterministic fixtures provide evidence setup; they do not replace the
independent no-coaching PLAY-053 player journey or allow the platform lane to
self-score visual quality.

Integration may merge the final platform completion candidate as one
already-combined history. Its ancestry contains exact PLAY-016 product,
PLAY-048 adoption/evidence, and PLAY-024 topology/evidence commits. No schema
migration, fixture consumer migration, or additional merge-order repair is
required.

Rollback may remove the PLAY-016/048/024 combined history and return to the
published Wave 006 authority. Authentic schema-0/schema-1 saves remain readable
because no persisted version or loader behavior changed.
