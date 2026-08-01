# PLAY-073 R4-A returned-candidate repair handoff

Status: **renderer closures complete; candidate blocked, not self-accepted**.

## Exact identity

- Frozen returned candidate preserved: `9d9531c58eb9f8ffc6fc6441bd3eeb6653ddfde5`
- Normal sync merge of published `5d86e804be679c765c2465c60ceaee72f3702c48`:
  `ffdb87c455972f8c188cf48a2ab2fc4c67263c1a`
- Focused renderer repair:
  `298167c74a7d28042857d7f87c1f7b9130f779ed`
- Preserved candidate before the accounting-schema return:
  `c05fd806d632107e43b1cb0309cdcde219c88ec6`
- Normal merge of current published master
  `a8b30be4a4a12515d934b035b63946af82247b1f`:
  `ed46ecb0d775c1a99ad82c12dd5de6b953d49b6e`
- PLAY-073 claim SHA-256:
  `47a260aea5ab9d38a98ceaaefb61e89e00322110b5a833e964a59d13157d7a49`
- Branch: `codex/citysim-world-rendering`

All product changes are descendants of the frozen return. No returned commit was
amended, rewritten, or removed.

## Returned closures

### P1 source + context repetition

The renderer and diagnostic ledger now share one effective visible context
identity. It binds accepted generated-v4 logical ID and source SHA-256 together
with context family, effective material variant, authoritative frontage, and
placement geometry.

The durable ledger is
`repetition/SOURCE-CONTEXT-REPETITION-LEDGER.json`
(`3cb5b098609789de82d8c7744103bb11734dfd4e7ed7d34b9ceaf4aeb648358e`):

| Fixture | Placements | Adjacent pairs | Avoidable violations |
|---|---:|---:|---:|
| Starter seed 42 | 12 | 3 | 0 |
| Mature Industrial L3 directional fixture | 16 | 7 | 0 |

Focused tests additionally construct an identical Residential pair with an
available alternative and require failure, then construct a Park pair with no
visible alternative and require `pass_unavoidable_no_alternative`.

### P2 completed-kind ground invalidation

`AmbientGroundSignature` now retains the exact completed `BuildingKind`. A
completed-to-completed replacement therefore reaches the existing
kind-dependent terrain/frontage/service-campus reconciliation instead of
returning through the coarse completed-role cache guard.

- City Hall → Fire Station rebuilds once and remains stable on the identical
  third render.
- Industrial → Commercial removes the service-campus presentation and rebuilds
  once.

Both focused receipts pass under `invalidation/`.

### P2 ownership

The renderer candidate contains the exact published-master
`CityCommandCatalogTests.swift` blob
`394ed6be506e52b4e431561ebbe0041eff724ee9`. The returned UI/input-owned
seven-line delta is gone.

Renderer-owned `WorldRenderingTests` proves the accepted camera truth:
regular opening/Focus City scale `0.50`, compact scale `0.655`, with position
and occupancy assertions.

## Technical evidence

- Current-master focused renderer recheck: **6 executed / 0 skips /
  0 failures**. The retained log is
  `validation/CURRENT-MASTER-FOCUSED-RECHECK.log`
  (`eb93fd6cf91f547495ce7c50441f04a569a222c9b9ff397a8e8ebabbebe27b9e`).
- `c05fd806..ed46ecb0` changes only the five published lane-skill/accounting
  validator paths. It has no `Native/CitySimNative` or pre-existing
  `r4-a-candidate-298167c` delta. Exact ancestry, blobs, and merge inventory
  are retained in `validation/CURRENT-MASTER-EXACT-CHECKS.json`.
- WorldRenderingTests: **78 executed / 1 expected skip / 0 failures**.
- Two complete generated-v4 builds: 79 files each, byte-identical inventory
  `58d452d4cdb3237d06037e0a4bf90ffc3f4177d33063dd047882479e26b80a4b`.
- Pack binding: 4/4; pack validator and geometry validator: pass.
- Source/staged resource inventory parity:
  `a72eb94a85f268eba6402beebaeb4b7629cb9e201db60c7bfedbb26e7e62b874`.
- Non-interactive staged resource verification launched exact product
  `298167c7`, observed PID `87185`, verified bundle/resource identity, then
  terminated only that PID; zero matching processes survive.
- No player interaction, AX journey, Reduce Motion journey, or GUI acceptance
  was performed.

The color-independent composition ledger remains truthful: regular/compact
district width `1.0`; largest semantic coarse plain components
`0.238350`/`0.182716`. Eleven empty enclosed commons remain excluded from
district/public-realm credit; 29 empty road-adjacent buildable cells count only
as frontage ground, never occupied or special.

## Blocking results

### Integration/UI-input contract request

The full native suite executed 325 tests with 3 expected skips and exactly 2
failures, both in
`CityCommandCatalogTests.testFocusCityFramesDevelopedCityAfterSelectionClearsButPreservesRealTargetCamera`
at lines 782 and 834. The restored master test asserts that block scale `0.50`
must differ from regular Focus City scale `0.50`. That inequality is stale;
position/selection/undo/coordinator behavior remains asserted, and the
renderer-owned exact-scale/occupancy test passes.

Integration/UI-input must replace or remove only those two scale-inequality
assertions. The renderer must not reintroduce a cross-lane test edit or distort
truthful camera behavior to manufacture a difference.

### Performance reliability

All five fresh processes meet the `6.03 ms` cold world-update ceiling
(`0.0657–0.0748 ms`). Four of five meet the separate `16.6667 ms` first-grid
preparation ceiling; sample 3 is `18.3940 ms`. No receipt was retried or
replaced, so the series is truthfully marked failed. This packet does not claim
performance acceptance.

## Execution accounting

`execution-accounting/EXECUTION-ACCOUNTING.json` now uses Integration's exact
`executionAccounting` shape. It binds PLAY-073 claim revision, batch
returned base/published base/helper-launch head, visible Renderer thread,
branch/worktree, serialized Git/evidence authority, helper resource and
read-only mutation classes, completed states, service-recorded intervals,
exact visible thread/turn/item evidence, capacity, the observed three-helper
overlap, and the completed join. Product `298167c7`, preserved evidence
candidate `c05fd806`, and current merged head `ed46ecb0` are recorded
separately so later commits are not falsely presented as the helpers' launch
HEAD.

The three read-only helpers overlapped from `2026-07-30T11:52:18Z` through
`11:56:28Z`; they wrote no files and launched no renderer or DCC process. The
two isolated pack processes are not misclassified as helper or DCC jobs:
their independent temporary roots, logs, and joined 79-file digest remain
bound by the resource receipts.

## Preserved rejects and boundaries

The prior returned packet and every rejected receipt remain byte-for-byte in
history. This packet additionally retains the incomplete-atlas invocation and
the streaming thermal-preflight stall under `rejected/`; neither contributes
to passing summaries.

No Industrial L4 source was consumed or activated. No shared shipping atlas,
manifest, gameplay, UI, save, package, or public contract changed. Nothing was
pushed or self-accepted.
