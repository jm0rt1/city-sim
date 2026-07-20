# PLAY-050-D002 — Compact objectives hide command-center content

- Severity: Priority 1
- Owner lane: UI and input
- Candidate: `c4460255ca810ce4de878f20f98a883983cf3dbd`
- Reproducibility: reproduced once through keyboard route at declared 900×600 minimum
- Requirement impact: UX-009, UX-010, PLAY-030 compact acceptance

## Start state

Staged `dist/CitySim.app`, `CITYSIM_COMPACT_WINDOW=1`, Day 42 quicksave loaded and paused, Reduce ambient animation enabled.

## Steps

1. Press ⌘J to open Objectives.
2. Press ⌥⌘I to open Command Center details.
3. Inspect the details content visually and through the accessibility tree.

## Expected

Both keyboard-opened critical surfaces remain operable at 900×600, or the layout safely arbitrates them without losing state or focus.

## Actual

The objectives panel remained visible while the command-center details surface extended below the bottom window edge. Only the details header was visible; the accessibility tree exposed its content collection with no child values.

## Evidence

- `../visuals/compact-objectives-details-clipped.jpg`
- AX state showed `City command center, Overview` followed by an empty `collection`.

## Player impact

The keyboard critical path can open a state in which diagnosis content is inaccessible at the declared compact minimum. This blocks compact and accessibility qualification.
