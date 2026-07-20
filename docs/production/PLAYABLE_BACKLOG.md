# CitySim Playable Backlog

This is the authoritative first-wave task source. The shared target is one coherent 20-minute journey: diagnose pressure, choose, observe consequences, recover, reach an outcome, save, and resume.

### [x] PLAY-001: Establish the native playable baseline

- **Player outcome:** A readable top-down city, rich command-center HUD, explicit modes, visible placement truth, keyboard-accessible global commands, and retained proof.
- **Owning lane:** Integration.
- **Dependencies:** None.
- **Scope:** Native world/HUD/input slice, tests, audit records, plans, and proof.
- **Acceptance:** Full tests, staged build/launch, live inspection, compact/default proof, and truthful residual risks.
- **Commits:** `cb30157`, `48bc2b5`.

### [x] PLAY-010: Create consequential early-game pressure

- **Player outcome:** Within two minutes the player understands a real treasury-demand-utilities-happiness-employment tradeoff; the session contains a warned recoverable squeeze, two viable strategies, and a meaningful Town Charter milestone.
- **Owning lane:** Gameplay loop.
- **Requirement IDs:** `SIM`, `ECO`, `POP`, `GOV`, `UX` first-wave rows.
- **Dependencies:** Accepted baseline; integration approval for durable objective, save, command, or snapshot contract changes.
- **In scope:** Starting scenario, economy/demand/service relationships, objective sequencing, recovery, milestone, causal analytics, deterministic scenarios.
- **Out of scope:** Renderer art, HUD composition, persistence format, package topology.
- **Acceptance:** First decision by 02:00; two distinct successful strategies; overextension is warned and recoverable; transient spikes cannot complete milestones; full tests plus a staged 20-minute journey and retained causal evidence.
- **Stop conditions:** Shared-model/save/store contract change without approval, non-deterministic outcome, or unrelated UI/rendering edits.
- **Accepted integration:** `6736c67666c1b4854e6a6f65eb7af292d161efb2`; completion record at `docs/production/completed/PLAY-010.gameplay-loop.md`.

### [x] PLAY-011: Make the city react to the player's strategy

- **Player outcome:** Commercial stewardship and industrial expansion produce different, readable city stories after the opening decision, including one authored opportunity, one warned setback, a recoverable response, and a clear next-stage payoff rather than a passive march to the Town Charter.
- **Owning lane:** Gameplay loop.
- **Requirement IDs:** `SIM`, `ECO`, `POP`, `GOV`, `ENV`, `UX` first-wave rows.
- **Dependencies:** Accepted PLAY-010; consumes existing `CityMessage`, objective, simulation, and analytics surfaces unless integration separately approves a smaller additive gameplay field.
- **In scope:** Deterministic strategy-sensitive incidents, causal consequences, recovery choices, post-choice pacing, analytics copy inputs, balance fixtures, and staged evidence.
- **Out of scope:** New UI components, renderer truth, persistence format, input commands, package/build scripts, general event framework.
- **Acceptance:** Two opening strategies diverge in at least three meaningful dimensions; each receives truthful advance warning, one setback, and at least two legitimate recovery responses; no random unavoidable failure; effects are visible through existing player surfaces; both remain viable but non-identical through the 20-minute horizon.
- **Live gate:** A fresh no-coaching pointer-and-keyboard route must reach the durable payoff inside 20 minutes including ordinary diagnosis and interaction time. An uninterrupted or coordinate-aware automated Day 701 fixture does not satisfy this gate. The binding utility, treasury, happiness, population, and qualification standards must be understandable early enough to act on.
- **Stop conditions:** New save/public-store/renderer contract, title-routed messages becoming domain authority, nondeterministic fixtures, or balance changes that invalidate the accepted PLAY-010 recovery path.

### [x] PLAY-020: Make consequences readable in the city

- **Player outcome:** Growth, construction, utility trouble, prosperity, pollution, selection, decline, and recovery are legible in the world without consulting only numbers.
- **Owning lane:** World rendering.
- **Requirement IDs:** `ART`, `UX`, `ENV`, `TEC` first-wave rows.
- **Dependencies:** Accepted baseline; approved simulation-to-renderer snapshot fields from PLAY-010/040.
- **In scope:** Renderer composition, truthful consequence states, representative neighborhood, camera/LOD behavior, renderer tests, telemetry, and visual proof.
- **Out of scope:** Inventing simulation truth, gameplay balance, HUD redesign, save schema.
- **Acceptance:** Named world states are visually distinct and non-color-only; default/compact/camera proof retained; stable deterministic variation; unchanged-pulse reuse preserved; performance budget and limitations recorded.
- **Stop conditions:** Renderer derives gameplay facts absent from snapshot, unapproved asset/license input, or regression beyond accepted render budgets.

