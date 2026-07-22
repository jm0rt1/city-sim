# PLAY-051 independent PLAY-022 Round 1 visual gate

**Disposition:** REJECT

**Independent score:** 13/20. Acceptance requires at least 17/20 and no category below 3.

**Audit date:** 2026-07-21 EDT

## Exact candidate admission

- Shared authority merged into quality lane: `c3c0f4ad109791fe5a90dd120b98a9812ff685e2`.
- World branch: `codex/citysim-world-rendering`.
- World evidence HEAD: `0f9841ad29860b60d2a3b32f970581fadc50ff19`, clean before and after the audit.
- Product commit: `3c44905467de4a6629098f6be51d0ac90f56f5f0`, verified as an ancestor of the evidence HEAD.
- Rejected comparison baseline: `8cb45b5848f070c25803213ee48b2523e8057d09` (comparison only).
- Staged bundle: `/Users/James/.codex/worktrees/cac1/city-sim/dist/CitySim-world-rendering-w5f893ad1da1b.app`.
- Candidate ID: `world-rendering-w5f893ad1da1b`.
- Bundle/defaults identity: `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`.
- Executable SHA-256: `3a834dee98eddbf7d03536611a9918474372fa19212b4815f1df9d39075b1b02`.
- `Info.plist` SHA-256: `f2a807f26fb559d5a505f2a15282d4b49e09de2c3887ca8fd35389d170387a72`.
- Candidate manifest SHA-256: `15ddcdeda4c21beb8e59dbce90caf26ae13208671b0a1164d3f50788826091c4`.
- Packaged generated-v4 manifest SHA-256: `afedf49fc0df87fa67733dd1b6a990aabcf22e77051425c78da222153353c93a`.
- Packaged base world manifest SHA-256: `411934e492a66216787f8c93dd91d3f68cc16637110dba9ed7186b22dda96d3d`.
- Independent isolated data root: `/private/tmp/play051-round1-3c44905.niWYJm`.
- Independent regular PID: `73930`; command matched the exact staged executable; final RSS `121,408 KiB` after 05:22.
- Independent exact-compact Reduce Motion PID: `89101`; command matched the exact staged executable. The live frame was 900x652 pixels, proving 900x600 content plus 52 pixels of title-bar chrome.
- Compact Reduce Motion RSS: cold transient `663,552 KiB`, `361,568 KiB` at 00:33, `136,016 KiB` after three LOD cycles, and `87,888 KiB` at 03:45. It settled below the 322.9-MiB ceiling and did not show continuing high-water growth.
- Both independent PIDs were terminated exactly. No other process was touched.

## Independent operation

The exact staged app was operated with pointer and keyboard at regular default and exact compact. The audit covered pause, city framing, pointer pan, keyboard selection, valid and invalid Residential preview, keyboard commit, construction at 0 percent and completion, Cmd-Z undo, Utilities overlay, three repeated camera-detail cycles, and Reduce Motion. AX exposed the selected coordinate, kind, lifecycle, authoritative validity, cost/upkeep, one disabled reason, and construction progress.

The frozen candidate packet's same-state regular city/neighborhood/block frames, exact-compact frames, grayscale states, seam mosaic, collision reports, manifest/residency reports, and 41-second 1-fps pan/zoom recording were inspected as supporting evidence. Author conclusions were not adopted as scores.

Independent focused validation:

- `swift test --package-path Native/CitySimNative --filter CitySimNativeTests.WorldRenderingTests`: **30/30 passed**, 0 failures, 20.062 seconds.
- The rerun emitted 3,616 nodes / 1,398 drawables at default and compact, 41,959,424 decoded resident bytes, zero fallbacks, and a 40.046-ms cold golden-fixture marker.
- `git diff --check` passed in the clean world worktree.

## Score

| Category | Score | Independent finding |
| --- | ---: | --- |
| Composition and map occupancy | **2/4** | The quiet terrain and HUD-safe framing are cleaner, but the default and city stops still read as a small toy island: roughly seven buildings and a few props cluster at one crossing while long empty roads and green acreage provide most of the measured 55–70% bounds. The calculated corridor occupancy does not produce believable developed visual mass. |
| Projection, material, light, and road coherence | **3/4** | Northwest light, southeast contact shadows, 2:1 projection, curb/sidewalk treatment, frontage, and deliberate rounded termini are consistent. No visible road seam or opaque collision was reproduced. The extremely flat macro terrain/road treatment remains noticeably simpler than the painterly architecture, and small lot plates are still perceptible at block scale. |
| Useful city/neighborhood/block LOD and depth | **3/4** | The three retained stops are distinct: block reveals curb markings, crossings, people, vehicles, entrances, and material detail; neighborhood and city simplify them without contact drift. The useful information gain is modest and the city stop mainly makes an already-small settlement smaller. Independent pointer pan worked continuously; Computer Use could not deliver an independent wheel-zoom gesture, so transition-fluidity relies partly on the retained 1-fps recording. |
| Believable life, state, and interaction restraint | **3/4** | Grounded selection, sparse Utilities marks, one invalid hatch, construction, a parked vehicle, pedestrians, and vegetation remain subordinate to the place. The starting city still feels lightly inhabited rather than alive, especially above block scale. The active-placement-target contradiction is excluded from this score as directed. |
| Systemic shipping credibility and performance | **2/4** | Focused tests, collision counts, zero fallbacks, 40.0 MiB decoded high-water, settled independent RSS, undo, AX, and Reduce Motion are credible. Shipping confidence remains insufficient because retained macOS footprints are 362 MiB compact / 397 MiB regular, the independently rerun cold fixture is 40.046 ms versus the 5.025-ms baseline, candidate isolation is deferred, and required proof is incomplete. |

