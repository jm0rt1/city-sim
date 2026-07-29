# PLAY-027 CONTRACT-019 R2 semantic visibility disposition

`RETURN_SEMANTIC_REPEAT_GATE`

This is diagnostic evidence only. It is not source authority, production
selection, modeling authority, normalization authority, or shipping approval.

The exact existing-renderer path was exercised twice and no third process was
run. Both processes used `ContractSceneBuilder`, the committed semantic node
recoloring mode, `NativeSourceRenderer`, the 4x SceneKit snapshot, the governed
Lanczos and registration path, and the same 52-node manifest SHA-256:
`c65f843ddfe026676a758fe90194034ab56db7211d113e172fd556ac2d8b2803`.

The final semantic rasters are not repeat-identical:

- run A PNG:
  `5bd64f02dc0e8af8f221d8de4a524ba28021df0f53460a63c276300918727245`
- run B PNG:
  `2538b4c0e42b2a53c1852f350a1049facc86e27a526ed8761d7d584d63259ef2`
- differing decoded pixels: `13,629`
- differing channels: `26,924`
- maximum channel delta: `64`
- difference bounds: `[524,710,1024,895]`
- first difference: `(922,710)`, run A `[112,112,112,255]`, run B
  `[144,112,80,255]`

The dominant classified transition is `other -> hall` at `13,191` pixels.
That is evidence of a real rendered ownership split despite identical node
manifests, not a report-only mismatch. Smaller transitions and same-class value
splits remain bound in `review/REVIEW.json`.

The actual-scale evidence is therefore retained but cannot admit modeling. At
literal 192, the portal inset is 57 pixels, the north jamb is 21 pixels, the
header is 19 pixels, and the south jamb is only 3 pixels. The south jamb is
visible but materially weaker than the other portal components. The canonical
v17 luma medians under the run-A masks are 142 for both jambs/header, 16 for the
inset, 73 for the hall, 48 for the gantry, and 131 for the crucible.

The no-Metal review packet itself reproduced byte-for-byte across two fresh
builds, with ordered 13-file aggregate SHA-256
`ad8704ceeb226684c112ec4773cb8717403a429488e632d29a42a4e68a8640f8`.
No authoritative raw process, normalizer process, sibling direction, or
modeling mutation was consumed.
