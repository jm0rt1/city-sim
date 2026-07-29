# PLAY-075 Industrial L4 family-level preregistration v1

- **Disposition:** `PREREGISTERED_CANDIDATE_NEUTRAL`
- **Lane:** `codex/citysim-playtest-quality`
- **Claim:** `PLAY-075`
- **Date:** July 28, 2026
- **Published operating authority:**
  `c08a0aa7b0a461c1dfcd6c50dfe149db5ff766a3`
- **Parallel-art skill authority:**
  `346a27240668d97f0e89b7a9d4be00f9ed6e8239`
- **Fixture checkpoint:**
  `17b3425ad0db72e8aa72d2128b923dd74329af2d`
- **L3 blocker checkpoint retained:**
  `c5c8f0bf18160bde255e6d04a73c313a8f38a604`

This is the candidate-blind contract for one focused Industrial L4 staged-app
gate. It does not inspect, admit, or score any L4 source cell or renderer
candidate. East, South, West, and North source work may mature independently,
but QA production acceptance is atomic: one exact renderer candidate must
contain all four accepted directions and must complete one fresh 4/4 real-app
journey.

This focused gate does not replace or pre-score the separate full 20-minute
Wave 009 `20/20` city-not-board release gate.

## Preserved R2 boundary

Exact Industrial L3 renderer candidate
`de6805092478c97d85f0230c93f7f10edcb257e6` remains `BLOCK`, not `APPROVE`
or `RETURN`. The real-app run stopped after the Mac locked, before compact,
four-direction, full LOD, interaction, Reduce Motion, screenshot, and live
frame proof completed. The exact evidence is retained at `c5c8f0bf`; this
preregistration does not infer acceptance from that partial run.

The current QA carrier contains the blocked renderer history plus the normal
merge of published authority `c08a0aa7`. The exact save-model, fingerprint,
save-service, and accepted source-fixture bytes used below are byte-identical
to `c08a0aa7`. No renderer byte from the blocked candidate was used to
construct or validate the fixture.

## Frozen fixture and state identity

Candidate-neutral accepted-L3 comparison/harness fixture:

`fixtures/industrial-l03-directional-mature-city-v1.json`

- Fixture SHA-256:
  `b8875422a277b59f6797aef03ca93175a502df5963a5c972684ca47be40e7aa5`.
- State digest:
  `dbe6860011f43063a39e228531db4b49303d64a918e7884301b3de80360dd97f`.
- Schema/fingerprint version: `1` / `1`.
- Byte count: `133925`.
- Seed: `10481999410520546993`.
- Tick/Day: `844` / `212`.
- Initial simulation state: playing save, loaded and immediately paused.
- Initial overlay: City.
- Initial Details/Journal/Overview/Guide state: closed.
- Initial Focus City: off.
- Four completed/maintained/89-worker Industrial L3 lots:
  North player block `11,11`, East `4,10`, South `5,9`, West `18,12`.

The exact transformation and sole-adjacent-road proof are in
`fixtures/industrial-l03-directional-mature-city-manifest-v1.json`.

The future L4 candidate fixture must be derived mechanically from these exact
bytes by changing only the four declared tiles from level `3` to level `4`.
Before launch, QA must save it through the candidate's unchanged schema-1 save
service, record its exact bytes and state digest, prove no other field changed,
and commit the identity receipt. If L4 requires a new save field, schema
change, product fixture hook, or renderer override, stop for an
integration-owned contract; do not improvise.

Construction and condition checks use candidate-bound derivatives of the same
four-tile L4 state:

- construction: North only, `constructionProgress = 0.50`;
- condition: West only, `condition = 0.30`;
- all other state fields and the other three L4 tiles remain exact.

Those two derived state digests must be recorded before app interaction. They
are presentation-only QA states and may not support simulation or balance
claims.

## Exact window and camera contract

Every binding capture is original-resolution and uncropped:

- regular: `1278 x 768` decorated-window image;
- compact: exact `900 x 600` app content inside a `900 x 652` decorated-window
  image.

At both widths:

1. load the exact fixture through the visible Open command;
2. pause before the first simulation step;
3. select City overlay, close transient surfaces, and wait for the load toast
   to disappear;
4. press `0` (`Frame Developed City`) before each direction's capture series;
5. retain the production camera center chosen by that command;
6. use player-visible zoom controls to capture canonical City,
   Neighborhood, and Block stops, with candidate diagnostics binding the
   semantic LOD and canonical targets `0.74`, `0.66`, and `0.50`;
7. use no camera rotation; CitySim has no player-facing rotation control and
   road frontage, never camera state, selects direction; and
8. retain City overlay, Focus City off, Details closed, and the same selected
   target for a direction's three LOD captures.

Candidate and accepted-baseline comparisons must use the same window, semantic
LOD, selection, overlay, focus state, and `Frame Developed City` route.
Selection-triggered reveal may not replace the reset composition. Any hidden
proof-camera environment value or renderer coordinate override is forbidden.

## Fresh-player knowledge boundary

The player may know only:

