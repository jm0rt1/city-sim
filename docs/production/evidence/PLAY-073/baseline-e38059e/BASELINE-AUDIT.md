# PLAY-073 exact staged baseline audit

## Authority and identity

- Branch: `codex/citysim-world-rendering`.
- Product: `e38059e721dae05c8df421754e3cb63ddf3fa153`.
- Prior accepted PLAY-066 author head
  `b0ce0b0d540d0a4fbdf24d1cacecef68ad190666` is an ancestor.
- Candidate ID: `world-rendering-w5f893ad1da1b`.
- Staging manifest SHA-256:
  `8b45b5e04896386906b8b58127b08367f7abb5891286a807182ff325d879739e`.
- Executable SHA-256:
  `683673e123edce5d91da568fb6fa17371b7e64f90a795d59e2eb419a14746b5a`.
- Source/staged generated-v4 manifest SHA-256:
  `4aac94eb37ec3a17dc345177519a1e5d43b284ede870170e12ca6a9bf0521bd8`.
- Canonical `story-industrial-complication-v1.json` and every isolated
  quicksave copy SHA-256:
  `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`.

`bash -n script/build_and_run.sh` and
`./script/build_and_run.sh --verify` passed before the audit. The exact staged
manifest is retained under `identity/`.

## Same-state protocol

Every binding route used a separate isolated `CITYSIM_DATA_ROOT`, the
byte-identical canonical quicksave, an explicit regular or compact window
environment, and an explicit camera scale. Computer Use invoked Command-O,
verified Day 33 paused, `$34,037`, 332 residents, Freight strategy, 12 notices,
and allowed the load toast to expire before capture.

Regular routes retain uncropped 1278 x 768 decorated-window JPEGs at:

- city `0.85`;
- neighborhood `0.65`; and
- block `0.50`.

Compact routes retain both uncropped 900 x 652 decorated-window JPEGs and
exact 900 x 600 content crops at:

- city `0.576345682144165`;
- neighborhood `0.52`; and
- block `0.45`.

Each route also retains its complete AX tree. All exact staged processes were
terminated after capture.

## Binding defects

1. **Sparse-board composition.** Regular city LOD devotes only 11.54% of the
   measured visible map aperture to non-terrain district pixels. The complete
   developed story reads as one small loop/crossroads surrounded by a field.
2. **Broad undifferentiated green void.** Green terrain occupies 88.46% of
   the regular city aperture and remains the largest connected visual mass at
   every route. Macro swatches change hue but still read as broad flat bands,
   not continuous authored land.
3. **Mixed visual language.** City Hall and the water tower carry richer
   texture, extrusion, and material response than the flatter commercial and
   industrial silhouettes. Hard water-tower and building shadows, outline
   weight, saturation, and facade detail do not share one hierarchy.
4. **Detached parcels.** The park, industrial building, water tower, and
   vacant loop interiors read as isolated plates or objects on terrain rather
   than parcels joined to sidewalks, entrances, and service space.
5. **Visible repetition.** Adjacent residential towers repeat the same
   silhouette, massing, facade rhythm, and lot apron. Vegetation and empty-lot
   treatment recur with obvious neighboring identity.
6. **Discontinuous public realm.** Road asphalt is connected, but curb,
   sidewalk, park access, building aprons, frontage, and lot ground do not
   compose into one continuous pedestrian/service network. Rounded outer
   termini and uniform green road interiors intensify the diorama reading.
7. **LOD is additive, not fully semantic.** Neighborhood and block add street
   furniture and lot props, but the ground plane, parcel relationships, and
   district hierarchy remain materially the same board at a larger scale.

## Quantitative occupancy method

`DEVELOPED-OCCUPANCY.csv` freezes one reproducible comparison method:

- regular aperture: decorated rows 200 through 645 inclusive;
- compact aperture: exact 900 x 600 content rows 125 through 483 inclusive;
- HSV value below 0.12 is excluded as outside-map darkness;
- terrain is hue 0.20 through 0.48, saturation at least 0.15, and value at
  most 0.82;
- every other eligible pixel is counted as developed/public-realm mass.

The metric intentionally excludes green terrain and vegetation, even when
decorative, while counting roads, sidewalks, buildings, material park
surfaces, utilities, props, and their grounding. It is a fixed A/B proxy, not
gameplay occupancy truth and not an acceptance score.

## First systemic product slice

The first renderer mutation will rebuild the occupied district's shared ground
contract across `TerrainRenderer`, `RoadRenderer`, `LotContextRenderer`, and
`CityScene`:

- continuous low-contrast terrain material without traceable broad bands;
- occupied parcel aprons and family-specific frontage/service context joined
  to authoritative road sidewalks;
- deterministic adjacent-identity rejection for lot/vegetation treatment;
- one coherent curb, shadow, outline, and ground-contact hierarchy; and
- a generic developed-district camera priority that raises regular occupancy
  without hiding authoritative roads or useful buildable context.

No new building art, invented parcel, fake road, mirrored/rotated alias,
gameplay rule, HUD change, or beauty-only fixture special case is part of this
slice.

## Rejected capture attempt

`rejected/duplicate-lod/` preserves the first regular city and neighborhood
captures. They are byte-identical because Computer Use transparently launched
an app process without the intended proof environment after the shell launcher
exited. They are not binding evidence. The corrected protocol uses
`open -n --env ...` and verifies the actual process environment before every
capture.
