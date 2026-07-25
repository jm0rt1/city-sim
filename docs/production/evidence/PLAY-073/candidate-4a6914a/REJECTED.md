# PLAY-073 rejected composition checkpoint

## Disposition

Exact product `4a6914a15ad6fd20dca9fcb6c52d8f55c1691fe7` is a
durable renderer-performance checkpoint, not an admissible PLAY-073 visual
candidate. Integration independently rejected the true same-save matrix on
July 25, 2026 because the road loop, thin building strip, and broad green
field remain the dominant composition at normal viewing size.

The matrix is retained to prevent this subtle node-count change from being
presented again as a city-not-board outcome.

## Exact comparison

- Frozen renderer before: `e38059e721dae05c8df421754e3cb63ddf3fa153`.
- Renderer after: `4a6914a15ad6fd20dca9fcb6c52d8f55c1691fe7`.
- State truth: the same immutable PLAY-072 v2 save bytes for Commercial and
  Industrial pressured, recovering, upgraded, and terminal states.
- Routes: regular and compact City, Neighborhood, and Block.
- Frames: 48 before plus 48 after; the six contact sheets are under `matrix/`.
- Every frame selected the manifest's authoritative focus coordinate and used
  Reduce Motion.
- Both exporters verified the frozen state digest before rendering and
  reported zero generated-v4 fallback.

All 48 paired rows have exactly identical camera scale, developed width and
height shares, authoritative public-realm/network width and height shares, and
camera-priority width and height shares. Only renderer tree size changes:

```text
node delta       +34 or +38
drawable delta   +33 or +37
perceptual admission
                 rejected; normal-size before/after is nearly indistinguishable
```

`matrix/before/COMPOSITION.csv` and `matrix/after/COMPOSITION.csv` retain the
complete measurements. `validation/Play073EvidenceExportTests.swift` is the
exact exporter source. `validation/make_matrix_sheets.py` uses only the
bundled Pillow runtime to assemble comparisons; it does not alter product
pixels.

## Engineering gates retained

- WorldRendering: 61/61 passed.
- Full native suite: 251/251 passed in 200.347 seconds.
- Five fresh-process pulse samples: 1.918, 1.920, 1.930, 1.909, and 2.048 ms;
  all satisfy the unchanged 2.1 ms ceiling.
- Generated-v4 residency: 3 textures, 41,943,040 decoded bytes, zero fallback.
- Cold world update: 4.486 ms; total render 7.295 ms.
- Staged verify passed for candidate
  `world-rendering-w5f893ad1da1b` at exact commit `4a6914a`.

These green engineering results do not override the visual rejection.

## Authorized next correction

PLAY-073 remains active. The next renderer-owned iteration must materially
increase perceptual non-terrain occupancy, author the road-enclosed vacant
interior as unmistakably non-gameplay commons/public realm, connect occupied
frontages, strengthen terrain/map-edge hierarchy, and reduce strip
repetition. It must not invent a road, building, occupancy, agent, or
simulation fact.
