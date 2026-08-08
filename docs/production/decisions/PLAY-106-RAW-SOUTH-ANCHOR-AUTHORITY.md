# PLAY-106 — Raw South Anchor Authority

Status: Integration-published authoring decision. This decision does not admit
assets to the renderer or select production.

The existing 43 South/rotation-zero PNGs from PLAY-097, PLAY-098, PLAY-099 and
PLAY-100 are the frozen identity references for the authored North, East and
West direction cells. Direction workers may read and hash these raw files to
preserve logical identity, level, variant, silhouette vocabulary and gameplay
meaning while producing independent sibling views.

This authoring authority is deliberately narrower than source admission:

- `sourceReady`, `integrationAdmitted`, `rendererQuarantined`, and
  `productionSelected` remain false in the existing South packets.
- Raw PNGs remain RGB ImageGen source material with their original chroma
  field; they are not shipping resources and may not be consumed by runtime.
- South normalization, CONTRACT-026 registration, four-direction handoff,
  renderer quarantine, visual acceptance and atomic 172/516 activation remain
  later gates owned by their respective lanes.
- Direction cells must verify the exact 43 logical IDs and raw SHA-256 values,
  must author independent N/E/W pixels, and must not mirror, rotate, copy,
  alias, fall back or overwrite a South source.

The decision resolves the status contradiction for authoring only. A worker may
proceed from raw-anchor evidence; no worker may infer that this decision is
South admission or shipping authorization.
