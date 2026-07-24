# PLAY-022 Round 1E Live-Gate Blocker

- **Date:** 2026-07-23
- **Branch:** `codex/citysim-world-rendering`
- **Merge authority:** `ebfbcdf43c9b497b01869ba15206cb6f1daaa31e`
- **Merge result:** `b5f5d58695c8a0640ad792b1d884b93fc50bfc28`
- **Exact product:** `45dd181221701f7cb73be39b558b7440d86e13b5`
- **Candidate ID:** `world-rendering-w5f893ad1da1b`
- **Bundle ID:** `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- **Staged executable SHA-256:** `9d2f81ec4bf831f7420bf42a49fdfdebdb4c7952808be0bb43bee3f05d596eb5`
- **Candidate manifest SHA-256:** `4e4ad0e151c2bab3187260cabc96b64c59d4c126569a8af5267f851a42ec9d5d`
- **Packaged/source generated-v4 manifest SHA-256:** `eab12ce0838be9dca6ae00927accac60b15eb41617b39c0e33dd1e727e759692`
- **Disposition:** blocked before independent quality resubmission; not self-accepted

## Preserved renderer outcome

The focused product commit replaces the oversized spatial-event ring with a
small frontage cue, preserves committed selection as a separate grounded
boundary, removes translucent/green remote-road styling, gives single-edge road
ends deterministic landscaped turning heads, and adds five bounded ambient
frontage vignettes using existing generated-v4 textures. It changes only
renderer-owned sources and tests; no SwiftUI view, store, command, simulation,
save, package, or build-script surface changed.

The exact staged default and 900 x 600 clean frames show the corrected physical
road language, authored endpoints, retained developed mass, and additional
vegetation, pedestrian, and service context.

## Named live-gate failure

The required pointer, keyboard, placement, and accessibility parity does not
hold because the shared one-active-placement-target contract is still absent:

1. At default size, pointer hover displayed an invalid red Residential preview
   at one visual coordinate while keyboard selection and the map accessibility
   value announced block 16,12 as available. The invalid pointer ghost and valid
   keyboard boundary were visible simultaneously in
   `live/08-default-valid-placement-keyboard.png`.
2. At exact 900 x 600, keyboard navigation announced block 16,14 as available.
   Clicking a different visibly occupied coordinate committed Residential at
   the keyboard-selected block 16,14 instead. The resulting construction site
   is retained in
   `live/11-compact-pointer-click-commits-keyboard-target.png`.
3. Undo restored the pre-action state, retained in
   `live/12-compact-undo-restores.png`.

This is the previously proposed CONTRACT-008 active-player-intent dependency.
The Round 1E dispatch explicitly forbids implementing CONTRACT-008 in the world
renderer. Independent visual scoring cannot judge a candidate whose named
interaction/AX gate contradicts itself.

`live/06-default-hover-only.png` retains the attempted click-then-Escape
hover-isolation flow for forensic completeness; the accessibility tree remained
selected, so that file is not claimed as accepted hover-only proof.

## Verification completed before the blocker

- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed at the exact product.
- `CITYSIM_COMPACT_WINDOW=1 ./script/build_and_run.sh --verify`: passed and
  launched exact 900 x 600 content.
- Focused `WorldRenderingTests`: 36/36 passed.
- Renderer diagnostics: default 1,138 nodes / 406 drawables; compact 1,129 /
  397; two ambient actions normally and zero with Reduce Motion; generated-v4
  residency stayed at 28 textures / 13,521,048 decoded bytes with zero fallback.
- Pulse soak: 4,286 pulses, stable nodes/actions, average renderer update
  approximately 0.0032 ms; ten-pulse diagnostic average 0.919 ms.
- Product diff check: passed.

The first full native run executed 166 tests and found one failure in the
integration-owned
`CityCommandCatalogTests.testExactCompactRetainsSemanticMapIdentityKeyboardSelectionAndEscapeFocus`
assertion at line 506. The exact test failed again unchanged on the Round 1E
product and on the clean pre-product merge result `b5f5d58`, proving it is an
inherited merged-baseline failure rather than a renderer-product regression.
No SwiftUI/store repair was attempted outside the lane.

The cold samples observed during non-governed mixed test runs were 3.983,
4.967, 6.326, and 4.318 ms. They are not substituted for the preregistered
governed series. Governed cold, memory, LOD cycling, overlay, Reduce Motion, and
final completion proof intentionally stopped after the named live gate failed.

## Required integration decision

Publish and integrate the approved one-active-placement-target contract so
pointer hover/click, keyboard selection/Return, placement overlay, and the map
accessibility value all resolve the same coordinate and availability reason.
Then rerun Round 1E live proof, the inherited compact-focus test, the full native
suite, governed cold and memory series, and independent PLAY-052 scoring.

No Round 2, PLAY-023, push, integration, or self-score occurred.
