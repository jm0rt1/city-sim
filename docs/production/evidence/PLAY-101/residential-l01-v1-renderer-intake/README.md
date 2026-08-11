# PLAY-101 residential L1 variant-one Renderer intake

The admitted `residential_l01_v1` source family at commit
`3f129be25d4557dd6002cc7e11df065e962ff50c` is ready for Renderer
quarantine. Four independent authored directions and 12 unique LOD payloads
match their committed receipts, pass fresh alpha/chroma pixel checks, retain
direction-specific registration, and reject alias, fallback, mirror, rotation,
registration drift, and cross-direction source substitution.

The current production selector remains deliberately unchanged on authority
baseline `614a768805644aa98b749e050887d1adb0fb476a`: residential variant zero is
still selected for every level/frontage/LOD with zero fallback. Variant one is
not copied into product resources, listed in the production manifest, or
activated at runtime by this intake.

## Visible evidence

- `source-four-view.png` — exact four-direction source contact sheet.
- `literal-lod-color.png` — exact block, neighborhood, and city payloads.
- `literal-lod-grayscale.png` — value/readability view of the same 12 payloads.

Mechanical identities, focused command, results, and scope boundaries are in
`RENDERER-QUARANTINE-RECEIPT.json`.
