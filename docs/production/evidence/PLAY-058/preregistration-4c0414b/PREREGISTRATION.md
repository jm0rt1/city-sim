# PLAY-058 Living-City Release Gate Preregistration

## Authority and boundary

- Quality claim: `PLAY-058`
- Published claim head: `22f6d7c6422d88ad0c3ef2fc95eb70050e575cec`
- Frozen product baseline: `4c0414b003a178948c62128f425b6d534ac2e7a7`
- Product-tree object at both commits:
  `2ccdf2cbac36688aef7deeefd95d87f9608c7bac`
- Branch: `codex/citysim-playtest-quality`
- Disposition: preregistered and waiting; this is not candidate acceptance.

The product remained read-only. Final scoring is prohibited until integration
provides exact clean PLAY-056 and PLAY-057 handoffs plus one exact combined
candidate. Author captures and scores may corroborate identity, but cannot
replace independent operation.

## Frozen staged identity

- Candidate: `playtest-quality-wf967be0ab5b4`
- Worktree token: `wf967be0ab5b4`
- Bundle ID and preferences:
  `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4`
- Executable SHA-256:
  `78863a8343ccd652441c315e4a52e45fda356adab48a42fd136a3368993632e9`
- Staging-manifest SHA-256:
  `aca66faa6dfc5b28933526769446971734accab9947f805ddb66bd49319913b0`
- Generated-v4 manifest SHA-256:
  `1753a314cfba5ce0034d486368dc92b23267b5a1ea8f2a30231e9a6c96f7e3fe`
- Fixture:
  `story-industrial-complication-v1.json`
- Fixture SHA-256:
  `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`
- Frozen state: seed 42, tick 128, Day 33, paused.

The complete paths and resource hashes are retained in `identity/`.

## Binding clear and capture procedure

Each route used a new `/private/tmp/citysim-play058-4c0414b/*-v2` data root and
the exact isolated executable:

1. Copy the canonical quicksave bytes into the route's fresh data root.
2. Launch one exact isolated process with an explicit regular or 900x600
   content-window environment.
3. Load the quicksave with Command-O.
4. Dismiss the load result with Command-period.
5. Clear overlays with Control-0 and reset the deterministic camera with `0`.
6. Wait at least eight seconds.
7. Refresh the full accessibility tree and require no `Action update`,
   `Action cancelled`, or `City loaded` transient before capture.
8. Open and close Details with `hud.command.details`; Escape is not used during
   baseline preparation because it can truthfully create an action-cancelled
   result.

The dark `Utilities` control in the freight-strategy band is the legitimate
persistent priority action. It remains visible and is not a contaminant.

Attempt 01 is retained separately because an `Action cancelled` toast obscured
world/HUD pixels. None of its images are binding.

## Independent live routes

| Route | Exact PID | Data root | Content/window proof | Cleanup |
|---|---:|---|---|---|
| Regular | 6846 | `/private/tmp/citysim-play058-4c0414b/regular-v2` | uncropped decorated window, 1278x768 capture | SIGTERM; exact quality PID absent |
| Compact | 10380 | `/private/tmp/citysim-play058-4c0414b/compact-v2` | exact 900x600 content; uncropped decorated 900x652 capture | SIGTERM; exact quality PID absent |
| Compact Reduce Motion | 13977 | `/private/tmp/citysim-play058-4c0414b/reduce-v2` | exact 900x600 content, `CITYSIM_REDUCE_MOTION_PROOF=1` | SIGTERM; isolated preference restored |

Other CitySim owners' processes were not terminated.

## Frozen baseline findings

- The block/neighborhood public realm is sparse: the park is a flat turquoise
  tile with one path, vegetation repeats in isolated clusters, and large green
  fields dominate outside the authored blocks.
- A few pedestrians establish scale but do not produce an active civic
  streetscape. The paused 20-second compact endpoint is byte-identical to its
  start; the regular endpoint shows only a very small map-region delta.
- Land Value, Traffic, and Happiness expose legends but no strong localized
  map truth in the representative state. Utilities and Pollution produce clear
  building-level marks.
- Closed HUD keeps the priority, metrics, speed, notices, and command deck
  legible. Details-open reduces the central world aperture from about 62.3% to
  44.1% in regular and from exactly 60.0% to 45.0% in compact.
- Tab reaches the semantic HUD identity in regular and compact; Shift-Tab
  restores map focus. Full AX captures expose the priority, metrics, speed,
  notices, command guide, Details, and layer controls.
- Reduce Motion retains the representative state, pollution truth, controls,
  and AX semantics.

These are comparison facts, not an early score.

## Candidate comparison protocol

The combined candidate must be operated independently from a fresh isolated
root with the same fixture bytes, paused state, window sizes, camera resets,
overlay, selection, panel state, and 20-second endpoints. Required uncropped
regular and compact comparisons include:

- closed HUD and Details open;
- city, neighborhood, and block camera stops;
- parks, plazas/public-realm edges, crossings, street furniture, vegetation,
  ambient people, and service activity;
- all five overlays with localized map truth, not legend-only truth;
- selection, construction, strain, recovery, normal motion, and Reduce Motion;
- pointer, keyboard, Full Keyboard Access, AX actions, focus generation, and
  topmost-first Escape;
- resource hashes, zero fallback, repeated LOD residency/RSS, cold and update
  diagnostics.

Material preference must be explicit in both regular and compact views. A
different state, camera, crop, or identity invalidates the comparison.

## Admission and disposition

The frozen rubric is in `RUBRIC.md`. Acceptance requires:

- at least 19/20;
- 4/4 public-realm coherence;
- 4/4 world/HUD composition;
- no category below 3;
- zero P0/P1 findings and zero automatic rejects;
- explicit material preference over this baseline in regular and compact.

This checkpoint stops at candidate-wait readiness.
