# PLAY-066 validation and resource ledger

## Product validation completed before evidence capture

- Focused activity selection/reuse tests: 3/3 passed.
- Focused `WorldRenderingTests`: 60/60 passed.
- Full native suite: 233/233 passed in approximately 110.9 seconds.
- Governed unchanged-pulse timing: 2.022 ms focused average and 2.013 ms
  full-suite average against the 2.1 ms ceiling.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed against exact product
  `481a6fbf09b8a31dff85941b3b9ebce0ca11715d`.
- Generated-v4 pack validator: passed with source/staged parity and zero
  failures.
- Production geometry validator: `result: pass`, zero failures and zero
  collisions.

The retained validator outputs are:

- `diagnostics/asset-pack-validation.json`
- `diagnostics/production-geometry-validation.json`

## Evidence-assembly recheck disclosure

After six separate staged proof launches, the identical focused renderer
command was run twice more without product mutation. Both rechecks executed 60
tests with 59 passing; the sole failure was the historical single-sample cold
update assertion:

| Recheck | Golden update | Golden total | Assertion ceiling |
|---|---:|---:|---:|
| first | 6.912 ms | 9.801 ms | update <= 6.03 ms |
| second | 7.288 ms | 9.683 ms | update <= 6.03 ms |

The first failure is not replaced by the second and neither is hidden. The
same runs reported zero asset decode loads, 41,943,040 high-water decoded
bytes, zero fallback, 1,474 nodes / 648 drawables / two bounded actions in the
unchanged-pulse soak, and 4,286 stable pulses. All non-timing renderer
assertions passed on both rechecks. This variance is a disclosed independent
review item; no threshold was loosened and no product edit followed it.

## Runtime resources

- Generated-v4 high-water decoded bytes: 41,943,040.
- Fallback count: zero.
- Soak: 4,286 pulses, stable identity, two bounded actions.
- Regular city live RSS: 204,288 KiB.
- Regular neighborhood live RSS: 225,216 KiB.
- Regular block live RSS: 179,424 KiB.
- Compact city live RSS: 228,656 KiB.
- Compact neighborhood live RSS: 256,768 KiB.
- Compact block live RSS: 215,984 KiB.
- Peak route RSS: 256,768 KiB (250.75 MiB), below the 333.8 MiB ceiling.

The live samples are route-bound observations, not a substituted 60-second
settled-memory protocol. No exact staged process survived packet assembly.

## Candidate identity

- Staged candidate manifest SHA-256:
  `5d1ed0f0cce386a7ff5af0e72be85092eb0d41e3212172c7588df707f1f36363`
- Executable SHA-256:
  `e5190f22bc4be130b8fa986ffb64e3ceeb8c24c9c364a72b6dae560055b23076`
- Generated-v4 manifest SHA-256:
  `4aac94eb37ec3a17dc345177519a1e5d43b284ede870170e12ca6a9bf0521bd8`
- Atlas manifest SHA-256:
  `411934e492a66216787f8c93dd91d3f68cc16637110dba9ed7186b22dda96d3d`
- Day-53 primary and backup save SHA-256:
  `952d70cb80068880896acc0c7e27ec4683b4cfd3497b5c4cc171bead1eb56f53`
