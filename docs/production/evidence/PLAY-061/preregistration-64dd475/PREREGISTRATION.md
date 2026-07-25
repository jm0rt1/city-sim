# PLAY-061 Independent Commercial Skyline Preregistration

- **Disposition:** preregistered; no PLAY-060 candidate has been received or scored
- **Published authority:** `91f885925fd601786fa95dbb969b71fefef5ddcd`
- **Frozen accepted product baseline:** `64dd47500fe5e2d4a32a64f6298ded5789d3b773`
- **Accepted Commercial source authority:** `bf3e24b2b465870f131ac0a01a2327ac4969d5d5`
- **Lane:** `codex/citysim-playtest-quality`
- **Claim:** `PLAY-061`
- **Date:** July 25, 2026

This packet freezes the independent release gate before integration names an
exact PLAY-060 product candidate. It records baseline behavior and the
candidate-blind scoring contract. It is not a partial candidate inspection,
score, waiver, or acceptance.

## Product-read-only boundary

The quality lane did not modify `Native/CitySimNative`, build scripts, asset
sources, manifests, or shipping resources. The published authority has no
shipping-product or staging-script difference from accepted product
`64dd475`; the retained lane-staged bundle is therefore the exact accepted
baseline product. Legacy Python remains read-only reference.

PLAY-060 owns selection, normalization, packing, manifesting, directional
lookup, and renderer presentation of the accepted Commercial source set.
PLAY-061 will only admit a clean, exact integration-nominated candidate and
will independently operate and score that candidate.

## Frozen same-state baseline

The binding state is committed fixture
`Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/StoryStates/story-commercial-complication-v1.json`:

- SHA-256
  `fbcff0377fb1692595292cabd81c2ea70f2b69681a9964006078d031546fe03a`;
- schema/fingerprint version `1` / `1`;
- envelope digest
  `2a1b046eb21665206709415e3a1363aeaa0a9a4a60e83e1e1b52ae3c53b50ad4`;
- seed `42`, tick `128`, Day `33`, status `playing`;
- Main Street strategy, complication phase, loaded paused;
- exact selected target for comparison: state coordinate `(13,11)`, exposed
  to the player and AX as `Commercial block 14,12`.

Each comparison must use byte-identical fixture bytes, the City layer, the
same selected coordinate, a settled paused state, the same overlay, and the
same window/camera route. Authored topology or state changes may not be
presented as art improvement.

## Baseline behavior

The accepted shipping baseline has one generated Commercial identity:
`commercial_l01`, level 1, south frontage, `south-facing-fixed`. Both
`CityScene` and `LotRenderer` resolve every Commercial tile to that identity.
Consequently all Commercial levels and road directions collapse to the same
south-facing L1 asset. The live Day 33 comparison therefore records a grounded,
readable storefront but no directional or skyline progression.

The binding regular and compact city/neighborhood/block captures are
hash-distinct and transient-free. Regular frames are uncropped 1278 x 768
decorated-window captures. Compact frames are uncropped 900 x 652 decorated
windows with exact 900 x 600 content. Compact LOD captures use explicit
candidate-independent proof scales: city `0.576345682144165`,
neighborhood `0.52`, and block `0.45`.

## Frozen execution matrix

The final exact candidate will be exercised without coaching through:

1. regular and exact 900 x 600 compact closed-HUD Commercial comparison;
2. city, neighborhood, and block stops with Commercial block 14,12 selected;
3. all sixteen `L1-L4 x N/E/S/W` identities in color and grayscale;
4. Commercial-versus-Residential family recognition at matching level/LOD;
5. construction, maintained/degraded condition, selection, valid and invalid
   preview, placement, undo, save, terminate, relaunch, and load-paused;
6. all five overlays, Focus City enter/exit, and settled Reduce Motion;
7. pointer selection/placement, Return and Space activation, command/menu
   routes, FKA, semantic AX, focus generation, and topmost-first Escape;
8. three repeated LOD cycles plus unchanged pulses for identity stability,
   decoded residency, settled RSS, cold/update/render timing, and fallback
   diagnostics; and
9. focused renderer/asset tests, full native suite, governed staged verify,
   source/staged pack parity, and two-build deterministic pack identity.

Every binding visual must be an original-resolution, uncropped decorated
window paired with its complete AX tree, exact PID, process environment,
window content size, camera/LOD, state digest, selection, layer, and SHA-256.

## Frozen disposition bar

The exact candidate must:

- score at least **19/20**;
- earn **4/4** for Commercial identity/direction;
- earn **4/4** for whole-scene world/HUD cohesion;
- have no category below **3/4**;
- have zero P0/P1 defects and zero automatic rejects; and
- be materially preferred over the frozen baseline in both regular and exact
  compact same-state comparisons.

`RUBRIC.md` is the immutable category and automatic-reject authority.
`BASELINE-LEDGER.md` records the exact accepted product behavior and evidence.
`ledgers/commercial-direction-level-matrix.csv` freezes the sixteen required
identity rows.

## Candidate-wait handoff

Quality will not start candidate interaction until integration supplies:

1. exact combined product, renderer product, evidence, and completion commits;
2. proof that the accepted source authority `bf3e24b` is an ancestor;
3. a clean candidate worktree and exact ancestry graph;
4. exact lane-staged bundle, executable, Info.plist, staging manifest,
   generated-v4 manifest, atlas pages, and source-to-pack hashes;
5. the canonical 16-row logical-ID/frontage/level inventory, with zero
   alias/mirror/rotation/fallback;
6. one exact isolated PID/data root/preferences domain per route; and
7. author tests and diagnostics as admission evidence only.

Quality will not inspect uncommitted lane work, substitute a nearby candidate,
reuse author scoring, coach the route, crop defects, repair product code, or
self-waive a failure.
