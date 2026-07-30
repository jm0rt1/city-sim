# PLAY-075 Industrial L3 replacement R2 disposition

## PASS

- `traceDisposition=FOCUSED_R2_PASS`
- `skillResult=PASS`
- `productBehavior=PASS_FOCUSED_INDUSTRIAL_L3_GATE`
- `mutation=QA_EVIDENCE_ONLY`
- Exact candidate:
  `472ffa85cd35639a675c1c2e4ede748c94446a7f`
- Exact accepted L2 comparison:
  `d41c2c68d5584c990e271af06c0b93ab50722f5e`

The replacement Industrial Level 3 renderer batch passes its single
independent same-SHA staged-app gate. This is a focused family disposition,
not the full PLAY-075 release journey and not self-acceptance or integration.

## Player-visible findings

1. The frozen mature-city save exposed four Level 3 Industrial buildings at
   the canonical North, East, South, and West road-frontage placements. Each
   was selectable in the real app at regular and exact 900 x 600 content
   layouts.
2. Direct pointer selection of West resolved to Industrial block 18, 12.
   Keyboard movement away and back resolved to the same block and identity.
   North, East, and South keyboard navigation resolved to Industrial blocks
   11, 11; 4, 10; and 5, 9 respectively.
3. City, neighborhood, and block camera segments retained nonblank,
   registered L3 imagery. The four placements did not alias to one another,
   detach from their tiles, rotate into a wrong frontage, or fall back to the
   accepted L2 asset.
4. The L3 family is materially more advanced than accepted L2: it has a
   broader multi-volume factory mass, taller service/stack elements, freight
   articulation, and warm orange structure. It remains compatible with the
   warm brick, dark-roof, road, civic, and terrain world and does not reproduce
   the returned clinical-white mixed-fidelity break.
5. Regular and compact AX exposed Industrial, Level 3, operational state,
   block identity, completed/maintained or distressed condition, 89 workers,
   330 capacity, road-connected operations, demolition cost, and Undo
   availability.
6. The pressured Level 3 state remained visibly identifiable and announced
   `distressed condition` with 35% vitality. The construction fixture remained
   visibly a foundation/site and announced `Construction site, 0 percent`
   rather than looking complete.
7. Demolition changed treasury, cashflow, openings, selection, and the visible
   parcel. Command-Z restored those values and the building; the saved
   pre-demolition and post-Undo bytes are exactly identical.
8. The exact compact segment ran with `CITYSIM_REDUCE_MOTION_PROOF=1`.
   Directional identity, selection, AX meaning, and the three LODs remained
   intact.

Both exact candidate PIDs were terminated. No renderer/product/resource,
fixture source, shared authority, claim, integration branch, or published
branch was changed.
