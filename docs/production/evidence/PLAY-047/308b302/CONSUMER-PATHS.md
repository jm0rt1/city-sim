# PLAY-047 Fixture Consumer Paths

The authoritative corpus lives only at:

`Native/CitySimNative/Tests/CitySimNativeTests/Fixtures/StoryStates/`

Consumers must select a named JSON file and verify it against
`story-states-manifest-v1.json`. The manifest binds the fixture name, strategy,
moment, tick, schema, fingerprint version, state digest, spatial digest, byte
count, and file SHA-256. Consumers must not regenerate, edit, or infer a
different state.

## Renderer evidence

1. Copy the selected committed fixture to an isolated evidence root as
   `quicksave.json`.
2. Load it through
   `Native/CitySimNative/Sources/CitySimNative/Services/SaveGameService.swift`.
3. Construct the immutable renderer boundary from
   `Native/CitySimNative/Sources/CitySimNative/Models/CityPresentationSnapshot.swift`.
4. Render that snapshot with
   `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`.
5. Record the selected fixture name, file SHA-256, state digest, spatial
   digest, exact product commit, candidate identity, and capture path.

This path gives the renderer a stable logical and spatial state without adding
a production fixture loader or debug menu.

## HUD evidence

1. Copy the selected fixture to the exact staged candidate's isolated
   `CITYSIM_DATA_ROOT` as `quicksave.json`.
2. Start `CityGameStore` with its normal production `SaveGameService` and
   invoke the existing Load City command.
3. Verify the store path in
   `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
   restores the state paused and clears Undo.
4. Exercise the existing UI from
   `Native/CitySimNative/Sources/CitySimNative/Views/ContentView.swift`;
   for terminal fixtures, include
   `Native/CitySimNative/Sources/CitySimNative/Views/GameStatusOverlay.swift`.
5. Bind screenshots, accessibility output, and command evidence to the
   fixture manifest identity and exact staged app identity.

This path verifies the shipping load and presentation contracts. It does not
authorize HUD composition changes in the platform lane.

## Quality and relaunch evidence

1. Stage the exact candidate with `./script/build_and_run.sh --verify`.
2. Read its candidate identity, bundle path, preference domain, isolated data
   root, and PID from the generated manifest.
3. Use `script/persistence_relaunch_gate.sh` to retain and inventory only that
   candidate's root.
4. Place the selected fixture at `quicksave.json`; place the same verified
   bytes at `quicksave.backup.json` only when proving the backup route.
5. Terminate and relaunch only the manifest-owned PID, then load with Cmd-O or
   the command guide.
6. Verify paused state, cleared Undo, exact strategy/phase/resolution/terminal
   analytics, recovery feedback, file inventory, and manifest-bound digests.

Fixtures are deterministic evidence setup. They support renderer, HUD, and
quality investigation of the same production story moments, but they never
replace the independent, no-coaching PLAY-052 critical journey or prove that a
player can discover and complete that journey.
