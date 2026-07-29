# PLAY-027 Industrial L3 source-v05 trace authority

- Exact rejected raw checkpoint:
  `baa444fb3e34f8aa72c6d9ae74955b8c591eea3d`
- Exact resolver checkpoint:
  `f7e67031f5fcd222e2755a75270685c54b4bd038`
- Integration disposition: `AUTHORIZE_TRACE_ONLY`
- Authorized descriptors: exact source-v05 North and West descriptors already
  bound by the published resolver authority
- Authorized processes: three fresh North and three fresh West trace processes
- Art mutation: `false`
- Sampling/canonicalizer mutation: `false`
- Normalization: `false`
- Source authority: `false`
- Production selected: `false`

The raw gate is visually complete and geometrically stable, but it fails exact
repeat identity at three fully opaque, red-channel, one-quantum edge pixels:

- North `(688,391)` and `(795,748)`;
- West `(847,391)`.

Independent Renderer diagnosis finds unchanged bounds, occupied area, alpha,
pivot, sockets, frontage edges, and shadow vector. The likely trigger is a
rasterized material edge landing on a quantizer midpoint; the current v3
canonicalizer correctly refuses to invent consensus when local support does
not meet its frozen majority or boundary-assist rule.

## Authorized trace

World Art may add a task-owned diagnostic-only trace path and run the exact
source-v05 North/West descriptors three times each. For every coordinate above
and every process, retain:

- immutable pre-quantized 5x5 RGBA neighborhood;
- quantized 3x3 RGBA neighborhood;
- material/node/primitive identity if the offline renderer can report it
  without changing scene evaluation;
- base majority support, boundary vote, effective support, selected output,
  and the exact canonicalizer accept/reject reason;
- renderer binary/source commit, descriptor hash, material-library hash,
  sampling contract, and process identity; and
- a deterministic contact sheet comparing all six traces.

The diagnostic flag must fail closed outside a dedicated PLAY-027 diagnostics
output path. Default rendering behavior and every accepted descriptor must
remain unchanged. Commit one clean trace checkpoint and stop.

## Decision boundary

Do not change geometry, materials, quantizer thresholds, canonicalizer rules,
descriptor revision, raw pixels, normalized pixels, East/South, renderer
shipping code, package topology, or shared manifests under this authority.

The follow-up repair will be selected only from retained trace evidence:

1. If all unstable samples map to one or more exact authored material roles
   straddling the known red-channel midpoint, integration may authorize a
   minimal task-owned swatch move away from that midpoint.
2. If the roles do not bind consistently, return for a narrower primitive or
   raster-stage probe.
3. Do not broaden the 6+1 boundary rule, accept majority-of-runs output,
   coordinate-patch pixels, nudge approved frontage geometry, or normalize a
   failed raw candidate.
