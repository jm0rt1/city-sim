# PLAY-073 candidate `6cb7179` validation

## Automated results

- Focused safe-pre-fit regression: `1/1`, passed in `3.659` seconds.
- Clean full renderer pass 1: `66/66`, passed in `41.315` seconds.
- Clean full renderer pass 2: `66/66`, passed in `41.134` seconds.
- First full native run: `260/261`; retained without replacement. The single
  governed pulse sample measured `2.1386125 ms` against the `2.1 ms` ceiling.
- Exact isolated pulse recheck: passed at `1.952 ms` average.
- Clean full native rerun: `261/261`, passed in `208.465` seconds; the governed
  pulse average was `1.999 ms`.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed against exact commit
  `6cb7179c60f7951d39d7e54733ddc34287be06f9`.
- `git diff --check`: passed.
- Final exact-candidate process check: no surviving process.

All complete outputs are retained under `logs/`, including the first full-suite
timing miss, isolated pass, and clean full-suite pass. No threshold or
production code was changed in response to the timing variance.

## Renderer diagnostics

Clean renderer pass 1:

- cold world update: `4.615 ms`;
- total render disclosure: `7.470 ms`;
- asset decode loads: `0`;
- asset decode: `0.000 ms`;
- nodes/drawables: `1679/847`.

Clean renderer pass 2:

- cold world update: `4.426 ms`;
- total render disclosure: `7.038 ms`;
- asset decode loads: `0`;
- asset decode: `0.000 ms`;
- nodes/drawables: `1679/847`.

The clean full native rerun reported:

- average state-changing render pulse: `1.999 ms` (`<= 2.1 ms`);
- cold world update: `4.745 ms`;
- preparation: `2.995 ms`;
- tile build: `1.743 ms`;
- tree metrics: `0.419 ms`;
- final nodes: `1685`.

## Staged identity and resources

- executable SHA-256:
  `5c890a83742f9527af8d58170fd1f186a762c5cb5b03eec62f70ae8ef064bf0c`;
- staging manifest SHA-256:
  `5da56444757f62f664c302bad56f09aeb576564180740ed495ea2a4f98211416`;
- packaged generated-v4 manifest SHA-256:
  `4aac94eb37ec3a17dc345177519a1e5d43b284ede870170e12ca6a9bf0521bd8`;
- packaged world atlas manifest SHA-256:
  `411934e492a66216787f8c93dd91d3f68cc16637110dba9ed7186b22dda96d3d`.

The six binding screenshots have their expected uncropped dimensions, and a
pixel audit found zero all-white rows in every final frame. The invalid
offscreen compact attempt is excluded and not referenced by `SHA256SUMS`.

## Product boundary

This evidence validates the integrated contextual-framing slice only. It does
not overturn the rejected sparse opening, does not close PLAY-073, does not
accept the same-coordinate Road recovery target, and does not modify gameplay,
UI, simulation, persistence, packages, or shared contracts.
