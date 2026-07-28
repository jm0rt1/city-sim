# PLAY-027 Industrial L4 R5 depth-ownership authority

- R4 diagnostic: `6e85f2f519290873521c3ab681a26f016ff9da99`
- Integration preservation merge: `a44293d51ab9fe422a10864e87fb4f23a12a1ebf`
- R4 disposition: `PREPARATION_STATE_SPLIT`
- Source authority: `false`
- Production selected: `false`
- Diagnostic SceneKit/Metal processes authorized: `2`
- Raw/normalizer/sibling processes authorized: `0`

Renderer review proves the residual `85`-pixel transition cannot belong to
the crucible: its conservative projection begins outside the changed region.
The changed pixels instead occupy the intentional overlap between the portal
lintel/header and north jamb. Nearest-color semantic classification misnames
one blended portal color as the crucible class.

World Art may implement the exact CONTRACT-019 R5 shader-only depth ownership
rule:

- bias only `v17-monumental-portal-lintel` and
  `v17-monumental-portal-header-wall`;
- move depth toward the camera by exactly `0.0625` world-depth units;
- apply the same rule to semantic and actual node-local material copies; and
- preserve every descriptor, geometry, transform, bounds, camera,
  registration, sampling, socket, pivot, hit, and non-header material fact.

Run exactly two diagnostic semantic SceneKit/Metal processes. Require
byte-identical PNG and decoded RGBA, zero differing pixels/channels, the exact
51-node manifest, canonical R3-A decoded output, unchanged portal counts, and
no changes outside the two header projections plus two-pixel Lanczos support.

Any failure is `HARD_PIPELINE_LIMIT`: remove the bias from the candidate,
commit the failed evidence, and stop all further SceneKit tuning. A pass still
does not accept or authorize portal modeling.

No authoritative raw, normalization, siblings, ingestion, shipping, or
production selection is authorized.
