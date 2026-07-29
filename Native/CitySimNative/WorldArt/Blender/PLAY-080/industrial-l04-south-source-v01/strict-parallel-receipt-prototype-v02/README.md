# PLAY-080 strict parallel schedule/receipt model v02

This is a South-owned, executable, nonproduction, zero-pixel model aligned to
Integration's frozen design at
`aeaecb0bef4e7fe1e9670b1d57bd49b50b4eeab7`. It keeps the modeled planned
schedule in a different document from the observed direction receipt and
proves the corrected boundary without creating a shared schema, a global
schedule receipt, source pixels, or production authority.

The model validates:

- a pre-receipt `cellContentCommit` with no self-referential `receiptCommit`;
  the eventual receipt commit belongs only in an Integration closeout;
- schedule separation from direction-local grants, results, observations,
  joins, and assembler evidence;
- exact allocation, attempt, slot, half-open lease, FIFO dispatch-sequence,
  and echoed scheduler-event identity bindings;
- portable, canonical, repository-relative paths with nofollow checks for
  existing components and input files;
- half-open process windows (`[start,end)`) with end events swept before start
  events at equal timestamps;
- contiguous dispatch and observed event sequences;
- direction-local cancellation that cannot affect North, East, or West;
- an append-only attempt ledger with immutable retry identity hashes, unique
  retry roots, and explicit predecessor/ordinal chains;
- a real `parallel_two_slot` overlap fixture and a distinct
  `sequential_exception` fixture whose Integration exception authority remains
  deliberately null and nonproduction;
- the fixed ten-job validation DAG and exactly one modeled assembler;
- strict JSON duplicate-key, extra-property, and nonfinite-number rejection;
  and
- fail-closed path, sibling-root, symlink, lease, slot, cap, false-overlap,
  cancellation, FIFO, dispatch, retry, DAG, join, commit, authority, grant,
  and schedule-binding adversaries.

The modeled schedule has neither grant nor result fields. All
Integration-owned executable schema, validator, global schedule-receipt, hash,
schedule-commit, exception, and authority fields remain `null` and
`published=false`. Both positive direction receipts therefore return
`PASS_NONPRODUCTION_GLOBAL_AUTHORITY_PENDING` with `globalCapProven=false`,
`productionReady=false`, no embedded receipt commit, and every receipt grant
false. Modeled A/B/C observations are structural fixture data, not DCC
invocations. This prototype does not fabricate Integration's eleven-job global
queue or claim cross-direction/global cap proof.

Run the complete deterministic suite:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 \
  Native/CitySimNative/WorldArt/Blender/PLAY-080/industrial-l04-south-source-v01/strict-parallel-receipt-prototype-v02/test_strict_parallel_receipt_v02.py
```

Run one fixture pair directly:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 \
  Native/CitySimNative/WorldArt/Blender/PLAY-080/industrial-l04-south-source-v01/strict-parallel-receipt-prototype-v02/validate_strict_parallel_receipt_v02.py \
  --schedule-schema Native/CitySimNative/WorldArt/Blender/PLAY-080/industrial-l04-south-source-v01/strict-parallel-receipt-prototype-v02/planned-schedule-fixture-schema-v02.json \
  --receipt-schema Native/CitySimNative/WorldArt/Blender/PLAY-080/industrial-l04-south-source-v01/strict-parallel-receipt-prototype-v02/observed-direction-receipt-fixture-schema-v02.json \
  --schedule Native/CitySimNative/WorldArt/Blender/PLAY-080/industrial-l04-south-source-v01/strict-parallel-receipt-prototype-v02/fixtures/cap2-overlap/PLANNED-SCHEDULE.json \
  --receipt Native/CitySimNative/WorldArt/Blender/PLAY-080/industrial-l04-south-source-v01/strict-parallel-receipt-prototype-v02/fixtures/cap2-overlap/OBSERVED-RECEIPT.json \
  --schedule-repo-path Native/CitySimNative/WorldArt/Blender/PLAY-080/industrial-l04-south-source-v01/strict-parallel-receipt-prototype-v02/fixtures/cap2-overlap/PLANNED-SCHEDULE.json
```
