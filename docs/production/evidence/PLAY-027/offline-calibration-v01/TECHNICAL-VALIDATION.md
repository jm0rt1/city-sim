# PLAY-027 rejected calibration technical validation

**Set:** residential L1 variant-zero

**Raw revisions:** north/east/south `source-v03`, west `source-v04`

**Technical result:** pass

**Independent art result:** reject

**Production selected:** no

## Passing technical gates

- Four explicit independently authored scene descriptors pass geometry,
  registration, socket, door-base, contact, projection, light, shadow, and
  no-sibling-transform validation.
- The four raw files reproduce byte-for-byte and canonical-pixel-for-pixel on
  the approved host.
- The four raw hashes and canonical pixel hashes are unique.
- Raw files are opaque 1536 x 1024 RGBA with exact flat `#ff00ff` corners and
  retained non-chroma bounds/padding.
- The existing unmodified normalizer reproduced twelve byte-identical LOD
  files over two runs. All twelve hashes are unique.
- Native normalized validation passes transparent alpha, no opaque chroma,
  nonempty subject, and minimum padding checks for every LOD.
- The native review tool produced source-scale, native-2x actual-scale, and
  unlabeled grayscale sheets in N/E/S/W order.

## Evidence

- scene geometry: `scene-validation.json`;
- raw repeat-run and uniqueness: `determinism/*-pixel-identity.json` and
  `determinism/four-view-prepared-unique-pixels.json`;
- normalized repeat-run hashes: `normalization-determinism.json`;
- normalized alpha/chroma/padding: `normalized-validation.json`;
- review order and hashes: `CONTACT-SHEET-ORDER.json`;
- art disposition: `INDEPENDENT-ART-REJECTION.md`;
- complete attempt inventory: `CALIBRATION-INVENTORY.md`.

Technical success does not override the independent art rejection. The set is
retained as a rejected calibration and cannot authorize the remaining 44
sources, renderer ingestion, atlas changes, or production selection.
