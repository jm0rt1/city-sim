# PLAY-088 Phase-A Validation

## Disposition

Phase A freezes the current persistence inputs and is evidence-only. Product,
tests, fixtures, manifests, schema and fingerprint versions are unchanged.
The future PLAY-085 acceptance matrix defaults to rejection and every phase-B
gate remains `NOT_RUN`.

Phase B is `BLOCKED_PENDING_EXACT_INTEGRATION_BINDING`. It may begin only when
Integration publishes a new authority that names one exact integrated
PLAY-085 revision-2 product commit. This worker does not accept that future
product.

## Exact authority

- Published authority and synchronized ancestor:
  `448fd45c2fb07e7c6efdd4ac19764cdd04ce6cda`
- Branch: `codex/citysim-simulation-platform`
- Claim:
  `docs/production/claims/PLAY-088.simulation-platform.md`
- Claim SHA-256:
  `516234a4496b6c643557397d03e4feef3e375355965d2e50de7fbc44ab50a282`
- Approved contract:
  `docs/production/decisions/CONTRACT-022-durable-storm-recovery-ownership.md`

## Frozen inputs

`phase-a-current-inputs.json` records SHA-256, Git blob, byte count, corpus
family/version, schema/fingerprint metadata, and state digest for every
committed JSON file under the test fixture root. Its generator also verifies
every manifest-advertised file SHA-256 and state digest before writing output.

The seed-42 current new city has no committed fixture file. Its canonical
sorted-key bytes were reconstructed directly from `CityGameState.newCity` and
cross-checked against the frozen XCTest digest:

- explicit `CityProgressionState()`: 63,107 canonical bytes,
  `ee95ebc98d8314e2ae2661baa03bc11809a70811cec1fdfb5633930ee78186d3`;
- nil-progression control: 63,032 canonical bytes,
  `bba31f738c9b3b4d4e91d22714d151520736cf3aa48fabb67f15e0b2d9bbceb7`.

The authoritative input map is:

- state: the complete Codable `CityGameState`;
- fingerprint: version-1 SHA-256 of sorted-key state JSON;
- schema 0: bare state JSON;
- schema 1: `{schemaVersion,fingerprintVersion,state,digest}`;
- save: validated candidate followed by atomic primary replacement;
- backup: last valid primary, with corrupt candidate bytes preserved;
- replay: typed `CitySimulationCommand` plus deterministic simulation steps;
- snapshot: copied state, fingerprint, and derived spatial consequences;
- Undo: bounded in-memory pre-construction state stack; successful load pauses
  and clears the stack.

## Two independent materializations

```text
python3 docs/production/evidence/PLAY-088/generate_phase_a_packet.py \
  --repo /Users/James/.codex/worktrees/e909/city-sim \
  --output-root /private/tmp/citysim-play088-a.ccHQHd

python3 docs/production/evidence/PLAY-088/generate_phase_a_packet.py \
  --repo /Users/James/.codex/worktrees/e909/city-sim \
  --output-root /private/tmp/citysim-play088-b.iGrpx5

diff -qr /private/tmp/citysim-play088-a.ccHQHd \
  /private/tmp/citysim-play088-b.iGrpx5
```

Result: empty recursive diff. Exact hashes and byte counts are frozen in
`repeat-identity.json`.

## Future fail-closed admission

`future-play085-acceptance-matrix.json` contains 34 required gates. Missing
candidate or Integration authority hashes, unexpected paths, missing inputs,
schema/fingerprint drift, unproved golden drift, or any failed gate rejects
the candidate and stops adoption. It covers:

- exact integrated revision-2 identity and the two authorized product files;
- optional/missing-key compatibility and byte preservation;
- exact row-major damage ownership, merge, retirement, clamping, and
  completion-once semantics;
- primary and corrupt-primary backup routes for active and recovered ledgers;
- deterministic replay/grouping, fingerprint repetition, immutable snapshots,
  exact Undo and paused-load behavior;
- existing storm identity, strategy/progression/four-route fixtures, and
  performance budgets.

The matrix neither publishes a candidate identity nor claims any phase-B
result.

## Validation commands

The evidence checkpoint is validated with:

```text
python3 -m py_compile \
  docs/production/evidence/PLAY-088/generate_phase_a_packet.py

python3 docs/production/evidence/PLAY-088/generate_phase_a_packet.py \
  --repo /Users/James/.codex/worktrees/e909/city-sim \
  --output-root <fresh-root>

diff -u <fresh-root>/phase-a-current-inputs.json \
  docs/production/evidence/PLAY-088/phase-a-current-inputs.json

diff -u <fresh-root>/future-play085-acceptance-matrix.json \
  docs/production/evidence/PLAY-088/future-play085-acceptance-matrix.json

swift test --package-path Native/CitySimNative \
  --filter 'SessionPlatformTests|ProductionStoryStateFixtureTests|VisibleCityStateFixtureTests|StrategyResolutionPlatformTests|TerminalVictoryPlatformTests|SpatialConsequenceTests'

swift test --package-path Native/CitySimNative

git diff --check
```

Results:

- generator syntax, fresh-root regeneration, both committed-output diffs, and
  all manifest-advertised file/digest checks: passed;
- `bash -n script/build_and_run.sh` and
  `bash -n script/persistence_relaunch_gate.sh`: passed;
- focused platform matrix: 54 tests executed, 54 passed, 0 failures in
  231.091 seconds;
- complete native suite: 313 tests executed, 2 skipped, 1 failure in
  1109.383 seconds;
- owned PLAY-088 failures: 0;
- unchanged external renderer failure:
  `CitySimulationTests.testRendererInitialRenderAndPulsesInvalidateOnlyChangedSpatialTruth`
  measured 4.130783304572105 ms against the renderer-owned 2.1 ms threshold;
- dense session: 400 attempted steps, tick 44, lost,
  simulation 47.103 ms, fingerprint 1.311 ms, snapshot 4.525 ms, save
  5.654 ms, load 2.907 ms, 136,310 bytes, 92,160 retained sample bytes,
  digest
  `d9faccd7c23b6632d3ff6213eece9ed60868388b059132bef2e7f908cf1009a7`;
- current story two-build generation: 5,401.762 ms and 5,302.665 ms for
  12 fixtures;
- current visible-city two-build generation: 2,059.645 ms and 2,010.684 ms
  for 14 fixtures;
- all focused and complete-suite platform persistence, fingerprint, snapshot,
  save/load, backup, replay, Undo, size, timing, and retained-memory assertions
  passed.

The external renderer threshold is disclosed without changing its test,
budget, product, or ownership classification.
