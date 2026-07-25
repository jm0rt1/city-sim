# PLAY-053 Final Independent Disposition — REJECTED

- **Exact published integration candidate:** `91438bfe305e66e6f40450c88e8fc346e94e8f4d`
- **Quality merge HEAD before evidence:** `c544e2b1081670d6cf4144cf57d19eb068f40a21`
- **Frozen preregistration:** `50cbb94d76589405d40972fd05e762534e591380`
- **World product / evidence / completion:** `a1e589e68783e25dc5788b055b3b9e786acb4b69` / `9791621c7f3a8109500d2c8567e7b2db8fa4d9b7` / `002ed20a5419ffcdaee7adb8e7e329bff781f786`
- **HUD product / evidence / completion:** `f8f800656cf1cefb87aa5cdca231fa31bef6d860` / `a895568cbf618830e587d1675be72702669c9af1` / `b497f1d78040ef186a77eebbbb2cc5b640bd13d1`
- **Gameplay / platform completions:** `f84c1bfd73d8aa01badef4064cb1b1b84a826bbe` / `01511e6d61b1a00bbc67d6121b9a48dda6face26`
- **Disposition:** **REJECTED**
- **Owning return lane:** world rendering (`PLAY-024`)
- **Product changes:** none

The exact candidate improves HUD hierarchy, compact aperture, road topology,
and authored fresh-start composition. It does not meet the preregistered
excellence bar because the current authoritative industrial-strain route
still renders a mostly empty green board around a small central cluster and
exposes conspicuous macro-terrain boundaries. Those are binding automatic
rejects. Product interaction stopped when the rejects were retained.

## Exact released identity

| Surface | Verified value |
|---|---|
| Main checkout | clean `master` at `91438bfe305e66e6f40450c88e8fc346e94e8f4d` |
| Bundle | `/Users/James/Library/Mobile Documents/com~apple~CloudDocs/James's Files/Programming/Python/city-sim/dist/CitySim.app` |
| Executable | `CitySim.app/Contents/MacOS/CitySimNative` |
| Staging manifest | `dist/manifests/master.manifest` |
| Manifest SHA-256 | `14d9915e855576ae0b64b2cc2eb393e49b74d03ce5058f90eb5a79134afa8df6` |
| Executable SHA-256 | `04b4a1e699e6b052d621fac714769ab761bbc0faace3fb0a2d723fbe2fbbc47d` |
| Candidate / token | `master` / `production` |
| Bundle id / preferences | `com.jfmortensen.citysim` / `com.jfmortensen.citysim` |
| Generated-v4 manifest | `ee1fa5c6d8d83d0f3e559ea4e6b0d30d4d90fe576f0347dac60d291fd661ae72` |
| Atlas manifest | `411934e492a66216787f8c93dd91d3f68cc16637110dba9ed7186b22dda96d3d` |
| City/neighborhood/block pages | `21d05fe9...` / `8d2094b3...` / `294722ac...`, `ff83db21...` |

No native product path differs between the quality merge and `91438bf`.
Every route used a separate root under
`/private/tmp/citysim-play053-final`. The exact released executable was the
sole process at its path for each route:

| Route | PID |
|---|---:|
| Comparison A default | `78088` |
| Comparison A compact | `78850` |
| Comparison B default | `79745` |
| Comparison B compact | `82575` |
| Reduce Motion fresh start | `83872` |
| Reduce Motion recovery | `84961` |
| Current industrial strain | `85596` |

All seven PIDs were terminated explicitly. Final process inspection retained
the separately owned UI and simulation-platform PIDs and found no production
candidate process.

## Independent automated validation

The first ordinary invocation did not reach tests because the sandbox blocked
the home module cache. A writable-cache invocation built successfully but its
sandboxed `xctest` process terminated with signal 11 after four passing tests.
One authoritative unsandboxed retry then completed:

