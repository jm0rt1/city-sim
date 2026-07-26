# PLAY-073 candidate `8bc9600` validation

## Automated results

- Focused contextual-framing regression: passed.
- Complete `WorldRenderingTests`: `66/66`, `0 failures`, `40.049` seconds.
- Complete native suite: `256/256`, exit `0`.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed against exact commit
  `8bc96003c4524ad761a556cfdc8175440d563906`.
- `git diff --check`: passed.
- Generated-v4 fallback diagnostics: zero.
- Final exact-candidate process check: no surviving process.

## Renderer diagnostic

The exact renderer run reported:

- backdrop: `0.423 ms`;
- preparation: `0.012 ms`;
- tile build: `4.638 ms`;
- tree metrics: `0.245 ms`;
- cold world update: `5.073 ms` (`<= 6.03 ms`);
- asset decode loads: `0`;
- asset decode: `0.000 ms`;
- total render disclosure: `7.918 ms`;
- soak total: `3.209 ms`;
- unchanged-pulse average: `0.0007 ms`;
- nodes: `1695`;
- drawables: `863`.

## Staged verification

The verified staged identity was:

- branch: `codex/citysim-world-rendering`;
- commit: `8bc96003c4524ad761a556cfdc8175440d563906`;
- candidate ID: `world-rendering-w5f893ad1da1b`;
- bundle:
  `dist/CitySim-world-rendering-w5f893ad1da1b.app`;
- executable:
  `dist/CitySim-world-rendering-w5f893ad1da1b.app/Contents/MacOS/CitySimNative-w5f893ad1da1b`;
- resource bundle:
  `dist/CitySim-world-rendering-w5f893ad1da1b.app/CitySimNative_CitySimNative.bundle`.

## Product boundary

The renderer tests and staged proof pass the contextual-framing slice only.
They do not overturn the independent rejection of the overall sparse opening,
do not accept the same-tile Road recovery target, and do not close PLAY-073.
No product mutation occurred after `8bc9600`.