### [x] PLAY-021: Deliver the golden-neighborhood visual breakthrough

- **Player outcome:** The staged game opens on an authored, visually dense miniature neighborhood that feels like a place worth growing, not a sparse procedural diagram on an empty grid.
- **Owning lane:** World rendering.
- **Requirement IDs:** `ART`, `UX`, `TEC` graphics vertical-slice rows.
- **Dependencies:** Integrated PLAY-020 renderer foundations; approved task brief at `docs/production/WORLD_RENDERING_RECOVERY_2026-07-19.md`.
- **In scope:** Terrain and connected-road art, complete residential/commercial/industrial/park/civic visual families, deterministic seeded variants, lot frontage and props, ambient truth-safe life, starting camera composition, camera LOD, world-only resources, renderer tests/telemetry, and real before/after proof.
- **Out of scope:** Gameplay balance, invented service/traffic/economy facts, HUD redesign, save schema, external unlicensed assets, broad engine replacement.
- **Acceptance:** The same real staged starting city is materially more compelling at default and 900 x 600; the primary visual language works without floating lifecycle labels; the golden 8 x 8 neighborhood is intentional at city/neighborhood/block detail; all road masks and five lot families are authored and distinct; empty-land repetition is broken up without implying false development; deterministic identity, accessibility, Reduce Motion, hit testing, incremental reuse, and performance remain sound; integration and PLAY-050 accept the visual delta from retained side-by-side evidence.
- **Stop conditions:** Improvement exists only in an off-window fixture, depends mainly on labels/recoloring/camera crop, fakes simulation truth, introduces unclear asset provenance, hides interaction state, or misses the live visual-acceptance gate.

### [x] PLAY-030: Complete the command and keyboard system

- **Player outcome:** Every non-spatial game action has one discoverable command, menu/shortcut route, contextual availability, accessible label, and consistent focus behavior.
- **Owning lane:** UI and input.
- **Requirement IDs:** `UX`, `AUD`, `TEC` first-wave rows.
- **Dependencies:** Accepted baseline; approved `CONTRACT-002`; PLAY-050 defect and journey inventory.
- **In scope:** Typed command registry, menus, shortcuts, command palette/help, focus rules, accessibility semantics, compact layout, UI/input tests and proof.
- **Out of scope:** Simulation rules, renderer truth, persistence architecture. Spatial grid navigation must be proposed separately if it changes interaction architecture.
- **Acceptance:** 100% inventory coverage for declared non-spatial actions; no collisions or focus traps; pointer and shortcut routes dispatch identical intents; default and 900 x 600 layouts remain usable; full tests and live keyboard evidence.
- **Stop conditions:** Duplicate command state, shortcut collision, inaccessible critical action, or shared-store change without approval.

### [x] PLAY-031: Quarantine onboarding input and restore the intended window

- **Player outcome:** A new player can read and dismiss onboarding without silently changing game state, opening another command surface, or beginning in a previously restored compact window.
- **Owning lane:** UI and input.
- **Requirement IDs:** `UX`, `AUD`, `REL`, `TEC` onboarding and keyboard acceptance rows.
- **Dependencies:** Integrated Wave 002 candidate `c70321b`; PLAY-050 defect `PLAY-050-D005`.
- **In scope:** One authoritative blocking-modal command policy, onboarding dismissal and focus, command/menu/renderer shortcut availability while blocked, default versus proof-compact window restoration, focused UI/input tests, and real staged evidence.
- **Out of scope:** Gameplay balance, renderer art, persistence schema, command inventory expansion, general window redesign.
- **Acceptance:** While onboarding is visible, Space, 1–3, build/mode keys, camera keys, global panels, and Command Guide cannot mutate or stack surfaces; only explicit onboarding dismissal/system-safe behavior works; dismissal restores the authored 1x start and stable focus; a normal fresh launch uses the intended default content size while `CITYSIM_COMPACT_WINDOW=1` alone produces the proof compact size; pointer and keyboard dismissal pass at default and 900 x 600; tests cover menu, store, renderer, focus, and modal leakage routes.
- **Validation/proof:** Focused command/onboarding/window tests; full native suite; staged fresh-start 0/10/30/60-second sequence; exact D005 shortcut sequence before dismissal; pointer and keyboard dismissal; default and compact captures; accessibility tree; `git diff --check`; script syntax; staged `--verify`.
- **Stop conditions:** A second modal authority, command-specific ad hoc guards, gameplay/store duplication, inability to prove default/compact separation, or any shortcut changing underlying state while onboarding blocks.