**Total: 13/20 — REJECT.** Categories 1 and 5 are below 3, and the total is four points below threshold.

## Automatic-reject checklist

| Condition | Result | Evidence / disposition |
| --- | --- | --- |
| Mostly empty city/default frame or toy-island composition | **REPRODUCED — automatic reject** | Independent default and exact-compact city stops plus the retained three-LOD mosaic. Long roads satisfy bounds while developed mass remains a tiny central cluster. |
| Visible unintended building/building, building/road, entrance, or ground overlap | Not reproduced | Live regular/compact pan and block inspection; deterministic reports retain 0 reciprocal and road collisions. |
| Road seam, pasted strip, broken crossing, or unexplained terminus | Not reproduced | Continuous pointer pan and seam mosaic; termini use a consistent rounded/socket treatment. |
| Mixed/fallback art language | No silent fallback reproduced; partial visual mismatch | Manifest/test evidence reports zero fallback. Flat terrain/roads versus painterly buildings costs one coherence point but was not classified as a separate automatic reject. |
| Selection, construction, or overlay obscures the place | Not reproduced | Grounded selection, sparse overlay, and construction remained legible at both sizes. |
| Duplicated rejection copy or debug-glyph clutter | Not reproduced | One AX/store reason; no baseline beam forest or floating debug labels. |
| Over-budget settled RSS, decoded residency, or continuing high-water | Not reproduced for the governed RSS method | Independent settled RSS and 40.0-MiB decoded high-water passed. The separately retained allocator footprints exceed 333.8 MiB and remain a blocking authority question; no exception is inferred. |
| Silent fallback, orphan resource, or unbounded residency | Not reproduced | 30/30 focused tests, zero fallbacks, 28 resident textures, bounded post-cycle RSS. |

## Binding non-score blocker

The PLAY-051 active-placement-target contradiction reproduced exactly and remains a final-integration blocker outside the visual score:

1. Keyboard selection at open block 15,14 was AX-authoritative and valid for Residential.
2. The visible red invalid ghost/hatch remained over pointer-hovered occupied block 14,14.
3. Moving keyboard selection to 14,14 made AX and the red invalid preview agree.
4. Returning to 15,14 and pressing Return built successfully while the stale pointer-target preview could still describe the neighboring tile.

Expected: visible preview, AX, pointer activation, and Return each identify their distinct target or share one authoritative active placement target without contradiction. Owner: integration-controlled renderer/store command-target contract.

## Blocking limitations

- The required packet omits a separately retained 25-percent construction frame and exact same-coordinate 100-percent frame. Independent live proof added 0-percent and completed observations but did not capture the missing 25-percent stage.
- No declared common color-vision-simulation contact sheets were found; grayscale alone does not satisfy that proof requirement.
- Candidate isolation remains deferred in the candidate record.
- The compact LOD stills are same-seed, not same-state; the regular LOD sequence is same-state.
- The pan/zoom recording is 1 fps. Independent pointer pan succeeded, but wheel zoom could not be injected through Computer Use, so fluid zoom transition quality is only partially independently reproduced.
- Retained compact/regular allocator footprints are 362/397 MiB, with 382/402 MiB peaks. If the explicit memory ceiling governs `footprint` as well as same-method RSS, this is an additional automatic reject.
- The cold golden-fixture marker reran at 40.046 ms versus the accepted 5.025-ms baseline, despite passing steady-state pulse gates.

## Retained independent evidence

- `live/default-after-construction-undo.jpeg`, SHA-256 `7966d745190f0fc3fe8848f3d7fb3fe56400ba41c35be92fb120b7ec42927474`.
- `live/compact-900x600-reduce-motion-city-after-lod-cycles.jpeg`, SHA-256 `5a0688c7aeac2dc2489fe15f1af8f08af00c17f98bd3650115a23f3ac515237d`.

The rejected `8cb45b5` comparison showed the prior oversized overlap, terrain-diamond seams, beam/glyph clutter, and inconsistent stacking. Round 1 removes those defects, but replacing them with a sparse central diorama does not meet the production-world composition gate.
