# Industrial L3 R2 Replacement Recovery Authority

- **Published baseline:** `642acc81992e5358768e71c4d8594b24c8d291a9`
- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Claim:** `PLAY-073`
- **Claim SHA-256:** `12c901919261e18763eae50910b48b83d9c2243fb2095d223f1d38791557b380`
- **Accepted Industrial L2 product:** `d41c2c68d5584c990e271af06c0b93ab50722f5e`
- **Cohesive replacement reference:** `25d291a7373833a797dc3bb3ba36658e18eccc06`
- **Reference deterministic evidence:** `de6805092478c97d85f0230c93f7f10edcb257e6`
- **Candidate ready for QA:** false
- **Production selected:** false

## Disposition

The original R2 product at
`a6000d1ac4c7ae8cca352ca7f55b000298a0058b` was returned for chalky
white/cyan material, thin outlines, and mixed fidelity. Do not revive it.

The later cohesive replacement at
`25d291a7373833a797dc3bb3ba36658e18eccc06` is not accepted product, but
its independent QA record is `BLOCK`, not `REJECT`. Regular launch, pack
identity, accessibility identity, and one warm/dark city view passed. The Mac
locked before four-direction, all-LOD, compact, interaction, Undo,
Reduce-Motion, and screenshot proof completed.

Integration therefore authorizes one new current-master descendant that
reconstructs only the exact accepted-L2-to-cohesive-replacement net delta,
produces new candidate-bound technical proof, and stops for one independent
same-SHA PLAY-075 gate.

## Frozen references

| Purpose | Commit |
|---|---|
| Original returned evidence | `b4191d98ee7c526bc08a6fe272521588572e27fd` |
| Accepted source family | `0aefb804c59b4ff9b919dc81fdca907cd4b85c5e` |
| Accepted metadata/material repair | `5b1378a2c81d7d55a39b19366b5206c28f70d9f7` |
| Replacement author handoff | `8e1bbba5bb811b9bd43eba7829047afd1787e00c` |
| Candidate-bound fixture intake | `cdcd1e92b2864f7f5c5ad879ee015ca2179459bd` |
| Fixture prerequisite clarification | `e5998bd5b892b75351f78b60e3a8ec33d0a64eda` |
| Independent QA blocker | `c5c8f0bf18160bde255e6d04a73c313a8f38a604` |

These records are references and provenance. None grants production
selection, player-facing acceptance, or permission to merge its historical
carrier.

## Exact implementation boundary

From a clean branch containing the published baseline, reconstruct the net
delta:

```text
git diff d41c2c68d5584c990e271af06c0b93ab50722f5e..25d291a7373833a797dc3bb3ba36658e18eccc06 -- <the paths below>
```

Apply only the resulting content to these 13 product/test/tool paths:

```text
Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift
Native/CitySimNative/Sources/CitySimNative/Rendering/LotRenderer.swift
Native/CitySimNative/Sources/CitySimNative/Rendering/WorldAssetCatalog.swift
Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/generated-v4-manifest.json
Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/pages/block/page-00.png
Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/pages/block/page-01.png
Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/pages/city/page-00.png
Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/pages/neighborhood/page-00.png
Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift
Native/CitySimNative/WorldArt/GeneratedV4/catalog/play-073-industrial-l3-directions.json
Native/CitySimNative/WorldArt/GeneratedV4/tools/build_world_asset_pack.py
Native/CitySimNative/WorldArt/GeneratedV4/tools/test_world_asset_pack_bindings.py
Native/CitySimNative/WorldArt/GeneratedV4/tools/validate_world_asset_pack.py
```

The worker may additionally adopt the already-preserved, candidate-neutral
external-fixture test:

```text
Native/CitySimNative/Tests/CitySimNativeTests/
  IndustrialL3DirectionalFixtureIntakeTests.swift
docs/production/evidence/PLAY-073/
  external-l3-directional-fixture-intake-v1/
```

Write all new candidate proof beneath a new exact-SHA-bound root:

```text
docs/production/evidence/PLAY-073/replacement-r2-<new-product-sha>/
```

Do not modify QA-owned fixture bytes. Commit the reconstructed product before
candidate evidence. Do not cherry-pick or merge
`25d291a7373833a797dc3bb3ba36658e18eccc06` or its historical carrier.

## Required technical gate

The exact new product candidate must prove:

1. authored North, East, South, and West lookup at city, neighborhood, and
   block LOD with authoritative frontage and no runtime transform;
2. stable identity through pulse, save/load, Undo, camera, and LOD changes;
3. construction, condition, selection, overlays, and Reduce Motion integrity;
4. explicit Industrial L4 rejection and zero fallback;
5. material-binding rejection for wrong revision, swapped N/W library, and
   wrong provenance hash;
6. two fresh pack builds with byte-identical manifest and pages;
7. source-to-normalized-to-pack-to-runtime identity;
8. byte-identical Industrial L1/L2 and every unrelated payload;
9. pack validator, production-geometry validator, external directional
   fixture intake, focused Renderer tests, and the complete Swift suite;
10. `bash -n script/build_and_run.sh` and
    `./script/build_and_run.sh --verify`;
11. exact staged source/resource parity and one non-interactive
    launch/resource smoke; and
12. cold update, pulse, residency, node/drawable, RSS, and fallback results.

Expected reference targets from the cohesive replacement are:

| Artifact | SHA-256 |
|---|---|
| L3 catalog | `e9fa8eda7330385d478fbcac358bdce444e996ce6e4e7c373271426cba4cd136` |
| Generated-v4 manifest | `317802265010fc758b232bea9198f18ec0ca4d75b5ceb6f759206238717cec92` |

The four atlas-page targets and all executable/staging-manifest hashes must be
recomputed and recorded in the new candidate packet. Historical executable or
staging hashes are not reusable.

## Independent QA handoff

Renderer may hand only the exact clean new product/evidence candidate to
PLAY-075. QA owns one fresh same-SHA journey covering:

- N/E/S/W at city, neighborhood, and block LOD;
- regular and exact `900x600`;
- pointer/keyboard parity, hover, and selection;
- construction and condition;
- demolition and exact Undo;
- Reduce Motion and accessibility; and
- visual comparison with published Industrial L2.

Renderer must not score that journey. Integration alone accepts, integrates,
selects production, and pushes.

## Explicitly forbidden

- Industrial L4 source intake, quarantine, runtime activation, or shipping;
- broad composition changes outside the exact net delta;
- modification of QA fixtures or preregistration;
- reuse of the rejected original R2 product;
- historical carrier merge/cherry-pick;
- self-score, self-acceptance, production selection, integration, or push.

Stop on any baseline, claim, path, content, resource, identity, build,
performance, staged-parity, or ownership mismatch. Return exact product and
evidence commits, commands/results, staged identities, resource hashes,
disclosed limitations, and a clean worktree.
