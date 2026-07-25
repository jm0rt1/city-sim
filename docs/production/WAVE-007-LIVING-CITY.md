# Wave 007 — Make the City Feel Alive

## Why this wave exists

The published `4c0414b003a178948c62128f425b6d534ac2e7a7` staged app is
coherent, readable, and independently approved. A fresh integration-owned
hands-on audit on July 25, 2026 nevertheless found that the directional
building work has overtaken the surrounding world:

1. The park is a flat turquoise rectangle with one path while nearby
   architecture carries materially richer form, light, and texture.
2. Sparse repeated tree clusters and large quiet grass fields still expose the
   board beneath the city.
3. Streets have almost no visible civic life. The accepted world is readable,
   but it does not feel inhabited.
4. Land Value and Traffic modes add a clear legend but do not produce a
   sufficiently obvious, localized change in the visible map at the audited
   city/neighborhood view.
5. The always-open priority band and command deck remain useful but consume
   too much of the most interesting skyline. Opening Details reduces the city
   to a narrow strip.
6. Building scale and detail are now strong enough to make repeated
   vegetation, the generic park, and empty public realm look conspicuously
   unfinished.

These observations do not reopen accepted PLAY-024, PLAY-028, PLAY-054, or
PLAY-055. They define a materially higher successor outcome.

## Work order

### PLAY-059 — Authoritative local diagnostics

Simulation platform first supplies the three missing presentation-only
channels approved by CONTRACT-013: developed-tile Land Value, developed-tile
Local Happiness, and road-tile Traffic Pressure. These values are transient,
deterministic, typed, and cannot affect gameplay or persistence.

### PLAY-056 — Living public realm

World rendering owns the space between buildings: authored parks, varied
vegetation, curbside/street props, restrained ambient life, and world-visible
data layers. Every choice must remain deterministic, collision-safe,
truth-safe, and readable at city, neighborhood, and block LOD.

Park, vegetation, furniture, and ambient work may proceed independently.
Land Value, Traffic, and Happiness adoption waits for accepted PLAY-059;
Utilities and Pollution continue using their existing spatial truth.

This slice does not ingest pending Commercial or Industrial directional art.
Those source catalogs retain their own governed acceptance and shipping tasks.

### PLAY-057 — Focus the city

UI/input owns a presentation-only Focus City mode that collapses the command
surface to the smallest still-truthful status rail. The same action must be
available through the visible HUD, command guide, macOS menus, and a declared
keyboard shortcut. Critical state, selected-target truth, modal quarantine,
and accessibility remain authoritative.

CONTRACT-012 authorizes the narrow transient command/store boundary.

### PLAY-058 — Independent living-city gate

Quality freezes the exact `4c0414b` baseline before receiving product
candidates. It independently compares the same state, camera, viewport, and
overlay in regular and exact 900 x 600 layouts, then exercises the real staged
app without coaching.

## Non-negotiable proof

- one same-state city/neighborhood/block comparison for the park and public
  realm;
- deterministic vegetation/prop identity and collision reports;
- a retained 20-second regular and compact ambient-life observation;
- Land Value, Traffic, Utilities, Happiness, and Pollution comparisons where
  map truth is visible without relying on the legend alone;
- Focus City entry/exit by pointer and keyboard, plus command-guide/menu
  parity, focus restoration, Escape ordering, AX, FKA, and Reduce Motion;
- measured map aperture with closed HUD, Focus City, and open Details;
- no invented roads, occupied lots, traffic congestion, pollution, utilities,
  prosperity, or population facts;
- exact staged resource identity, full native suite, renderer diagnostics,
  residency/RSS, and frame-time evidence.

## Acceptance bar

The integrated candidate must score at least 19/20 with 4/4 in public-realm
coherence and world/HUD composition, no category below 3, zero P0/P1 defects,
and zero automatic rejects. It must be materially preferred to `4c0414b` in
both regular and compact same-state comparisons.

Automatic rejection includes a decorative park tile, obvious repeated
vegetation rows, ambient sprites that imply unavailable simulation truth,
overlay truth visible only in a legend, HUD focus mode hiding urgent state,
map targets moving under HUD transitions, clipped/open panels, collision,
fallback, unbounded resource growth, or author-authored acceptance.
