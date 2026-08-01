# RETURN — PLAY-075 R4-A Wave 009 final gate

Exact candidate `0e89914566ba4593b25e2cd52b4b788d204b7331` is **RETURNED**.

## Score

| Frozen category | Score | Candidate-bound result |
|---|---:|---|
| Consequential post-Charter second act | 4/4 | Industrial warning, invalid placement, road recovery, utility setback, visible recovery actions, and authoritative story completion were all player-legible. |
| World, public realm, and activity truth | 2/4 | Roads, curbs, sidewalks, frontage, park/utility landmarks, and district occupancy are materially better than `87e1e68`, but the regular city view retains a broad undifferentiated green quadrant and an unmistakable adjacent duplicate orange-building pair. At block distance, the flat orange buildings also remain materially shallower than the civic landmark. |
| Game/HUD cohesion and map aperture | 4/4 | Priority, economy, warnings, speed, selected target, action, overlays, compact Details, and map aperture remained coherent at both widths. |
| Playability, control, persistence, and accessibility | 4/4 | Pointer/keyboard target parity, visible invalid preview and recovery, FKA focus, command guide, topmost Escape, AX identity/condition/action, Reduce Motion, Save, and exact demolition/Undo fingerprint passed the dispatched one-start route. |
| Shipping identity, determinism, and performance | 4/4 | Exact source/tree/bundle/executable/manifest/resource/defaults/root/PID identity held before and after; the Integration receipt supplied the exact aggregate suite/build result; live RSS was bounded and no visible accumulation or fallback occurred. |
| **Total** | **18/20** | Acceptance requires `20/20`, every category `4/4`, and zero automatic returns. |

## Automatic-return defects

1. **Sparse-board / broad-green condition remains at regular city LOD.** In
   [`live/regular/lod-city.jpg`](live/regular/lod-city.jpg), the developed road
   network is materially larger than the baseline but still leaves a broad,
   visually undifferentiated green quadrant across the upper-right of the
   intended camera. The authored district does not fully dominate the frame.
2. **Obvious adjacent repetition remains.** The same regular city frame and
   [`live/regular/lod-neighborhood.jpg`](live/regular/lod-neighborhood.jpg)
   show two near-identical orange/black-roof buildings side by side in the
   upper-left parcel, with the same silhouette, value grouping, entrance, and
   roof treatment. This reads as a duplicate, not controlled neighborhood
   variation.

Both conditions are enumerated automatic returns in
`docs/production/WAVE-009-CITY-NOT-BOARD.md`. They remain visible without
labels, survive the regular LOD transition, and cannot be waived by the
candidate's otherwise successful interaction/accessibility route.

## Baseline preference

R4-A is materially preferred to exact baseline `87e1e682...` at regular and
compact widths and across the three retained LOD comparisons: it has more
connected road/public-realm mass, more developed frontage, better compact HUD
arbitration, and substantially less empty terrain. That necessary preference
does not clear the zero-automatic-return bar. The exact retained baseline
paths and pixel hashes are bound in `IDENTITY.json`.

## Key evidence

- Regular LOD matrix: `live/regular/lod-city.jpg`,
  `live/regular/lod-neighborhood.jpg`, `live/regular/lod-block.jpg`
- Compact LOD matrix: `live/compact/lod-city.jpg`,
  `live/compact/lod-neighborhood.jpg`, `live/compact/lod-block.jpg`
- Compact parity/AX: `live/compact/pointer-selection.*`,
  `live/compact/keyboard-inspect.*`, `live/compact/fka*`
- Variants: `live/compact/details.*`, `live/compact/pollution-overlay.*`,
  `live/compact/command-guide.*`, `live/compact/reduce-motion.*`
- Exact Undo: `live/compact/undo-pre-fingerprint.txt`,
  `live/compact/undo-restored-fingerprint.txt`,
  `live/compact/undo-restored-reselected.*`

No product repair, second launch, duplicate journey, candidate substitution,
author coaching, push, integration, or Industrial L4 scoring occurred.
