# PLAY-063 Independent Industrial L1 Gate

- **Disposition:** APPROVED
- **Score:** **20/20**
- **Exact combined candidate:**
  `f928696a84676032b20c6306b14d943592e219fb`
- **Frozen preregistration:**
  `b9f2aedc985d31329c49d259cbbd1a303b021047`
- **PLAY-062 product / admission evidence:**
  `02612e414912fdabcab858b0ca97e1f5edbc2757` /
  `7ea9971f58f9c86cb17c1b978c7af3ae9b230cae`
- **Accepted source authority:**
  `79668c347e58d602f9627c73cb09e3272a83ef57`
- **Frozen baseline:**
  `8f85a0cff1adb489eec2f8a95f066e5161d7e7d3`
- **Independent evidence commit:**
  `87e165645a2487765722853929cb61ac56b4e9ae`
- **Date:** July 25, 2026

Exact candidate `f928696` passes the immutable candidate-blind PLAY-063 gate:
every category earns four points, regular and exact compact are materially
preferred to the same-state baseline, no P0/P1 defect was found, and every
automatic-reject class is clear.

## Frozen score

| Category | Score | Independent result |
|---|---:|---|
| Industrial L1 identity and road-facing frontage | 4/4 | All twelve N/E/S/W x city/neighborhood/block identities are unique accepted source-v05 derivatives with authored orientation, distinct color/grayscale silhouettes, exact frontage sockets, and no Residential/Commercial/cross-direction alias, mirror, rotation, or fallback. |
| Whole-scene world/HUD cohesion | 4/4 | The loading works sits physically on the authored parcel beside roads, Commercial, public realm, water tower, and City Hall. Selection, construction, five overlays, Details, Focus City, compact HUD, and Reduce Motion remain coherent. Candidate is materially preferred in uncropped regular and compact same-state views. |
| Silhouette, material hierarchy, LOD, and family recognition | 4/4 | Gantry, factory mass, entrance, roof equipment, service apron, foundation, and shadow remain complete and direction-distinct at all three LODs. Industrial is unmistakable beside Residential and Commercial in color and grayscale without fringe, toy-icon collapse, or mixed fidelity. |
| Interaction, state truth, persistence, and accessibility | 4/4 | Pointer, Return, Space, menu/command, FKA, and AX preserve one authoritative target. Occupied rejection retains tool/target, valid pointer and keyboard placements mutate block 16,12 once, undo restores exact bytes, load returns paused, all overlays and Focus City retain truth, and Escape/Reduce Motion remain stable. |
| Shipping identity, determinism, and performance | 4/4 | Exact commit/bundle/executable/manifest/PID/data roots are bound; source and staged manifests match; two pack builds are byte-identical; four-page residency is bounded with zero fallback; geometry is collision-free; focused/full suites and staged verify pass; frame/RSS budgets are met. |

## Material preference

The frozen baseline uses one generic brick, south-facing factory for every
Industrial frontage. At the byte-identical Day 33 complication state,
candidate south renders the accepted authored loading works: a high
orange-edged gantry, dark factory mass, industrial roof/equipment rhythm,
grounded entrance/loading edge, service apron, and contact shadow.

- **Regular:** the Industrial block is easier to distinguish from the
  adjacent Commercial building and civic/water assets without hiding the road,
  selection, priority action, or HUD.
- **Exact compact:** the gantry/factory/apron silhouette survives the tighter
  aperture and remains identifiable behind the white selection boundary,
  Details, Focus City, and overlays.
- **Systemic direction:** the independent packed 4 x 3 matrix replaces the
  baseline's four-direction alias with visibly distinct, road-facing north,
  east, south, and west identities at city, neighborhood, and block LOD.

This preference uses uncropped real-app same-state frames and an independently
rerun exact packed matrix. It is not an author score, crop, or hero-only frame.

## Automatic-reject audit

