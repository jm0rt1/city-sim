# PLAY-073 direct world-composition evidence

## Candidate identity

- Baseline commit: `8208366b9c19b3b0ccd5e0e50edc59db1cc90709`
- Branch: `codex/citysim-world-rendering-play073-direct8208366`
- Worktree: `/private/tmp/citysim-play073-renderer-direct8208366`
- Scope: renderer framing, shared world palette, terrain/public-realm presentation, and focused renderer assertions only.
- Simulation state, save behavior, gameplay cells, road/building geometry, topology, hit targets, generated art, manifests, and building renderers were not changed.

## Same-state visual comparison

The deterministic shipping-start renderer harness exported both viewport classes from the same seed-42 state before and after the candidate.

| Viewport | Before | After | Framing result |
| --- | --- | --- | --- |
| Regular 1280x800 | [before-regular.png](before-regular.png) | [after-regular.png](after-regular.png) | Developed occupancy width increased from `0.6633707860` to `0.7280899126`; scale changed from `0.7047830224` to `0.6421356201`; detail changed from `city` to `neighborhood`. |
| Compact 900x600 | [before-compact.png](before-compact.png) | [after-compact.png](after-compact.png) | Framing remained stable at occupancy `1.0201732615`, scale `0.6549999714`, and `neighborhood` detail. |

Visual assessment: the regular aperture is tighter around the developed corridor without hiding its road network. Warm-charcoal roads and warm-stone curbs/sidewalks now anchor the scene; muted sage terrain, subdued lot rectangles, low-alpha regional variation, and the darker map rim reduce the former broad olive-field impression. Building sprites and truthful sparse development are unchanged.

### Screenshot identities

| File | Pixels | SHA-256 |
| --- | ---: | --- |
| `before-regular.png` | 2560x1600 | `caf3eada1811cd9a378847765e386f7db19fd8fcbc0596ebe79bfe29c1f70d10` |
| `before-compact.png` | 1800x1200 | `0b3d2a4658bfb103a872f8e16ce73d7c656c06e8bc4caa6cb84949a983a2daeb` |
| `after-regular.png` | 2560x1600 | `724cfee769733f4510e9af9ae814c81bdd0ef0286ce1b7277d58f0f710e78cea` |
| `after-compact.png` | 1800x1200 | `d120b7c7ba7a5df843ded44c1c2e649f423e98c47867ebd437aedde11046c958` |

These are deterministic renderer-harness exports, not independent playability acceptance or release evidence.

## Focused proof

1. Baseline screenshot export: `WorldRenderingTests/testRoundOneShippingStartExportsDevelopedBoundsDefaultAndCompact` — PASS, 1 test, 0 failures.
2. First candidate camera/composition attempt — RETURN, 5 tests with 4 assertion failures. The renderer output was internally consistent, but three focused assertions still encoded the old LOD/scale relationship. No product repair was required.
3. Single bounded assertion repair, then camera/composition rerun — PASS, 5 tests, 0 failures:
   - `testRoundOneShippingStartExportsDevelopedBoundsDefaultAndCompact`
   - `testStartingCameraFramesTheDevelopedCoreAtDefaultAndCompactLODs`
   - `testOpeningCameraRefitsOnceAfterTheShippingViewportSettles`
   - `testDevelopedCoreCameraSurvivesViewportInvalidationPermutations`
   - `testIndustrialStrainCameraPrioritizesTheDominantDistrictWithoutHidingRemoteTruth`
4. `PLAY073DistrictFabricTests` — PASS, 5 tests, 0 failures. This preserves 121 backdrop patches, exactly three regional materials, buildable district fabric, road-mask topology, deterministic regular/compact masks, and the conservative green-mass ceiling.
5. `git diff --check` — PASS.

## Staged-app smoke

`script/build_and_run.sh --verify` built and launched the isolated candidate bundle successfully:

- Candidate ID: `world-rendering-play073-direct8208366-wc1868b098e2d`
- Bundle ID: `com.jfmortensen.citysim.world-rendering-play073-direct8208366.wc1868b098e2d`
- Data root: `/private/tmp/PLAY-073-direct8208366-dist/test-data/world-rendering-play073-direct8208366-wc1868b098e2d`
- Process: PID `14904`, observed running, then terminated by exact PID; subsequent process lookup returned no process.

This is a focused candidate smoke check. Integration, independent playability review, acceptance, push, and release remain out of scope.
