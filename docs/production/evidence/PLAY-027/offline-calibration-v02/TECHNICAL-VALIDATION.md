# PLAY-027 replacement calibration technical validation

**Set:** residential L1 variant-zero

**Raw revisions:** north/east/south `source-v04`, west `source-v05`

**Technical result:** pass

**Independent art result:** pending

**Production selected:** no

## Passing technical gates

- Four explicit, independently authored scene descriptors pass geometry,
  registration, socket, door-base, contact, projection, light, shadow, and
  no-sibling-transform validation.
- Each scene contains its own direction-specific entry pavilion and porch
  dimensions. The shared stable building envelope, camera, light, pivot,
  contact polygon, and family material library remain frozen.
- The four raw files reproduce byte-for-byte on a second native renderer run.
  Their raw and canonical-pixel hashes are unique.
- Raw files are opaque 1536 x 1024 RGBA with flat `#ff00ff` corners, nonempty
  non-chroma bounds, and retained padding.
- The existing unmodified normalizer reproduced twelve byte-identical LOD
  files over two runs. All twelve hashes are unique and pass normalized
  alpha, chroma, nonempty-subject, and padding inspection.
- The task-owned native review tool produced full source-scale and native-2x
  sheets plus fixed descriptor-derived footprint panels at exact native-2x
  scale, source-pixel zoom, and grayscale.

## Review surfaces

The manifest `CONTACT-SHEET-ORDER.json` records N/E/S/W row-major order and
the hashes of every panel. The most efficient independent review sequence is:

1. `contact-sheets/residential-l01-v0-footprint-native2x.png`;
2. `contact-sheets/residential-l01-v0-footprint-native2x-grayscale.png`;
3. `contact-sheets/residential-l01-v0-footprint-zoom.png`;
4. `contact-sheets/residential-l01-v0-source-scale.png`.

The fixed crop `[512, 512, 512, 384]` is derived from the frozen registration
template. It is not inferred from generated pixels and does not become
geometry authority.

Technical success does not accept the art. This replacement set remains
pending independent source-art review and cannot authorize the remaining 44
sources, renderer ingestion, atlas changes, or production selection.
