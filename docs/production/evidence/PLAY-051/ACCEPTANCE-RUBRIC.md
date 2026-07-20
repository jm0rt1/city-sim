# PLAY-051 Frozen Independent Acceptance Rubric

**Frozen against:** accepted baseline `cbcc6fd2b23cb08fc0b937ae1f236c630d499474`

**Authority:** `docs/production/WAVE-003-MAKE-IT-A-GAME.md` and the PLAY-051 claim

**Disposition owner:** integration. Quality classifies evidence as passed, failed, partial, not reproduced, or blocked; it does not advance requirements.

This rubric is frozen before an integrated PLAY-012/041/022/032 candidate is supplied. It must not be relaxed or rewritten after observing a candidate. A correction may only clarify an ambiguity, must be committed before the affected run, and may not convert a failure into a pass retroactively.

## Candidate and tester contract

- Test only an exact full commit supplied by integration after PLAY-012, PLAY-041, PLAY-022, and PLAY-032 adoption.
- Use the staged bundle produced by `./script/build_and_run.sh --verify`, never `.build/debug/CitySimNative` or a fixture-only renderer.
- Freeze full commit, bundle identifier, preference domain, executable hash, `Info.plist` hash, data root, PID, fixture/seed, window size, input mode, accessibility settings, and start digest before starting a timer.
- Use a fresh isolated data root for each route. Never read or write the production Application Support save.
- Allowed player knowledge: only labels, hints, visible state, standard macOS conventions, and the in-app command guide. No source knowledge, hidden coordinates, fixture commands, console state, author instructions, or coaching.
- The tester may record observations but may not suggest the next action. A coached route is invalid and must be rerun from a fresh root.

## Frozen routes

| Route | Strategy | Input | Window/accessibility | Required scope |
| --- | --- | --- | --- | --- |
| P-COM | Commercial | Pointer only after launch | Default window, default motion | Fresh start through durable payoff, save/leave/resume, undo |
| K-IND | Industrial | Keyboard only after launch | Exactly 900 × 600, default motion | Fresh start through durable payoff, save/leave/resume, undo |
| FKA | Strategy chosen by tester without coaching | Full Keyboard Access only | 900 × 600 | Welcome, diagnosis, map navigation, placement, warning remedy, panels, save/load, undo, cancellation |
| VO | Opposite of FKA where possible | VoiceOver plus keyboard | Default window | Read current pressure, costs, selected location, consequence, warning cause/remedies, progression, save/recovery feedback |
| CORRUPT | Continue either completed isolated route | Same input as source route | Source route size | Preserve invalid primary, recover known-good backup, explain recovery, save again |

P-COM and K-IND are separate complete no-coaching sessions. FKA and VO may be shorter critical-path sessions but cannot borrow success from P-COM or K-IND. CORRUPT operates only on a copied isolated route root after its normal save/resume evidence is sealed.

## Operational definitions

- **Session zero:** welcome is explicitly dismissed and control reaches the map. Keep launch-to-dismiss time separately; the first-decision clock starts at session zero.
- **Meaningful decision:** a player-initiated build, zone, demolition, or policy commitment that spends resources or changes authoritative city rules and yields a measurable consequence. Opening a panel, selecting a tile, camera movement, changing speed, saving, or undoing solely for the persistence check does not count.
- **Readable consequence:** the player can identify what changed and why from both an authoritative numerical/UI signal and the corresponding live world signal. A toast alone, title routing, animation with no causal explanation, or test-only state does not qualify.
- **Dead time:** contiguous wall time in which the player has no new actionable prompt or consequence and is searching, waiting, or repeating ineffective actions. Deliberate pause for evidence capture is logged separately and excluded only when the simulation is visibly paused. Unlogged exclusions fail the timing claim.
- **Recovery:** a meaningful decision responding to the observed complication, followed by truthful improvement in the implicated authoritative metric and world condition. Undoing the setback or loading an earlier save is not gameplay recovery.
- **Durable payoff:** the real session presents the promised success/failure milestone and it survives save, process stop, relaunch, and load.

## Hard acceptance gates

