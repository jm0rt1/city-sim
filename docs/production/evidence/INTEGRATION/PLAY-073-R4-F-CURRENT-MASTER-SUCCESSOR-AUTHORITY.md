# PLAY-073 R4-F current-master successor authority

## Disposition

`RETURN_CURRENT_RENDERER`. Exact combined renderer head
`7e564c2c21209f594ffdc6c58cb1603b7f04df7c` is rejected as a product
candidate. It remains preserved as evidence. No product commit from that
lineage may be merged or cherry-picked wholesale.

The accepted product base for both implementation cells is the clean published
current master named by their model routes. The frontier visual audit freezes
the following outcomes; Luna executes them without making new visual-architecture
or acceptance decisions.

## Frozen player-visible outcomes

1. Authored occupied and public-realm fabric spans at least 60% of the safe
   aperture width at regular and exact 900x600 compact sizes. Default camera,
   crop, pan, focus, and buildable coordinates remain unchanged.
2. No connected plain-terrain component exceeds 25% of the safe aperture.
   Pixel noise, recolored vacancy, or invented development does not count.
3. Roads, curbs, sidewalks, parcel grounds, service edges, and authoritative
   frontages form one connected district. Road surface is at most 35% of that
   authored-district mask; one complete buildable expansion band remains.
4. Every completed place has continuous parcel contact and a road-facing access
   link. Context geometry stays inside the lot diamond plus its normalized
   frontage corridor, with no road or neighboring-lot collision.
5. City Hall remains the focal silhouette. Utility/service silhouettes stay at
   or below 85% of City Hall height and screen area; props stay at or below 50%
   of their host building height.
6. Adjacent contextual alternatives must differ in real geometry and raster
   support. Common-origin silhouette-mask Jaccard overlap is at most 0.70 and
   each context contributes at least 24 unique compact pixels.
7. Contact shadows follow one northwest-light/southeast-shadow hierarchy,
   remain parcel-bound, and sit 18-32 grayscale levels below local ground.
8. City, Neighborhood, and Block retain the same massing and grounding while
   removing progressively finer detail. Stacked duplicate geometry, fallback,
   aliases, mirroring, rotation, recolor substitution, mixed fidelity, and
   camera workarounds are automatic returns.

## Parallel implementation cells

### R4-F1 — District fabric

Exclusive mutable paths:

- `Native/CitySimNative/Sources/CitySimNative/Rendering/TerrainRenderer.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/RoadRenderer.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/PLAY073DistrictFabricTests.swift`
- `docs/production/evidence/PLAY-073/r4-f1-district-fabric-v1/`

Implement the connected authored-district/public-realm envelope, broad-green
breakup, and road/curb/sidewalk hierarchy without changing camera, gameplay,
simulation, accepted source art, or buildable truth. Focused proof covers the
new test class plus existing road-atlas, physical-network, macro-terrain,
vacant-commons, and starting-camera tests, with deterministic regular/compact
semantic masks and exact repeat output.

### R4-F2 — Place cohesion

Exclusive mutable paths:

- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotContextRenderer.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotRenderer.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/PLAY073PlaceCohesionTests.swift`
- `docs/production/evidence/PLAY-073/r4-f2-place-cohesion-v1/`

Reconstruct only the narrow useful semantics from the rejected lineage:
explicit ground-before-sprite and foreground-after-sprite phases; normalized
frontage/socket calculations; template caching; fixed visible variant counts;
parcel-bound contact shadows; containment; lossless path/color identity. Phase
ownership must be authored at construction, never inferred from node names.

Remove or replace the concrete garden-grove and terraced-court geometry,
oversized canopy/slab projections, fixed edge offsets, and failed exporter
assertions. Do not import the expanded historical `WorldRenderingTests.swift`.
Focused proof covers the new test class plus existing lot-context and three-LOD
tests for every family, variant, and frontage: geometry/raster identity,
containment, entrance clearance, noninteraction, civic/park exclusion, focal
scale, shadow hierarchy, and exact repeat output.

## Join and acceptance

The two implementation cells must remain path-disjoint and commit independently.
A failure or return in one does not demote the other. Integration alone reviews
and joins exact candidates, runs the aggregate technical gate and stages one
exact-SHA app. PLAY-075 then produces one independent comparison board with
columns for accepted master, rejected `7e564c2c`, and the joined successor; rows
are regular color/grayscale and exact 900x600 color/grayscale at the frozen fresh
opening/default camera. The board records district width, largest plain
component, road share, focal scale, grounding, repetition masks, interaction,
accessibility, and resource measurements. Numerical green cannot replace the
fresh unaided frontier real-app judgment.

## Hard boundaries

No cell may edit `CityScene.swift`, camera behavior, resources, package/build
files, accepted art, gameplay, UI, simulation, persistence, claims, Integration
authority, or another cell's paths. No worker runs the unfiltered full suite,
staged build, final real-app journey, push, integration, or self-acceptance.
