# PLAY-027 Industrial L3 source-v06 attribution stop

Disposition: `STOP_ATTRIBUTION_GATE_FAILED`

This checkpoint implements and preserves the required standalone,
no-SceneKit analytical ownership gate before any source-v06 descriptor or
material mutation.

The tool reads the exact frozen source-v05 North/West descriptors and material
library, reconstructs the render-consumed explicit primitives (including the
four generated flat-parapet trim boxes), projects the full positive separable
Lanczos-3 support through the exact production camera and registered
post-offset, and resolves the nearest finite primitive for every supported
4x sample.

Three governed coordinates pass:

- North `(688,391)`: high-bay parapet / charcoal outline steel,
  `1.000000` attributed ownership.
- West `(847,391)`: high-bay parapet / charcoal outline steel,
  `1.000000` attributed ownership.
- North `(795,748)`: annex parapet / warm trim,
  `0.983169` attributed ownership.

West `(786,524)` fails the binding 80 percent threshold:

- expected `w-loading-spine` / `l3c-warm-formed-concrete`:
  `0.669498`;
- secondary `w-portal-header` / `l3c-restrained-safety`:
  `0.312034`;
- secondary `w-high-bay-hall` / `l3c-weathered-blue-steel`:
  `0.018469`.

The expected material remains the primary contributor, but the authority
requires at least `0.80`; therefore no source-v06 descriptor, material copy,
resolver, raw render, or normalization was created. No threshold, sign, or
delta was altered.

Evidence:

- `attribution/LANCZOS-OWNERSHIP.json`
- `attribution/LANCZOS-OWNERSHIP.png`
- `ATTRIBUTION-REPLAY.json`

The report and panel reproduce byte-identically across two fresh tool
processes. The standalone tool compiles with warnings as errors and rejects an
output root outside the task-owned PLAY-027 Industrial L3 evidence path.

`sourceAuthority=false`; `productionSelected=false`.
