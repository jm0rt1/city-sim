# PLAY-073 R4-A first-grid reliability handoff

Status: **renderer technical gate complete; not self-accepted**.

## Exact identity

- Preserved approved closure candidate:
  `7c2ee61d4f62a8836edc6bc74dd2ddb0daf5999e`
- Normal merge of Renderer authority
  `d4f18ea3b1ccfd522f3b5e877bc7cb742fd9be09`:
  `4395f0003466892fcc6468bd74163886d7246e26`
- First measured Renderer repair:
  `1f3f81ec94dabab8c096f2dc427acc6b886ab11b`
- Profiling checkpoint:
  `3a0982c5c41a8d436b007dd0b841ea329249a65e`
- Normal merge of parallelism-validator authority
  `9217e64c796fef3e9d45d0726453157e70b4ef16`:
  `7653ac027631873403d8f7b3077ce75e7cd56654`
- Final product repair:
  `526ff4f91d72cf5dd83926df1c55636d698be38b`
- Final product tree:
  `ae5269a4ccef57ee70cf76efef26036a27562360`
- PLAY-073 claim SHA-256:
  `47a260aea5ab9d38a98ceaaefb61e89e00322110b5a833e964a59d13157d7a49`

No returned commit was amended or rewritten.

## Repair

The governed preparation interval still surrounds the complete authoritative
576-tile record construction and process-cold backdrop. It was not prewarmed,
deferred, skipped, moved into `updateWorld`, retried, or relabeled.

The final repair constructs the exact row-major tile-record pairs in a
capacity-reserved contiguous buffer, attaches the exact original SpriteKit
roots, then materializes the dictionary once with
`Dictionary(uniqueKeysWithValues:)`. This removes repeated dictionary mutation
from the timed path without changing record count, root order, pixels, camera,
assets, nodes, drawables, sockets, or truth.

## Exact five-process series

The final series is under `performance/five-fresh-processes/`. All five
ordered samples used distinct PIDs and the exact package test executable:

- executable:
  `.build/arm64-apple-macosx/debug/CitySimNativePackageTests.xctest/Contents/MacOS/CitySimNativePackageTests`
- executable SHA-256:
  `ca3681246e441a637d322233654c80e113e24b73d5243877a65ccc81d18e53c5`
- PIDs: `45470`, `45529`, `45571`, `45607`, `45641`
- first-grid preparation milliseconds:
  `13.208666816353798`, `14.776249881833792`,
  `15.361916273832321`, `12.609750032424927`,
  `13.449749909341335`
- cold world-update milliseconds:
  `0.07479172199964523`, `0.06370805203914642`,
  `0.06304169073700905`, `0.08124997839331627`,
  `0.06641680374741554`

Every first-grid result is at or below `16.666666666666668 ms`; every
world-update result is at or below `6.03 ms`. Every receipt records:

- 576 created and 576 total tile records;
- prepared buffer count `0` after consumption;
- nodes/drawables `1673/734`;
- cache `0 → 1 → 1`;
- preparation included in total render;
- per-sample UTC, load average, memory pressure, thermal status, and full
  process inventory.

No sample was retried or replaced inside this exact v4 series.

## Preserved failures

- The immutable earlier `18.394041806459427 ms` miss remains at
  `../r4-a-candidate-298167c/performance/five-fresh-processes/sample-3.json`
  (SHA-256
  `865dbcb6fc80035880ef9a5a279b073642788317754804ce81f4c7469dfcb189`).
- The first post-repair five-process v2 series remains under
  `../r4-a-candidate-1f3f81e/performance/rejected/five-fresh-processes-v2/`;
  samples 1 and 2 miss at `23.902374785393476` and
  `17.086000181734562 ms`.
- The passing v3 measurements remain under
  `performance/rejected/five-fresh-processes-v3-invalid-product-binding/`.
  They are rejected because their receipt field contains an incorrect expanded
  product SHA; no JSON was edited or promoted.
- The rejected road-template cache experiment remains outside the worktree at
  `/private/tmp/play073-r4a-road-cache-probes/`. It was removed because the
  deterministic visual probe exposed atlas-subtexture corruption. No
  `RoadRenderer.swift` delta survives.

## Regression and resources

- Focused `WorldRenderingTests`: 78 executed, 1 expected receipt-only skip,
  0 failures.
- Complete native suite: 325 executed, 3 expected skips, 0 failures.
- Focused generated-v4 binding tests: 4/4.
- Pack validation: passed, zero failures, source/staged parity true.
- Geometry validation: passed, zero failures/collisions.
- Source and staged atlas inventories: 79 files each, byte-identical SHA-256
  `58d452d4cdb3237d06037e0a4bf90ffc3f4177d33063dd047882479e26b80a4b`.
- `WorldAssets.atlas` Git tree:
  `74dc97abbd39518c8936979a2fe1558c2ab11445`.
- GeneratedV4 Git tree:
  `df3876e10520312d8a3d51e7597ce81227e00ca7`.
- Manifest SHA-256:
  `317802265010fc758b232bea9198f18ec0ca4d75b5ceb6f759206238717cec92`.
- Atlas manifest SHA-256:
  `411934e492a66216787f8c93dd91d3f68cc16637110dba9ed7186b22dda96d3d`.

The non-interactive technical smoke staged exact product `526ff4f9`, launched
only Renderer PID `43455`, retained RSS/process identity, and terminated only
that PID. Unrelated PLAY-075 PID `26465` remained alive. No player interaction,
visual score, AX journey, Reduce Motion journey, or staged-app acceptance was
performed.

## Boundary

No Industrial L4 source was consumed or activated. No gameplay, simulation,
UI, save, package, public contract, shared atlas, or shipping manifest changed.
Nothing was pushed, integrated, scored, or self-accepted.
