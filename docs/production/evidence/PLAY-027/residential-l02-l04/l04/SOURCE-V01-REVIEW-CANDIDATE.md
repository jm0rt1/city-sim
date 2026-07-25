# PLAY-027 Residential L4 source-v01 review candidate

**Disposition:** frozen for independent review; not accepted; not production
selected.

Residential L4 is a seven-floor urban residential tower. A warm two-floor
stone podium supports a narrow setback terracotta tower and stepped side wing.
The oxidized-copper crown, green podium terrace, dark side-wing parapet,
limestone horizontal belts, vertical divided-light window stacks, projecting
balconies, and urban lobby establish a materially different density story from
both L2 and L3.

North and west expose grounded return lobby doors; east and south use direct
urban lobby canopies. All four scene descriptors, geometry IDs, and raw hashes
are unique. No sibling source, mirror, rotation, or transform is declared.

Each retained raw is byte-identical to an additional independent native
process. Every normalized LOD is byte-identical across two unchanged-normalizer
runs. Native reports pass four unique raw hashes, twelve unique normalized
hashes, alpha/chroma/padding, and 81 explicit window centers per direction.

The unlabeled source-scale, normalized-alpha native-2x, grayscale, registered
footprint, footprint grayscale, and zoom sheets use row-major `N, E, S, W`.
This checkpoint authorizes neither batch selection nor renderer ingestion.
