# PLAY-042 Beauty-Baseline Closure Evidence

- **Accepted baseline:** `9f38efec4877ab7c3f0d77bf3bd4e36b56e3c034`
- **Platform merge:** `970d0f8a3ad24144906760abcf1dbe184f0c3904`
- **Date:** July 23, 2026
- **Branch:** `codex/citysim-simulation-platform`
- **Disposition:** existing platform adoption remains trustworthy; no product or
  test delta required

## Synchronization and accepted ancestry

The clean platform branch fetched `origin` and normally merged the exact
accepted beauty baseline. The sole conflict was
`docs/production/claims/PLAY-047.simulation-platform.md`; it was resolved
verbatim to `origin/master`, preserving the accepted status. There was no
product or other conflict.

After merge:

- `origin/master` is the second parent and an ancestor of `970d0f8`;
- divergence is 0 behind / 13 ahead;
- `git diff --exit-code origin/master --` passes, proving exact tracked-tree
  parity;
- the worktree is clean.

The accepted commits are all ancestors:

| Contract | Accepted commits |
|---|---|
| PLAY-042 | `0daaf1399256d30e667a123b4a743a8692f30452`, `e0114c18c77cc76460b84fdf1f61317bb92adb79`, `40ed343fa6f13aa6b147adb6a2eac1f9d6992bff` |
| PLAY-044 | `705fc5179cf75c386e0dc5817b24d80cfc1bb20d`, `75398a3b8f32432f61838e7735b59b909930c0c5`, `7be0e6b27384c32f5f761287fbd8828320af640f` |
| PLAY-046 | `e63672480136ba7f146cd25936de59ab166478da`, `64a360c10debd9504ebc6a58fcb5ec4fd46adad5`, `6d7df1efa73b4fbcb3e6acf992a80adbaac148ec` |
| PLAY-047 | `0706dbe8e50bf98e60eb8ba1c503c2027e1f2d87`, `ce450a38134c1146f60d05664ee58e98b363f898`, `57c75b7d14a5d1c188ebe3e4572cf64a7f991bee` |

## Compatibility and fingerprints

Schema remains 1 and fingerprint version remains 1. The authentic legacy
resources retain:

| Save | File SHA-256 | Fingerprint-v1 state digest |
|---|---|---|
| schema 0 / nil progression | `28c41c2a8c44adc0de49110ebb05ba0952f9deb4f9cb59c3f10035e7a925e908` | `b7608f0aa748f5b40086d59ffeba746908599780f791b6483d6c613e80dedeb5` |
| schema 1 / explicit progression, nil strategy | `56ea7704735540d2a573aea7d96575d34d363e3583b5c90bb81ceb8b620e01b9` | `947b383684145d6d18738f313fec4f648861680165134f33b4f65ad42e5c0e3f` |

Missing strategy remains nil through decode/load and normalizes only at the
accepted daily boundary. The current phase matrix repeated every fingerprint
five times:

| Strategy | Opportunity | Complication | Setback | Recovery | Completed |
|---|---|---|---|---|---|
| Commercial | `2cace0ea8802121aa20b09290467151a41a50febc9f9387d173ac4ebfd87fd63` | `fee970b179d521b263f0a88931c95afe80d3e270428abf93df0a54eeb63f2cde` | `c9ccc91744fc55b32bc5d3bd824772e70b7043b3da5d9b72900bc05edcdf771c` | `f8d8d1a1ae89ed6ed34b6b0c82ef1e66a00be28676a7de2dfb598b859aaad5a0` | `550a334c2e8d1692696e63f31c74d0be72906cf1acc648c3f3f6124e456f6232` |
| Industrial | `6925de40f282ea591af88d799633ad2f49ffd6f5b86ac80e6b29fdbf4ae1fc5b` | `bf224d530d68bac4934d3ccad61edaa08eb908ce911f73d07c58c91561ac23b4` | `dccab9562ed39a8b6ceec4234058c0f907ea12da573135ebcaeeb2d374215c63` | `57fafd73980a3dc45ada65e8432a8951c1eaa9cdab66fa393e63f2f5fa0a7609` | `c7e934c3a28bcc915491a731f1e30586af183e5e476c45b4c9c697c9507ef3eb` |

Grouped-speed, uninterrupted, save/resume, typed replay, and whole-state undo
remain exact. Corrupt-primary recovery preserves the corrupt bytes and loads
the last-known-good progression. Immutable presentation analytics and all 576
row-major spatial samples remain stable after the source state advances.

## Recovery, terminal, and story resources

All four durable recovery resolutions passed speed, replay, save/resume,
backup-only, corrupt-primary, undo, snapshot, and deterministic continuation
tests. The frozen resolution digests remain:

