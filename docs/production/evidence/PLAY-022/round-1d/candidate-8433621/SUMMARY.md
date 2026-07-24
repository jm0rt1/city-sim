# PLAY-022 Round 1D candidate evidence

- **Disposition:** author-complete candidate; independent PLAY-052 scoring
  required, no self-acceptance
- **Product commit:** `8433621760ba169995aa1a5dc81cac27c380d746`
- **Product tree:** `c02c6811f8a4e257f0297a189514ff9875a004a1`
- **Rejected predecessor:** product `2cf18b0` / evidence `f35d6ef`
- **Candidate ID:** `world-rendering-w5f893ad1da1b`
- **Bundle ID:** `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`

## Corrective outcome

1. The shipping start now frames authoritative developed mass rather than the
   long opportunity-road bounds. Default developed-width occupancy is 74.73%;
   exact compact is 56.00%.
2. Every road mask is compiled from the retained generated-v4 road material
   into a single deterministic road/curb/sidewalk language. Connected masks,
   crossings, lane marks, frontage joins, and intentional terminal treatment
   replace flat procedural strips and ladder-like junction marks.
3. City, neighborhood, and block stops are materially distinct in both regular
   and compact live captures: city reads network and mass, neighborhood reads
   frontage and blocks, and block reveals material, props, and construction.
4. Existing selection, overlay, hit testing, placement truth, Reduce Motion,
   asset identity, collision safety, and bounded residency remain intact.

No UI/view, store, gameplay, save, Package.swift, build-script, legacy Python,
PLAY-023, Round 2, or CONTRACT-008 implementation is included.

## Exact live flows

- Default shipping start: `live/default-city.jpeg`.
- Exact 900 x 600 content: `live/compact-900x600.jpeg` (900 x 652 including
  native title bar).
- Same-state LODs:
  `live/regular-city-lod.jpeg`, `regular-neighborhood-lod.jpeg`,
  `regular-block-lod.jpeg`, plus the corresponding compact frames.
- Pointer selected City Hall 12,12 and AX announced type, completion,
  condition, utility/pollution/vitality consequence, and available Inspect
  action.
- Keyboard selected Road 14,13 with one grounded cyan boundary.
- Build mode on occupied Road 14,13 announced and drew the exact invalid
  reason: `Unavailable. Demolish the existing structure before building here.`
- Keyboard moved to Road 21,13; AX and preview agreed it was available at
  $120 / $2 per cycle. Return committed the road, making that coordinate
  occupied/unavailable; Command-Z restored open land and cleared selection.
- Utilities overlay retained selection and used sparse non-color status marks.
- Reduce Motion proof used the exact compact staged app with
  `CITYSIM_REDUCE_MOTION_PROOF=1`; A/B frames five seconds apart are
  byte-identical, and focused diagnostics report zero reduced-motion actions.
- Pan/zoom proof contains 25 direct real-app frames encoded at 7 fps, with no
  generated intermediate frames:
  `live/regular-pan-zoom-7fps.mov`.

## Automated and staged validation

- Focused renderer suite: 36/36 passed, zero failures, 9.779 seconds.
- Full native suite: 136/136 passed, zero failures, 45.725 seconds.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed at exact product `8433621`;
  packaged generated-v4 manifest equals source.
- Candidate isolation: PASS for two clean disposable clones with distinct
  worktree tokens, bundle IDs, preference domains, data roots, executables,
  manifests, and live PIDs while retaining the same product commit.
- Geometry validator: PASS; 324 reciprocal ground checks, 36 building/road
  setback checks, 256 entrance/prop exclusion-neighbor checks, zero collisions,
  zero missing or orphan inventory entries.
- Road topology proof covers all 16 masks at all three semantic LODs.
- Five same-coordinate construction frames (0/25/50/75/100) are unique and
  retain zero actions under Reduce Motion.

## Performance and residency

- Preregistered fresh-process totals: 3.913, 3.766, 3.658, 3.800, 3.743 ms.
- Governed median: 3.766 ms; maximum: 3.913 ms; 5/5 at or below 6.03 ms.
- Full scene: 1,111 nodes / 389 drawables at default, 1,102 / 380 at compact.
- Ten pulses: 5,759 reused tiles, one update, 0.826 ms average render.
- Active decoded bytes: city 862,592; neighborhood 3,407,960; block
  13,521,048. Repeated LOD high water remains 13,521,048 with zero fallback.
- After three live LOD cycles and 60-second settle:
  regular 218 MB footprint / 252,944 KiB RSS / 325 MB peak;
  compact 179 MB / 242,752 KiB / 311 MB peak. Both settled footprints are
  below the 333.8 MiB ceiling.

## Accessibility and color independence

Retained AX trees cover regular pointer and compact keyboard selection.
Selection, valid placement, invalid placement, utility status, road sockets,
construction silhouettes, and LOD changes remain non-color-only. Deterministic
grayscale, protanopia, deuteranopia, and tritanopia sheets are generated from
exact candidate frames and five construction proofs.

## Truthful limitations

- Independent quality has not scored this candidate; this packet cannot close
  PLAY-022 or authorize integration by itself.
- Exact staged default/compact and interactions are live. Five-stage
  construction, decline/recovery, and spatial consequence sequences use the
  shipping renderer harness because advancing those exact states on demand
  would require gameplay mutation outside this lane.
- Native `screencapture` recording was unavailable. The retained 7 fps movie
  uses only 25 direct Computer Use frames from the exact staged app; no frames
  were synthesized.
- The 900 x 600 aperture intentionally lets peripheral roofs/shadows sit under
  translucent chrome so the central developed district remains dominant.
  Active selection and placement coordinates remain visible and AX-addressable.
