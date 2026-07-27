# PLAY-027 Industrial L3 source-v06 sensitivity authority

- Exact analytical attribution checkpoint:
  `a235546ef0a7ddf31cc2e78d16dfba62f08f82fe`
- Exact causal trace checkpoint:
  `722c8c5456f58716827adee598c48361d0ee0295`
- Integration disposition: `AUTHORIZE_DIAGNOSTIC_SWATCH_MATRIX`
- Candidate source revision: unchanged source-v05
- Diagnostic-only material copies: authorized
- Maximum delta per changed channel: exactly `+2/255`
- SceneKit processes: exactly 12
- Normalization: `false`
- Source authority: `false`
- Production selected: `false`

The no-SceneKit ownership gate passes three coordinates at 98–100 percent:

- North/West high-bay parapets:
  `l3c-charcoal-outline-steel`;
- North annex parapet:
  `l3c-warm-trim`.

West `(786,524)` is a real mixed edge: 66.9498 percent
`l3c-warm-formed-concrete`, 31.2034 percent `l3c-restrained-safety`, and 1.8469
percent weathered steel. This invalidates a concrete-only ownership claim, but
it supplies a bounded two-material sensitivity question.

## Diagnostic matrix

Create diagnostic-root-only copies of the exact source-v05 material library
and descriptors. Preserve source-v05 revision, geometry, camera, sampling,
frontage, registration, material assignment, and every unlisted field.

Render exactly three fresh processes for each row:

| Row | Direction | Authorized material-channel changes |
|---|---|---|
| `N1` | North | `l3c-charcoal-outline-steel.red +2/255`; `l3c-warm-trim.red +2/255` |
| `W1` | West | `l3c-charcoal-outline-steel.red +2/255`; `l3c-warm-formed-concrete.blue +2/255` |
| `W2` | West | `l3c-charcoal-outline-steel.red +2/255`; `l3c-restrained-safety.blue +2/255` |
| `W3` | West | `l3c-charcoal-outline-steel.red +2/255`; `l3c-warm-formed-concrete.blue +2/255`; `l3c-restrained-safety.blue +2/255` |

Do not test the negative sign, another channel, a wider delta, or another
combination. The copies and outputs must remain under a dedicated PLAY-027
diagnostics path and must not replace the frozen source-v05 files.

## Required result

For each row retain:

- three-process file and decoded-pixel identity;
- complete whole-image difference inventory against exact source-v05;
- prequantized and final neighborhoods at every governed coordinate for that
  direction;
- alpha, bounds, padding, registration, socket, frontage, and structural
  invariance;
- proof that changed pixels lie only on primitives using an authorized changed
  material;
- source, native-2x, compact, and grayscale comparisons against source-v05;
  and
- exact descriptor/material/binary/process hashes and a deterministic matrix
  manifest.

The matrix does not self-select a source candidate. Report each row as
repeat-pass or repeat-fail. If several West rows pass, integration will prefer
the row changing the fewest material channels, then the smallest changed-pixel
region, provided native/compact review remains visually equivalent. If no West
row passes, stop without widening scope.

Commit one clean diagnostic matrix and stop. Do not create source-v06
descriptors or production materials, normalize, change the resolver,
canonicalizer, geometry, East/South, renderer shipping code, package topology,
or shared manifests; do not begin L4/A2, push, or self-accept.
