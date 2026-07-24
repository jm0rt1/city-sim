# PLAY-052 combined Round 1E independent disposition

## Disposition

**APPROVED — exact combined product
`704784b21294562fba5f145455c44e2de2a64e76`.**

The exact candidate closes the prior CONTRACT-008 P1 contradiction and
preserves the independently approved 17/20 renderer gate. No category is below
3 and no renderer automatic reject was reproduced. This disposition applies
only to the candidate, bundle, executable, resource pack, and manifest named
in `IDENTITY.md`.

## CONTRACT-008 closure

At exact compact, quality independently reproduced the old sequence:

1. Keyboard selected valid Residential target A at block 14,11. Map AX,
   preview, cost, and primary action all named A.
2. Pointer targeted occupied Commercial block B at 14,12.
3. The click changed the sole active target, map AX value/help/action, and
   blocked preview to B.
4. The exact occupied reason remained visible, Residential stayed selected,
   selection did not silently return to A, treasury did not change, and Undo
   remained disabled.

The former stale-coordinate build did not reproduce. Valid pointer, Return,
and AX custom-action routes were then isolated by Undo and each built exactly
one Residential at the announced block 14,11 for exactly $1,800.

The keyboard contract remains internally consistent: Return is the spatial
primary action; Space on map focus is pause/resume. Full Keyboard Access Space
activated the focused New Arcadia button exactly once, opened Command Center,
and did not mutate the selected coordinate. This prevents a Space/placement
shortcut collision rather than inventing a second spatial action.

## Target truth matrix

| State | Live coordinate and action | Result |
|---|---|---|
| Occupied | Residential at Road 14,13 and Commercial 14,12 | Exact occupied reason, retained tool/coordinate, no mutation |
| Road required | Commercial 14,8 | Exact direct-road-access reason, retained after 4 seconds, no mutation |
| Newly connected | Build Road 14,9, then re-read Commercial 14,8 | Same target became immediately available; one $2,400 build |
| Unaffordable | Power Plant 15,9 with $11,044 treasury | Exact treasury reason, retained tool/coordinate, no mutation |
| Valid pointer | Residential 14,11 | One build, exactly $1,800 |
| Valid Return | Residential 14,11 | One build, exactly $1,800 |
| Valid AX action | `Build Residential at block 14,11` | One build, exactly $1,800 |

For every state, the grounded preview, City map AX value/help/custom action,
availability, coordinate, reason, treasury change, and Undo state agreed.

## Default, compact, modal, focus, and accessibility

- Fresh compact Welcome exposed only the blocking content and Start Building.
  Space, 1, 2, 3, B, V, Escape, Command+/ and pointer attempts did not alter
  state or expose underlying controls. Pointer dismissal restored normal
  renderer and gameplay input.
- The explicit regular route ran as sole PID 76963 at 1278 x 768. It retained
  the developed world, one valid placement preview, 0% construction, and a
  Traffic overlay without changing the active block.
- The explicit compact Reduce Motion route ran as sole PID 77076 at 900 x 600
  content. Selection and Utilities overlay remained readable without motion
  dependence or hidden critical controls.
- Pointer, keyboard, semantic AX, and the AX custom build action converged on
  the same coordinate. Full Keyboard Access Tab and Space worked once on the
  focused HUD control.
- Command Center plus Objectives retained the map target. Escape closed the
  topmost surface first and returned focus to the map.
- Command Guide owned text focus: `taxb1` remained search text and invoked no
  gameplay shortcut.

## Preserved renderer score

No visual regression was found against the immutable independent renderer
approval at `b2e318cf78c03cbe0490ba12af40a4f0a85100a3`.

| Frozen renderer category | Score | Combined-candidate observation |
|---|---:|---|
| Composition / map occupancy | 3/4 | Default and compact still frame the modest but inhabited connected crossroads; no toy-island regression |
| Projection / material / light / road coherence | 3/4 | Physical asphalt, curbs, junctions, frontage, shadows, and explained turning heads remain coherent |
| Useful city / neighborhood / block LOD and depth | 3/4 | Packaged three-LOD identity is unchanged; live regular/compact framing and focused tests remain green |
| Believable life / state / interaction restraint | 4/4 | Selection, blocked/valid previews, construction, overlays, and Reduce Motion remain grounded and non-obscuring |
| Systemic shipping credibility / performance | 4/4 | Exact resources, zero fallback, bounded residency, stable soak, sole PIDs, and full suite remain green |
| **Total** | **17/20** | Threshold met; no category below 3 |

Automatic-reject checks:

- unintended physical overlap: not reproduced;
- mixed art language: not reproduced;
- mostly empty city frame: not reproduced;
- unexplained road end: not reproduced;
- obscuring hover, selection, preview, or overlay: not reproduced;
- duplicated rejection copy: not reproduced;
- silent asset fallback: not reproduced;
- over-budget residency or continuing high-water growth: not indicated by the
  retained exact resource identity or current diagnostics;
- harness-only proof: not triggered because default, compact, pointer,
  keyboard, AX, construction, overlay, modal, and Reduce Motion were operated
  in the real staged app.

## Validation

- Focused command/renderer suite:
  `swift test --package-path Native/CitySimNative --filter '(CityCommandCatalogTests|WorldRenderingTests)'`
  — **66/66 passed**, 0 failures, 19.665 seconds:
  30 command tests in 9.756 seconds and 36 renderer tests in 9.909 seconds.
- Full native suite:
  `swift test --package-path Native/CitySimNative`
  — **180/180 passed**, 0 failures, 72.862 seconds.
- Current full-run renderer diagnostics:
  1,138 nodes / 406 drawables regular,
  1,129 nodes / 397 drawables compact,
  28 resident textures / 13,521,048 decoded bytes,
  zero fallback,
  single cold profile 4.351 ms,
  and 4,286-pulse soak at 0.0033 ms average with two bounded actions.
- The first sandboxed full-suite invocation could not write the frozen
  candidate's Swift cache and exited before a valid run. The authorized rerun
  above is the complete authoritative result; this was infrastructure, not a
  product failure.

## Evidence

- Identity and process binding: `IDENTITY.md`
- Compact semantic observations: `compact-ax.txt`
- Regular semantic observations: `default-ax.txt`
- Independent live frames: `live/`
- File hashes: `SHA256SUMS`

No product source, shared contract, renderer evidence, or author conclusion
was changed. No push or integration was performed.
