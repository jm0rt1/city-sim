# PLAY-027 Industrial L2 East v03 pre-render bounds repair

Disposition: **PENDING INDEPENDENT PRE-RENDER REVIEW**. No source-authority pixels exist for v03.

## Measured correction

The CPU/SceneKit `ContractSceneBuilder` audit supersedes the earlier descriptor-only horizontal inference:

- descriptor-only component inference: X `[-25.75, 28]`, Z `[-27.25, 28]`;
- actual v02 root union: X `[-28, 28]`, Z `[-28, 28]`, Y `[0, 33.900001525878906]`;
- required root union: X `[-28, 28]`, Z `[-28, 28]`, minimum Y `<= 0`, maximum Y `>= 35.65`;
- actual v02 failed predicate: maximum Y `33.900001525878906 < 35.65`.

The truthful 56×56 foundation already owns the west, north, east, and south root faces. It remains unchanged.

V03 makes the smallest visible structural correction:

- `v02-hall-clerestory` becomes `v03-hall-clerestory-envelope`;
- dimensions change from `[18, 5, 6]` to `[18, 6.8, 6]`;
- position changes from `[-6, 31.4, -6]` to `[-6, 32.25, -6]`;
- the visible hall/service envelope now owns maximum Y `35.650001525878906`;
- its lower face overlaps the hall roof by `0.05` world units, avoiding a coincident support plane while remaining physically connected.

The secondary process monitor is reduced from Y `[20.7, 26.7]` to `[20.7, 26.0]`. It remains secondary and does not become the height repair.

## Preserved contracts

- 56×56 footprint and truthful foundation;
- pivot, frontage socket, two door bases, contact polygon, camera, sampling, light, and authored southeast shadow;
- 48-unit hall presentation, 18-unit administration wing, three 11-unit docks, loading spine, component-to-pixel budget, and wide-low silhouette;
- minimum identity feature budget `13.659074067865795` native-2x pixels;
- later raw luma targets: p25 ≥ 80, IQR ≥ 48, p95 ≥ 192, at least five occupied step-32 bins, and maximum major-facade bin share ≤ 0.31;
- approved v02 descriptor/material/pre-pixel evidence, both probe-attempt records, probe tools, and rejection packet byte-for-byte;
- `productionSelected=false`.

No new material library is required. V03 deliberately reuses the exact approved v02 material library SHA `94069509093c122d4cb2383bd648757561f6561f78b8345c6222b5354f3f18f6`.

## Pre-render-only proof

Both bounds audits instantiate `ContractSceneBuilder` and enumerate geometry nodes. They do not create an `SCNRenderer`, invoke renderer capability preflight, call `snapshot`, or produce pixels.

- v02 audit: `V02-ROOT-BOUNDS-AUDIT.json` — expected failure;
- v03 audit: `V03-ROOT-BOUNDS-AUDIT.json` — completeness pass;
- typed validation: `PREPIXEL-VALIDATION.json` — pass;
- changed-primitive coincident face count: `0`;
- raw render processes consumed: `0`.

## Future raw-probe compatibility

The unchanged v02 raw-probe executable **cannot consume v03**. It correctly fails closed because it hard-binds:

- approved commit `857d39bcdc1cbf799368623f3749a1c66897da94`;
- v02 descriptor SHA `01ee10ef87c7a23d8fab151091f7237fc0a12563694cea3080f63a25d4e90775`;
- source revision `projection-silhouette-reset-art-proof-v02`;
- the v02 evidence output suffix.

A future Metal probe requires separate integration authority and a newly frozen v03-bound executable. The v02 executable remains immutable.