- this mature city contains four operational high-tier Industrial works;
- the ordinary map, Details, pause, zoom, command guide, save, Undo, and
  accessibility controls are available; and
- the goal is to decide whether all four works belong to one premium
  heavy-industry family and face their real roads.

The player may not receive fixture coordinates, source labels, expected
direction order, hidden scale thresholds, screenshot annotations, author
narration, renderer node names, prior answer text, or instructions identifying
which pixels constitute a portal, stack, court, or defect. Machine coordinates
are used only after each unaided selection to bind evidence identity.

## One fresh focused staged-app journey

After exact candidate admission and isolated staging:

1. Start with fresh defaults and an isolated data root. Record source commit,
   product commit, executable, bundle, Info.plist, staging manifest, packaged
   atlas, generated-v4 manifest, fixture bytes, PID, and process environment.
2. Load the four-place L4 fixture through the visible Open command and pause.
   Without coordinate coaching, identify the four Industrial L4 works in the
   city composition and state the first-glance family, hierarchy, frontage,
   and cohesion read.
3. At regular size, inspect North, East, South, and West. For each, capture
   City, Neighborhood, and Block LOD in color and literal grayscale. Confirm
   one authored family, truthful road-facing entrance/logistics story, stable
   parcel registration, and visible advancement over the exact published L3
   renderer baseline.
4. Select each visible building with the pointer, then reacquire that same
   building through keyboard map navigation and open Details. Target block,
   level, workers, condition, road connection, selection outline, and action
   must agree.
5. Exercise the affected AX path, VoiceOver, and Full Keyboard Access for one
   direction at regular and one at compact. AX must announce Industrial Level
   4, exact player block, operational/construction/condition state, workers,
   road connection, and actionable identity. Visual direction remains bound
   by the visible road relationship and may not exist only in AX.
6. Load the preregistered construction and condition derivatives. Verify that
   the Industrial L4 family remains recognizable while construction and
   weathering meaning remain visible at all three LODs.
7. On one completed L4 lot, save the exact before state, demolish through the
   visible action, invoke Undo, save again, and require the restored save/state
   digest to equal the preregistered before digest exactly.
8. Repeat the four-direction and three-LOD same-state matrix at exact
   `900 x 600`. Enable Reduce Motion through system settings for a separate
   exact candidate process and repeat selection, one construction/condition
   check, and one direction at every LOD.
9. Cycle City/Neighborhood/Block three times, allow a 60-second settle, retain
   RSS/footprint and frame diagnostics, confirm exact candidate identity
   again, then terminate the exact PID and prove it absent.

Do not rerun Integration's full native suite or the unrelated 20-minute
release journey. Focused pack/runtime validation and the real changed-family
journey are sufficient for this batch gate.

## Atomic admission requirements

Do not launch the final journey until Integration supplies:

1. one clean exact renderer candidate and its exact product commit;
2. a published exact accepted R2/L3 product for the comparison baseline;
3. all four exact independently accepted Industrial L4 source directions as
   ancestors or immutable admitted inputs;
4. twelve distinct `N/E/S/W x City/Neighborhood/Block` L4 normalized outputs;
5. four unique source keys and source hashes, twelve unique normalized hashes,
   exact raw/normalized/pack/runtime parity, and two-build determinism;
6. zero alias, mirror, rotation, recolor, fallback, crop, registration, socket,
   alpha, padding, extrusion, or overlap failure;
7. one isolated attached-SHA staged environment with unique bundle/defaults,
   data root, executable, resources, manifest, and PID; and
8. the three exact candidate-bound L4 fixture digests described above.

A missing direction, returned source, unpublished R2 baseline, dirty worktree,
candidate drift, mixed resources, or candidate substitution is `BLOCK`, never
a partial family score.

## Disposition boundary

Return exactly one candidate-bound `APPROVE` or `RETURN` after the complete
journey. `APPROVE` means only that the atomic L4 batch may publish. It does not
accept a source cell separately, close PLAY-075, or satisfy the final Wave 009
20/20 release gate.

The binding category thresholds and automatic returns are frozen in
`RUBRIC.md`. The exact future capture tree is frozen in `EVIDENCE-PLAN.md`.

## Candidate-neutral rehearsal status

The fixture has passed byte identity, save/fingerprint generation, mature-state
placement, and exclusive-road-frontage validation. A real-app rehearsal has
not run because the Mac remained manually locked. After unlock, QA may rehearse
this exact L3 fixture only against the exact published accepted baseline. That
rehearsal proves the harness and capture route, not L3 or L4 acceptance, and
must be committed separately from candidate evidence.

The existing accepted visible-city fixture mechanism was independently
revalidated after the `c08a0aa7` merge:

```text
VisibleCityStateFixtureTests/
  testMatrixMatchesTwoIndependentBuildsAndFrozenManifest
Executed 1 test, with 0 failures, in 4.286 seconds.
```

`git diff --check` and `bash -n script/build_and_run.sh` also pass. No staged
app, GUI process, renderer candidate, product source, shared fixture, or test
source was created or changed by this preregistration.
