# PLAY-052 Round 1E combined-candidate blocker

## Disposition

**REJECTED FOR COMBINED OR FINAL INTEGRATION.**

The exact renderer adapter earns a separate 17/20 renderer-only score, but the
candidate does not satisfy the one-active-target requirement. Pointer
presentation and click intent can target one coordinate while keyboard,
Return, and the City map AX value retain another coordinate and availability
reason. This is the known CONTRACT-008 UI/input blocker. Quality did not repair
or waive it.

## Independent reproduction — default

Starting from the sole exact PID `85453` at 1278 x 768:

1. Pause and establish map focus.
2. Enter Build > Zones > Residential.
3. Move by keyboard from road `14,13` to open land `14,11`.
4. Observe AX: `Pending Residential placement at block 14, 11`, available,
   `$1,800` and `$4 upkeep`.
5. Point at and click the visibly occupied commercial frontage.

Actual result:

- the renderer shows a red invalid Residential ghost over the occupied
  commercial/industrial frontage;
- the visible message says to demolish the existing structure and choose
  another block;
- simultaneously, the semantic City map value still announces block `14,11`
  as the available primary action.

Evidence:
`live/default-active-target-contradiction.jpeg`.

## Independent reproduction — exact compact

Starting from sole exact PID `91740`, launched with
`CITYSIM_COMPACT_WINDOW=1` and `CITYSIM_REDUCE_MOTION_PROOF=1`:

1. Pause and select Residential from the compact Catalog.
2. Move by keyboard from road `14,13` to open land `16,14`.
3. Observe AX: block `16,14` is available at the Residential cost.
4. Point at and click a different visibly occupied road/frontage coordinate.

Actual result:

- the renderer shows a red invalid ghost and occupied-target rejection at the
  pointer location;
- AX and the keyboard primary action remain the different valid block `16,14`.

Evidence:
`live/compact-active-target-contradiction.jpeg`.

Quality did not reproduce the renderer author's stronger compact symptom in
which the pointer click committed the retained keyboard target. The
independently reproduced simultaneous two-target state is already sufficient
to reject the combined candidate because the player cannot know which block
pointer click, Return, or AX Press will act on.

## Ownership and acceptance test

- **Owning lane:** UI/input, under the approved CONTRACT-008 integration
  authority.
- **Renderer lane:** retain the exact `45dd181` adapter; do not repair shared
  target authority inside renderer nodes.
- **Required combined retest:** pointer hover/click, keyboard selection/Return,
  placement preview, rejection reason, committed selection, and City map AX
  value/action must expose one coordinate and one availability reason in
  default and exact compact. Pointer, Return, Space, and AX activation must
  execute that same target exactly once.

## Compact focus finding

The inherited automated failure at
`CityCommandCatalogTests.swift:506` was **not reproduced hands-on**:

1. compact keyboard selection announced Road `14,13`;
2. Objectives opened;
3. Command Center details opened without replacing or clearing the semantic
   map selection;
4. first Escape closed Command Center while preserving Objectives, selection,
   and map focus;
5. second Escape closed Objectives while preserving selection and map focus.

The unchanged baseline/product automated failure remains real evidence and
must be resolved or reconciled by its owner before integration, but it did not
create an additional live renderer rejection in this route.

## Final boundary

Renderer-only status: **17/20 compatible adapter approved.**

Combined/final status: **REJECTED pending UI/input CONTRACT-008 repair and
independent retest.**

No product code was changed. No push, merge into master, or integration
acceptance is authorized by this record.
