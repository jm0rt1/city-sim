# PLAY-075 Industrial L4 final staged-app gate v1

- **Disposition:** `PREREGISTERED_BLOCKED_AWAITING_EXACT_4_OF_4_RENDERER`
- **Published authority:** `f9cb5fbae1be459ba297a8605347c4174f912ba0`
- **QA merge carrier:** `72aafa5539d115edfe8c6fb426703e6524c7d678`
- **Fixture-admission support:** `dc450f898f80d815631cf6b6aaef3b5280ff7699`
- **Claim/lane:** `PLAY-075` / `codex/citysim-playtest-quality`

This checkpoint assembles the already frozen mature-city fixture, rubric,
evidence plan, direction-local source-review boundary, and published
fixture-admission support into one fail-closed final-gate contract. It changes
no threshold and supplies no candidate-specific coaching.

No Industrial L4 renderer candidate was supplied or inspected. Nothing in this
packet admits a direction, materializes an L4 save, runs the app, scores the
rubric, or accepts product behavior.

## Exact mature-city state

The immutable accepted-L3 harness remains:

- fixture SHA-256
  `b8875422a277b59f6797aef03ca93175a502df5963a5c972684ca47be40e7aa5`;
- state digest
  `dbe6860011f43063a39e228531db4b49303d64a918e7884301b3de80360dd97f`;
- tick `844`, seed `10481999410520546993`;
- loaded through the visible Open route and paused before the first tick; and
- City overlay, Focus City off, Details and transient surfaces closed.

The four target lots and sole-road relationships are copied exactly from the
frozen manifest:

| Runtime direction | Player block | State coordinate | Sole road | Source-pixel socket |
|---|---:|---:|---:|---:|
| North | `[11,11]` | `[10,10]` | `[10,9]` | `[896,704]` |
| East | `[4,10]` | `[3,9]` | `[4,9]` | `[896,832]` |
| South | `[5,9]` | `[4,8]` | `[4,9]` | `[640,832]` |
| West | `[18,12]` | `[17,11]` | `[16,11]` | `[640,704]` |

These coordinates bind evidence only after unaided player selection. They are
not journey coaching and are never used as a hidden input route.

## Exact camera and view states

Every direction starts by invoking player-visible `0` / `Frame Developed
City`. No pan, selection recenter, rotation, proof camera, DCC label, or hidden
coordinate is allowed. City, Neighborhood, and Block use canonical camera
scales `0.74`, `0.66`, and `0.50`.

The required view matrix is:

| Width | Exact capture | Exact content | City | Neighborhood | Block |
|---|---:|---:|---:|---:|---:|
| Regular | `1278×768` decorated | record actual content | `0.74` | `0.66` | `0.50` |
| Compact | `900×652` decorated | `900×600` | `0.74` | `0.66` | `0.50` |

The fixture serializes no camera center and this preparation is explicitly
barred from running the app. Therefore this packet does not fabricate a
numeric center. The exact center identity is the output of `Frame Developed
City` for the frozen fixture. Candidate evidence must record numeric `x/y`
immediately after every reset and fail if it differs within a width or between
the exact candidate and accepted-baseline comparison. The same rule binds
rotation `0`, scale, target block, overlay, focus, Details, Reduce Motion,
fixture digest, PID, and timestamp in `identity/window-and-camera.csv`.

This produces exactly `24` binding visual cells: four runtime directions by
three semantic LODs by two widths. Every cell retains original uncropped color
and literal-grayscale evidence.

## Candidate-bound admission

The final app journey remains unavailable until all checks below pass:

1. Four exact v2 `source_candidate` packets exist in canonical
   North/East/South/West order and preserve the exact logical identities and
   source-pixel sockets.
2. Integration publishes a separate exact source-admission receipt for each
   unchanged packet. Direction-local QA may recommend pass or return but never
   writes or implies admission.
3. Integration publishes one fixture-admission manifest below
   `docs/production/evidence/INTEGRATION/industrial-l04-admissions/`. Its local
   bytes, declared SHA-256, and blob at the declared published
   `origin/master` commit must be identical and must bind the immutable
   fixture, one exact clean renderer candidate, accepted bridge, and all four
   packet objects.
4. Candidate-bound materializer mode must verify candidate and packet
   existence, inspect Integration Git authority, remain fail-closed, and emit
   the completed/construction/condition plans as eligible. A rehearsal receipt
   can never satisfy this check.
5. The renderer candidate must contain twelve distinct direction/LOD outputs,
   exact source-to-normalized-to-pack-to-runtime parity, two-build
   determinism, and zero alias, mirror, rotation, recolor, fallback, DCC-label,
   transform, crop, registration, or socket failure.
6. Isolated staging must bind source commit, product commit, executable,
   bundle, defaults, data root, PID, Info.plist, staging manifest, packaged
   atlas, generated-v4 manifest, and the three materialized fixture digests.

Any missing, returned, stale, synthetic, unverified, unbound, mixed, dirty, or
substituted input is `BLOCK`, not a partial score.

## Frozen visual and interaction rubric

The rubric remains byte-bound to
`RUBRIC.md` SHA-256
`3807edfe7ea7cd5263723b4b045562f445ba5f727ec9a3adeccc395ffdbfa692`.
No scoring is allowed before the complete live journey.

Visual proof must establish one premium heavy-industrial family, truthful
sole-road frontage, material progression and world cohesion versus exact
accepted L3, intact hierarchy/contact at every width and LOD, legible
construction and condition, and zero alias/fallback/transform/raster failure.

Interaction proof must establish exact pointer/keyboard lot parity, matching
visible and AX Level 4/block/workers/condition/road/action identity, unobscured
frontage, Full Keyboard Access, VoiceOver, Escape, Reduce Motion, bounded
resources, and one-lot demolition followed by exact Undo/save restoration.

The frozen batch threshold is `20/20`, every category `4/4`, zero P0/P1, and
zero automatic returns.

## One final staged-app gate

Exactly one fresh no-coaching journey may run after the admission chain passes.
It covers all four directions, both widths, three LODs, construction,
condition, pointer, keyboard, accessibility, Reduce Motion, demolition/Undo,
pack identity, performance, and termination. Its only possible
candidate-bound dispositions are `APPROVE` or `RETURN`.

Direction-local reviews are recommendations to Integration and never receive
QA production acceptance. A baseline rehearsal, one-to-three directions,
fixture identity, static screenshots, author evidence, or renderer tests
cannot substitute for this serialized atomic gate. A focused L4 approval would
permit only the family batch to publish; it would not close the separate full
PLAY-075 release gate.
