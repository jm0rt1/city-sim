# PLAY-073 R4-A — Ground the authentic opening as one district

**Owner:** Integration
**Lane:** World Rendering
**Branch:** `codex/citysim-world-rendering`
**Published technical baseline:** `b72272e1a41b272c9ba549f05760a72f8ed92fd8`

## Release decision

Industrial L4 shipping ingestion is explicitly deferred while its independent
source cells continue. Renderer may now implement one bounded R4-A composition
slice against the authentic opening. Exact integrated L3 technical candidate
`472ffa85cd35639a675c1c2e4ede748c94446a7f` remains frozen with its still-open
PLAY-075 same-SHA gate active and isolated. R4-A may not restage, relaunch,
rebind, replace, or substitute that candidate or its app/bundle/evidence
paths.

The authority and claim must first be published on `master`. Renderer must
then merge that exact publication commit cleanly and verify it as an ancestor
before any R4-A mutation; current returned Renderer HEAD `4a8c118e…` alone is
not authority.

This is a narrow sequencing amendment to the R4 closeout order: worktree-local
R4-A source, tests, diagnostics, and isolated build artifacts may proceed in
parallel while the L3 gate finishes, but R4-A may not be integrated, published,
accepted, staged, launched, or sent to PLAY-075 until L3 receives its
independent disposition and Integration records the resulting publication or
deferral decision. R4-A then receives its own separate full PLAY-075 20/20
gate; it may not reuse the L3 focused gate.

Preserve the integrated Industrial L4 nonshipping intake harness. Do not
consume a live L4 source, receipt, pixel, atlas slot, or production mapping.

## Player-visible outcome

Replace the broad green-board reading with one grounded, authored starter
district:

- the connected district and public-realm envelope occupies at least 60% of
  safe map width at regular and compact opening layouts;
- no plain-terrain connected component exceeds 25% of the safe aperture;
- roads read as continuous civic fabric, not isolated black strips;
- every occupied or special parcel visibly meets its authoritative road-facing
  frontage through curb, sidewalk/service edge, entrance, parcel ground, and
  contact shadow;
- buildings, parks, utilities, service lots, props, roads, and terrain share
  one material, value, outline, northwest-light, and southeast-shadow system;
- one complete truthful buildable parcel band remains visible;
- City, Neighborhood, and Block LODs carry distinct district, frontage, and
  entrance roles; and
- selection, placement preview, warnings, overlays, keyboard/pointer targeting,
  compact Details, accessibility, and Reduce Motion remain legible.

Freeze one candidate-bound rendered-pixel measurement definition before
implementation:

- safe aperture is the exact visible map rectangle after HUD and fixed window
  insets for the governed regular and compact fixtures;
- district/public realm is the union of authoritative occupied/special parcel
  ground, roads, curbs, sidewalks/service edges, frontage/entrance geometry,
  and their contact regions within that aperture;
- plain terrain is the four-connected set of pixels classified only as
  unmodulated vacant terrain after removing truthful district/public-realm
  classes; and
- opaque building pixels are nonzero-alpha pixels belonging to authoritative
  building sprites before selection/preview overlays.

Retain the exact baseline and candidate masks, dimensions, connected-component
ledger, numerator/denominator counts, and computed 60%/25%/10% results from the
same deterministic fixtures.

## Claimed implementation surfaces

- `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
- `TerrainRenderer.swift`
- `RoadRenderer.swift`
- `LotContextRenderer.swift`
- a narrowly required `LotRenderer.swift` change
- renderer-local `WorldVisualStyle.swift`
- `WorldRenderingTests.swift`
- task-owned PLAY-073 diagnostics and evidence

Do not change gameplay, simulation, UI/HUD composition, saves, package
topology, World Art source roots, accepted asset bytes, shipping manifests, or
the Industrial L4 admission contract.

## Automatic rejection

Return the candidate if any of these remains:

- district/public-realm safe-width coverage below 60% at either layout;
- plain terrain above 25%, a visible road/frontage seam, floating/detached
  parcel plate, collision, overlap, clipped critical parcel, fallback, or
  invented road/occupancy;
- adjacent identical source-and-context signatures where alternatives exist;
- selection or preview obscuring 10% or more of opaque building pixels;
- one LOD acting only as a scaled copy of another;
- pointer, keyboard, AX, Reduce Motion, overlay, or compact Details regression;
- unexplained regression beyond the accepted cold render budget of 6.03 ms,
  pulse budget of 2.1 ms, or established node/draw/RSS/residency envelopes; or
- mixed high- and low-fidelity ground contact, materials, lighting, or shadows.

## Evidence and stop

Commit the coherent renderer product before evidence. Then retain
deterministic regular/compact authentic-opening masks and frames, color and
grayscale state/LOD matrices, 16-mask road/junction mosaics, frontage and
collision reports, source/context repetition ledger, interaction/AX/Reduce
Motion results, two-build identity, and resource telemetry.

While L3 QA remains open, run focused renderer tests and only worktree-isolated
build/resource checks that cannot alter or launch the shared staged app,
bundle, or evidence path. After the L3 disposition, Integration may separately
authorize candidate-only noninteractive staging. Integration owns the later
full-suite/staged identity gate; PLAY-075 owns R4-A's sole fresh player-facing
acceptance journey. Stop clean at one candidate handoff. Do not push,
integrate, self-score, self-accept, or pin.
