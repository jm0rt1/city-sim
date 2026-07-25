# PLAY-063 Candidate-Blind Industrial L1 Preregistration

- **Disposition:** preregistered; no PLAY-062 product candidate received or scored
- **Published authority and frozen shipping baseline:** `8f85a0cff1adb489eec2f8a95f066e5161d7e7d3`
- **Accepted non-shipping Industrial L1 source authority:** `79668c347e58d602f9627c73cb09e3272a83ef57`
- **Lane:** `codex/citysim-playtest-quality`
- **Claim:** `PLAY-063`
- **Date:** July 25, 2026

This packet freezes the independent release gate before integration names an
exact PLAY-062 product candidate. It contains only the exact published
shipping baseline, accepted source authority, candidate-blind criteria, and
the future execution contract. It is not an early candidate inspection,
partial score, waiver, or acceptance.

## Read-only boundary and product parity

Quality did not modify `Native/CitySimNative`, build scripts, source art, pack
inputs, manifests, or shipping resources. The active product/build tree at
published authority `8f85a0c` is byte-identical to accepted combined product
`1799fbc2810f14d85511b74a8808bbee1928eef7`:

```text
git diff --quiet 1799fbc..8f85a0c --
  Native/CitySimNative/Sources
  Native/CitySimNative/Resources
  Native/CitySimNative/Package.swift
  script/build_and_run.sh
exit 0
```

The intervening authority adds accepted source-art and governance history.
PLAY-062 owns production selection, normalization, packing, manifesting,
frontage lookup, renderer presentation, and candidate evidence. PLAY-063 will
only admit and score a clean exact candidate explicitly nominated by
integration.

## Frozen same-state baseline

The binding state is:

`Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/StoryStates/story-industrial-complication-v1.json`

- file SHA-256:
  `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`;
- schema/fingerprint version `1` / `1`;
- envelope digest
  `a43611573cd888edba5292b9740b8a4e15f05e9cfd50edf73648427eaf775c5a`;
- seed `42`, tick `128`, Day `33`, status `playing`, loaded paused;
- Freight strategy, complication phase, next scheduled tick `192`;
- treasury `$34,036.80`, population `332`, jobs `231`, power `291/300`,
  water `256/270`; and
- selected comparison target: state coordinate `(14,11)`, exposed to the
  player and AX as `Industrial block 15, 12`.

Every future same-state A/B must use byte-identical fixture bytes, City layer,
that exact selected coordinate, settled paused state, matching overlay, and
matching viewport/camera route. Topology, simulation, camera, target, HUD, or
state changes may not be presented as an art improvement.

## Frozen baseline defect and accepted improvement target

The shipping manifest contains one Industrial identity:
`industrial_l01`, level `1`, south frontage,
`supported_orientation: south-facing-fixed`. `CityScene` and `LotRenderer`
resolve every Industrial tile to that identity. The future N/E/S/W matrix
therefore begins from a deliberate defect: north, east, and west road
frontages visually alias the same south-facing generic factory; south passes
only by coincidence. The baseline also lacks the accepted directional
gantry/factory/service-apron silhouettes.

The accepted source authority supplies four separately authored source-v05
identities with unique raw and normalized bytes. Those accepted files define
the candidate's permitted art identity. They remain `productionSelected:
false` at this baseline and are not candidate evidence.

## Frozen live comparison matrix

The exact staged quality bundle loaded the fixture from fresh isolated roots.
After the load toast expired, keyboard navigation selected Industrial block
15,12. All captures are original-resolution decorated-window images:

- regular: 1278 x 768 image of the explicit regular route;
- compact: 900 x 652 decorated window with exact 900 x 600 app content;
- regular LOD proof stops: city `0.85`, neighborhood `0.65`, block `0.50`;
- compact default and block proof `0.45`;
- City and Pollution layers, Focus City, closed HUD and Details open; and
- compact keyboard focus plus a separate Reduce Motion process.

The three regular LOD image hashes differ. The compact default and block hashes
also differ. No load/action toast is present in any binding image. The
persistent `Utilities` priority action is authentic HUD truth and is retained.

## Frozen future execution matrix

The final exact candidate will be exercised without coaching through:

1. regular and exact 900 x 600 same-state Industrial comparison;
2. city, neighborhood, and block stops with block 15,12 selected;
3. all twelve `N/E/S/W x city/neighborhood/block` identities in color and
   grayscale, unlabeled and randomized against accepted Residential and
   Commercial peers;
4. authoritative frontage resolution for every direction, including
   roadless rejection and deterministic frontage priority;
5. complete gantry, factory, entrance, and service-apron silhouette with no
   crop at all three LODs and both widths;
6. maintained/degraded condition, construction stages, selection, valid and
   invalid preview, placement, undo, save, terminate, relaunch, load-paused;
7. all five overlays, Focus City enter/exit, and settled Reduce Motion;
8. pointer selection/placement, Return, Space, command/menu routes, FKA,
   semantic AX, focus generation, and topmost-first Escape;
9. three repeated LOD cycles plus unchanged pulses for identity stability,
   decoded residency, settled RSS, cold/update/render timing, and fallback
   diagnostics; and
10. focused renderer/asset tests, full native suite, governed staged verify,
    accepted-source/staged-pack parity, and two-build deterministic output.

Each binding visual must be an original-resolution uncropped decorated window
paired with exact PID/process environment, window content size, camera/LOD,
state digest, selection, layer, and file hash. AX trees must describe the same
coordinate, state, availability, and action visible in the paired frame.

## Frozen disposition bar

The exact candidate must:

- score at least **19/20**;
- earn **4/4** for Industrial L1 identity and road-facing frontage;
- earn **4/4** for whole-scene world/HUD cohesion;
- have no category below **3/4**;
- have zero P0/P1 defects and zero automatic rejects; and
- be materially preferred over this baseline in both regular and exact compact
  same-state comparisons.

`RUBRIC.md` is immutable category and automatic-reject authority.
`BASELINE-LEDGER.md` records exact baseline behavior.
`ledgers/industrial-direction-lod-matrix.csv` binds the twelve baseline and
accepted-source identities.

## Candidate-wait handoff

Quality will not begin candidate interaction until integration supplies:

1. exact combined/product, renderer evidence, and completion commits;
2. proof that accepted source authority `79668c3` is an ancestor;
3. a clean candidate worktree and exact ancestry graph;
4. exact lane-staged bundle, executable, Info.plist, staging manifest,
   generated-v4 manifest, atlas pages, and source-to-pack hashes;
5. the canonical twelve-row direction/LOD inventory with zero
   alias/mirror/rotation/fallback;
6. one exact isolated PID/data root/preferences domain per route; and
7. author tests and diagnostics as admission evidence only.

Quality will not inspect uncommitted feature-lane work, substitute a nearby
candidate, reuse author scoring, coach the route, crop defects, repair product
or source art, self-waive a failure, push, or integrate.
