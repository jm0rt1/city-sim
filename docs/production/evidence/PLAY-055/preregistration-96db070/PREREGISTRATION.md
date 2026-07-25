# PLAY-055 Independent Preregistration and Frozen Baseline

- **Disposition:** preregistered; no PLAY-028/054 candidate has been received or scored
- **Published authority:** `96db07032e548448f659b573381b6b5abbd94eb2`
- **Quality merge checkpoint:** `56d099714d90c63c76993dcbd23eca9f6d615c54`
- **Lane:** `codex/citysim-playtest-quality`
- **Claim:** `PLAY-055`
- **Date:** July 25, 2026

This record freezes the independent gate before integration supplies the exact
combined PLAY-028/054 product. It is a baseline defect reproduction and
candidate-wait contract, not a partial candidate score or an acceptance.

## Frozen real-app identity

The quality merge contains no product or staging-script difference from
published authority `96db070`. The baseline was built once through the
governed lane staging script and operated through the real SwiftUI/SpriteKit
app.

| Identity surface | Frozen value |
|---|---|
| Staged source commit | `56d099714d90c63c76993dcbd23eca9f6d615c54` |
| Product authority | `96db07032e548448f659b573381b6b5abbd94eb2` |
| Candidate ID | `playtest-quality-wf967be0ab5b4` |
| Bundle ID / preferences | `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4` |
| Bundle | `dist/CitySim-playtest-quality-wf967be0ab5b4.app` |
| Executable SHA-256 | `2b86a22674883efeacaa4b0f5b2acb91b6ae22281d6144e135d133a9d3df60e9` |
| Staging-manifest SHA-256 | `968170a07fd61c2921c289ba1423242a8d1dcddb0c06f2602922a5d73c478e3a` |
| Info.plist SHA-256 | `cc1ec2a4c4472d4c22c47ec5318fd8848a3a7ab5757e82045bf67c00f12f0afe` |
| Atlas manifest SHA-256 | `411934e492a66216787f8c93dd91d3f68cc16637110dba9ed7186b22dda96d3d` |
| Generated-v4 manifest SHA-256 | `ee1fa5c6d8d83d0f3e559ea4e6b0d30d4d90fe576f0347dac60d291fd661ae72` |

Source and staged atlas manifests plus city, neighborhood, and block page zero
matched byte-for-byte. `identity/IDENTITY.md` retains the hashes, explicit
window environments, exact PIDs, RSS readings, and cleanup result.

## Frozen same-state baseline

Regular and compact comparisons use committed fixture
`story-industrial-complication-v1.json`:

- file SHA-256
  `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`;
- schema/fingerprint version `1` / `1`;
- envelope digest
  `a43611573cd888edba5292b9740b8a4e15f05e9cfd50edf73648427eaf775c5a`;
- seed `42`, tick `128`, Day `33`, status `playing`;
- loaded paused through Command-O, City layer, no selection, then framed with
  deterministic `0`;
- isolated roots under `/private/tmp/citysim-play055-96db070/`.

The candidate must consume byte-identical fixture bytes and reproduce the same
state, camera command, layer, selection, window mode, and settled transient
state. No authored topology change may be represented as presentation
improvement.

## Baseline defects reproduced

1. **Residential level/direction collapse:** the real staged L1/L4 fixture
   visibly renders its level-1 and level-4 Residential parcels with the same
   building form. Runtime inspection confirms every Residential tile resolves
   to `residential_l01`, while the shipping entry declares south frontage.
   L2/L3 share that same level-blind path. Evidence:
   `live/residential-levels/l1-l4-collapse-regular.png` and
   `BASELINE-DEFECTS.md`.
2. **AX-visible but visually collapsed command details:** at exact compact,
   Overview exposes identity, health, objective, and operating-position
   content to AX, while only the header and clipped card edges are visible.
   Journal exposes seven complete notice records and their controls to AX,
   while the visible frame again shows only the header and card slivers.
   Evidence:
   `live/compact/baseline-overview-open-900x600.png`,
   `live/compact/baseline-journal-open-900x600.png`, and paired AX trees.

The regular window shows the same content-compression tendency. These are
baseline reproductions returned to PLAY-028 and PLAY-054, not quality-lane
product repairs.

## Frozen disposition bar

The final exact combined candidate must:

- score at least **19/20**;
- earn **4/4** for Residential direction/level identity;
- earn **4/4** for HUD legibility and operability;
- have no category below **3/4**;
- have zero P0/P1 defects and zero automatic rejects; and
- be materially preferred over this baseline in both uncropped regular and
  exact compact comparisons.

The complete category anchors and automatic rejects are frozen in
`RUBRIC.md`. Candidate inspection must cover the 16-row Residential matrix,
city/neighborhood/block LOD, same-state regular/compact HUD, Details,
Overview, Journal, objectives, selection/rejection, pointer, keyboard, FKA,
AX, Reduce Motion, source/staged resource identity, residency, RSS, and
performance.

## Candidate-wait boundary

No score will be assigned until integration supplies:

1. exact combined product, evidence, and completion commits;
2. exact lane-staged bundle, executable, resource and manifest hashes;
3. a clean candidate worktree and ancestry proof;
4. the declared deterministic state/fixture and window identities; and
5. a sole exact PID per independently operated route.

Author evidence is admission material only. Quality will independently
operate the exact combined app and will not inspect uncommitted lane work,
coach the journey, crop defects, substitute identities, repair product code,
or reuse this baseline as a candidate score.
