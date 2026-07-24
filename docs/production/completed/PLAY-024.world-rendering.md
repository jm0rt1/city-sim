# PLAY-024 Environment and Street-System Excellence Completion

- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Status:** combined renderer/gameplay/platform candidate complete and clean
  for integration; not pushed, self-integrated, or self-scored
- **Authority:** `e3ba50cd478f185265c9ddaad1e319ddb9475942`
- **Platform adoption checkpoint:** `60bf0c066cd7a5d75e399b518ae697fbd73690eb`
- **World/platform merge:** `f4ebca3c2fb9558a7d5ff83189319ca9ef39d9e6`
- **Exact product:** `a1e589e68783e25dc5788b055b3b9e786acb4b69`
- **Same-state evidence:** `4e0bb39ea66484e433d32338aa8b40ee92cb801a`
- **Authoritative fresh-start evidence:** `9791621c7f3a8109500d2c8567e7b2db8fa4d9b7`
- **Bundled-Python validation:** `108878f3ac0859349df8981781da11d27fcc492b`
- **Candidate identity:** `world-rendering-w5f893ad1da1b`
- **Bundle identifier:** `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- **Final Wave acceptance:** pending independent PLAY-053 scoring

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
   same-state proof.
6. `108878f3ac0859349df8981781da11d27fcc492b` — reproduce the source
   and exact staged-bundle validators with the bundled Python runtime.
7. `f4ebca3c2fb9558a7d5ff83189319ca9ef39d9e6` — normally merge the
   accepted gameplay/platform starter-district adoption.
8. `a1e589e68783e25dc5788b055b3b9e786acb4b69` — consume the
   authoritative 32-road, two-block topology generically and repair exact
   renderer expectations.
9. `9791621c7f3a8109500d2c8567e7b2db8fa4d9b7` — retain uncropped
   default/compact Comparison B proof and exact staged validator reports.
10. This completion commit records the final independent-quality handoff; it
    changes no product source or resource.

## Player-visible outcome

The accepted starter state now presents 32 connected authoritative road cells,
two developed blocks, eight occupied lots, and the relocated water tower on a
deterministic, materially varied isometric landscape. Every road cell uses the
complete 16-mask curb, sidewalk, crossing, and frontage grammar. No renderer
road, occupied lot, or apparent gameplay truth exists outside `CityGameState`.
Deterministic generated-v4 vegetation and public-realm details fill truthful
empty and developed-road space without changing gameplay state, hit targets,
or occupied parcels.

City, neighborhood, and block LODs expose useful material detail while
preserving one semantic object set and stable reuse. Cold staged launch frames
the real developed bounds once, making the authoritative city fill default and
compact apertures without player intervention.

The renderer adoption is topology-generic: it derives road masks, bounds,
camera occupancy, references, and spatial focus from authoritative state. No
new generated art, gameplay truth, HUD state, save contract, shared package
surface, seed special case, or legacy Python implementation was introduced.

## Exact changed product surfaces

- `Native/CitySimNative/Sources/CitySimNative/Rendering/AmbientLifeRenderer.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/CitySceneView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/RoadRenderer.swift`
- `Native/CitySimNative/Sources/CitySimNative/Rendering/TerrainRenderer.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`

The final topology-adoption commit changes only `CityScene.swift` and
`WorldRenderingTests.swift`; gameplay and platform files arrive unchanged
through the reviewed platform merge.

## Automated and staged validation

- Focused `WorldRenderingTests`: 41/41 passed in 13.216 seconds.
- Full combined native suite at the exact product: 199/199 passed in 93.736
  seconds.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed with staged manifest commit
  `a1e589e`.
- The exact bundled interpreter
  `/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`
  imported Pillow 12.2.0 without any dependency change.
- Source/staged pack validation passed 84 payload, 84 extrusion, 974 packed
  overlap, 133 inventory, all-mask, all-LOD, digest, fallback, and residency
  checks with zero failures.
- Geometry validation passed 324 reciprocal contact, 36 road setback, and 256
  entrance/prop exclusion checks with zero collisions or failures.
- The final staged source/resource validator reports are retained and hashed
  in the Comparison B packet.

## Hands-on flow and proof

The original same-state exact staged app was operated at default and exact
900 x 600 content through cold launch, all three LODs, pointer and keyboard
selection, valid and invalid placement, Return commit, undo, diagnostic
overlay, repeated pan/zoom, compact mode, accessibility inspection, and Reduce
Motion. AX state, overlay text, placement availability, Return behavior, and
selected coordinates agreed.

That immutable packet is
`docs/production/evidence/PLAY-024/candidate-20edac8/VALIDATION.md`; every
retained file is bound by its adjacent `SHA256SUMS`.

The post-adoption staged app was then launched without a save and captured
uncropped at default and exact 900 x 600 content. Both frames show the same
unchanged 32-road, two-block, eight-lot fresh-start topology. This is
truthfully labeled Comparison B because the authoritative starter state
changed; it is not relabeled as same-state proof. The app reached Day 8 before
pause, with no player build, bulldoze, placement, or topology mutation. The
packet and hashes are under
`docs/production/evidence/PLAY-024/candidate-a1e589e/`.

## Budgets

- Cold render: 3.516 ms world update, 4.785 ms total, zero decode loads.
- Default: 1,357 nodes / 549 drawables, occupied-width ratio
  `0.7473417932`.
- Compact: 1,333 nodes / 525 drawables, occupied-width ratio `0.5600000271`.
- City active plus adjacent decoded bytes: 10,485,760.
- Neighborhood/block active plus adjacent decoded bytes: 33,554,432.
- Reduce Motion: zero actions with equivalent static meaning.
- Unchanged-pulse soak: stable node identity with no accumulation and two
  bounded actions.

## Integration and quality handoff

Integrate the ordered commits above and hand the exact combined candidate to
independent PLAY-053. The renderer consumes generic `CityGameState` topology
through all 16 masks and contains no special case for either the retired cross
or the accepted starter district.

Same-state engineering proof and authoritative fresh-start Comparison B proof
are complete, but final Wave acceptance is intentionally not claimed. The
binding 19/20 score, 4/4 composition and coherence, and zero automatic rejects
remain open.

No shared-contract proposal is required.
