# PLAY-075 Wave 010 R1 focused disposition

## APPROVE

- `traceDisposition=FOCUSED_R1_APPROVE`
- `skillResult=APPROVE`
- `productBehavior=PASS_FOCUSED_ART_BATCH`
- `mutation=EVIDENCE_ONLY`
- Exact renderer candidate:
  `d41c2c68d5584c990e271af06c0b93ab50722f5e`
- Exact published pre-R1 comparison:
  `10c2ed8cacc6c14a748aa953365b5779c7e06ad5`

The Industrial Level 2 R1 batch may publish. This disposition is limited to
the Wave 010 changed-family gate. It is not the PLAY-075 20-minute release
journey, does not replace the 20/20 final gate, and does not accept the release.

## Binding findings

1. The staged candidate contains four distinct Industrial L2 identities
   (north/east/south/west) and twelve distinct city/neighborhood/block payload
   hashes. The manifest contains no mirror, rotation, recolor, alias, or
   fallback field for the four identities.
2. All twelve accepted normalized source files match their manifest SHA-256
   values. The packaged manifest is byte-identical to the candidate source
   manifest, and the focused pack validator reports `passed: true`,
   `staged_matches_source: true`, zero failures, zero anchor drift, 5,727
   packed-overlap checks, and bounded decoded memory.
3. On the same Day 212 paused fixture and the same selected Industrial block
   15,12, the exact `10c2ed8` app displayed the published pre-R1 brick factory
   at both widths. The exact `d41c2c68` app displayed the new white/blue
   Industrial L2 factory at both widths. The candidate is visibly distinct
   from the previous level while remaining grounded, road-facing, aligned to
   the selected tile, and coherent with the accepted directional source.
4. Keyboard navigation and a direct pointer click resolved to the same
   Industrial block 15,12 and opened the same command-center identity.
   Selection stayed registered to the building footprint without overlap or
   detachment.
5. AX exposed Industrial, Level 2, block context, Operational status, maintained
   or weathered condition, road-connected context, workers/capacity, and the
   actionable demolition identity with cost and Undo availability. It did not
   literally speak the cardinal word `south`; the player-facing orientation
   context was the selected block plus active road connection.
6. The pressured state preserved the L2 identity and exposed weathering,
   service causes, 46% vitality, 94 workers, and the recovery response. The
   Industrial construction state remained visibly unmistakable as a foundation
   and flag rather than a finished building.
7. Demolition changed the selected parcel and the city metrics. Command-Z then
   restored the exact prior state: retained pre-demolition and post-Undo
   quicksaves are byte-identical with SHA-256
   `d6e60c425fb240c196655516c236eda1ee5cf7d17ad19b11b2b1149492715826`.
8. The exact 900 x 600 content launch retained the same Industrial L2 meaning,
   selection, interaction identity, and AX data with
   `CITYSIM_REDUCE_MOTION_PROOF=1`. Its decorated capture is 900 x 652 because
   the 52-pixel title/toolbar chrome is included.

Both exact staged app processes were terminated after capture. No product code,
resource, fixture, claim, completion record, integration branch, or published
branch was mutated.
