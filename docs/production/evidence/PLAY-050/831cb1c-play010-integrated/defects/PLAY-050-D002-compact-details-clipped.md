# PLAY-050-D002 — Compact objectives still obstruct command-center diagnosis

- Severity: Priority 1
- Owner lane: UI and input
- Candidate: `831cb1c11d3a26883cf40a11a5af87f7e94176d0` containing accepted PLAY-010 baseline `f96ff8022ee12e0ac32f0250621993d23f2f0d23`
- Reproducibility: reproduced again at the declared 900×600 minimum with Reduce Motion enabled
- Original reproduction: `c446025-baseline/defects/PLAY-050-D002-compact-details-clipped.md`
- Requirement impact: PLAY-050 compact/accessibility/cause-effect gates; PLAY-030 compact acceptance

## Start state

Repository-staged `dist/CitySim.app`, `CITYSIM_COMPACT_WINDOW=1`, paused at Day 5, Reduce Motion enabled, objectives and command-center details initially closed.

## Steps

1. Open Objectives (`⌘J` route also verified separately).
2. Open Command Center details (`⌥⌘I` route also verified separately).
3. Inspect the simultaneous surfaces visually and in the accessibility tree.
4. Invoke the details collection's exposed `AXScrollToBottom` action.

## Expected

The compact layout arbitrates the two critical surfaces or preserves a visibly operable details viewport with a clear scrolling affordance. Current objective, operating position, and diagnosis controls remain reachable.

## Actual

The full objectives panel remains on the left while the command-center details surface begins at the bottom of the window. Only the details header and the tops of diagnostic cards are visible; the body extends below the bottom edge. The accessibility tree now exposes the collection's child values, an improvement over the baseline reproduction, but `AXScrollToBottom` caused no visible movement and did not make the obscured content operable.

## Evidence

- `../visuals/compact-objectives-details.jpeg`
- Screenshot SHA-256: `c76a195b484786f1d89dbbbd9bcef7d494d4971645e691cf025b2131ebc475aa`
- AX exposed `City command center, Overview`, the details values, and `AXScrollToTop`/`AXScrollToBottom`; visual position did not change after the bottom action.

## Player impact and disposition

Critical compact/accessibility failure. The same keyboard-accessible routes can create a state where the visual diagnosis surface is largely outside the declared minimum window, obstructing cause/effect comprehension and keyboard recovery.

No product fix was made in PLAY-050.
