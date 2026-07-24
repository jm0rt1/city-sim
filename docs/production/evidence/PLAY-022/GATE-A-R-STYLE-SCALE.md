# PLAY-022 Gate A-R — systemic calibration style and scale

**Status:** binding nine-source calibration sheet; July 21, 2026

**Appearance reference:** `Native/CitySimNative/WorldArt/GateA/golden_district_imagegen_source-v2.png` (provisional; appearance only)

## One projection and registration contract

- Orthographic 2:1 isometric with parallel edges. One simulation tile is 72 ×
  36 world points and 512 × 256 authoring pixels.
- All sources use a 1536 × 1024 canvas and the exact south ground pivot at
  `(768, 896)`. Trimming records the pivot before crop and must round-trip it
  within 0.5 world point.
- The committed transparent 1×1, 2×1, and 2×2 guides define footprint corners,
  N/E/S/W sockets, the permitted height box, northwest light origin, and
  southeast shadow box. Generated pixels never redefine those coordinates.
- Calibration footprints: grass 1×1, road 1×1, residential frontage 1×1,
  residential L1 1×1, commercial L1 1×1, industrial L1 2×1, park 2×2, city
  hall 2×2, water tower 1×1.

## Physical and camera pixel budget

| LOD | Camera scale | 2× physical tile demand | Export density |
|---|---:|---:|---:|
| Block | 0.30–0.60 | 480×240 to 240×120 | 512×256 per tile |
| Neighborhood | 0.601–1.15 | 240×120 to 125×63 | 256×128 per tile |
| City | 1.151–1.60 | 125×63 to 90×45 | 128×64 per tile |

Each source is normalized once, then exported independently for city,
neighborhood, and block. Mipmaps cover continuous scaling only within a LOD.
The default and compact launch cameras must leave developed land at 55–70% of
the available viewport; camera framing cannot conceal empty-world composition.

## Material, value, light, and scale

- Preserve the provisional plate interior’s olive/moss terrain, charcoal road,
  warm aggregate walk, brick/stone/stucco/steel architecture, deep foliage,
  restrained ochre markings, and warm windows.
- Northwest planes receive the warm key; southeast walls are cooler/darker;
  every building has contact grounding and a coherent southeast cast shadow.
- Buildings occupy 55–78% of their declared parcel. Residential is the smallest
  silhouette, commercial is compact and street-facing, industrial is wider and
  lower, city hall is the focal height, and the water tower remains a narrow
  vertical landmark.
- Ground stays mid-value, roads darker, walls/roofs separate in grayscale, and
  only selection/placement may use a high-contrast outline. No cyan rings,
  bolts, labels, debug markings, text, logos, or floating geometry.

## Deterministic topology and LOD

- Code compiles the road material into all 16 masks and owns asphalt edges,
  curbs, sidewalks, crosswalk placement, road ends, and frontage joins.
- Generated road pixels provide material character only; generated frontage
  pixels provide a surface vocabulary only. Neither source owns connectivity.
- City LOD emphasizes mass and network; neighborhood adds facade and major
  planting; block adds entry, material, and prop detail. Objects keep one pivot
  and may simplify independently—synchronized disappearance is prohibited.
- The rejected monolithic plate remains a non-shipping appearance reference and
  is disabled in the scored candidate.

## Calibration budgets and rejection rules

- No missing resource or fallback; no node/action accumulation; unchanged-pulse
  average no more than 20% above the accepted 0.8778 ms comparison unless
  integration approves an exception; absolute ceiling remains 2.1 ms.
- Reject source art for projection convergence, >1 normalized-pixel footprint
  or socket drift, >5% family scale drift, wrong light/shadow, clipped bounds,
  magenta halo, invented roads/scenery, floating ground, text, or watermark.
- If one family repeats the same drift twice, freeze it and repair this
  geometry/prompt contract before another call.
