# PLAY-073 R4-A first-grid reliability checkpoint

This checkpoint binds the focused Renderer repair before the required merge of
published Integration authority `9217e64c5f68fc254a7ca313e2413773fc5c29b0`.
It is technical evidence, not player-facing acceptance.

- Product commit: `1f3f81ec94dabab8c096f2dc427acc6b886ab11b`
- Product parent/merged authority: `4395f0003466892fcc6468bd74163886d7246e26`
- Preserved closure candidate ancestor:
  `7c2ee61d4f62a8836edc6bc74dd2ddb0daf5999e`
- PLAY-073 claim SHA-256:
  `47a260aea5ab9d38a98ceaaefb61e89e00322110b5a833e964a59d13157d7a49`

## Profile before repair

The isolated `make-backdrop` discriminator measured five fresh processes at
`30.94004187732935` through `74.14266653358936` milliseconds cold versus
`0.21120859310030937` through `0.36745844408869743` milliseconds warm. Every
sample retained 18 nodes, 13 drawables, and descendant-name SHA-256
`aed46ef02db31ee5b2ef455dedae5d308f93779ea3e217d2e75f3add19762e43`.

These profile receipts predate the executable-binding repair and therefore
identify Apple's generic XCTest launcher. They establish causality only and
must not be used as the final reliability series.

The historical failed v1 receipt remains immutable at:

`docs/production/evidence/PLAY-073/r4-a-candidate-298167c/performance/five-fresh-processes/sample-3.json`

It retains the original `18.394041806459427` millisecond miss.

## Focused product validation

`validation/world-rendering.log` records:

- 78 tests executed
- 1 expected explicit fresh-process skip
- 0 failures
- 92.874 seconds test duration
- 1,245,970,432 byte maximum resident set size reported by `/usr/bin/time -l`
- generated-v4 fallback count 0
- 1,673 nodes and 734 drawables in the governed opening

The final five-process series, complete native suite, resource checks, and
non-interactive staged verification remain pending on the post-`9217e64c`
descendant. No GUI acceptance journey was run.

## Rejected optimization

A road-corridor `SKNode.copy()` cache met the timing probe but corrupted packed
atlas subtexture presentation in deterministic temporary frames. It was removed
before the product commit. Its excluded probes remain outside the worktree at:

`/private/tmp/play073-r4a-road-cache-probes/`

No rejected road-cache code or pixels are present in the committed candidate.
