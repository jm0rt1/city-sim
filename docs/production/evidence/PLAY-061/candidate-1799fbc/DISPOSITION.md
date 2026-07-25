# PLAY-061 Independent Commercial Skyline Gate

- **Disposition:** APPROVED
- **Score:** **20/20**
- **Exact integration candidate:** `1799fbc2810f14d85511b74a8808bbee1928eef7`
- **Frozen preregistration:** `bd0a06ea676f492e5dc7a354f423f51e6ed4a741`
- **Accepted source authority:** `bf3e24b2b465870f131ac0a01a2327ac4969d5d5`
- **PLAY-060 product / evidence / completion:** `4473f5a1fe827e143701fea6386299db1116ed45` / `528f0e03911b521a2100b9191b4864f2be29631d` / `2c1e9f28004d710cf614c8803d2223de1e5861cb`
- **Independent evidence commit:** `cca42813ebbced1201bcb3c4fb3f6c568c0307ec`
- **Date:** July 25, 2026

Exact candidate `1799fbc` passes the frozen PLAY-061 gate with every category
at four, zero P0/P1 defects, zero automatic rejects, and explicit material
preference over frozen product `64dd475` in uncropped regular and exact compact
same-state comparisons.

## Score

| Category | Score | Independent result |
|---|---:|---|
| Commercial identity and road-facing direction | 4/4 | All sixteen L1-L4 x N/E/S/W exact-runtime identities are unique, accepted-source-derived, correctly socketed, visually directional, and free of Residential/Industrial alias, mirror, rotation, substitution, or fallback. |
| Whole-scene world/HUD cohesion | 4/4 | The low storefront, market block, stepped office block, and tower form a coherent density sequence without overwhelming roads, public realm, neighboring families, selection, overlays, Focus City, Details, or compact HUD aperture. Candidate is materially preferred at regular and compact sizes. |
| Skyline progression, material hierarchy, and LOD readability | 4/4 | Color and grayscale matrices distinguish every level by massing, roofline, fenestration and height. Explicit city/neighborhood/block app frames are useful and hash-distinct; exact tests retain all identities across all three LODs. |
| Interaction, state truth, persistence, and accessibility | 4/4 | Pointer, keyboard, command search, FKA and AX agree on Commercial identity and target. Occupied rejection retains tool/target, valid placement commits once, undo restores exact state, Focus City preserves target, save/relaunch loads paused, Escape restores focus, and Reduce Motion preserves meaning. |
| Shipping identity, determinism, and performance | 4/4 | Exact commit/bundle/executable/manifest/PID/data roots are bound; source and staged pack hashes match; two pack builds are byte-identical; four-page residency is bounded with zero fallback; focused/full suites and staged verification pass; frame/RSS budgets are met. |

## Material preference

The frozen baseline resolves every Commercial lot to one south-facing L1
asset. At the exact Day 33 state, that old asset reads as a generic medium-rise
regardless of authoritative level or road. Candidate L1 is a correctly
low-rise storefront with directional entrance massing and commercial
awning/color accents. It is easier to recognize beside Residential and
Industrial neighbors and better communicates the first skyline step.

- **Regular:** candidate L1 has a truthful low storefront scale and does not
  compete with City Hall, the water tower, roads, selection, or HUD.
- **Exact compact:** candidate L1 remains identifiable at the tighter scale,
  leaves the road crossing and neighboring parcels legible, and avoids the
  baseline's visually inflated level signal.
- **Systemic progression:** the independent 4 x 4 runtime matrix makes the
  L1-to-L4 climb from storefront through market and office block to tower
  materially clearer than the baseline's sixteen-cell alias.

The preference is based on uncropped same-state app frames plus the exact
runtime matrix, not a hero crop or author score.

## Authored-story L1 limitation

Production story fixtures contain only L1 Commercial lots. This is disclosed
but is neither waived nor treated as an automatic rejection because the
frozen requirement is still fully exercised through three independent proof
classes:

1. the exact staged app proves the authentic L1 gameplay, HUD, selection,
   preview, construction, persistence, input, AX, compact, overlay, Focus City,
   and Reduce Motion route;
2. the independently exported production resolver matrix proves all sixteen
   L1-L4 x N/E/S/W identities in color and grayscale; and
3. exact candidate tests exercise all sixteen identities through every LOD,
   unchanged pulse, save/load, undo, camera, selection, overlay, construction,
   condition, and Reduce Motion transition.