- `swift test --disable-sandbox --package-path Native/CitySimNative`
- **199 tests passed, 0 failed**
- XCTest time: **84.897 seconds**
- `WorldRenderingTests`: **41/41** in **13.243 seconds**
- cold renderer: `3.630 ms` world update, `4.902 ms` total, zero decode loads
- unchanged-pulse soak: `0.0006 ms` average with stable node identity
- active-plus-adjacent residency: `10,485,760` bytes city and `33,554,432`
  bytes block
- fallback count: zero

The released bundle was hashed before launch and was not rebuilt or altered.
Integration's `build_and_run.sh --verify` result is corroboration, not a
substitute bundle.

## Comparison A — same-state presentation

The candidate loaded the exact frozen Wave 005
`industrial-complication-v1` bytes:

- fixture SHA-256:
  `660ed6a93c54b7e853e4fc6e9388e29d048b5bdbaefdd5cde066ca5be0dc05f1`;
- tick/day/status: `128` / `33` / `playing`, loaded paused;
- state digest:
  `37c1cf4e620c8af5741fd9f4b4acfa9b7976d49f6149ec88475ac2b260f1529e`;
- spatial digest:
  `de611c63c11a2c2004e329b5dccc9d60193ceb547895f79c4bcf9992bef1bd90`;
- City layer, no selection, deterministic `0` frame.

Default and exact 900 x 600 compact frames are materially preferred to the
frozen baseline for HUD hierarchy and map aperture. The top priority is
integrated into the status ribbon and the lower command wall is shorter.
Compact retains an approximately 58% closed map band and approximately 52%
with Objectives plus Command Center open. Three keyboard LOD cycles preserve
state and focus.

Comparison A therefore passes explicit material preference, but it does not
override the route-level automatic rejects below.

## Comparison B — authored fresh start

Command-N, immediate Space, and `0` produced authentic paused Day 1 starts in
default and exact compact:

- treasury `$32,000`, cashflow `-$90 / cycle`;
- residents `300`, jobs filled `190`;
- power spare `54` default / `55` compact, water spare `48`;
- two strategy routes announced;
- 32 authoritative road cells;
- eight occupied lots;
- state envelope SHA-256:
  `3ba7b8f35be032039653268faafb7a4c174a64485ed692446d9ec190a80a6a3d`;
- envelope digest:
  `be37ccc1d475fb01422c894f6c318328efc1b37be1431c21c1f5e5ab8e9bcfd9`;
- runtime seed: `6949471600526859443`.

The two-block loop and multiple road-adjacent directions are materially
preferred to the old cross for composition and player choice. This is
truthfully classified as topology/gameplay improvement, not same-state art
improvement.

## Hands-on interaction and accessibility

Passed:

- default and exact 900 x 600 compact, uncropped decorated windows;
- keyboard selection of City Hall at `12,12` with detailed semantic AX truth;
- occupied Residential rejection at `12,12`, with exact reason, tool, and
  selection retained beyond 4 seconds;
- valid Residential preview at `15,11`;
- Return construction at `15,11`, exactly once;
- AX secondary-action construction at `15,11`, exactly once;
- construction at zero percent remained semantically distinct;
- Undo restored the pre-build save byte-for-byte:
  `3ba7b8f...` before and after;
- semantic map click selected the announced center coordinate `13,13`;
- Tab moved from map to the city-identity control and Shift-Tab restored map
  focus;
- command guide opened with Command-/; `tax` returned exactly one available
  Tax Policy route;
- typing `b` in command search changed the text to `taxb` and did not activate
  Bulldoze;
- compact Escape closed Command Center first, Objectives second, then restored
  map focus;
- Objectives plus Command Center remained scrollable with a 311-point live
  map band;
- normal pollution overlay exposed equivalent AX state and a non-color legend;
- Reduce Motion retained the authentic fresh start and current industrial
  recovery state without loss of AX meaning.

Computer Use coordinate-click attempts returned
`Computer Use server error -10005: noWindowsAvailable`. AX-element pointer
click remained operational and independently selected `13,13`; the full suite
also passed pointer/keyboard/AX one-target tests. A coordinate-specific valid
pointer commit was not substituted or claimed.

