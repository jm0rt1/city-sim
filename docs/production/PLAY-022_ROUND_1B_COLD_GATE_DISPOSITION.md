# PLAY-022 Round 1B controlled cold-gate disposition

**Authority date:** July 22, 2026

**Frozen candidate:** `fc8b838d6d33ee8091ce6c54c125ea0cee279f5b`

## Disposition

The existing strict 2/3 set remains disclosed and does not pass. Integration authorizes one final preregistered five-sample window because the retained failing sample records an unrelated Chrome renderer at 93.8% CPU and the candidate otherwise satisfies full tests, geometry, isolation, occupancy, residency, and physical-footprint gates.

## Method

1. Freeze product code and resources at `fc8b838`; evidence-only commits may follow.
2. Record exact commit, executable/resource hashes, thermal state, free memory, and all CitySim/XCTest/Swift-build processes before every sample. Do not terminate unrelated user applications.
3. Run five fresh-process whole-class samples using one documented command and cache policy. Retain every result in order; no replacement samples.
4. Separately report world-update, asset-decode, and total-render timing. Do not relabel one measure as another.
5. Pass only if median cold total is at most 6.03 ms, at least four of five totals are at most 6.03 ms, and no uncontaminated sample exceeds 9.045 ms. Any externally contaminated sample remains in the series and must be identified from the prerecord, not discarded.
6. If the window passes, send the exact frozen bundle immediately to PLAY-052 for independent visual scoring. If it fails, return to renderer engineering; do not widen the window or self-accept.

Independent visual acceptance remains at least 17/20, no category below 3, and no automatic reject. Round 2, PLAY-023, and CONTRACT-008 implementation remain unauthorized.
