# PLAY-028 exact candidate validation

## Identity

- Product commit: `a08414c591b0f3600da5588d8c771e74d237727f`
- Branch: `codex/citysim-world-rendering`
- Accepted source authority: Residential L1
  `6380037d42ede73eca60aac4a9b1c7b710f681d6`; Residential L2-L4
  `8f928ed5dd01453ff9d4d9910858d8bf786afa9d`
- Candidate ID: `world-rendering-w5f893ad1da1b`
- Bundle ID: `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Staged manifest: `staged-candidate.manifest`
- Staged executable SHA-256:
  `1daae4e401871c63fcc0f0a8557a7e4382ecbc6d6eaefaf79cbcc0f88937f7dd`
- Source and staged generated-v4 manifest SHA-256:
  `1753a314cfba5ce0034d486368dc92b23267b5a1ea8f2a30231e9a6c96f7e3fe`

The staged app was built and verified from this exact product commit. The
pack validator reports `staged_matches_source: true`, 16 directional
Residential identities, 16 unique raw hashes, 48 unique normalized hashes,
zero failures, and no silent fallback.

## Direction and level proof

The 2800 x 2200 matrices are supporting renderer-harness evidence:

- `matrix/pre-ingestion-runtime-matrix.png` repeats the retired level-blind
  presentation across all 16 cells.
- `matrix/production-directional-runtime-matrix.png` shows independently
  authored N/E/S/W views for each of L1, L2, L3, and L4.

The real staged app provides the player-visible evidence:

- Default, paused industrial story:
  `live/default-industrial-story-l4-residential-unselected-1278x768.jpeg`
  and `live/default-residential-l4-south-selected-clean-1278x768.jpeg`.
- Exact compact 900 x 600 content, uncropped 900 x 652 decorated window:
  `live/compact-industrial-story-unselected-900x600.jpeg`,
  `live/compact-residential-l4-south-selected-clean-900x600.jpeg`, and
  `live/compact-residential-l1-south-selected-clean-900x600.jpeg`.
- Reduce Motion:
  `live/compact-residential-l4-south-selected-reduce-motion-900x600.jpeg`.

The industrial story's selected Residential is internal coordinate `(10,11)`,
announced by accessibility as one-based `Block 11, 12`. The frozen state
identifies it as completed Residential L4. Its north, east, and west neighbors
are not roads, while `(10,12)` is an authoritative road; therefore the
production identity is `residential_l04_v0_south`. The staged details AX file
reports `Residential Level, 4`, `Operational`, and `Road, Connected`.

The authentic starter capture selects the same one-based block as Residential
L1 and retains its south-road entrance. Its staged details AX file reports
`Residential Level, 1`, `Operational`, and `Road, Connected`. Together, the
default L4 and compact L1/L4 states prove real Residential selection, visible
level progression, and authoritative road-facing entrance rather than a civic
selection or manifest-count substitute.

The selection boundary remains grounded and non-obscuring. Normal and Reduce
Motion AX selection text is byte-identical, while the focused renderer test
reports zero reduced-motion actions and equivalent static meaning.

## Deterministic pack and geometry

Two fresh pack builds from the exact candidate compared with `diff -qr` and
produced no differences. Both emitted:

- manifest:
  `1753a314cfba5ce0034d486368dc92b23267b5a1ea8f2a30231e9a6c96f7e3fe`
- block page 00:
  `b1e3a711c8743fb12d916948d9e094051a19b0dcbbd0aa44d5638a7dc99454f0`
- block page 01:
  `f80a56f21d08d1675d39431cab35a391c000d585994be5b8016962c8be831de8`
- city page 00:
  `ddbe4c128c19c6cf89455cc6311fd8c1ee1a0d62a3a24b06d1f2877f4272bde6`
- neighborhood page 00:
  `d9ffea926ecf424527ef34e60f7b36066949feeeefd3c8cb95ad0fbfcde813d5`

`production-geometry-validation.json` reports:

- result `pass`;
- 2,500 reciprocal ground-contact checks and zero collisions;
- 100 building/road checks and zero collisions;
- 372 entrance/exclusion neighbor checks and zero collisions;
- zero failures, orphan inventory entries, or missing references.

The validator adoption repair derives each exact socket and exclusion
rectangle from the accepted source registration, supports the four authored
orientations, preserves strict physical contact checks, and allows only the
accepted 0.51-point antialiased alpha edge. It does not rotate, mirror, alias,
or repair source art.

## Automated and staged gates

- `swift test --package-path Native/CitySimNative --filter
  WorldRenderingTests`: 47/47 passed in 21.442 seconds.
- `swift test --package-path Native/CitySimNative`: 205/205 passed in
  94.571 seconds.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed from exact product
  `a08414c591b0f3600da5588d8c771e74d237727f`.
- Exact bundled-Python pack validation: passed with source/staged parity.
- Exact bundled-Python production geometry validation: passed.
- Runtime matrix export test: passed and retained both 4 x 4 outputs.
- Identity stability test: passed across unchanged pulse, save/load, undo,
  camera changes, and all three LODs.
- Roadless selection test: passed with explicit missing identity rather than a
  direction, legacy, or cross-family fallback.

The first repeat-validation invocation was corrected without product mutation:
SwiftPM initially lacked sandbox access to its module cache, and the Python
tools were initially called with `--output` instead of their documented
`--report` flag. The exact corrected commands above all passed.

## Budgets and diagnostics

- Full-suite cold profile: 3.830 ms world update, 0 decode loads, 0.000 ms
  decode, 5.154 ms total render.
- Full-suite representative render: 3.774 ms world update, 0 decode loads,
  5.159 ms total render.
- Default production frame: 1,369 nodes / 553 drawables.
- Thirty-minute-equivalent unchanged-pulse soak: 4,286 pulses, 2 bounded
  actions, 0.0006 ms average update, stable identity.
- Repeated LOD residency: 41,943,040 bytes high water, 648 hits, 12 misses,
  9 evictions, 0 fallbacks.
- Active plus adjacent decoded pages: city 12,582,912 bytes; neighborhood
  41,943,040 bytes; block 41,943,040 bytes.
- Exact compact Reduce Motion staged process after interaction: 236,320 KiB
  RSS (230.78 MiB), below the 333.8 MiB ceiling.

## Limits and disposition

This candidate ingests only accepted Residential L1-L4 variant-zero N/E/S/W.
It does not add Residential variants beyond zero, ingest Commercial or
Industrial directional families, expose player-controlled rotation, or change
gameplay, saves, store, commands, HUD, package contracts, or source art.

The evidence is ready for independent quality review. This record does not
self-score or claim integration acceptance.
