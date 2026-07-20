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

### [ ] PLAY-011: Make the city react to the player's strategy

- **Player outcome:** Commercial stewardship and industrial expansion produce different, readable city stories after the opening decision, including one authored opportunity, one warned setback, a recoverable response, and a clear next-stage payoff rather than a passive march to the Town Charter.
- **Owning lane:** Gameplay loop.
- **Requirement IDs:** `SIM`, `ECO`, `POP`, `GOV`, `ENV`, `UX` first-wave rows.
- **Dependencies:** Accepted PLAY-010; consumes existing `CityMessage`, objective, simulation, and analytics surfaces unless integration separately approves a smaller additive gameplay field.
- **In scope:** Deterministic strategy-sensitive incidents, causal consequences, recovery choices, post-choice pacing, analytics copy inputs, balance fixtures, and staged evidence.
- **Out of scope:** New UI components, renderer truth, persistence format, input commands, package/build scripts, general event framework.
- **Acceptance:** Two opening strategies diverge in at least three meaningful dimensions; each receives truthful advance warning, one setback, and at least two legitimate recovery responses; no random unavoidable failure; effects are visible through existing player surfaces; both remain viable but non-identical through the 20-minute horizon.
- **Live gate:** A fresh no-coaching pointer-and-keyboard route must reach the durable payoff inside 20 minutes including ordinary diagnosis and interaction time. An uninterrupted or coordinate-aware automated Day 701 fixture does not satisfy this gate. The binding utility, treasury, happiness, population, and qualification standards must be understandable early enough to act on.
- **Stop conditions:** New save/public-store/renderer contract, title-routed messages becoming domain authority, nondeterministic fixtures, or balance changes that invalidate the accepted PLAY-010 recovery path.

### [ ] PLAY-020: Make consequences readable in the city

- **Player outcome:** Growth, construction, utility trouble, prosperity, pollution, selection, decline, and recovery are legible in the world without consulting only numbers.
- **Owning lane:** World rendering.
- **Requirement IDs:** `ART`, `UX`, `ENV`, `TEC` first-wave rows.
- **Dependencies:** Accepted baseline; approved simulation-to-renderer snapshot fields from PLAY-010/040.
- **In scope:** Renderer composition, truthful consequence states, representative neighborhood, camera/LOD behavior, renderer tests, telemetry, and visual proof.
- **Out of scope:** Inventing simulation truth, gameplay balance, HUD redesign, save schema.
- **Acceptance:** Named world states are visually distinct and non-color-only; default/compact/camera proof retained; stable deterministic variation; unchanged-pulse reuse preserved; performance budget and limitations recorded.
- **Stop conditions:** Renderer derives gameplay facts absent from snapshot, unapproved asset/license input, or regression beyond accepted render budgets.

### [ ] PLAY-021: Deliver the golden-neighborhood visual breakthrough

- **Player outcome:** The staged game opens on an authored, visually dense miniature neighborhood that feels like a place worth growing, not a sparse procedural diagram on an empty grid.
- **Owning lane:** World rendering.
- **Requirement IDs:** `ART`, `UX`, `TEC` graphics vertical-slice rows.
- **Dependencies:** Integrated PLAY-020 renderer foundations; approved task brief at `docs/production/WORLD_RENDERING_RECOVERY_2026-07-19.md`.
- **In scope:** Terrain and connected-road art, complete residential/commercial/industrial/park/civic visual families, deterministic seeded variants, lot frontage and props, ambient truth-safe life, starting camera composition, camera LOD, world-only resources, renderer tests/telemetry, and real before/after proof.
- **Out of scope:** Gameplay balance, invented service/traffic/economy facts, HUD redesign, save schema, external unlicensed assets, broad engine replacement.
- **Acceptance:** The same real staged starting city is materially more compelling at default and 900 x 600; the primary visual language works without floating lifecycle labels; the golden 8 x 8 neighborhood is intentional at city/neighborhood/block detail; all road masks and five lot families are authored and distinct; empty-land repetition is broken up without implying false development; deterministic identity, accessibility, Reduce Motion, hit testing, incremental reuse, and performance remain sound; integration and PLAY-050 accept the visual delta from retained side-by-side evidence.
- **Stop conditions:** Improvement exists only in an off-window fixture, depends mainly on labels/recoloring/camera crop, fakes simulation truth, introduces unclear asset provenance, hides interaction state, or misses the live visual-acceptance gate.

### [ ] PLAY-030: Complete the command and keyboard system