- Commercial Tax Relief:
  `a6c0aec6b0469fb8f9962bdaf4ec4304f66ed4ad64d26fc8eb6de88db5e436f2`
- Commercial Public Realm:
  `9ce0951b499e8885ccafd3e0dd135b98a8e8ce9d75bb4481c39732391b6ac37e`
- Industrial Utility Expansion:
  `2b674038ceb42f2abf506bf438010504184cc19890aa60ec37be2f7b452b7697`
- Industrial Green Buffer:
  `4a3585f2ba00ce4c311b071d2af0ea185716b236c1225990d172e509260a283f`

Every recovery route reaches the frozen tick-844 Charter victory, then rejects
post-terminal commands without mutation. Primary save/load, corrupt-primary
backup recovery, cleared undo, replay, and immutable snapshots retain exact
terminal identity.

The PLAY-047 manifest remains 4,860 bytes with SHA-256
`aa62273943debe4b841a324584468a1953039f1a399e570321cbca46f4dcb000`.
Two independent generations matched all eight committed Commercial/Industrial
opening, complication, recovery, and Charter-victory envelopes, state
fingerprints, spatial digests, and file hashes.

## Exact validation

Focused platform matrix:

```text
swift test --package-path Native/CitySimNative \
  --filter '(SessionPlatformTests|StrategyResolutionPlatformTests|TerminalVictoryPlatformTests|ProductionStoryStateFixtureTests|BackupLoadAvailabilityTests|SpatialConsequenceTests)'
```

- 42 tests executed, 42 passed, 0 failures in 24.930 seconds.
- Breakdown: backup availability 4, story fixtures 5, session platform 16,
  spatial consequences 9, recovery resolution 6, terminal victory 2.

Complete accepted inventory:

```text
swift test --package-path Native/CitySimNative
```

- 185 tests executed, 185 passed, 0 failures in 83.506 seconds.
- The inventory includes current gameplay, HUD/input, renderer, test-resource,
  save/recovery, terminal, and immutable snapshot consumers.

Additional gates:

- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- `bash -n script/verify_candidate_isolation.sh`: passed.
- `bash -n script/persistence_relaunch_gate.sh`: passed.
- `./script/build_and_run.sh --verify`: passed and launched exact merge
  `970d0f8a3ad24144906760abcf1dbe184f0c3904`.

The staged candidate was `simulation-platform-w8bb1822a1e25`, with
bundle/preference identity
`com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`, isolated data
root `dist/test-data/simulation-platform-w8bb1822a1e25`, and verified PID
`87296`. The PID was terminated after proof.

## Current measured budgets

The dense fixture remains tick 44 / lost with digest
`149e0da1d33ed30c1077b99d55be875782c14914c21b20cbe50145f9b9473246`,
136,367 envelope bytes, and 46,080 retained spatial bytes:

| Simulation | Fingerprint | Snapshot | Save | Load |
|---:|---:|---:|---:|---:|
| 41.768 ms | 1.366 ms | 2.449 ms | 6.002 ms | 3.018 ms |

Additional full-suite ranges:

| Fixture family | Bytes | Fingerprint | Snapshot | Save | Load |
|---|---:|---:|---:|---:|---:|
| Four resolutions | 132,585–132,966 | 1.251–1.324 ms | 2.252–2.397 ms | 5.940–6.009 ms | 2.784–2.840 ms |
| Four terminal routes | 133,148–133,204 | 1.276–1.328 ms | 2.310–2.399 ms | 5.942–6.222 ms | 2.864–3.040 ms |
| Eight story states | 131,891–133,229 | 1.161–1.355 ms | 2.232–3.363 ms | 9.104–11.074 ms | 2.807–3.158 ms |

The two story-corpus builds took 1,637.925 ms and 1,630.832 ms. Spatial
diagnostics measured 1.231 ms average / 1.345 ms maximum derivation, 0.096 ms
diff, 68 events, and 46,080 retained bytes. All results remain below the
accepted 5,000 ms simulation/corpus, 500 ms fingerprint/snapshot, 1,500 ms
save/load, 2 MB envelope, and 128 KiB retained-sample ceilings.

## Contract disposition

No uncovered platform boundary or unexplained golden drift was found. Adding a
new narrow test would duplicate existing coverage, so this closure changes no
product or test source. Gameplay retains rules, balance, phase semantics,
messages, and commands. UI and renderer remain read-only consumers of
authoritative analytics and immutable snapshots.

No migration, schema bump, fingerprint-version bump, fixture rewrite, or
dependent-lane adoption is required. Future authoritative persisted fields
remain the only material contract risk: they must follow the existing
version/golden decision process rather than silently blessing changed digests.
