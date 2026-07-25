# PLAY-027 Residential density template architecture

The accepted L1 path remains the renderer's unchanged legacy-domestic branch.
L2-L4 descriptors opt into explicit density geometry through four task-owned
descriptor structures:

- `massBlocks` — independently named wall volumes with exact dimensions,
  positions, and materials;
- `roofVolumes` — independently named hip or flat-parapet volumes;
- `trimBands` — explicit facade/cornice hierarchy rather than L1's fixed
  two-floor bands;
- `windowRhythms` — explicit groups of world-space window centers, sizes,
  floors, and materials.

No density scene is inferred from pixels or derived from a sibling direction.
The final scene JSON still contains every facade, window center, entrance,
frontage, prop, occlusion exclusion, and massing volume.

Three density entrance styles are task-owned source geometry:

- `walkup-stoop` for L2;
- `courtyard-portal` for L3;
- `urban-lobby` for L4.

Each uses descriptor-owned doors, transoms, portals, steps, canopies, columns,
and optional far-edge frontage returns. The shared camera, light, chroma,
registration, and deterministic compositor remain unchanged.

The review tool accepts an explicit registered crop per level, allowing taller
sprites to be shown at exact normalized-alpha scale without clipping. Its L1
defaults remain unchanged. The scene validator accepts an explicit logical
building ID, level, and calibration ID while preserving the accepted L1
default validation.

The new material library preserves the accepted warm residential family but
adds level-specific ochre, deep terracotta, honey stone, tower brick, green
slate, and copper roof values. No ImageGen swatch or whole-building generation
is used.

These task-owned changes add no product target, package dependency, build
hook, shipping atlas page, shared manifest, runtime renderer behavior, or
production selection.