### [x] PLAY-040: Establish deterministic simulation and recovery contracts

- **Player outcome:** A city can be saved, resumed, replayed, diagnosed, and recovered without losing or silently changing authoritative state.
- **Owning lane:** Simulation platform.
- **Requirement IDs:** `SIM`, `TEC`, `REL` first-wave rows.
- **Dependencies:** Accepted baseline; PLAY-010 fixture/command sequence; approved `CONTRACT-003` and `CONTRACT-004`.
- **In scope:** Typed command boundary, deterministic checkpoints, hashes, atomic versioned saves, migration/recovery, immutable presentation snapshots, diagnostics, and focused performance evidence.
- **Out of scope:** Balance, renderer art, HUD redesign.
- **Acceptance:** Equivalent logical outcomes across speed settings; repeated fixture hashes; save/load/undo/recovery invariants; corrupt-write fallback preserving originals; measured vertical-slice budgets; full suite and retained fixtures.
- **Stop conditions:** Silent save incompatibility, gameplay balance invented by platform, shared contract without approval, or mature-city claims from slice-only evidence.

### [x] PLAY-050: Prove the playable-session gate

- **Player outcome:** Independent evidence proves or rejects a coherent 20-minute session across pointer, keyboard, compact, accessibility, save/resume, and recovery paths.
- **Owning lane:** Playtest quality.
- **Requirement IDs:** `UX`, `AUD`, `REL`, and cross-system acceptance rows.
- **Dependencies:** Accepted baseline; consumes PLAY-010 scenario, PLAY-020 visual states, PLAY-030 command inventory, and PLAY-040 fixture/save/hash contracts as they land.
- **In scope:** Golden fixture/manifest, journey records, confusion/dead-time ledger, strategy comparison, accessibility and compact checks, proof manifest, reproducible defects.
- **Out of scope:** Casual cross-lane product fixes; defects return to owners.
- **Acceptance:** Decision by 02:00; no blocking confusion over 30 seconds; no false feedback; pressure diagnosed within two minutes; recovery before minute 18; clear outcome and resume comprehension; every critical failure rejects the wave.
- **Stop conditions:** Missing authoritative fixture/contract, unretained visual proof, coaching required to pass, or contradictory player feedback.

### [ ] PLAY-012: Deliver a three-act playable session

- **Player outcome:** A fresh player reaches an opening fork, a strategy-specific complication, a recovery decision, and an unmistakable durable result within 20 minutes, with no unexplained wait longer than 30 seconds.
- **Owning lane:** Gameplay loop.
- **Dependencies:** Accepted Wave 002 baseline `74b694d`; consume PLAY-041 truth after integration approval.
- **In scope:** Deterministic pacing, authored strategy decisions, incidents, recovery, balance, objectives/messages through approved surfaces, gameplay fixtures, and live causal proof.
- **Out of scope:** Renderer art, UI composition, input architecture, save schema, and unapproved shared contracts.
- **Acceptance:** First meaningful decision by 02:00; at least three consequential decisions; feedback within 15 seconds of relevant simulation time; commercial and industrial stories remain viable and mechanically distinct; recovery before minute 18; focused/full tests plus a staged no-coaching session.
- **Stop conditions:** Passive fixture-only success, nondeterminism, renderer/UI edits, or a shared contract change without approval.

### [x] PLAY-041: Publish spatial consequence truth