- **Player outcome:** Every non-spatial game action has one discoverable command, menu/shortcut route, contextual availability, accessible label, and consistent focus behavior.
- **Owning lane:** UI and input.
- **Requirement IDs:** `UX`, `AUD`, `TEC` first-wave rows.
- **Dependencies:** Accepted baseline; approved `CONTRACT-002`; PLAY-050 defect and journey inventory.
- **In scope:** Typed command registry, menus, shortcuts, command palette/help, focus rules, accessibility semantics, compact layout, UI/input tests and proof.
- **Out of scope:** Simulation rules, renderer truth, persistence architecture. Spatial grid navigation must be proposed separately if it changes interaction architecture.
- **Acceptance:** 100% inventory coverage for declared non-spatial actions; no collisions or focus traps; pointer and shortcut routes dispatch identical intents; default and 900 x 600 layouts remain usable; full tests and live keyboard evidence.
- **Stop conditions:** Duplicate command state, shortcut collision, inaccessible critical action, or shared-store change without approval.

### [ ] PLAY-031: Quarantine onboarding input and restore the intended window

- **Player outcome:** A new player can read and dismiss onboarding without silently changing game state, opening another command surface, or beginning in a previously restored compact window.
- **Owning lane:** UI and input.
- **Requirement IDs:** `UX`, `AUD`, `REL`, `TEC` onboarding and keyboard acceptance rows.
- **Dependencies:** Integrated Wave 002 candidate `c70321b`; PLAY-050 defect `PLAY-050-D005`.
- **In scope:** One authoritative blocking-modal command policy, onboarding dismissal and focus, command/menu/renderer shortcut availability while blocked, default versus proof-compact window restoration, focused UI/input tests, and real staged evidence.
- **Out of scope:** Gameplay balance, renderer art, persistence schema, command inventory expansion, general window redesign.
- **Acceptance:** While onboarding is visible, Space, 1–3, build/mode keys, camera keys, global panels, and Command Guide cannot mutate or stack surfaces; only explicit onboarding dismissal/system-safe behavior works; dismissal restores the authored 1x start and stable focus; a normal fresh launch uses the intended default content size while `CITYSIM_COMPACT_WINDOW=1` alone produces the proof compact size; pointer and keyboard dismissal pass at default and 900 x 600; tests cover menu, store, renderer, focus, and modal leakage routes.
- **Validation/proof:** Focused command/onboarding/window tests; full native suite; staged fresh-start 0/10/30/60-second sequence; exact D005 shortcut sequence before dismissal; pointer and keyboard dismissal; default and compact captures; accessibility tree; `git diff --check`; script syntax; staged `--verify`.
- **Stop conditions:** A second modal authority, command-specific ad hoc guards, gameplay/store duplication, inability to prove default/compact separation, or any shortcut changing underlying state while onboarding blocks.

### [ ] PLAY-040: Establish deterministic simulation and recovery contracts

- **Player outcome:** A city can be saved, resumed, replayed, diagnosed, and recovered without losing or silently changing authoritative state.
- **Owning lane:** Simulation platform.
- **Requirement IDs:** `SIM`, `TEC`, `REL` first-wave rows.
- **Dependencies:** Accepted baseline; PLAY-010 fixture/command sequence; approved `CONTRACT-003` and `CONTRACT-004`.
- **In scope:** Typed command boundary, deterministic checkpoints, hashes, atomic versioned saves, migration/recovery, immutable presentation snapshots, diagnostics, and focused performance evidence.
- **Out of scope:** Balance, renderer art, HUD redesign.
- **Acceptance:** Equivalent logical outcomes across speed settings; repeated fixture hashes; save/load/undo/recovery invariants; corrupt-write fallback preserving originals; measured vertical-slice budgets; full suite and retained fixtures.
- **Stop conditions:** Silent save incompatibility, gameplay balance invented by platform, shared contract without approval, or mature-city claims from slice-only evidence.

### [ ] PLAY-050: Prove the playable-session gate

- **Player outcome:** Independent evidence proves or rejects a coherent 20-minute session across pointer, keyboard, compact, accessibility, save/resume, and recovery paths.
- **Owning lane:** Playtest quality.
- **Requirement IDs:** `UX`, `AUD`, `REL`, and cross-system acceptance rows.
- **Dependencies:** Accepted baseline; consumes PLAY-010 scenario, PLAY-020 visual states, PLAY-030 command inventory, and PLAY-040 fixture/save/hash contracts as they land.
- **In scope:** Golden fixture/manifest, journey records, confusion/dead-time ledger, strategy comparison, accessibility and compact checks, proof manifest, reproducible defects.
- **Out of scope:** Casual cross-lane product fixes; defects return to owners.
- **Acceptance:** Decision by 02:00; no blocking confusion over 30 seconds; no false feedback; pressure diagnosed within two minutes; recovery before minute 18; clear outcome and resume comprehension; every critical failure rejects the wave.
- **Stop conditions:** Missing authoritative fixture/contract, unretained visual proof, coaching required to pass, or contradictory player feedback.
