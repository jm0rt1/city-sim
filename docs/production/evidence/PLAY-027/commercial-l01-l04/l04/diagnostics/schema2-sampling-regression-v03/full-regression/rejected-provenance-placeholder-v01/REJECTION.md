# PLAY-027 v3 full-regression invocation rejection

Disposition: rejected before candidate use

The first full-regression invocation supplied the invalid literal
`2d5ae389c319placeholder` as `rendererSourceCommit`. The renderer does not
currently resolve that caller-provided provenance string against Git, so five
fresh-process outputs completed before the batch was interrupted:

- Commercial L1 North runs A, B, and C;
- Commercial L1 East runs A and B.

The retained pixels are deterministic within each direction, but the
provenance is invalid. These ten files are preserved outside the candidate
`raw/` and `normalized/` paths and may not satisfy any regression gate.

The corrected regression must start again from run A with exact committed
authority `2d5ae38ca210a72cb5de9be9fa71fff3be521366`.
