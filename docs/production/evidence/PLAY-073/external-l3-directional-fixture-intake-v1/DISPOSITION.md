# PLAY-073 external Industrial L3 directional fixture intake

## Disposition

`RENDERER_INTAKE_PASS_NON_SHIPPING`

The published PLAY-075 schema-1 fixture is sufficient for a candidate-bound
replacement-R2 staged-app pass without product code, save-schema, shared
fixture, generated-v4 manifest, runtime-selection, or source-art changes.
This checkpoint validates the renderer intake only. It does not run or score
QA, approve replacement R2, activate Industrial L4, or change any accepted
product byte.

The earlier action-built exploration was rejected and removed before this
checkpoint. It established that producing four natural L3 upgrades is coupled
to demand, utility reserve, progression qualification, and terminal-state
rules; using that route for visual evidence would create an unnecessary
simulation/balance dependency. No exploratory fixture or test remains.

## Exact authority and ownership

- Synced renderer merge: `f52c6d169575e8fca187b5eece38ee836501f65b`.
- Published authority: `184e6e5b83b405b217f1908bf331605c8aa0c912`.
- QA-owned fixture:
  `docs/production/evidence/PLAY-075/industrial-l4-family-preregistration-v1/fixtures/industrial-l03-directional-mature-city-v1.json`.
- Fixture SHA-256:
  `b8875422a277b59f6797aef03ca93175a502df5963a5c972684ca47be40e7aa5`.
- State digest:
  `dbe6860011f43063a39e228531db4b49303d64a918e7884301b3de80360dd97f`.
- Schema/fingerprint: `1` / `1`.
- Generated-v4 manifest SHA-256:
  `317802265010fc758b232bea9198f18ec0ca4d75b5ceb6f759206238717cec92`.

`RUNTIME-LEDGER.json` binds the four state coordinates, sole adjacent roads,
logical IDs, source revisions and hashes, and all twelve LOD payload hashes.
The fixture bytes are referenced, not duplicated or modified.

## Renderer validation

The new renderer-owned intake test:

`Native/CitySimNative/Tests/CitySimNativeTests/IndustrialL3DirectionalFixtureIntakeTests.swift`

copies the immutable published bytes into a temporary `quicksave.json`, loads
them through the unchanged `SaveGameService`, verifies the schema-1 digest,
and checks:

- four completed, maintained, 89-worker Industrial L3 lots;
- exactly one authoritative road edge per lot;
- exact North/East/South/West logical identity;
- four distinct source keys and source hashes;
- twelve distinct City/Neighborhood/Block normalized hashes;
- exact generated-v4 node selection at regular `1278 x 768` and compact
  `900 x 600`;
- no alias, direction substitution, mirror, rotation, recolor, or fallback;
  and
- zero fallback-count delta.

Focused results:

- `IndustrialL3DirectionalFixtureIntakeTests`: **1/1**, 5.312 seconds.
- existing Industrial L1-L3 production selection/frontage/LOD gate: **1/1**,
  1.159 seconds.
- frozen VisibleCityStates two-build/manifest gate: **1/1**, 4.283 seconds.
- fail-closed Industrial L4 intake gate: **2/2**, 0.006 seconds.

No staged app or QA journey ran in this checkpoint.

## Candidate-bound stage recipe

Use this only after Integration identifies the exact admitted renderer
candidate:

1. Verify the attached renderer branch, clean status, exact product/evidence
   ancestry, and candidate commit.
2. Run `./script/build_and_run.sh --stage-only`, retain
   `./script/build_and_run.sh --print-identity`, and hash the executable,
   Info.plist, staging manifest, packaged resource bundle, and packaged
   generated-v4 manifest.
3. From the printed candidate `data_root`, create that isolated directory and
   copy the QA-owned fixture bytes to exactly `quicksave.json`. Re-hash the
   copy and require the fixture SHA above. Do not use
   `CITYSIM_WORLD_ASSET_PACK` or any renderer/coordinate override.
4. Launch one exact regular process with `CITYSIM_REGULAR_WINDOW=1` and the
   script-provided `CITYSIM_DATA_ROOT`; load through the visible Open command,
   pause immediately, and bind PID/bundle/defaults/data-root identity.
5. Terminate only that PID, then repeat from a fresh exact process with
   `CITYSIM_COMPACT_WINDOW=1`. The complete interaction and capture journey
   remains owned by PLAY-075 preregistration.

## Earliest Industrial L4 quarantine slot

The existing non-shipping intake checkpoint
`5d81479453dbd574ab3a880db3e37b227ed5a1d5` remains the earliest slot. Its
logical IDs, pivots, sockets, frontage, LOD slots, camera expectations, and
fail-closed nil runtime lookup are green after the `184e6e5` sync. Per-direction
art may enter only an Integration-authorized candidate resource quarantine.
Shipping manifest/runtime activation remains blocked until one exact,
independently accepted 4/4 family is supplied atomically.