| ID | Criterion | Pass rule | Automatic failure |
| --- | --- | --- | --- |
| G01 | Exact isolated candidate | Every manifest identity is complete and internally consistent; the exact PID resolves to the staged executable; two-candidate isolation passes | Ambiguous commit/process/root, production state touched, identity collision, candidate changes mid-run |
| G02 | Pointer route | P-COM completes without keyboard gameplay commands or coaching | Hidden coordinate/source knowledge, keyboard substitution, critical pointer path unavailable |
| G03 | Keyboard route | K-IND completes after launch without pointer input; focus and map navigation remain visible and deterministic | Pointer rescue, focus trap, shortcut leakage/double action, undiscoverable spatial target |
| G04 | First meaningful decision | First qualifying decision is committed by `02:00.000` after session zero in both full routes | Either route exceeds two minutes or timestamp provenance is missing |
| G05 | Dead time | Every interval is logged; no unexplained interval exceeds `00:30.000` | Any unexplained interval over 30 seconds, including passive authored waiting |
| G06 | Consequence latency | Every material decision is logged; first truthful UI signal and first truthful world signal each appear within 15.000 seconds of relevant unpaused simulation time | Missing signal, stale/contradictory signal, either latency over 15 seconds |
| G07 | Decision count | Each full route contains at least three distinct meaningful decisions before payoff: opening commitment, complication response/preemption, and recovery/follow-through | Repeated equivalent clicks, save/undo, or navigation counted as decisions |
| G08 | Recovery timing | A recoverable setback is diagnosed, a legitimate counterplay decision is committed, and the recovery signal is visible by `18:00.000` | Only reload/undo recovers; remedy is unaffordable or undiscoverable; signal occurs after minute 18 |
| G09 | Strategy viability/distinction | Both full routes reach a non-failed durable payoff within 20 minutes; comparison shows at least three mechanically distinct outcomes and two non-color-only world distinctions attributable to accepted truth | One route dominates, stalls, fails, or differs only by copy/color |
| G10 | World/UI truth agreement | For each utility, pollution, vitality/strain, and recovery sample, map location/band/direction agrees with HUD/inspector cause, consequence, remedy, and authoritative snapshot | Renderer/UI inference contradicts spatial-v1 truth, false affected location, stale recovery, decorative claim |
| G11 | Default and compact | Required HUD, map, objective, warning, remedy, selected state, costs, and command access remain readable and operable at default and exactly 900 × 600 | Clipping/overlap hides a critical action or map ceases to dominate |
| G12 | Full Keyboard Access | FKA critical route completes with visible focus, deterministic order, no trap, safe Escape, and no pointer rescue | Missing focus, inaccessible map/action, modal leakage, destructive surprise |
| G13 | VoiceOver | VO exposes names, roles, values, state, costs, cause/remedy, selection, progression, and save/recovery result in logical order without color-only dependence | Critical state silent, misleading announcement, inaccessible action |
| G14 | Save/load/undo | Each full route saves, stops its exact process, relaunches through the verified launcher, loads paused to the exact digest, and exact undo restores the pre-action digest and visible state | State/digest drift, auto-running load, partial undo, another root/process touched |
| G15 | Corruption recovery | Isolated invalid primary is preserved, known-good backup loads with explicit recovery feedback, a new save succeeds, and all artifacts remain inside the route root | Silent reset, invalid file overwritten/lost, production path touched |
| G16 | Replay desire | After both routes, tester answers privately before debrief: `Would you immediately replay? Why, and what would you choose differently?` Pass requires yes plus a specific alternative decision motivated by observed tradeoffs | Generic praise, no concrete alternative, replay motivated only by testing unfinished coverage |

Any G01–G16 failure rejects Wave 003 acceptance. A blocked live or accessibility surface is not a pass. Automated and deterministic evidence may localize a defect but cannot waive a live gate.

## Evidence required per full route

- Candidate manifest and pre/post Git state.
- Continuous wall-clock session record with timezone, session zero, end, pauses, and process lifetime.
- `session-ledger.csv` with every decision, consequence, dead-time interval, confusion, ineffective action, diagnosis, recovery, and payoff.
- Before/after screenshots for opening choice, each consequence, complication diagnosis, recovery, payoff, save, and resumed exact state.
- Map and UI capture of the same spatial truth samples.
- Start, pre-decision, post-decision, pre-save, loaded, pre-undo, and post-undo fingerprints.
- Exact data-root inventory with sizes and SHA-256 hashes.
- Route disposition table for G01–G16 and reproducible defect records for every failure.

## Stop conditions

Stop and classify blocked before the player timer if candidate identity is incomplete, isolation fails, the wrong bundle appears, production data could be touched, Computer Use is unresponsive, required accessibility permissions are unavailable, or the exact candidate is not frozen. Stop and classify failed during a route on coaching, hidden-state use, input substitution, or candidate mutation. Preserve all evidence up to the stop; do not repair product defects in this lane.
