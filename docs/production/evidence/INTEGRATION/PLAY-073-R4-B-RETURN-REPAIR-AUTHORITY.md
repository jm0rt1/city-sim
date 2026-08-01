# PLAY-073 R4-B return-repair authority

**Owner:** Integration

**Status:** active frontier design authority

**Model boundary:** bounded implementation is `LUNA_IMPLEMENTATION / gpt-5.6-luna / high`; final visual acceptance remains independent `FRONTIER_AUTHORITY / gpt-5.6-sol / high`

## Exact return

Independent PLAY-075 returned exact R4-A product candidate
`0e89914566ba4593b25e2cd52b4b788d204b7331` at exact QA evidence commit
`35ff256581d8f5f14c74309f52ee0853658c937a`. The candidate scored 18/20 and
was materially preferred to baseline `87e1e682566b68d20deb1a9e2028e2b885e0423a`,
but two frozen automatic-return conditions remained:

1. `live/regular/lod-city.jpg` retains a broad undifferentiated green quadrant;
   the authored district does not dominate the intended camera.
2. `live/regular/lod-city.jpg` and `live/regular/lod-neighborhood.jpg` retain an
   unmistakable adjacent pair of orange/black-roof buildings with the same
   silhouette, value grouping, entrance, and roof treatment.

The same frames also show a secondary cohesion defect: the flat orange
buildings remain materially shallower than the civic landmark. Interaction,
HUD cohesion, compact layout, pointer/keyboard parity, FKA, AX, Reduce Motion,
save, exact demolition/Undo, resource identity, and observed performance all
passed and must not regress.

Integration retained the QA packet and explicitly rolled the R4-A product out
of the publishable baseline. The R4-A commit remains the exact implementation
input; do not reconstruct it from prose or substitute a nearby renderer tree.

## Frozen R4-B outcome

Produce one coherent renderer-owned successor that preserves R4-A's accepted
district, road/public-realm, interaction, and performance gains while closing
all three visible cohesion defects:

- Break the upper-right plain-terrain mass into a deliberate authored context
  using truthful deterministic terrain material, topographic, vegetation,
  parcel-edge, and public-realm transitions. Preserve at least one complete
  buildable parcel band. No single plain-grass region may exceed `0.25` of the
  safe map aperture or remain the largest authored visual mass; the connected
  district/public-realm envelope must occupy at least `0.60` of safe map width
  at regular and compact sizes.
- Remove obvious adjacent repetition without mirroring, rotating, recoloring,
  or semantically relabeling building art. Use stable neighbor-aware selection
  among already accepted identities where available, plus deterministic
  frontage, yard, path, vegetation, fence, service-edge, and prop composition
  so adjacent occupied lots do not share the same silhouette/value/entrance/
  roof read at city or neighborhood LOD.
- Bring ordinary residential/commercial shells into the same ground-contact,
  shadow depth, outline weight, facade value hierarchy, and screen-space scale
  language as landmarks. Do not flatten landmarks or hide the mismatch with
  fog, crop, overlay, blur, or reduced opacity.

## Exact mutable surfaces

- `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/LotContextRenderer.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/TerrainRenderer.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
- one new task-owned evidence root under `docs/production/evidence/PLAY-073/r4-b-*`

No other product, test, asset, package, manifest, gameplay, simulation, UI,
save, art-source, shipping-selection, claim, shared-authority, or build-script
path is authorized. Stop for Integration if another path or contract is
required.

## Focused execution and proof

The Renderer task is the only Git/evidence writer. It must expose an internal
execution plan and safely overlap independent terrain analysis, neighbor-
repetition analysis, and read-only proof preparation while serializing edits
and commit assembly.

Required focused proof before handoff:

1. renderer-focused Swift tests, including adversaries for one oversized plain
   region, adjacent duplicate visual signatures, unstable variation, false
   semantic variation, and interaction hit-target drift;
2. deterministic same-state exports at city, neighborhood, and block LOD for
   regular and exact 900x600 compact layouts, in color and grayscale;
3. measured safe-width occupancy, largest plain-region share, adjacent visual
   signature collisions, ground-contact/outline/value metrics, resource
   identity, and repeat determinism;
4. exact retained comparison against the R4-A QA frames and accepted baseline,
   with no fixture-only substitution;
5. focused frame/node/draw/RSS evidence and zero fallback, collision, clipped
   interaction, overlay, placement, selection, or Reduce Motion regression;
6. one coherent product commit followed by one evidence commit, both clean and
   confined to the exact allowed paths.

The worker must return its own candidate if any automatic return remains. It
does not run the full Swift suite, publish, push, self-score, or self-accept.
Integration owns the single aggregated full suite and staged build; a fresh
independent frontier QA task owns the one exact-candidate real-app 20/20 gate.
