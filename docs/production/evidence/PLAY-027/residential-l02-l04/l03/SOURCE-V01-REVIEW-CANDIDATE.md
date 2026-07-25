# PLAY-027 Residential L3 source-v01 review candidate

**Disposition:** frozen for independent review; not accepted; not production
selected.

Residential L3 is a five-floor stepped U/courtyard mid-rise: two deep-red
residential wings, a lower honey-stone bridge, south-open court, flat dark
parapets, a green stepped bridge roof, balcony stacks, and a small copper roof
pavilion. The massing and facade rhythm are materially distinct from L1 and
L2 while retaining warm residential masonry, lit windows, planted court, and
green entry doors.

North and west expose grounded return doors; east has a direct wing portal;
south has a central courtyard-threshold portal. All four descriptors and raw
pixels are unique, with no sibling source, mirror, rotation, or transform.

Each raw source is byte-identical to two additional native process renders.
Each normalized LOD is byte-identical across two unchanged-normalizer runs.
Native reports pass four unique raw hashes, twelve unique normalized hashes,
alpha/chroma/padding, and four scene registrations with 53 explicit window
centers each.

The unlabeled source-scale, normalized-alpha native-2x, grayscale, registered
footprint, footprint grayscale, and zoom sheets use row-major `N, E, S, W`.
This checkpoint authorizes neither batch selection nor renderer ingestion.
