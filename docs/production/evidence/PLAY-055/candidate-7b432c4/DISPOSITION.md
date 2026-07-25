# PLAY-055 Independent Combined Release Gate

- **Disposition:** APPROVED
- **Exact combined product:** `7b432c4af1ee62553598e70c6103efe7a26e8af9`
- **Quality merge under test:** `fc8684a24f5cc36489c9b2b4d8edefe0b6c2e42b`
- **Frozen preregistration:** `a6919c2dc991d92d5c6c5946a96c836e4e7a9241`
- **Renderer product / completion:** `a08414c591b0f3600da5588d8c771e74d237727f` / `9da0aa9f802f80a3a10d5a21053de36158ed9e71`
- **HUD product / completion:** `35c5eba893b0515560b9a37a5fd92d83d02d3b19` / `f3806c255fc32ceb17403c1dd040de8814f92e02`
- **Date:** July 25, 2026

The exact combined candidate passes the preregistered PLAY-055 gate at
**20/20**, with Residential **4/4**, HUD **4/4**, no category below four,
zero P0/P1 findings, and zero automatic rejects. The candidate is materially
preferred over the frozen baseline in uncropped regular and exact compact
same-state comparisons: all sixteen Residential level/frontage identities
replace the former one-south-asset collapse, while Overview and Journal
replace AX-only collapsed content with visible, actionable layouts.

## Score

| Category | Score | Independent result |
|---|---:|---|
| Residential direction and level identity | 4/4 | The 16-row L1-L4 × N/E/S/W runtime matrix is distinct, correctly grounded and level-progressive; source, normalized, packed and staged identity is deterministic with no alias, mirror, rotation or fallback. |
| HUD legibility and operability | 4/4 | Critical/support type is 11/10 pt; compact aperture is 60.2% closed and 45.2% open; Overview exposes a complete Operating Position and Current Objective, while Journal exposes two complete notices and actions. |
| World/HUD composition, LOD and state clarity | 4/4 | Regular and compact remain world-first through useful city, neighborhood and block stops; selection, construction, invalid feedback, overlay and Reduce Motion remain legible and non-obscuring. |
| Interaction and accessibility truth | 4/4 | Pointer, Return, Space, FKA and AX preserve one target; modal text quarantines commands; focus and topmost-first Escape restore correctly. |
| Shipping identity, determinism and performance | 4/4 | Exact isolated identity, source/staged hash parity, four pages, zero fallback, bounded repeated-cycle residency, stable soak, sub-ceiling RSS, focused/full tests and staged verification all pass. |

## Candidate identity

The lane-staged app was built from the quality merge whose product subtree is
byte-identical to `7b432c4`. Every live route used the exact isolated
`playtest-quality-wf967be0ab5b4` executable recorded in `identity/IDENTITY.md`
and the final not-running manifest in `identity/staged-candidate.manifest`.

- Executable SHA-256:
  `78863a8343ccd652441c315e4a52e45fda356adab48a42fd136a3368993632e9`
- Staging-manifest SHA-256:
  `91f2ef287e04c30d2509d543129d7efc74eee414ea024557d8df079726c3ac17`
- Generated-v4 source/staged manifest SHA-256:
  `1753a314cfba5ce0034d486368dc92b23267b5a1ea8f2a30231e9a6c96f7e3fe`
- Fixture SHA-256:
  `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`
- State: seed 42, tick 128, Day 33, paused, then deterministic `0`.
- Windows: regular `1278 × 768` decorated capture; exact compact
  `900 × 600` content / `900 × 652` decorated capture.

## Hands-on routes

### Regular

PID `55551` loaded the frozen industrial-complication state into isolated root
`/private/tmp/citysim-play055-7b432c4/regular`. Keyboard Right/Left moved the
announced selection, Shift-Return opened the exact Residential L4 target,
three city-neighborhood-block cycles remained coherent, Overview and Journal
were complete, command search found the available Tax Policy route, and
Escape restored map focus. Settled RSS after the LOD cycles was
`199,184 KiB` (`194.52 MiB`).

### Exact compact

