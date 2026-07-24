# PLAY-022 Round 1B final preregistered cold window

**Disposition: failed — return to renderer engineering.**

- Authority: `52fc2c17643e7987f78bc360196599e3297967da`
- Frozen product: `fc8b838d6d33ee8091ce6c54c125ea0cee279f5b`
- Product tree: `1277422dabd28c67469b11516ba06692f978bc1a`
- Starting evidence HEAD: `881dba4fbae06610cd08b10af268d4a4e407633c`
- Governed samples: exactly five, retained in execution order; no replacement
  or additional sample was run
- Product/resource changes: none
- Unrelated application termination or manipulation: none

## Frozen staged identity

- Candidate: `world-rendering-w5f893ad1da1b`
- Bundle identifier: `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Executable SHA-256:
  `8f202e62c36bb277212d06fde08fe6e45621759a57eec7287d02094c387c7f4c`
- Candidate manifest SHA-256:
  `7bd817949baf5e87ce92f495e51450699e039fbbbcf4460eed75dcc55d1f6c79`
- Packaged and source generated-v4 manifest SHA-256:
  `900287027256d7f5ea960b7b17c9208f3ff990de532feb87448eb01328076e78`
- Canonical staged-resource inventory SHA-256:
  `64fa52246102f5e298bed63ec949c2504729abeccaa10f8a8849ee3f06aa4361`

Every prerecord independently captured these same hashes and reported no
`Native/CitySimNative` difference from the frozen product commit.

## Method

The test bundle was built once in the new
`/private/tmp/citysim-play022-fc8b838-wave005-five` scratch/cache root. The
prebuild passed 35/35 and is retained but excluded from the governed window.
Each sample then received a 30-second idle window, an immediate environment
capture, and a fresh process running the identical whole-class `--skip-build`
command recorded in `PREREGISTRATION.md`.

The prerecord includes the full process table, focused CitySim/XCTest/Swift
processes, load, physical memory, free-memory percentage, `vm_stat`, and
`pmset -g therm`. The thermal query consistently reported that no thermal,
performance, or CPU-power warning level had been recorded.

## Ordered results

| # | Golden update | Golden decode | Golden total | Cold update | Cold decode | Cold total | <= 6.03 | Whole class |
|---:|---:|---:|---:|---:|---:|---:|:---:|:---|
| 1 | 6.147 ms | 8 / 24.880 ms | 32.477 ms | 4.379 ms | 0 / 0.000 ms | **5.729 ms** | pass | 34/35; separate golden-update assertion miss |
| 2 | 5.463 ms | 8 / 27.945 ms | 34.659 ms | 4.733 ms | 0 / 0.000 ms | **5.943 ms** | pass | 35/35 |
| 3 | 4.443 ms | 8 / 23.788 ms | 29.538 ms | 5.007 ms | 0 / 0.000 ms | **6.579 ms** | fail | 35/35 |
| 4 | 5.018 ms | 8 / 24.552 ms | 30.790 ms | 4.879 ms | 0 / 0.000 ms | **6.253 ms** | fail | 35/35 |
| 5 | 4.503 ms | 8 / 24.210 ms | 29.928 ms | 4.685 ms | 0 / 0.000 ms | **5.910 ms** | pass | 35/35 |

The sample-1 command exited nonzero only because the separate historical
golden-fixture update assertion measured `6.147 ms` against its `6.03 ms`
ceiling. Its governed cold total was `5.729 ms`. The failure is retained and
not relabelled.

## Prerecorded external load

All five prerecords show material unrelated host work. No process was stopped:

1. four unrelated CitySim applications plus a concurrent gameplay XCTest;
2. four unrelated CitySim applications plus concurrent gameplay and command-
   catalog XCTest/Swift work;
3. three unrelated CitySim applications, a gameplay XCTest at `112.1%` CPU,
   and another Swift test starting;
4. three unrelated CitySim applications and a gameplay XCTest at `98.4%` CPU;
5. three unrelated CitySim applications and two unrelated XTests at `98.4%`
   and `99.1%` CPU.

The samples remain in their original order and in the gate. External load does
not excuse the 4/5 criterion.

## Gate calculation

Sorted cold totals: `5.729, 5.910, 5.943, 6.253, 6.579 ms`.

| Criterion | Result |
|---|---|
| Median <= 6.03 ms | pass: `5.943 ms` |
| At least 4/5 totals <= 6.03 ms | **fail: 3/5** |
| No uncontaminated sample > 9.045 ms | pass: no sample of any classification exceeded `9.045 ms` |

Because every criterion is required, the final window **fails**. PLAY-022
remains active and returns to renderer engineering. This packet does not send
the candidate to PLAY-052, authorize another measurement window, self-score
the visuals, or authorize Round 2, PLAY-023, or CONTRACT-008 implementation.
