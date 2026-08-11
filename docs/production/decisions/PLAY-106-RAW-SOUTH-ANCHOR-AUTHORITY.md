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

For logical identity `industrial_l01_v0`, the canonical raw South authoring
anchor is
`Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/industrial_l01_v00-source-v01.png`
at SHA-256
`7ca3e26234e7e15df9a46775a83f7132f89e1ea1f22d97c42ca6d3502099bbd2`.
The later sibling
`Native/CitySimNative/WorldArt/ImageGenSingleAngle/PLAY-099/industrial/raw/industrial_l01_v00-source-v02.png`
at SHA-256
`8e33dafb3a40f7dac6f5ca8c9c5cb81df2b63011d3fd0d4a0302ec04a99d264a`
is preserved byte-for-byte as noncanonical rejected evidence with disposition
`RETURN_source_v02_chroma_gate_failed`. It is excluded from the 43-row
canonical digest and may not count as a logical identity, source admission,
direction, retry, renderer selection, or production asset.
