# PLAY-027 Residential L2-L4 independent review request

## Requested disposition

Review the frozen 12-source Residential L2-L4 variant-zero slice. This request
does not assert acceptance, authorize `productionSelected`, authorize renderer
ingestion, or authorize Commercial/Industrial production.

Published starting authority is `1744c3d`. The accepted Residential L1
calibration at `6380037` remains an unchanged registration and family-style
baseline.

## Candidate identity

| Level | N/E/S/W revision | Frozen candidate commit |
|---|---|---|
| Residential L2 | `source-v05` | `ed06c8e` |
| Residential L3 | `source-v01` | `50977b3` |
| Residential L4 | `source-v01` | `af4dd25` |

The complete raw hash inventory is in `FINAL-SLICE-INVENTORY.md`. Each
direction uses an explicit independent scene descriptor. No sibling raster,
scene, mirror, rotation, or transform is used.

## Art review surfaces

All rows are unlabeled and ordered `N, E, S, W`.

### Residential L2

- `l02/SOURCE-V05-NATIVE-2X-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png`
- `l02/SOURCE-V05-NATIVE-2X-GRAYSCALE-REVIEW-CANDIDATE.png`
- `l02/SOURCE-V05-FOOTPRINT-NATIVE-2X-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png`
- `l02/SOURCE-V05-FOOTPRINT-NATIVE-2X-GRAYSCALE-REVIEW-CANDIDATE.png`
- `l02/SOURCE-V05-ZOOM-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png`
- `l02/SOURCE-V05-SOURCE-SCALE-REVIEW-CANDIDATE.png`

### Residential L3

- `l03/SOURCE-V01-NATIVE-2X-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png`
- `l03/SOURCE-V01-NATIVE-2X-GRAYSCALE-REVIEW-CANDIDATE.png`
- `l03/SOURCE-V01-FOOTPRINT-NATIVE-2X-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png`
- `l03/SOURCE-V01-FOOTPRINT-NATIVE-2X-GRAYSCALE-REVIEW-CANDIDATE.png`
- `l03/SOURCE-V01-ZOOM-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png`
- `l03/SOURCE-V01-SOURCE-SCALE-REVIEW-CANDIDATE.png`

### Residential L4

- `l04/SOURCE-V01-NATIVE-2X-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png`
- `l04/SOURCE-V01-NATIVE-2X-GRAYSCALE-REVIEW-CANDIDATE.png`
- `l04/SOURCE-V01-FOOTPRINT-NATIVE-2X-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png`
- `l04/SOURCE-V01-FOOTPRINT-NATIVE-2X-GRAYSCALE-REVIEW-CANDIDATE.png`
- `l04/SOURCE-V01-ZOOM-NORMALIZED-ALPHA-REVIEW-CANDIDATE.png`
- `l04/SOURCE-V01-SOURCE-SCALE-REVIEW-CANDIDATE.png`

## Binding technical evidence

- `CROSS-LEVEL-RAW-VALIDATION.json`: 12 sources, 12 unique pixel hashes,
  expectation and validation pass.
- `CROSS-LEVEL-NORMALIZED-VALIDATION.json`: 36 LOD sources, 36 unique pixel
  hashes, expectation and validation pass.
- Each level's scene, raw, and normalized reports pass geometry registration,
  unique hashes, alpha/chroma/padding, and subject bounds.
- Every retained raw is repeat-run identical across native renderer processes.
- Every normalized LOD is repeat-run identical across two unchanged-normalizer
  runs.
- All twelve scene descriptors and final provenance records remain
  `productionSelected: false`.

## Density progression for visual review

- L2: compact walk-up, cross-gabled roof, corner stair bay, direct and return
  stoops.
- L3: denser stepped courtyard block, paired wings, lower bridge, balcony
  stacks, and courtyard threshold.
- L4: urban podium tower, setback wing, vertical window rhythm, balconies, and
  distinct copper crown.

Independent quality should judge family recognition, density progression,
frontage readability at actual scale, grayscale hierarchy, normalized edge
quality, and compliance with the frozen footprint/pivot/contact/light/shadow
contracts before any further production is authorized.