PID `57974` used `/private/tmp/citysim-play055-7b432c4/compact`. The closed
map aperture measured `361/600` (60.2%); Overview and Journal each measured
`271/600` (45.2%). Pointer selection opened the announced City Hall at
`(12,12)`. Return on the occupied target retained the same target, tool and
exact reason for more than five seconds. A valid target at `(13,18)` built
exactly once and Command-Z restored treasury and placement state. The map's AX
secondary action opened the same target, FKA moved from map to HUD and
activated Overview, command-guide text entry quarantined `3`, Right and Space,
Tax Policy search remained available, and Escape closed only the top layer.
Settled RSS was `180,048 KiB` (`175.83 MiB`).

### Reduce Motion

PID `60396` used `/private/tmp/citysim-play055-7b432c4/reduce-motion`.
Residential L4 selection and the Utilities overlay retained identical target,
legend and consequence meaning with Reduce Motion enabled. Settled RSS was
`198,912 KiB` (`194.25 MiB`). The isolated defaults key was restored after
capture.

All three candidate PIDs and staged-verification PID `62886` were terminated.
The separately owned production PID `51487` was not touched and remained live.

## Residential and resource proof

The independently exported `2800 × 2200` matrix shows distinct massing,
roofline, entrance and density progression for all sixteen L1-L4 × N/E/S/W
identities. The pack validator passed 16 raw directional identities, 48
normalized identities, 132 payload digests, 2,403 packed-overlap checks and
132 extrusion checks. The geometry validator passed 2,500 ground, 100 road
and 372 entrance checks with zero collisions or failures. Source and staged
generated-v4 manifest and all four page hashes match exactly.

The retained 10,485,760 / 33,554,432-byte figures are PLAY-024/053 observed
baseline values, not published ceilings. Candidate active-plus-adjacent
residency is 12,582,912 bytes at city and 41,943,040 bytes at
neighborhood/block: +20% / +25% over those observations, but only 12 MiB /
40 MiB and therefore within CONTRACT-006's 128 MiB hard high-water. The pack
uses exactly four pages; repeated cycling plateaus at 41,943,040 bytes with
648 hits, 12 misses, 9 evictions and zero fallbacks. This scores against the
published authority and the frozen rubric's bounded-residency requirement,
not a post-result waiver.

## Validation

| Command / route | Result |
|---|---|
| `swift test --package-path Native/CitySimNative --filter WorldRenderingTests` | 47/47 passed in 21.401 s |
| `swift test --package-path Native/CitySimNative` | 206/206 passed in 94.122 s |
| Directional matrix export test | 1/1 passed in 0.590 s |
| World-pack validation | Passed; four pages, source/staged parity, zero failures/fallbacks |
| Production geometry validation | Passed; zero failures/collisions |
| `./script/build_and_run.sh --verify` | Passed against exact isolated staged identity |
| Final `./script/build_and_run.sh --stage-only` | Passed; final manifest records not launched / not running |

Independent focused diagnostics report 3.664 ms world update and 4.946 ms
total render, below the PLAY-028 3.830 / 5.154 ms comparison. The
30-minute-equivalent soak retained 1,369 nodes, 553 drawables, two bounded
actions and 0.0006 ms average update. No continuing residency or RSS growth
was observed.

## Automatic-reject audit

All checks are clear: no identity substitution; cropped or single-width proof;
wrong Residential level/frontage; alias, mirror, rotation, seam, overlap,
pivot, foundation, ground-contact or mixed-style defect; target-obscuring HUD;
AX-only critical content; compact aperture failure; incomplete Overview or
Journal; false state/selection/rejection/consequence; input-target
disagreement; modal leakage; focus/Escape failure; Reduce Motion information
loss; fallback; hash mismatch; nondeterminism; unbounded residency/RSS growth;
unexplained over-budget regression; coaching; or product mutation.

## Limitations

- Spoken VoiceOver audio was not recorded. Independent proof covers live AX
  trees, AX actions and Full Keyboard Access behavior.
- The matrix exporter supplements but does not replace the real-app routes;
  uncropped app frames, AX captures, input operation and process identity are
  retained separately.
- PLAY-055 evaluates the exact combined Residential/HUD candidate. It does not
  authorize Commercial/Industrial directional production or new gameplay.

## Evidence index

- `identity/IDENTITY.md`
- `identity/staged-candidate.manifest`
- `ledgers/residential-direction-level-matrix.csv`
- `ledgers/hud-interaction-accessibility.csv`
- `ledgers/performance-and-residency.csv`
- `matrix/`
- `live/regular/`
- `live/compact/`
- `live/reduce-motion/`
- `validation/`
- `SHA256SUMS`
