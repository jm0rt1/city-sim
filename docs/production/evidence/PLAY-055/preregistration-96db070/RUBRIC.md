# PLAY-055 Frozen 20-Point Rubric

This rubric is preregistered before receipt of the final combined PLAY-028/054
candidate. Each category is scored from zero through four. Every lost point
must identify an observable cause and retained candidate-bound evidence.

## 1. Residential direction and level identity — required 4/4

Four requires all sixteen `L1-L4 × N/E/S/W` identities to:

- use the accepted authored source for that exact level and frontage;
- face an authoritative adjacent road, never the camera;
- remain distinguishable at city, neighborhood, and block LOD;
- preserve level progression, entrance, footprint, pivot, foundation, ground
  contact, projection, material, and lighting;
- remain stable through unchanged pulses, pan/zoom, save/load, undo, overlays,
  construction, condition, and Reduce Motion; and
- report exact source/normalized/packed/runtime identity without mirror,
  rotation, alias, fallback, or cross-level substitution.

Any missing or wrong identity makes this category less than four and rejects
the gate.

## 2. HUD legibility and operability — required 4/4

Four requires:

- no critical metric, priority, warning, current-state, or action text below
  11 points at standard text size;
- no decision-supporting secondary text below 10 points;
- paused/running, negative cashflow, constrained utility, objective, selected
  target, rejection reason, and next action readable in one glance;
- compact Details visibly exposes one complete actionable section and two
  complete notice summaries with an obvious operable scroll region;
- AX-visible information is also visibly usable by a sighted player;
- Overview, Journal, objectives, command search, selection and rejection
  remain stable under simulation changes; and
- accepted compact map-aperture floors hold: at least 58% closed and 45% open.

Compression, scale factors, clipping, faint priority, visually missing
AX content, focus loss, or pointer-only operation rejects this category.

## 3. World/HUD composition, LOD and state clarity — minimum 3/4

Four requires a world-first regular and compact hierarchy with three useful
LODs. City communicates district and growth context; neighborhood
communicates roads, frontage and civic fabric; block communicates entrance,
condition, construction and interaction. HUD chrome, overlays, selection,
valid/invalid preview, strain and recovery must not obscure or contradict the
active target. Three allows one disclosed minor polish limitation.

## 4. Interaction and accessibility truth — minimum 3/4

Four requires pointer, Return, Space, FKA and AX to name and mutate exactly one
identical target once. Preview, AX value/help/action, click and feedback must
agree on coordinate, availability and reason. Welcome, modal and text-entry
surfaces must quarantine gameplay commands. Focus generation and topmost-first
Escape must be stable through three repeats. Reduce Motion must preserve
meaning and state. Three allows one non-blocking limitation.

## 5. Shipping identity, determinism and performance — minimum 3/4

Four requires exact product/bundle/executable/manifest/PID/data-root/window
identity, source/staged resource parity, zero fallback diagnostics, a
deterministic pack, focused and full tests, staged verification, bounded
active-plus-adjacent residency, no continuing RSS high-water after three LOD
cycles, and no unexplained cold/update/render regression. Regular and compact
settled RSS must remain within the accepted 333.8 MiB ceiling unless
integration publishes a stricter replacement. Three allows one explained,
accepted non-player-blocking limitation.

## Automatic rejects

Any item rejects regardless of total:

- substitute or ambiguous commit, bundle, manifest, resource, state, camera,
  window, defaults domain, data root, or PID;
- cropped, resized, composited, harness-only, author-only, or single-width
  proof;
- any Residential mirror, rotation, alias, fallback, wrong level, wrong
  frontage, wrong-road entrance, overlap, seam, pivot drift, floating
  foundation, broken ground contact, mixed projection/light/material, or
  unreadable identity at a required LOD;
- one hero frame masking failure elsewhere in the 16-row matrix;
- HUD or transient feedback obscuring the target or surrendering the city;
- critical information present in AX but visually clipped, collapsed, hidden,
  microscopic, or unreachable;
- compact aperture below 58% closed or 45% open;
- Overview without one complete actionable section or Journal without two
  complete visible notice summaries;
- false selection, preview, rejection, construction, consequence, strain,
  recovery, paused/running, metric, objective, or next-action truth;
- pointer, keyboard, FKA or AX target/action disagreement;
- modal/text-field command leakage, unstable focus, or broken Escape order;
- Reduce Motion information loss or state change;
- silent fallback, hash mismatch, nondeterministic bytes, unbounded residency
  or RSS growth, or unexplained over-budget performance; or
- product mutation, coaching, candidate substitution, or author self-score
  entering the independent disposition.
