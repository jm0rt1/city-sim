# CitySim restart brief

## Standing mandate

Build a polished, playable city-building game inspired by the depth and core
loop of SimCity 4, with an original art style and original assets. Deliver
roads, zoning, utilities, growth, money, and useful city feedback as one
satisfying management experience. The project owner may choose and sequence
the concrete outcomes needed to reach that mandate, escalating only critical
product tradeoffs, material scope or budget changes, irreversible actions, or
true external blockers.

## Current sequence

The new-player journey is complete. Next, improve interruption safety, then
dense-city runtime responsiveness, then compact usability at true 900x600;
reassess after those outcomes. Volatile current-task details belong in the
active Goal Driver task, and explicit user direction supersedes this sequence.

## Visual rules

- Every visible building uses one canonical near-orthographic/isometric camera
  family: consistent roofline slope, facade exposure, footprint axes, base,
  pivot, and ground contact.
- Use one lighting and shadow language. Do not hide mismatched art through
  per-asset rotation, skew, or camera hacks.
- The city, not diagnostic chrome, is the dominant view. Keep details available
  without permanently consuming the playable map.

## Proof of success

Compare the real composed game screen before and after at 1280x800 and 900x600.
The block must read as one world, remain map-dominant, and support the intended
player interaction. A passing build or isolated component test is not enough.

## Working rule

Use one accountable Goal Driver with a lightweight liaison. Bring in at most
one short-lived specialist for a genuinely independent, bounded contribution.
Keep the task brief and proof in the task itself; do not create a standing
operational control plane.
