# PLAY-055 Frozen Baseline Defects

## D055-B01 — Residential levels and frontage collapse

- **Severity at final gate:** P1 / automatic reject
- **Owner:** World rendering, PLAY-028
- **Baseline product:** `96db07032e548448f659b573381b6b5abbd94eb2`
- **Staged quality merge:** `56d099714d90c63c76993dcbd23eca9f6d615c54`

### Reproduction

1. Launch the exact staged quality bundle with isolated root
   `/private/tmp/citysim-play055-96db070/residential-levels` and explicit
   regular sizing.
2. Install byte-identical
   `story-industrial-opening-v1.json` as `quicksave.json` (SHA-256
   `b6fb32abafca99592a5ad5f0e7312c0cad7520c556c4b785e19e8894936ce0d3`).
3. Load with Command-O, remain paused, use City layer/no selection, and press
   `0`.
4. Observe authoritative Residential L4 at `(9,11)` and L1 at `(10,11)`.

### Expected

Level 4 has materially denser massing than level 1, and an exact directional
identity faces its authoritative road.

### Actual

The two parcels use the same visible Residential building form. The active
renderer resolves every Residential tile to `residential_l01` without
consulting `tile.level`
(`Rendering/CityScene.swift:2057-2060` and
`Rendering/LotRenderer.swift:113-116`). The only packed Residential entry is
level 1 with `frontage_edge: south`. `LotRenderer` explicitly preserves the
south-facing architecture and only bends a site path toward another road
socket (`LotRenderer.swift:208-216`).

Thus L2/L3/L4 collapse to L1 and N/E/W road cases retain south-facing
architecture. The live L1/L4 frame proves the level collapse; the exact
runtime selection and pack records prove the systematic level/direction path.
No uncommitted renderer work was inspected.

### Evidence

- `live/residential-levels/l1-l4-collapse-regular.png`
- `live/residential-levels/l1-l4-collapse-regular.ax.txt`
- `ledgers/residential-direction-level-matrix.csv`

## D055-B02 — Overview and Journal are AX-visible but visually collapsed

- **Severity at final gate:** P1 / automatic reject
- **Owner:** UI/input, PLAY-054

### Reproduction

1. Launch the same exact bundle with isolated root
   `/private/tmp/citysim-play055-96db070/compact` and
   `CITYSIM_COMPACT_WINDOW=1`.
2. Load byte-identical industrial-complication state, press `0`, and confirm
   Day 33, paused, City layer, no selection.
3. Open Details and inspect Overview.
4. Choose Journal.

### Expected

At exact 900×600 content, Overview visibly exposes one complete actionable
section and Journal visibly exposes two complete notice summaries. Remaining
content has an obvious operable scroll region. AX and sighted content agree.

### Actual

Overview AX contains City Identity, City Health, Current Objective, Operating
Position and Open Journal. The frame displays only the Overview header and
thin card edges. Journal AX contains seven complete notice entries plus
Related Data, Act and Dismiss controls; its frame shows only the Journal
header and clipped card edges. The structural baseline caps compact details at
66 points (`BuildToolbarView.swift:11`, `:47-50`).

Regular Overview and Journal also show compressed card tops rather than a
useful diagnostic workspace.

### Evidence

- `live/compact/baseline-overview-open-900x600.png`
- `live/compact/baseline-overview-open-900x600.ax.txt`
- `live/compact/baseline-journal-open-900x600.png`
- `live/compact/baseline-journal-open-900x600.ax.txt`
- `live/regular/baseline-overview-open.png`
- `live/regular/baseline-journal-open.png`
- `ledgers/font-aperture-baseline.csv`