| Frozen reject class | Result |
|---|---|
| Candidate, bundle, executable, manifest, resource, fixture, camera, target, window, root, or PID ambiguity | CLEAR — exact hashes, environments, routes, and PIDs retained |
| Cropped/resized/transient-obscured, harness-only, author-only, or one-width proof | CLEAR — uncropped regular and compact live frames, exact scale routes, real inputs, and full AX captures retained |
| Residential/Commercial alias, wrong level/frontage, cross-direction alias, synthesized fallback, mirror, or rotation | CLEAR — 12/12 packed identities are unique authored L1 frontages; zero fallback |
| Source/raw/normalized/packed/staged/runtime mismatch | CLEAR — four raw and twelve normalized identities; source/staged manifest parity and exact runtime tests pass |
| Footprint, pivot, socket, exclusion, foundation, shadow, contact, projection, material, light, alpha, padding, or registration drift | CLEAR — pack and geometry validators report zero failures |
| Building/road/prop/public-realm/HUD/overlay/selection/label/material overlap | CLEAR — none observed; road, reciprocal-ground, and entrance/prop collisions are zero |
| Broken road end, reciprocal seam, apron-road discontinuity, or public-realm regression | CLEAR |
| Identity, direction, condition, construction, preview, overlay, Focus City, consequence, warning, speed, save/load, or undo mismatch | CLEAR — live screenshots and AX agree; undo-restored save and backup match the original fixture bytes |
| Stale/moved target, pointer leak, double activation, inaccessible action, text/modal leakage, focus instability, or broken Escape order | CLEAR — exact coordinate retained; pointer, keyboard, FKA, and AX routes remained coherent |
| Critical AX-only information visually clipped, hidden, microscopic, or unreachable | CLEAR — compact Details exposes identity, operations, consequence, and response visibly or through its explicit scroll region |
| Reduce Motion information loss or state change | CLEAR |
| Nondeterminism, fallback, more than four pages, excess/accumulating residency or RSS, or unexplained timing regression | CLEAR |
| Hero frame hiding direction/LOD/width/color/grayscale/interaction failure | CLEAR — complete 4 x 3 matrices, exact live LODs, both widths, lifecycle, overlays, inputs, AX, and persistence retained |
| Product/source mutation, coaching, substitution, author score, or post-result waiver | CLEAR — quality-only evidence; preregistration unchanged |

## Tests, resources, and performance

- `WorldRenderingTests`: **55/55**, zero failures, 30.235 seconds.
- Full native suite: **226/226**, zero failures, 108.929 seconds.
- Staged verification and shell syntax: passed.
- Pack: four pages, four Industrial raw identities, twelve unique normalized
  LODs, staged/source parity, zero failures.
- Geometry: 48 assets, zero building/road, reciprocal-ground, or
  entrance/prop-exclusion collisions.
- Repeated LOD residency: three textures and 41,943,040-byte high-water, zero
  fallback.
- Cold total: 5.702 ms in the full run and 5.907 ms in the focused repeat,
  versus 5.632 ms frozen baseline; +1.24% and +4.88%, below the 20% guard.
- Soak: 4,286 pulses, 0.0006 ms unchanged-pulse average.
- Highest observed quality RSS: 230,208 KiB launch sample, with lower settled
  samples and no continuing growth; below the 333.8 MiB ceiling.

## Defects and limitations

- **P0/P1 defects:** none.
- **Product defects in PLAY-063 scope:** none found.
- Spoken VoiceOver audio was not recorded. Quality retained and exercised
  complete AX trees, the map's exact custom AX action, semantic
  value/help/action text, FKA traversal, and focus restoration.
- The authentic story fixture contains one south-facing Industrial L1 lot.
  Quality did not fabricate north/east/west story state. Those directions are
  independently covered by the exact packed color/grayscale matrix, accepted
  source/staged hashes, frontage and geometry validators, and runtime
  all-LOD/save/load/undo tests. The live route prevents the disposition from
  becoming harness-only.
- Early wheel/key zoom attempts were visually ambiguous and remain retained
  chronology only. Binding LOD proof comes from separate exact
  `CITYSIM_PROOF_CAMERA_SCALE` processes at 0.85, 0.65, 0.50, and compact
  0.45.

## Integration recommendation

Accept exact combined candidate
`f928696a84676032b20c6306b14d943592e219fb` for PLAY-063. Do not generalize
this approval to another commit, pack, bundle, or future Industrial candidate.
