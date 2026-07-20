# PLAY-022 Living Strategy Art Direction

## Visual contract

The renderer consumes authoritative `CityTile.kind`, `level`, `condition`, and
`constructionProgress`. Wave 003 architecture may communicate land use,
density, construction, and condition from those fields. It must not infer
utility service, pollution, prosperity, strain, recovery, occupancy, freight,
traffic, employment, or event state.

Commercial form progresses non-color-only from a fine-grained main-street shop
row, through a courtyard mixed block, to a stepped tower district with podium,
roof crowns, and skybridge. Industrial form progresses from fabrication sheds
and an open service yard, through a warehouse-and-silo logistics form, to a
process campus with production hall, tanks, stacks, and pipe gantries. Three
coordinate-stable variants at every tier change massing, roofline, and material
arrangement without changing simulation meaning.

Parcel language reinforces form at every camera distance: commercial lots use
pedestrian-scale paving, planting, and finer frontage rhythm; industrial lots
use hardened yards, striped safety edges, container forms, and gantry lines.
The family must remain identifiable in grayscale and without labels.

## Camera and interaction states

- City detail: skyline and low-wide versus tall-stepped massing carry identity.
- Neighborhood detail: frontage rhythm, podiums, sheds, silos, tanks, and yards.
- Block detail: awnings, shop bays, loading doors, pipework, banners, windsocks,
  planters, and parcel markings.
- Selection, hover, valid/invalid placement, overlays, road topology, and hit
  testing retain visual priority over parcel decoration.
- Reduce Motion keeps the banner/windsock silhouette and removes its action.

## Determinism and budgets

- Identity is `kind + clamp(level, 1...3) + coordinate-seeded variant`.
- Asset atlas schema 2 adds 18 strategy buildings and 6 parcel treatments.
- Ambient strategy decoration is bounded to one keyed action per completed
  commercial or industrial lot and zero actions under Reduce Motion.
- Unchanged pulses must reuse tile roots and retain fixed node/draw/action
  counts. PLAY-021's 30-minute-equivalent soak remains the comparison baseline.

## Contract boundary

PLAY-041 remains the required authority for factual per-location utility,
pollution, prosperity, strain, and recovery presentation. Those consequence
layers are deliberately absent from this renderer-local checkpoint. Once the
approved snapshot contract is integrated, PLAY-022 will map only its typed
values to localized, non-color-only effects and retain same-city live evidence.
