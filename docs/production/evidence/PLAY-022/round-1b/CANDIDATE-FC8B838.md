# PLAY-022 Round 1B corrective candidate — `fc8b838`

**Disposition:** exact product candidate and proof packet preserved, but PLAY-022
remains active and returns to renderer engineering. The authority-ordered final
five-sample cold window passed its median criterion but failed its 4/5
criterion, so this record does not mark the round ready, self-accept the
visuals, request PLAY-052 scoring, or authorize Round 2 or PLAY-023.

## Exact identity and authority

- Branch: `codex/citysim-world-rendering`
- Product commit: `fc8b838d6d33ee8091ce6c54c125ea0cee279f5b`
- Product tree: `1277422dabd28c67469b11516ba06692f978bc1a`
- Synchronization merge: `9993245cc519be67b42406e073dc785643799be7`
- Published authority ancestor: `5df04fa4f4ac908e50e20a3f4cb1bc84ad883daf`
- Rejected predecessor: `3c44905467de4a6629098f6be51d0ac90f56f5f0`
- Predecessor audit: `717b286c7bcb62911aed9358ad36d9022833d8b9`
  (`13/20`, rejected)

## Ordered Round 1B product commits

1. `ed67261b488c7666f8a6945b9b53fd11e3fe0d54` — Center the truthful developed city
2. `a6249815fb7fa24c3545150c20d5da09512a428d` — Trim generated world residency
3. `a71d4d6b89d3fca690b3b2375c595b61b48a7972` — Resolve map hits from isometric geometry
4. `eea94be2053e1543c329b2157e3a0d7ba621ecae` — Make developed mass dominate the frame
5. `503e22d3c3c80632307cd9121713f6be7d0d9c72` — Keep compact framing interaction-safe
6. `1f91f71a4edf0a4c2b356f4f37d9cd6c2a066a6b` — Bound ambient motion residency
7. `432592242f86402a9ca75ce82319e310f094a915` — Bound compact ambient residency
8. `860b9e93329299b37f12939af320c19eeae9ad0e` — Keep city LOD composition legible
9. `fc8b838d6d33ee8091ce6c54c125ea0cee279f5b` — Bound SpriteKit render surfaces

The trim/loader checkpoint and inverse-isometric resolver are intentionally
separate durability boundaries. The resolver is geometry and hit-test
correctness only; it does not implement CONTRACT-008 active player-intent
targeting.

## Player-visible outcome

Automated camera diagnostics report occupied visual mass separately from the
larger road/opportunity rectangle:

| Fixture | Detail | Occupied mass | Network context | Limiting occupied axis |
|---|---|---:|---:|---:|
| 1280 x 800 | block | `0.624132 x 0.850377` | `1.482314 x 1.703555` | `62.41%` |
| 900 x 600 | neighborhood | `0.540000 x 1.220904` | `1.282500 x 2.445830` | `54.00%` |

Both limiting occupied axes exceed the directive's 45% numerical gate. The
exact staged packet retains default and exact 900 x 600 city, neighborhood,
and block frames; pointer and keyboard selection; valid/invalid placement;
commit and undo; utilities overlay; Reduce Motion; save/load; and one app-only
pan/zoom sequence. The same Residential coordinate `(16, 14)` is retained at
0, 25, 50, 75, and 100 percent construction with matching accessibility text.
Independent review must still judge composition, LOD usefulness, transition
fluidity, and interaction legibility.

The integrated rejected-predecessor frame remains at
`docs/production/evidence/PLAY-051/PLAY-022-round-1-3c44905/live/default-after-construction-undo.jpeg`.
It is retained as the historical comparison anchor, but its 1278 x 768 capture
does not match the current 1229 x 768 default capture. This packet therefore
does not claim a pixel-identical same-camera A/B pair.

## Staged identity and packaged resources

