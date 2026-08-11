# PLAY-101 Claim — industrial_l01_v0 renderer asset intake

- **Title:** Wire the admitted industrial_l01_v0 four-view family into runtime resources
- **Lane:** Renderer asset intake
- **Owner:** Agent 404 Renderer Asset Intake Engineer, task `019fe1b1-71b8-7aa2-b13d-04d10cffb3d9`
- **Branch/worktree:** `codex/citysim-world-rendering-play101-industrial-l01-v0-intake-current5775` at `/private/tmp/citysim-play101-industrial-l01-v0-renderer-intake`
- **Published base:** `5775287b78a65f84613eb5ce2757493d1acf69fd`
- **Admitted family:** `industrial_l01_v0`, disposition `ADMIT_SOURCE_FAMILY` in `docs/production/evidence/PLAY-101/industrial-l01-v0-family/FAMILY-ADMISSION-LEDGER.json`, SHA-256 `d6faa7ad735cb9a299cf9addae56399753b213040a0a2b210c2e08b49624cb61`.
- **Status:** Active for one direct pass/fail outcome lease and one coherent focused commit.

## Outcome

Replace only the historical runtime selection for `industrial_l01_v0` with the
admitted North/East/South/West family and its three block/neighborhood/city LOD
payloads per direction. Preserve the existing cardinal-frontage selection
contract: no mirror, rotation, transform, alias, fallback, or direction reuse.
The runtime catalog must resolve all twelve admitted payloads from packaged
resources and select the exact authored direction for the authoritative road
frontage at each LOD.

The maximum mutable set is:

- `Native/CitySimNative/WorldArt/GeneratedV4/catalog/play-101-industrial-l1-directions.json`;
- `Native/CitySimNative/WorldArt/GeneratedV4/tools/build_world_asset_pack.py`, only for the minimum admitted-family selection adapter;
- `Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/generated-v4-manifest.json`;
- `Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/pages/block/page-00.png`;
- `Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/pages/block/page-01.png`;
- `Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/pages/block/page-02.png`;
- `Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/pages/city/page-00.png`;
- `Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/pages/neighborhood/page-00.png`;
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`, limited to industrial L1 resource/selection assertions and excluding every PLAY-073 camera assertion;
- `Native/CitySimNative/Tests/CitySimNativeTests/SingleAngleWorldArtTests.swift`, limited to the admitted-family intake contract;
- `docs/production/evidence/PLAY-101/industrial-l01-v0-renderer-intake/`; and
- `docs/production/completed/PLAY-101.industrial-l01-v0-renderer-intake.md`.

The allowlist is a maximum, not a required touched-file count. Existing runtime
code outside this set is already direction-aware and must remain unchanged.

## Immutable inputs and exclusions

Every byte under the admitted source-family inputs remains immutable, including
all PLAY-099 South raw/normalized/provenance/receipt bytes, all PLAY-103 North,
PLAY-104 East, and PLAY-105 West bytes, and all four files under
`docs/production/evidence/PLAY-101/industrial-l01-v0-family/`. The excluded
PLAY-073 camera worktree and all `CityScene.swift` camera/composition bytes are
out of scope. No UI, gameplay, simulation, save schema, build script, app,
aggregate suite, QA, running-process, push, release, source-admission, or visual
admission mutation is authorized.

## Focused proof and durability

Run the deterministic pack build into fresh temporary roots and require the
resulting current atlas bytes to be repeatable. Run the affected generated-pack
validator plus focused Swift resource/directional-selection tests covering all
four `industrial_l01_v0` directions and all three LODs. Require packaged
resource resolution, exact admitted input hashes, zero runtime fallback, and
no source/admission-byte drift. Stage explicit changed paths, inspect the full
index, and commit only one coherent renderer-intake packet with subject
`PLAY-101: Integrate industrial L1 four-view resources`.

Stop and return the first real defect on an admitted hash mismatch, missing
registration input, nondeterministic pack, direction/LOD alias, fallback,
unexpected path, focused failure, or need to change runtime/product code outside
the maximum set. Do not repair source art or broaden scope.

## E365 aggregate-repair amendment

Agent 002 authorizes one bounded Agent 404 repair from current authority
`e365835f8e00067ca461f2e035264f663f1a8605`. For this repair only, the mutable
maximum is reduced to these exact five paths:

- `Native/CitySimNative/WorldArt/GeneratedV4/catalog/play-101-industrial-l1-directions.json`;
- `Native/CitySimNative/WorldArt/GeneratedV4/tools/build_world_asset_pack.py`;
- `Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/generated-v4-manifest.json`;
- `Native/CitySimNative/Sources/CitySimNative/Rendering/WorldAssetCatalog.swift`; and
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`.

The catalog and builder changes are limited to the approved runtime-only
vertical source-registration offsets: east `+15` px, west `+43` px, and
north/south `0`. The builder applies each offset identically to
`groundPivotSource.y`, `frontageSocketSource.y`, and both `doorBaseSource.y`
values while preserving entrance-socket world values, exclusion geometry, and
every source, admission, normalized, and atlas-page PNG byte. The manifest may
change only in the resulting runtime registration metadata.

`WorldAssetCatalog.swift` may remove only the stale
`manifest.pages.count > 4` rejection; every other consistency, padding,
extrusion, power-of-two, and active-plus-next residency guard remains frozen.
`WorldRenderingTests.swift` may change only the two current-bundle cardinality
assertions from four to five and, after corrected manifest generation, the two
deterministic camera occupancy-height literals. `CityScene.swift`, camera
behavior, every other assertion, and every other product/test byte remain
immutable.

Proof is one outcome: two fresh isolated deterministic pack builds with
byte-identical manifests, all five page PNG hashes unchanged from `e365835f`,
all source/admission/normalized hashes unchanged, east/west opaque minimum Y at
least `-18.51`, allowed bottom overhang at most `0.51`, and one focused Swift
invocation containing exactly the five Agent-002-listed WorldRendering tests.
Any drift, unexpected path, or focused failure stops the repair. On PASS, stage
only the exact paths actually changed from the five-path maximum and create one
coherent local candidate commit; no aggregate, build, app, QA, push, or release.
