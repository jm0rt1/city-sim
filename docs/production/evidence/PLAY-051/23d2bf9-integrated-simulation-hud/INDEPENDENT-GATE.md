# PLAY-051 integrated simulation/HUD gate — REJECTED

Date: 2026-07-21

Quality lane: `codex/citysim-playtest-quality`

Scope: PLAY-013 + PLAY-033 + PLAY-042 only

World-rendering status: excluded from this score; PLAY-022 remains independently rejected.

## Exact candidate identity

- Product commit: `23d2bf972834b11be82f763d156d111f8ff76bc4`
- Staged bundle: `/Users/James/Library/Mobile Documents/com~apple~CloudDocs/James's Files/Programming/Python/city-sim/dist/CitySim.app`
- Executable SHA-256: `e6b2d8e8a9650ac8c7a6d2f873be40edfb7417e104eff33ed28e32bc49002d02`
- Manifest: `/Users/James/Library/Mobile Documents/com~apple~CloudDocs/James's Files/Programming/Python/city-sim/dist/manifests/master.manifest`
- Manifest SHA-256: `ebbf3cf88a2223e9e850e96dc2404cf07b746ee4737abae326c0a13440699f7f`
- Manifest identity: `branch=master`, exact product commit, `candidate_id=master`, `bundle_identifier=com.jfmortensen.citysim`, `data_root=production-default`, exact staged bundle and executable paths.
- Supplied initial process: PID `60007`; exact executable path verified before interaction; settled RSS observed at `930720 KiB`.
- Fresh default process: PID `62943`; exact executable path; fresh onboarding preference only; initial RSS `741056 KiB`.
- Exact compact process: PID `80741`; exact executable path; environment contained only `CITYSIM_COMPACT_WINDOW=1` as the test-mode change and no data-root override; RSS `665248 KiB`.
- Compact window: position `450,160`, size `900x652`, which is the requested `900x600` content area plus macOS window chrome.
- All three supplied/launched exact-candidate PIDs (`60007`, `62943`, `80741`) were terminated explicitly. A separate lane bundle process under this quality worktree was observed and left untouched.
- Integrated validation supplied by integration: `130/130` tests and staged verify green. The suite was not rerun because this gate explicitly required use of the already-running exact bundle without rebuild or substitution.

## Journey and positive findings

1. Reset only the production welcome preference, launched the same exact bundle, and observed the Welcome surface on a fresh Day 1 city.
2. Space was quarantined while Welcome was visible. Return dismissed Welcome by keyboard; the compact rerun dismissed it by pointer. Gameplay commands worked immediately afterward.
3. The Day 1 journal explained the Commercial versus Industrial growth-engine tradeoff. The player chose Commercial from the notice action, selected a valid open block, and committed it through a real placement.
4. At the next daily boundary, `Choose a Growth Engine` retired and the journal changed to `Main Street Crossroads`: Commercial stewardship was committed and the next decision was tax relief or a second park before Day 23.
5. The saved schema-1 file independently retained the authoritative progression payload: `committedStrategy=commercialStewardship`, `currentPhase=opportunity`, `nextScheduledTick=88`, `townCharterAwarded=false`.
6. `PAUSED`, running 2x, pause, and resume-to-2x were unmistakable in AX values and HUD state.
7. Pointer invalid placement passed its local requirement: after `5.765 s`, the exact reason remained `Demolish the existing structure before building here. Commercial remains selected — choose another block.` The selected Commercial tool and block 15,14 did not move. A valid Commercial placement had already demonstrated recovery.
8. `tax` search returned `Open Tax Policy and Finances`, advertised shortcut `⌥2`, and reported `Available`.
9. Compact visual layout preserved approximately 61% unobscured map occupancy using a conservative screenshot-area estimate after subtracting the top HUD, Objectives, and Command Center overlays; opening Command Center details collapsed the expanded objectives body while retaining the top objective summary. A pointer-selected open block exposed Road, Homes, and Open build catalog actions in the details panel.

## Blocking findings

### P1 — keyboard invalid placement has no durable rejection feedback

Owner: PLAY-033 UI/input.

Reproduction:

1. Dismiss Welcome, use the journal action to select Commercial, and establish map focus.
2. Select occupied block 15,14. AX reports the primary action unavailable with `Demolish the existing structure before building here.`
3. Press Return and wait at least four seconds.

Observed: after `5.781 s`, no `Action blocked` surface appeared and the AX tree did not change. The tool and selection stayed put, but the player received no durable accepted reason. Clicking an occupied tile with the pointer immediately produced the correct persistent message, proving a pointer/keyboard policy split.

Acceptance: pointer and keyboard invocation of the same unavailable spatial action must both retain the same accepted reason for at least four seconds, keep the tool selected, preserve selection, and offer an obvious valid-action recovery.

### P1 — required command-search vocabulary and activation are incomplete

Owner: PLAY-033 UI/input.

Reproduction:

1. Open Command Guide and search `tax`: one available Tax Policy result appears.
2. Search `budget`, then `storefront`.
3. Return to `tax`, focus the result with Tab, and invoke it by Return, Space, or AX click.

Observed: `budget` and `storefront` returned no results. The focused available Tax Policy result did not activate by Return, Space, or AX click during the live run. The advertised `⌥2` command was quarantined while the guide was topmost, as expected, but did not establish a successful Tax Policy route after the guide closed.

