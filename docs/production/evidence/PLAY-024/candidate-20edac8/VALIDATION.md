# PLAY-024 Same-State World Excellence Evidence

- **Exact product:** `20edac880a6f22d902e353d5ce939028f753de84`
- **Authority ancestor:** `e3ba50cd478f185265c9ddaad1e319ddb9475942`
- **Candidate identity:** `world-rendering-w5f893ad1da1b`
- **Bundle identifier:** `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- **Staged bundle:** `dist/CitySim-world-rendering-w5f893ad1da1b.app`
- **Manifest SHA-256:** `ee1fa5c6d8d83d0f3e559ea4e6b0d30d4d90fe576f0347dac60d291fd661ae72`
- **Disposition:** same-state author evidence complete; final fresh-start composition and independent PLAY-053 acceptance remain open

## Truth boundary and visual outcome

This candidate renders only authoritative `CityGameState` roads and occupied
parcels. The Wave 005 opening remains the exact cross at `x 4..<20 @ y 12`
and `y 8..<17 @ x 12`; PLAY-024 adds no decorative road cells, apparent
frontages, plazas, or occupied civic parcels.

The truth-safe same-state correction replaces the flat empty board with a
deterministic 4 x 4 isometric field-material system, gives all 16 real road
masks continuous curb/sidewalk/crossing treatment, and replaces ambiguous
green continuation marks with paved turning heads contained inside terminal
road cells. Sixteen stable generated-v4 groves occupy only authoritative empty
cells outside the road frontage band. Denser public-realm props remain attached
only to real developed road cells. City, neighborhood, and block LODs expose
different material detail without changing semantic objects or hit truth.

Cold launch now invokes the existing renderer-owned Frame Developed City route
once after the initial render. The staged world therefore fills the default
and compact map aperture without player reframing while preserving manual
camera controls.

No ImageGen call or new authored source art was used. This slice reuses the
accepted generated-v4 asset pack and changes deterministic composition,
materials, environmental placement, road termini, and camera presentation.

## Ordered product commits

1. `baa7852` — truth-safe terrain material hierarchy and authenticated road termini
2. `5ce0b36` — deterministic empty-cell landscape and truthful public realm
3. `b8c86b2` — stable environmental semantic objects across LOD
4. `20edac8` — one-time shipping cold-launch developed-city framing

## Validation

- Focused `WorldRenderingTests`: 41/41 passed.
- Full native suite at the exact product: 194/194 passed in 92.216 seconds.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed at exact product `20edac8`.
- Exact staged Bundle.module generated-v4 pack loaded successfully.
- Pack validation: 84 payload checks, 84 extrusion checks, 974 packed-overlap
  checks, 133 retained source records, all 16 road masks at all three LODs,
  zero failures, and source/staged manifest identity.
- Geometry validation: 324 reciprocal ground-contact checks, 36
  building/road-setback checks, 256 entrance/prop exclusion checks, and zero
  collisions or failures.
- Reduce Motion: zero actions with equivalent static meaning.
- Unchanged-pulse soak: stable semantic node identity with no accumulation.

## Performance and residency

| Measure | Result |
|---|---:|
| Cold world update | 3.678 ms |
| Cold total render | 4.907 ms |
| Cold asset decode loads | 0 |
| Default nodes / drawables | 1,313 / 561 |
| Compact nodes / drawables | 1,286 / 534 |
| City active plus adjacent decoded bytes | 10,485,760 |
| Neighborhood/block active plus adjacent decoded bytes | 33,554,432 |
| Default settled RSS after three LOD cycles | 241,056 KiB |
| Compact settled RSS after three LOD cycles | 224,816 KiB |
| RSS ceiling | 333.8 MiB |

The default RSS sample was taken after 2:19 and the compact sample after 3:24.
Both were captured from the exact staged executable after repeated LOD cycling.

## Live staged journeys

The exact staged app was operated at default and exact 900 x 600 content:

- cold launch, block, neighborhood, and city detail;
- keyboard and pointer selection;
- valid and invalid commercial placement with matching overlay and AX truth;
- Return commit to a visible 0% construction site and Command-Z undo;
- pollution diagnostic overlay;
- compact selection and placement;
- Reduce Motion static presentation;
- repeated pan, zoom, frame-developed-city, and hit-test stability.

The retained AX transcripts show that invalid occupied placement remains
unavailable with its exact reason, valid placement advertises the same cost and
upkeep that Return commits, and pointer selection exposes the same authoritative
Power Plant coordinate and action.

`live/pan-zoom-reduce-motion.mp4` is a 14-frame, 7 fps sequence captured from
the real staged app while exercising five pans, two zoom-outs, five return pans,
and frame-developed-city. Direct macOS screen recording was unavailable in the
proof environment, so the retained sequence is frame-sampled rather than a
native continuous screen recording.

## Evidence inventory

- `before/` retains the immutable Wave 005 default and compact reference.
- `live/` retains uncropped exact staged app frames, AX transcripts, and the
  pan/zoom sequence.
- `validation/` retains the 16-mask seam mosaic, default/compact and three-LOD
  harness frames, construction 0/25/50/75/100, strain/recovery, compact spatial
  proof, and exact pack/geometry reports.
- `SHA256SUMS` binds every retained evidence file to this packet.

## Open acceptance dependency

The published Wave contract delegates the richer authoritative starter city to
PLAY-016/PLAY-048. This candidate is deliberately judged against the frozen
Wave 005 truth and contains generic road-mask, terrain, environment, LOD, and
camera behavior that will consume the later topology without special-casing.
PLAY-024 remains active until the accepted PLAY-016/PLAY-048 baseline is
integrated, fresh-start default/compact composition is recaptured, and
independent PLAY-053 review reaches the binding 19/20 bar with no automatic
reject.
