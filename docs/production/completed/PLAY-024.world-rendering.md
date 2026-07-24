# PLAY-024 Environment and Street-System Excellence Completion

- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Status:** renderer candidate complete and clean for integration; not pushed or self-integrated
- **Authority:** `e3ba50cd478f185265c9ddaad1e319ddb9475942`
- **Exact product:** `20edac880a6f22d902e353d5ce939028f753de84`
- **Primary evidence:** `4e0bb39ea66484e433d32338aa8b40ee92cb801a`
- **Bundled-Python validation:** `108878f3ac0859349df8981781da11d27fcc492b`
- **Candidate identity:** `world-rendering-w5f893ad1da1b`
- **Bundle identifier:** `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- **Final Wave acceptance:** pending integrated PLAY-016/PLAY-048 fresh-start composition and independent PLAY-053 scoring

## Ordered task commits

1. `baa7852b3a994bc8ff3837cf86bdafa964c7724b` — author truth-safe
   terrain materials and authenticated road termini.
2. `5ce0b36a3c30773f1a3b561dafa20a0e6e218296` — populate only
   authoritative vacant cells and truthful real-road public realm.
3. `b8c86b2ed25a8c04236b5fd919e8761ccc1ccf49` — preserve stable
   environmental semantic objects across LOD.
4. `20edac880a6f22d902e353d5ce939028f753de84` — frame the shipping
   developed city once after cold launch.
5. `4e0bb39ea66484e433d32338aa8b40ee92cb801a` — retain exact staged
   default, compact, LOD, interaction, accessibility, performance, and geometry
   proof.
6. `108878f3ac0859349df8981781da11d27fcc492b` — reproduce the source
   and exact staged-bundle validators with the bundled Python runtime.
7. This completion commit records the integration and quality handoff; it
   changes no product source or resource.

## Player-visible outcome

The frozen Wave 005 state now sits on a deterministic, materially varied
isometric landscape rather than a flat green board. Every authoritative road
cell uses the complete 16-mask curb, sidewalk, crossing, and frontage grammar.
Interior road ends use paved, bounded turning heads instead of ambiguous green
continuations. Deterministic generated-v4 vegetation and public-realm details
fill truthful empty and developed-road space without changing gameplay state,
hit targets, or occupied parcels.

City, neighborhood, and block LODs expose useful material detail while
preserving one semantic object set and stable reuse. The cold staged launch
uses the existing renderer-owned frame-developed-city behavior once, making
the real world fill default and compact apertures without player intervention.

No new generated art, gameplay truth, HUD state, save contract, shared package
surface, or legacy Python implementation was introduced.

## Exact changed product surfaces

- `Native/CitySimNative/Sources/CitySimNative/Rendering/AmbientLifeRenderer.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/CitySceneView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/RoadRenderer.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/TerrainRenderer.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`

## Automated and staged validation

- Focused `WorldRenderingTests`: 41/41 passed.
- Full native suite at the exact product: 194/194 passed in 92.216 seconds.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed with staged manifest commit
  `20edac8`.
- The exact bundled interpreter
  `/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`
  imported Pillow 12.2.0 without any dependency change.
- Source/staged pack validation passed 84 payload, 84 extrusion, 974 packed
  overlap, 133 inventory, all-mask, all-LOD, digest, fallback, and residency
  checks with zero failures.
- Geometry validation passed 324 reciprocal contact, 36 road setback, and 256
  entrance/prop exclusion checks with zero collisions or failures.
- The newly generated validator reports were byte-for-byte identical to the
  retained evidence reports.

## Hands-on flow and proof

The exact staged app was operated at default and exact 900 x 600 content
through cold launch, all three LODs, pointer and keyboard selection, valid and
invalid placement, Return commit, undo, diagnostic overlay, repeated pan/zoom,
compact mode, accessibility inspection, and Reduce Motion. AX state, overlay
text, placement availability, Return behavior, and selected coordinates agreed.

The immutable packet is
`docs/production/evidence/PLAY-024/candidate-20edac8/VALIDATION.md`; every
retained file is bound by its adjacent `SHA256SUMS`.

## Budgets

- Cold render: 3.678 ms world update, 4.907 ms total, zero decode loads.
- Default: 1,313 nodes / 561 drawables; settled RSS 241,056 KiB.
- Compact: 1,286 nodes / 534 drawables; settled RSS 224,816 KiB.
- City active plus adjacent decoded bytes: 10,485,760.
- Neighborhood/block active plus adjacent decoded bytes: 33,554,432.
- Reduce Motion: zero actions with equivalent static meaning.
- Unchanged-pulse soak: stable node identity with no accumulation.

## Integration and quality handoff

Integrate the ordered commits above before rerunning proof on the accepted
PLAY-016/PLAY-048 authoritative starter state. The renderer consumes generic
`CityGameState` topology through all 16 masks and contains no special case for
the old cross or the forthcoming district.

The same-state proof is complete, but final Wave acceptance is intentionally
not claimed. Integration must recapture uncropped default and exact compact
fresh-start composition after PLAY-016/PLAY-048 adoption and hand the exact
combined world/HUD candidate to independent PLAY-053. The binding 19/20 score,
4/4 composition and coherence, and zero automatic rejects remain open.

No shared-contract proposal is required.