## Performance

| Route | Settled RSS | Observation |
|---|---:|---|
| Comparison A default after three LOD cycles | `159,184 KiB` | 1m32s elapsed |
| Comparison B default | `147,248 KiB` | 3m42s elapsed |
| Comparison B exact compact after three LOD cycles | `157,840 KiB` | 1m15s elapsed |

All are below the preregistered `333.8 MiB` ceiling with no observed
continuing high-water growth. Automated residency, cold/update/total-render,
unchanged-pulse, overlap, contact, and fallback assertions passed.

## Independent score

| Category | Score | Reason |
|---|---:|---|
| 1. Composition and map occupancy | **2/4** | Fresh start improves, but the current industrial-strain `0` frame is a small central cluster inside a mostly empty loop and dominant green board. This category required 4. |
| 2. Projection/material/light/street coherence | **2/4** | Roads and curbs are more coherent, but long dark boundaries between macro-terrain cells remain conspicuous and the flat terrain/public realm does not match building fidelity. This category required 4. |
| 3. LOD usefulness, depth, variety, and life | **3/4** | Three stops remain usable and stable, but city/neighborhood primarily reduce the same repeated silhouettes rather than adding enough strategic district meaning. |
| 4. State, consequence, and interaction clarity | **3/4** | Selection, rejection, construction, recovery, and AX truth are strong; pollution marks visibly cover much of several building silhouettes. |
| 5. Shipping credibility, HUD, accessibility, performance | **4/4** | Compact hierarchy, focus, commands, tests, deterministic identity, RSS, residency, and renderer budgets pass. |
| **Total** | **14/20** | Required total was 19/20. |

## Automatic rejects

Triggered:

- **Mostly empty city frame / dominant green board:** the exact current
  industrial-complication state at default, loaded paused and framed with
  `0`, leaves the developed buildings as a small center cluster inside large
  empty road and green regions.
- **Visible seams / mixed fidelity:** long dark macro-terrain boundaries
  remain visible through default and compact; high-detail buildings and
  roads sit on broad low-detail polygonal green fields.

Not triggered in the executed routes:

- candidate, bundle, state, camera-command, layer, selection, window, or PID
  substitution;
- cropped or harness-only quality proof;
- changed starter topology mislabeled as same-state presentation;
- decorative road or occupied parcel outside authoritative state;
- accidental road ends (visible ends use deliberate curved termini);
- floating foundation or building/road overlap;
- HUD obscuring the active selected target;
- pointer/keyboard/AX coordinate contradiction;
- Reduce Motion information loss;
- fallback, hash, memory, residency, or frame-budget regression.

The pollution overlay's large X/bolt/check marks materially reduce clarity,
but quality records them as category-4 loss rather than a separate
debug-glyph automatic reject because they carry a documented non-color legend.

## Reproducible blocking defect

1. Launch exact executable SHA `04b4a1e...` with a fresh isolated root.
2. Place current
   `story-industrial-complication-v1.json` in that root as `quicksave.json`
   (file SHA `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`;
   envelope digest `a43611573cd888edba5292b9740b8a4e15f05e9cfd50edf73648427eaf775c5a`).
3. Launch default, press Command-O, then `0`.
4. Observe Day 33 paused with no selection and the City layer.
5. Compare the uncropped frame to the required connected, inhabited,
   world-first strain presentation.

Expected: the active city and its pressured district remain the dominant,
coherent composition without visible terrain seams.

Actual: a small building cluster is surrounded by a large empty road loop and
green board, with long dark boundaries between terrain cells.

Severity: **P1 Wave gate blocker**. Owner: **world rendering / PLAY-024**.

## Stop and limitations

The gate stopped at the first binding visual automatic reject, as directed.
Consequently, quality did not extend the session into a second normal-motion
recovery capture, a second physical coordinate-pointer commit, or an
additional candidate rebuild. Those omissions cannot turn this rejection into
approval. Product code, resources, build scripts, and the released bundle were
not changed.
