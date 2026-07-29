# PLAY-080 strict parallel-receipt prototype v1

This is a task-owned, nonproduction, zero-pixel executable prototype. It
models the future South A/B/C receipt and validates:

- exact frozen South scene, material, source-stage schema, runner, assembler,
  and authority-bundle hashes;
- distinct task-owned process, evidence, and validation-job roots;
- exactly one modeled invocation per A/B/C process and validation job;
- UTC process/job intervals, actual overlap, or a sequential exception with
  queue order;
- the exact direction-local dependency graph and its completion barriers;
- one direction-local packet assembler; and
- a fail-closed reference to the future Integration global DCC schedule
  receipt.

The fixtures do not represent real DCC or validation invocations. They record
zero Blender, render API, ImageGen, normalization, contact-sheet, and pixel
activity. The global schedule reference is deliberately null and
`globalCapProven` remains false; only Integration may later publish that
authority.

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 \
  Native/CitySimNative/WorldArt/Blender/PLAY-080/industrial-l04-south-source-v01/strict-parallel-receipt-prototype-v01/test_strict_parallel_receipt_fixture.py
```
