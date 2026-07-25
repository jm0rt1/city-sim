# PLAY-028 Directional Residential Skyline Completion

- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Status:** ready for independent quality review; not self-accepted
- **Published authority:** `1d4d4f7eba1bb1cf3c8d64b1c221f33d3be91637`
- **Exact product:** `a08414c591b0f3600da5588d8c771e74d237727f`
- **Exact evidence:** `61b20d47df5a1118e2ca83f06bc8fa91af3cb75c`
- **Candidate ID:** `world-rendering-w5f893ad1da1b`
- **Bundle ID:** `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- **Evidence packet:**
  `docs/production/evidence/PLAY-028/candidate-a08414c/`

## Ordered task commits

1. `f17e57e0e6121aa6cbd221efb9bac29a7fc1ad4e` — bind the
   renderer-lead ingestion audit to the accepted 16-source inventory.
2. `4149f8de075a0751a4778facfeef61012800e111` — ship deterministic
   production packing and authoritative level/frontage runtime selection.
3. `c8843dc5815ed3ebdefaa7dcd8c828db88f4d649` — export the 4 x 4
   pre-ingestion and production runtime matrices.
4. `a08414c591b0f3600da5588d8c771e74d237727f` — adopt exact authored
   four-direction registration in the production geometry validator and
   manifest.
5. `61b20d47df5a1118e2ca83f06bc8fa91af3cb75c` — retain exact staged
   default/compact Residential, matrix,
   accessibility, Reduce Motion, geometry, pack, identity, and hash evidence.
6. This completion commit updates only the claim and completion record.

## Player-visible outcome

Normal CitySim play now uses the independently accepted Residential
variant-zero source matching both the authoritative logical level L1-L4 and an
actual adjacent road edge N/E/S/W. A Residential building no longer reuses the
old level-one south-facing mansion for every level or frontage.

All 16 identities are distinct authored sources. The renderer does not mirror,
rotate, alias, infer frontage from the camera, substitute another building
family, or repair the accepted pixels. A roadless Residential lot emits an
explicit bounded missing-identity diagnostic rather than silently inventing a
direction or fallback.

The selected level and frontage are part of stable render identity. Unchanged
pulses reuse the existing node; level or authoritative road changes rebuild
the affected tile; save/load, undo, camera changes, and all three LODs preserve
the same source identity.

## Product and pipeline surfaces

- `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/GeneratedWorldAssetManifest.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotRenderer.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/WorldAssetCatalog.swift`
- `Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
- `Native/CitySimNative/WorldArt/GeneratedV4/catalog/play-028-residential-directions.json`
- `Native/CitySimNative/WorldArt/GeneratedV4/tools/build_world_asset_pack.py`
- `Native/CitySimNative/WorldArt/GeneratedV4/tools/validate_production_geometry.py`
- `Native/CitySimNative/WorldArt/GeneratedV4/tools/validate_world_asset_pack.py`

No gameplay, simulation, save, public store, command, SwiftUI HUD,
`Package.swift`, build-script, source-art, Commercial, or Industrial surface
changed.

## Exact source and resource identity

- Accepted L1 source authority:
  `6380037d42ede73eca60aac4a9b1c7b710f681d6`.
- Accepted L2-L4 source authority:
  `8f928ed5dd01453ff9d4d9910858d8bf786afa9d`.
- 16 unique accepted raw sources and 48 unique normalized LOD payloads.
- Source and staged manifest:
  `1753a314cfba5ce0034d486368dc92b23267b5a1ea8f2a30231e9a6c96f7e3fe`.
- Staged executable:
  `1daae4e401871c63fcc0f0a8557a7e4382ecbc6d6eaefaf79cbcc0f88937f7dd`.
- Staged candidate manifest:
  `4721fcdcde34c093f27070e3f06aa15d6152c8e4a84231d0d63af42bce7e4e94`.

Two clean pack builds were byte-identical. Page hashes, exact raw inventory,
normalized payload hashes, resource identity, and every retained proof file
are recorded in the evidence packet and `SHA256SUMS`.

## Automated validation

- Focused `WorldRenderingTests`: 47/47 passed in 21.442 seconds.
- Full native suite: 205/205 passed in 94.571 seconds.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed from exact product
  `a08414c591b0f3600da5588d8c771e74d237727f`.
- Exact bundled-Python source/staged pack validation: passed with 16
  directional identities, 48 normalized payloads, zero failures, and
  `staged_matches_source: true`.
- Exact bundled-Python production geometry validation: passed 2,500
  reciprocal contact, 100 road, and 372 entrance-clearance checks with zero
  collisions or failures.
- The 4 x 4 runtime matrix export, authoritative frontage selection, roadless
  explicit failure, and identity stability suites all passed.

The first repeat-validation invocation needed two non-product corrections:
SwiftPM required its writable module-cache execution context, and the Python
tools require `--report` rather than `--output`. The corrected exact commands
above passed; no threshold or assertion was weakened.

## Real staged-app flow

The exact staged app was operated with Computer Use at default and exact
compact size:

1. launch the isolated worktree bundle;
2. load the frozen industrial-complication story and confirm it is paused;
3. reset deterministic framing with `0`;
4. select the real Residential at internal `(10,11)`, announced as one-based
   `Block 11, 12`;
5. inspect AX identity and confirm Residential L4, operational, road connected;
6. verify its only adjacent road is authoritative south neighbor `(10,12)`;
7. repeat unselected and selected proof at default and compact;
8. start the authentic city, select the same block, and confirm Residential
   L1 with the same south-road frontage;
9. repeat compact L4 selection under Reduce Motion and confirm identical AX
   meaning with suppressed actions.

The default screenshot is uncropped at 1278 x 768. Compact screenshots retain
the complete decorated 900 x 652 window around exact 900 x 600 app content.
The 4 x 4 matrices are clearly labeled supporting renderer-harness evidence;
they are not substituted for the staged app.

## Performance and residency

- Cold render: 3.830 ms world update, zero decode loads, 5.154 ms total.
- Representative render: 3.774 ms world update, 5.159 ms total.
- Default: 1,369 nodes / 553 drawables.
- Unchanged-pulse soak: 4,286 pulses, stable node identity, 2 bounded actions,
  0.0006 ms average update.
- Repeated LOD residency: 41,943,040 bytes high water, 648 hits, 12 misses,
  9 evictions, zero fallback.
- Compact Reduce Motion RSS after the real selection flow: 236,320 KiB
  (230.78 MiB), below the 333.8 MiB ceiling.

## Limitations and handoff

This task intentionally ships only accepted Residential variant zero. More
Residential variants, directional Commercial and Industrial families, and
future player-controlled four-side rotation require separately accepted
source inventories and a new claim. PLAY-028 does not claim those outcomes.

No shared-contract proposal is required. Hand the exact clean commit range to
independent quality review; this lane does not self-score, push, or integrate.
