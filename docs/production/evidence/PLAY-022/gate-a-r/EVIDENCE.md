# PLAY-022 systemic Gate A-R evidence

Disposition: **candidate awaiting independent integration/playtest scoring**.
This record does not accept Gate A-R and does not close PLAY-022.

## Candidate identity

- Branch: `codex/citysim-world-rendering`
- Exact staged product/evidence checkpoint: `4887ebad9519fccb08844e2746f9bfbbc93aaa4d`
- Authority ancestor: `4fe0df5`
- Candidate: `world-rendering-w5f893ad1da1b`
- Bundle: `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- App: `dist/CitySim-world-rendering-w5f893ad1da1b.app`
- Packaged resources: `dist/CitySim-world-rendering-w5f893ad1da1b.app/CitySimNative_CitySimNative.bundle`
- Candidate manifest: `dist/manifests/world-rendering-w5f893ad1da1b.manifest`
- Candidate-manifest SHA-256: `36e864683749ba02dd51cdc4831b2efffaaeef34a336498999ba77a4d6ec7291`
- Generated-v4 manifest SHA-256: `838961bc08cee4492c3ebe5be4fedb1931468af74ab8eee589e84484fd7553b6`
- `4887eba` has the same product tree as the fully tested `fed1380`; `f14b8bb`/`4887eba` record and then remove an ineffective allocator-pressure experiment with no net product diff.

## Ordered systemic repair commits

1. `6bbe37a` merge published systemic-repair authority.
2. `254d635` lock transparent 2:1 footprint/socket/pivot/light geometry.
3. `852e252` establish the minimal manifest-v4 calibration ingestion spine.
4. `06a6fa0` retain the nine distinct ImageGen sources, prompts, provenance, cleanup, and rejections.
5. `98dddaa` compose separate semantic objects and deterministic road topology in shipping `CityScene` with the rejected plate disabled.
6. `b3c147e` eliminate unchanged-pulse renderer churn.
7. `e32f1f3` preserve incremental tile reuse.
8. `6a4cb59` frame the developed city at the real starting camera.
9. `faa534d` avoid duplicate SpriteKit mip chains for explicit LOD exports.
10. `c43872b` right-size calibrated LOD exports and scale the deterministic road-material crop.
11. `fed1380` replace oversized transition graffiti with compact grounded feedback.
12. `f14b8bb`, `4887eba` preserve and remove a measured ineffective allocator-relief experiment; final tree equals `fed1380`.

## Generated calibration set and provenance

Exactly nine built-in ImageGen calls produced: grass material, road material,
residential frontage, L1 residential, L1 commercial, L1 industrial, park,
city hall, and water tower. Each accepted raw source is retained under
`WorldArt/GeneratedV4/ImageGen/raw/calibration/<logical-id>/source-v01.png`;
the corresponding prompt and provenance/normalization JSON are retained under
`ImageGen/prompts/calibration/` and `ImageGen/provenance/calibration/`.
`ImageGen/rejections.jsonl` records rejected attempts/reasons. No raw sheet
ships. Road masks, curbs, crossings, sockets, and frontage joins are compiled
deterministically rather than generated as gameplay geometry.

The production manifest contains 9 semantic assets and 75 inventory entries:
27 semantic LOD exports plus 48 deterministic road masks. Semantic LODs are
1024x683 block, 512x342 neighborhood, and 256x171 city, with a combined decoded
estimate of 33,057,792 bytes and runtime mipmaps disabled.

## Validation

- `bash -n script/build_and_run.sh`: pass.
- `./script/build_and_run.sh --verify`: pass at exact `4887eba`; staged resource manifest/probe present.
- Focused `WorldRenderingTests`: 24/24 pass in 161.094 s after the LOD repair; exact-final tree's renderer block also passed 24/24 in 164.618 s inside the final full run.
- Full suite on the exact-final product tree (`fed1380`, identical to `4887eba`): 121/121 pass in 277.880 s.
- Diagnostics: initial 576 tiles / 10,206 nodes; ten changing pulses reused 5,759 tiles and updated 1; average changing render 1.145 ms; final 10,207 nodes.
- Thirty-minute unchanged soak: 4,286 pulses, 10,206 nodes, 2,426 drawables, 5 bounded actions, 0.0003 ms average unchanged pulse.
- Golden fixture: 1,597 nodes, 526 drawables, 0 actions under Reduce Motion.

## Live staged flows

The retained uncropped packet covers default, exact 900x600 content (900x652
including the 52 px title bar), distinct block/neighborhood/city thresholds,
utilities overlay, selection, valid and invalid road placement, commit, exact
undo, Reduce Motion static meaning, grayscale, same-seed A/B, and the start/end
of a continuous frame/zoom/shift-navigation sequence. The exact-final placement
route changed treasury `$25,698 -> $25,578` and cashflow `-$67 -> -$71`; Command-Z
restored both exactly and disabled Undo. Accessibility exposed the city-map
selection, primary action, cost, block reason, overlay, HUD metrics, and toolbar
state. Hit testing remained stable across zoom and shifted navigation.

Reduce Motion retained non-color static meaning and zero transition actions.
Direct screen recording failed before producing a file, so the packet retains
the exact start/end frames and records the exercised live sequence rather than
claiming a movie.

## Memory and performance limitation

- Comparable fresh compact process: 253,776 KiB RSS; 324.3 MiB physical footprint; 339.5 MiB peak.
- Fresh regular process on the final product tree: 609,168 KiB RSS; 475.0 MiB physical footprint.
- A long regular all-LOD/capture traversal reached 936,640 KiB RSS / 707.7 MiB physical footprint. `vmmap` attributed 629 MiB to empty `MALLOC_SMALL` pages in that session.
- An explicit allocator-pressure-relief experiment did not improve the regular result and was removed in `4887eba`.

Compact current RSS is within the recorded baseline-plus-128-MiB threshold;
regular-window RSS is not. This is an unresolved, disclosed scoring limitation,
not an approved regression. Independent review must decide Gate A-R disposition.

`SHA256SUMS` authenticates every retained proof image. The historical rejected
plate and its 12/20 evidence remain separate and are not production geometry.
