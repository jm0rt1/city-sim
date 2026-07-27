# PLAY-027 Industrial L3 source-v06 North final sensitivity authority

- Exact sensitivity-matrix checkpoint:
  `9a384ebceef0a4dadd64b980950d8fe2a9d4137e`
- Exact source-v05 North descriptor SHA-256:
  `a147ad0a7023374b982a6677325da2912f45796616b03579e1a72eb7da4a6b61`
- Exact source-v05 material-library SHA-256:
  `f39bbf5914ba15f90f100bfed5ac65e537b5a6a62d677be82698ac89cf982b65`
- Integration disposition: `AUTHORIZE_FINITE_NORTH_SENSITIVITY`
- Candidate source revision: unchanged source-v05
- Diagnostic-only material copies: authorized
- SceneKit processes: three for `N2`, then three for `N3` only if `N2` fails
- Maximum total processes: six
- Normalization: `false`
- Source authority: `false`
- Production selected: `false`

The completed matrix proves that West row `W1` is the sole three-process
repeat-identical West recipe. Preserve it unchanged for a later governed
source-v06 selection:

- `l3c-charcoal-outline-steel.red`: source-v05 value plus exactly `2/255`;
- `l3c-warm-formed-concrete.blue`: source-v05 value plus exactly `2/255`;
- West descriptor SHA-256:
  `56e9aef896ef5eef435f76ff466f837ac022ff18edbc4e6bd3fa24cb583d78dc`;
- diagnostic material SHA-256:
  `59a450c842058067d35374b041a4f5a263eb2ffb02c010e90bc156a1a3430d52`.

Do not rerender `W1` under this authority.

## North diagnosis

`N1` removed the original charcoal-owned split at `(688,391)`. Its sole
remaining repeat difference is one opaque red-channel step at `(796,746)`.
That coordinate lies in the overlapping projected envelopes of
`n-annex-roof-parapet-south` and `n-annex-roof-parapet-east`, both owned by
`l3c-warm-trim`; retained attribution assigns the adjacent annex edge 98.32
percent to that material. The prequantized red sample toggles `183`/`184`,
which produces the final `176`/`208` split.

The smallest justified experiment is therefore one additional positive red
increment on warm trim while preserving the proven charcoal increment.

## Finite diagnostic sequence

Create diagnostic-root-only copies of the exact source-v05 North descriptor
and material library. Preserve revision, geometry, camera, sampling, frontage,
registration, material assignment, and every unlisted field.

1. Render `N2` in exactly three fresh processes:
   - `l3c-charcoal-outline-steel.red`: source-v05 plus exactly `2/255`;
   - `l3c-warm-trim.red`: source-v05 plus exactly `3/255` total.
2. If and only if `N2` fails exact file or decoded-pixel identity, render `N3`
   in exactly three fresh processes:
   - `l3c-charcoal-outline-steel.red`: source-v05 plus exactly `2/255`;
   - `l3c-warm-trim.red`: source-v05 plus exactly `4/255` total.
3. Stop immediately after the first passing row. Stop after `N3` regardless
   of result.

No retry, extra run, negative sign, other channel, other material, larger
delta, geometry change, or alternative combination is authorized.

## Required result

For each consumed row retain:

- A/B/C file and decoded-RGBA identity;
- explicit repeat disposition;
- complete whole-image differences against exact source-v05;
- prequantized and final neighborhoods at `(796,746)`, `(795,748)`, and
  `(688,391)`;
- proof that all changed pixels remain inside the projected charcoal or
  warm-trim material envelopes;
- exact occupancy, alpha, chroma, hidden-RGB, bounds, padding, pivot, socket,
  frontage, contact, shadow, and structural invariance;
- source, native-2x, compact, and grayscale comparisons against source-v05;
  and
- exact descriptor, material, renderer-binary, process, and evidence hashes in
  a deterministic manifest.

Commit one clean diagnostic packet and stop. Do not create source-v06
descriptors or production materials, normalize, change the resolver,
canonicalizer, East/South, renderer shipping code, package topology, or shared
manifests; do not begin L4/A2, push, or self-accept.