- **Player outcome:** Location-specific service, pollution, prosperity/strain, recovery, and event identity are deterministic, inspectable, persistent where required, and safe for renderer/UI consumption.
- **Owning lane:** Simulation platform.
- **Dependencies:** Accepted Wave 002 baseline `74b694d`; integration approval before any public contract change.
- **In scope:** Smallest presentation contract proposal, deterministic derivation, replay/save/load/undo/fingerprint consequences, diagnostics, performance budgets, and contract tests.
- **Out of scope:** Gameplay balance, renderer art, HUD layout, and invented player-facing copy.
- **Acceptance:** One authoritative spatial truth source; stable identity; exact undo/replay/save behavior; frozen fixtures and performance evidence; documented compatibility and migration risk; integration-approved contract before consumers change.
- **Stop conditions:** Duplicate truth, implicit schema migration, renderer-oriented facts in persistence without need, or unapproved public surface changes.
- **Accepted integration:** `36774db97e5dd017f1a4c9ecd0a4c288dd09c387`; completion record at `docs/production/completed/PLAY-041.simulation-platform.md`.

### [ ] PLAY-022: Make strategy reshape the living city

- **Player outcome:** Commercial and industrial strategies visibly create different cities, and utility trouble, pollution, prosperity, decline, construction, and recovery are legible in the live world without reading the HUD alone.
- **Owning lane:** World rendering.
- **Dependencies:** Accepted PLAY-021; approved and integrated PLAY-041 truth for factual consequence states.
- **In scope:** Authored architecture/environment families, density progression, consequence layers, bounded ambient life, LOD/reuse/performance, accessibility, and live default/compact visual proof.
- **Out of scope:** Inventing simulation facts, gameplay balance, HUD redesign, save schema, and fixture-only visual claims.
- **Acceptance:** First pass the independently reviewed golden-block gate in `PLAY-022_VISUAL_RECOVERY_DIRECTIVE.md`; then the same live city shows strategy and three-act state changes non-color-only at city/neighborhood/block scales. Both integration and playtest must score the exact staged candidate at least 17/20 with no category below 3/4. Retain stable deterministic identity, truthful feedback, bounded performance, and uncropped same-seed before/after evidence.
- **Stop conditions:** A mostly empty developed frame, disconnected road language, inconsistent projection/scale/light, debug-like indicator clutter, cosmetic recolor or asset-count delivery, author self-acceptance, off-window-only proof, false simulation implications, unclear asset provenance, or regression in hit testing/reuse/accessibility.

### [ ] PLAY-032: Turn diagnosis into direct action

- **Player outcome:** Important warnings reveal cause, consequence, and legitimate remedies, and keyboard-only players can navigate and act spatially without falling out of the governed command system.
- **Owning lane:** UI and input.
- **Dependencies:** Accepted PLAY-031; approved PLAY-041 truth; integration approval for shared commands/store/input contracts.
- **In scope:** Diagnosis-to-remedy journeys, direct actions, keyboard world navigation, focus/accessibility, compact arbitration, command metadata, tests, and staged proof.
- **Out of scope:** Simulation rules, renderer truth, save schema, and duplicate command state.
- **Acceptance:** Every critical warning has truthful cause/consequence/remedy routes; pointer and keyboard dispatch the same intent; spatial focus is visible and stable; no shortcut collisions or modal leakage; default/compact/Full Keyboard Access/VoiceOver journeys pass live.
- **Stop conditions:** Ad hoc shortcuts, inaccessible critical action, duplicated domain truth, broken map dominance, or unapproved shared-store/input architecture.

### [ ] PLAY-051: Prove fun, comprehension, and replay value

- **Player outcome:** Independent evidence establishes whether the integrated build is understandable, consequential, recoverable, visually expressive, and worth replaying differently.
- **Owning lane:** Playtest quality.
- **Dependencies:** Exact integrated PLAY-012/041/022/032 candidate; isolated staged-app identity.
- **In scope:** Frozen rubric/harness, pointer and keyboard journeys, decision/dead-time/consequence ledgers, strategy comparison, visual storytelling, accessibility, compact, persistence/recovery, defects, and retained proof.
- **Out of scope:** Casual product fixes, coaching, candidate substitution, and acceptance based on tests alone.
- **Acceptance:** Complete no-coaching 20-minute routes; first decision by 02:00; no unexplained dead time over 30 seconds; consequence latency at most 15 seconds of relevant simulation time; three meaningful decisions; recovery before minute 18; distinct viable strategies; save/resume trust; explicit replay desire; any critical defect rejects the wave.
- **Stop conditions:** Missing exact candidate identity, coached success, unretained proof, false feedback, or contradictory evidence.
