# PLAY-027 Commercial L1 source-v04 rejection

**Disposition:** technically stable but visually rejected

**Production selected:** no

Source-v04 passes three-process byte identity, four-view source uniqueness,
scene-node bounds, and the first non-chroma occupied-area thresholds.
Integration's exact retained-PNG inspection still shows complete north/south
sources but only thin facade/roof slices for east/west, with the footprint
plate and southeast shadow absent in the standard review path.

The result proves that the source-v04 threshold is non-discriminating for the
reviewed decoded presentation. Scene-node bounds also describe authored
geometry before snapshot and cannot substitute for retained-file visibility.
Both gates remain useful diagnostics but do not constitute art acceptance.

All raw files, render records, three-process repeats, scene validation, raw
repeat reports, and raw uniqueness evidence are retained. A normalization run
had begun before the rejection arrived; those uncommitted normalized outputs
and normalization records were removed and are not retained or cited.

No source-v04 image is selected, ingested, packaged, or shipped. Before
another source revision, a separate validator must decode the exact retained
PNG bytes through the standard image path, mask chroma, compare occupied
bounds/area against ratios derived from complete north/south and accepted
Residential sources, and emit an occupied-pixel crop contact sheet from those
exact bytes.

## Post-rejection retained-byte diagnostic

`SOURCE-V04-EXACT-RGBA-VISIBILITY.json` now performs that check through
`CGImageSource` immediate RGBA decode and the decoded provider bytes. Every
direction reports:

- straight RGBA decode;
- alpha-visible / non-magenta RGB occupancy ratio `1.0`;
- zero hidden non-magenta pixels;
- exact RGB/alpha-visible occupied-bounds equality;
- occupied-count ratios from `0.9979` through `1.0281` against the complete
  N/S plus accepted Residential reference floor.

`SOURCE-V04-EXACT-RGBA-OCCUPIED-CROPS.png` masks only exact flat chroma and
shows complete N/E/S/W buildings, footprint plates, southeast shadows, and
frontages from the exact retained bytes. This evidence narrows the prior
direct-view discrepancy to the uncropped review presentation path rather than
hidden RGB in the retained PNG. Source-v04 nevertheless remains rejected and
unnormalized until integration independently reviews this exact diagnostic.