Acceptance: all three governed queries must expose a truthful relevant route; the available Tax Policy result must execute by pointer and keyboard and land on the Finance/Tax Policy surface.

### P1 — same-candidate save cannot be loaded after relaunch

Owner: PLAY-042 gameplay/persistence integration. This is not routed to simulation-platform absent evidence of a deterministic snapshot or shared persistence-contract fault.

Reproduction:

1. Commit Commercial stewardship and advance through its next daily boundary.
2. Save with Cmd-S; observe `City saved`.
3. Verify `/Users/James/Library/Application Support/CitySimNative/quicksave.json` exists.
4. Terminate the exact PID and relaunch the same exact bundle with only `CITYSIM_COMPACT_WINDOW=1` added; do not override the production data root.
5. Dismiss Welcome and press Cmd-O.

Observed: the app reported `No valid save was found`. The primary file remained present at `131197` bytes with SHA-256 `e79dc93eb6e5a806711599de39134aaf8acdbbb8eb28fadeee1ce172f3095186`; its schema-1 progression fields were readable and contained the committed strategy. The backup SHA-256 was `f9890b1c954256358ba9dc97f6858db34f0bbd424dafaedf82de75ba655aac3a`.

Acceptance: a save produced by this exact candidate must reload in the same exact candidate after process restart, preserve the strategy/phase/next-action values, restore a paused state, and not emit recovery/failure feedback for a valid primary.

### P1 — compact map loses keyboard/AX spatial parity

Owner: PLAY-033 UI/input.

Reproduction:

1. Launch the exact bundle with `CITYSIM_COMPACT_WINDOW=1` and dismiss Welcome.
2. Inspect the AX tree at the exact compact size.
3. Pointer-select open block 12,8; verify its actions appear.
4. Focus the map and press Right, then re-enter Inspect mode and press Right again.

Observed: the compact world exposed only a generic `SKView`, not the default-mode `City map` element with selected-block value/help/primary action. Pointer selection worked and details showed Road, Homes, and Open build catalog, but Right did not move the selected target or update AX. This prevents keyboard/AX parity for the selected-tile inspector-to-action loop.

Acceptance: compact must expose the same semantic City map element as default, retain focused selection, move it with arrow keys, and keep selected target/actions reachable without pointer dependence.

### P1 — Escape does not close the compact Objectives surface

Owner: PLAY-033 UI/input.

Reproduction:

1. In exact compact mode, clear transient action feedback.
2. Open Objectives and verify the `MAYOR'S MANDATE` body is present.
3. Press Escape.

Observed: no AX or visual state changed; Objectives remained open. With Objectives and Command Center details both open, the first Escape closed Command Center details, but the next Escape still did not close Objectives.

Acceptance: Escape must close only the topmost governed surface on each invocation: Command Center details first, then Objectives, without cancelling an unrelated underlying action.

## Disposition

**REJECTED.** PLAY-013's live strategy commitment and next-action transition worked before persistence, but PLAY-042 cannot preserve that result through the required save/relaunch/load path. PLAY-033 is independently blocked by keyboard rejection feedback, governed command search/activation, compact spatial accessibility, and Escape precedence. No rendering observation affected this disposition.

## Evidence inventory

| Evidence | SHA-256 | Purpose |
|---|---|---|
| `live/01-default-welcome.jpeg` | `b65c471ee19fe5c9b26662b6c187990a932447b24be0f644e00989ebe95668bf` | Exact fresh Welcome surface |
| `live/04-default-search-storefront-no-result.jpeg` | `cecdff7d655ebc7d88844639bf426cab4c0814a0f3a01d952f905a2537bafd78` | Required search term returning no command |
| `live/05-default-keyboard-rejection-after-5s.jpeg` | `5177c7edc56cca384d09aa593fed2c8c474e9de3d37b407b71c2b8be3d5e10f0` | Silent keyboard rejection after governed duration |
| `live/06-default-pointer-rejection-after-5s.jpeg` | `fb98c3b2c8e7d52684a2e45f5bb76dec00fc654dd977a3e2e6ee54effea5f07c` | Correct durable pointer rejection control |
| `live/07-compact-pointer-dismissed.jpeg` | `3321d7ccc5cd1014ddabcd31bb8e5172db47b08db9302bed58fa3f88f8e5b7ff` | Compact pointer dismissal and live layout |
| `live/08-compact-objectives-command-center.jpeg` | `c5e4cc2906747ebdc9f00a07a0a9185967f158aa1a83ae270a7e3acd34c8b80b` | Exact compact surfaces and map occupancy |
| `live/09-compact-selected-actions.jpeg` | `b566e1ea73c5d2b314aafc5811414dfe547b44c552d2b9f05260ed1820915428` | Compact selected-target/action attempt |
| `live/ax-and-state-capture.txt` | `f3fbdaa32913fa3dec674e3fb3b92d035060e16ee77706439f0e32c372f10a68` | Exact AX excerpts, timings, progression payload, hashes, viewport, and occupancy calculation |

## Limitations

- The candidate failed multiple critical governed paths, so the gate did not extend into unrelated world-rendering assessment or additional polish exploration.
- AX was inspected through the live macOS accessibility tree used by Computer Use; VoiceOver speech output was not separately recorded after the compact map exposed only generic `SKView` semantics.
- The running local master checkout advanced after this bundle was staged. Candidate identity is therefore established by the frozen bundle executable hash and manifest, not by the checkout's later HEAD.