- Candidate ID: `world-rendering-w5f893ad1da1b`
- Bundle/preference domain:
  `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Canonical manifest SHA-256:
  `7bd817949baf5e87ce92f495e51450699e039fbbbcf4460eed75dcc55d1f6c79`
- Canonical executable SHA-256:
  `8f202e62c36bb277212d06fde08fe6e45621759a57eec7287d02094c387c7f4c`
- Generated-v4 manifest SHA-256:
  `900287027256d7f5ea960b7b17c9208f3ff990de532feb87448eb01328076e78`
- Exact proof data root:
  `dist/test-data/world-rendering-w5f893ad1da1b-round1b-fc8b838`
- Quicksave and backup SHA-256:
  `1e1410070a19e2291ceee35aa8523bb49bf1b1a3d8ab7473c936b91330082693`
- Saved-state digest:
  `9e2f234316b9332c90fde2295acfff305386b67a84ad26e0ab5e0a703006f7cd`

Candidate isolation passed in two disposable shared clones. Source, canonical
bundle, and both candidates retained the same 159-file world-resource
inventory with digest
`64fa52246102f5e298bed63ec949c2504729abeccaa10f8a8849ee3f06aa4361`.
No isolation process remains.

## Geometry, reuse, and residency

- Geometry validator: 616 checks, zero collisions and zero failures.
- Road seams: 1/1 passed across 16 masks and three semantic LODs; zero fallback.
- Repeated-LOD high water: 28 textures, 13,521,048 decoded bytes, zero fallback.
- Ten pulses: 1,932 initial nodes, 1,935 final nodes, 5,759 reuses, one update,
  and 1.582 ms average changed-pulse time.
- Unchanged soak: 1,932 nodes, 758 drawables, one bounded action, and 0.0025 ms
  average pulse time.
- Reduce Motion: zero actions in automated diagnostics.

## Validation and timing disclosure

- Full native suite: 135/135 passed.
- Focused renderer runs: 35/35 functional tests in every controlled sample.
- Focused resolver: 3/3 passed.
- Script syntax, candidate isolation, and `git diff --check`: passed.

The initial focused run occurred amid concurrent test/evidence work and failed
at 16.573 ms golden update and 6.280 ms separate cold total. It remains in the
packet. Four later whole-class samples reported separate cold totals of 5.544,
5.392, 8.781, and 5.277 ms. Sample three captured an unrelated Playwright
Chrome renderer at 93.8% CPU; it is retained, not discarded. The strict first
three-sample disposition is therefore **2/3 passing** and the expanded retained
series is **3/4 passing**. All four golden-update portions were at or below
6.03 ms. Under the directive's automatic gate this is not wholly green and
requires integration disposition or a newly authorized measurement window.

## Physical footprint

After three LOD cycles and a 60-second settle, exact staged measurements are:

| Window | Physical footprint | RSS | Ceiling | Result |
|---|---:|---:|---:|---|
| exact compact 900 x 600 | 236 MB | 102,896 KiB | 333.8 MiB | pass |
| regular 1278 x 768 | 300 MB | 274,768 KiB | 333.8 MiB | pass |

The retained reports also disclose process-lifetime peaks of 363 MB compact
and 396 MB regular. A separate long interactive default session settled at
319 MB after extensive proof capture and reported a 431 MB lifetime peak; it
is supporting context, not substituted for the governed regular sample.

## Evidence index and boundaries

- `geometry-fc8b838/` — collision JSON, logs, and road-seam mosaic
- `isolation-fc8b838/` — exact candidate/resource isolation packet
- `tests-fc8b838/` — focused/full tests and complete timing disclosure
- `live-fc8b838/` — exact staged screenshots, AX text, video, and memory reports
- `supporting-fc8b838/` — deterministic grayscale and color-vision sheets

CONTRACT-008 remains unchanged at blob
`bc519df6974c80ff9b1f2cc9e516882dd62dc407`. Round 2 and PLAY-023 remain
unauthorized.

## Final preregistered cold disposition

Authority `52fc2c17643e7987f78bc360196599e3297967da` authorized exactly
one final five-sample window while freezing this product commit and resources.
The window used a new build/cache root, one prebuild, the same whole-class
`--skip-build` command for all five samples, a 30-second idle before every
prerecord, and no replacement samples or unrelated-process termination.

Ordered cold totals were `5.729, 5.943, 6.579, 6.253, 5.910 ms`. The median
`5.943 ms` passed, but only 3/5 totals met `6.03 ms`; no total exceeded
`9.045 ms`. Every prerecord disclosed material unrelated CitySim and/or XCTest
load. Sample 1 also retained a separate golden-update assertion miss at
`6.147 ms` even though its governed cold total passed at `5.729 ms`.

The complete ordered logs, environment/process/thermal/memory prerecords,
method, result JSON, and hashes are under
`tests-fc8b838/preregistered-five-2026-07-22/`. The final cold window therefore
fails and returns PLAY-022 to renderer engineering. The candidate is not sent
to PLAY-052, and no broader product work or additional measurement is
authorized by this record.
