# PLAY-068 Candidate-Blind Wave 008 Preregistration

- **Disposition:** preregistered; no PLAY-064/065/066/067 product candidate
  received, inspected, or scored
- **Published authority:** `0ed9f3a8ad28d6b29f734c97f3dd3111fd118cc6`
- **Frozen comparison product:** `1b883ca684b07ba38c5c755b616723bde0cd2230`
- **Lane / claim:** `codex/citysim-playtest-quality` / `PLAY-068`
- **Date:** July 25, 2026

This packet freezes the independent Wave 008 release gate before integration
names a combined candidate. It contains only the accepted comparison product,
approved contracts, real-app baseline evidence, immutable scoring method, and
future execution protocol. It is not an early product inspection, a partial
score, a waiver, or an acceptance.

## Read-mostly boundary and product parity

Quality did not modify `Native/CitySimNative`, legacy Python, source art,
shipping resources, build scripts, manifests, fixtures, or contracts. The
active product/build tree at `0ed9f3a` is byte-identical to the frozen
`1b883ca` comparison:

```text
git diff --quiet 1b883ca..0ed9f3a --
  Native/CitySimNative
  script/build_and_run.sh
exit 0
```

The intervening commits publish Wave 008 governance and claims. PLAY-064 owns
the post-Charter rules/content, PLAY-065 owns transient authoritative activity,
PLAY-066 owns world presentation, and PLAY-067 owns HUD/input composition.
PLAY-068 owns only candidate-blind admission, independent operation, retained
evidence, defects, and disposition.

## Frozen same-state comparison

The binding comparison state is:

`Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/StoryStates/story-industrial-complication-v1.json`

- SHA-256:
  `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`;
- schema/fingerprint version `1` / `1`;
- envelope digest:
  `a43611573cd888edba5292b9740b8a4e15f05e9cfd50edf73648427eaf775c5a`;
- seed `42`, tick `128`, Day `33`, status `playing`, loaded paused;
- Freight strategy, complication phase, next scheduled tick `192`;
- treasury `$34,036.80`, population `332`, jobs `231`; and
- selected state coordinate `(14,11)`, exposed as `Industrial block 15, 12`.

Every candidate A/B must use byte-identical fixture bytes, City layer, selected
coordinate, settled paused state, matching overlay, and the exact route-specific
window/camera. Changed state, topology, camera, selection, HUD mode, overlay, or
transient cannot be described as presentation improvement.

## Frozen real-app routes

The exact staged quality app loaded the comparison quicksave from fresh
isolated roots. Command-O loaded the save, the load/action toast was allowed to
expire for at least 5.5 seconds, and four keyboard Right presses selected
Industrial block 15,12.

Binding captures are original-resolution decorated windows:

- regular: 1278 x 768 captured output from the explicit regular route;
- exact compact: 900 x 652 decorated output around 900 x 600 app content;
- regular LOD stops: city `0.85`, neighborhood `0.65`, block `0.50`;
- exact compact block stop: `0.45`;
- normal HUD, open Details, Focus City, all five overlays, command guide,
  keyboard focus, and compact Reduce Motion; and
- full paired AX state for the selected coordinate and critical surfaces.

The command-guide screenshot is a supplemental uncropped system sheet
capture, 620 x 560. It is not used as a same-state world-composition frame.
All other binding images are full decorated windows and contain no
load/action/cancellation toast. The persistent `Utilities` priority action is
authentic HUD truth and remains visible.

## Candidate execution matrix

Once integration names an exact clean combined candidate, quality will:

1. prove exact ancestry, bundle, executable, manifest, resources, defaults
   domain, data root, process, window, fixture, digest, camera, and selection;
2. reproduce this comparison at regular and exact compact widths, all three
   LODs, normal/Details/Focus, five overlays, construction/selection/preview,
   strain and recovery, and normal/Reduce Motion;
3. operate one fresh no-coaching 20-minute journey plus both Commercial and
   Industrial post-Charter routes and their distinct recovery branches;
4. prove consecutive daily qualification, failure reset, one-time Regional
   Capital recognition, undo, save/terminate/relaunch/load-paused, backup
   recovery, and deterministic replay;
5. compare zero, low, high, recovery, and nil local street/place activity
   against authoritative snapshot values, including suppression and wording;
6. measure normal, Focus City, and open-Details map aperture at both widths;
7. traverse pointer, keyboard, command guide search, application menus,
   topmost-first Escape, focus restoration, FKA, AX, text quarantine, and
   Reduce Motion; and
8. independently run pack/geometry validators, deterministic two-build
   comparison, focused/full native suites, staged verify, repeated LOD
   residency/RSS, cold/update/render timing, and unchanged-pulse soak.

## Frozen bar

The exact candidate must:

- score at least **19/20**;
- earn **4/4** in world/public-realm/activity coherence;
- earn **4/4** in game/HUD cohesion and map aperture;
- have no category below **3/4**;
- have zero P0/P1 defects and zero automatic rejects; and
- be materially preferred to `1b883ca` in both regular and exact compact
  same-state comparisons.

`RUBRIC.md`, `JOURNEY-PROTOCOL.md`, and the ledgers are immutable execution
authority after this packet is committed.

## Candidate-wait handoff

Quality will wait for integration to provide:

1. exact combined commit and clean ancestry graph;
2. exact accepted PLAY-064/065/066/067 product/evidence/completion commits;
3. exact staged bundle, executable, resource bundle, manifests, hashes, and
   candidate-specific identity;
4. machine-readable second-act, activity, pack, geometry, collision,
   residency, fallback, timing, and deterministic-build inventories; and
5. author tests and screenshots as admission inventory only.

Quality will not inspect an uncommitted lane worktree, substitute a nearby
commit or bundle, reuse author scoring, coach a player, crop a defect, repair
product/source, push, integrate, self-waive, or self-accept.
