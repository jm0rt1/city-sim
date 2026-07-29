# PLAY-027 Industrial L4 v17 matte-attribution disposition

- Disposition: `PASS_DIAGNOSTIC_MATTE_ATTRIBUTION`
- Diagnostic only: `true`
- Source authority: `false`
- Production selected: `false`
- Metal, SceneKit, raw, and authority-normalizer processes: `0`

The immutable v16 and v17 raw files reproduce the same `1,807` near-chroma
coordinates. Their row-major `x,y` newline-terminated coordinate SHA-256 is
`824601712493f3e8b402b69055267a10bfdd8d80254e4d04b8c91f58d6df4109`.
The frozen contact-polygon projection attributes every coordinate:

- silhouette edge: `1,552`
- contact-shadow edge: `245`
- overlap: `10`
- unowned: `0`

The diagnostic copy applies the existing `NormalizeOfflineSource`
border-connected matte flood, retained-edge despill, and hidden-RGB clearing
without invoking the authority normalizer. It changes `1,461,112`
border-connected matte pixels and `685` pixels selected by the existing
despill predicate. Exactly `0` pixels change outside that classified
matte/spill union.

Three near-chroma coordinates are not border-connected but are covered by the
existing despill predicate. Two additional despill pixels lie beyond the
three-pixel matte neighborhood; their original tuples are
`(208,16,208,255)` at `(837,622)` and `(144,48,144,255)` at `(837,623)`.
Both are magenta-family compositor spill, not an authored palette role.

The resulting diagnostic copy has:

- exact/near chroma at nonzero alpha: `0`
- hidden RGB at alpha zero: `0`
- retained candidate bounds before/after: `[512,525,1023,895]`
- unchanged canvas: `1536x1024`
- file SHA-256:
  `39bcb896664ef436853790e2acd87bb0d450b8401bb5318708757aef331a2385`
- decoded RGBA SHA-256:
  `d5ef428818b2ea5ba5e44c3d46f30c06b69589964ed37f53843a6976128c87ad`

Two fresh no-Metal processes emitted byte-identical ten-file packets with
aggregate SHA-256
`e0180de9e38fb077aff3736db0ff0d6d6e8a0b0a9607fa5cba82b2ee14835ae6`.

The v17 raw remains rejected and byte-immutable. This diagnostic does not
authorize a compositor change, raw repair, normalization, source authority,
sibling production, ingestion, or shipping.