The matrix invokes the production `LotRenderer` and `WorldAssetCatalog` with
authoritative tile level and road masks; it is not a static contact sheet.
The real-app route prevents the result from becoming harness-only. No
un-authored gameplay state was fabricated or narrated as live proof.

## Automatic-reject audit

| Frozen reject class | Result |
|---|---|
| Candidate, bundle, executable, manifest, state, window, root, or PID ambiguity | CLEAR — exact identities and per-route PIDs retained |
| Cropped, resized, transient-obscured, harness-only, author-only, or single-width proof | CLEAR — uncropped regular and compact binding frames, full AX, and live inputs retained |
| Wrong identity/level/frontage; Residential/Industrial/cross-level alias; mirror/rotation/fallback | CLEAR — 16/16 matrix and exact runtime assertions pass; fallback count zero |
| Footprint/pivot/socket/foundation/shadow/ground/projection/material/light/alpha drift | CLEAR — geometry and pack validators pass with zero failures |
| Building, road, prop, HUD, overlay, label, or public-realm overlap | CLEAR — none observed; 6,724 ground, 164 road, and 628 entrance/prop checks have zero collisions |
| Broken road end, reciprocal seam, or public-realm regression | CLEAR — none observed in regular, compact, or LOD frames |
| State/selection/preview/construction/condition/overlay/Focus City/save/load/undo mismatch | CLEAR — live AX and screenshots agree; undo-restored save is byte-identical |
| Stale target, pointer leak, double activation, inaccessible action, modal leakage, focus/Escape failure | CLEAR — one announced target/action, stable FKA/AX, and topmost restoration verified |
| Critical AX-only clipped/hidden/microscopic content | CLEAR — compact Details and primary actions are visible or scroll-reachable |
| Reduce Motion information loss or state change | CLEAR |
| Source/staged mismatch, nondeterminism, excess pages, unbounded residency/RSS, fallback | CLEAR |
| Cold/update/render regression over frozen limit | CLEAR — candidate cold metrics improve on the frozen baseline |
| Hero frame masking a matrix/LOD failure | CLEAR — complete 4 x 4 matrix, three LODs, regular/compact, lifecycle and interaction evidence retained |
| Product mutation, coaching, substitution, author score, or post-result waiver | CLEAR — quality-only evidence; frozen rubric unchanged |

## Performance and validation

- `WorldRenderingTests`: 52/52, zero failures, 27.987 seconds.
- Full native suite: 223/223, zero failures, 105.980 seconds.
- Cold renderer: 3.724 ms world update / 5.305 ms total in the focused run;
  3.821 / 5.406 ms in the full run, versus frozen 3.806 / 5.643 ms.
- 30-minute-equivalent soak: 4,286 pulses, 0.0006 ms average.
- Residency: three textures, 41,943,040-byte repeated-cycle high-water,
  888 hits, 12 misses, 9 evictions, zero fallback.
- Pack: four pages; 12,582,912 bytes active-plus-adjacent at City and
  41,943,040 at Neighborhood/Block, within CONTRACT-006.
- Highest live RSS was 273,136 KiB initially and 272,000 KiB after 47 seconds
  in the explicit block-LOD session. There was no continuing high-water
  growth, and the route remains below the accepted high baseline plus 128 MiB.
- Independent pack and geometry validators passed; two clean pack builds were
  byte-identical; staged verification passed.

## Defects and limitations

- **P0/P1 defects:** none.
- **Product defects:** none found within PLAY-061.
- Spoken VoiceOver audio was not recorded. Full AX trees, AX custom actions,
  descriptions/help/value, focus order, and Full Keyboard Access activation
  were exercised independently.
- `city-900x600.jpg` and `valid-commercial-preview.jpg` retain setup toasts as
  chronological evidence. Their `-clean` counterparts are the binding visual
  comparisons.
- Computer Use wheel captures were retained but are not binding LOD proof
  because their camera delta was visually ambiguous. Separate exact
  `CITYSIM_PROOF_CAMERA_SCALE` app sessions at 0.85, 0.65, and 0.50 are the
  binding LOD captures.
- The story fixture's L1-only scope is handled by the proof-class split above;
  a future authored L2-L4 story would improve live narrative breadth but is
  not required to prove the renderer contract and is not a PLAY-061 defect.

## Integration recommendation

Accept exact combined candidate
`1799fbc2810f14d85511b74a8808bbee1928eef7` for PLAY-061. Do not generalize
this disposition to a different commit, pack, bundle, or future Commercial
candidate.
