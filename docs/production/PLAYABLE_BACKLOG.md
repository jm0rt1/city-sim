# CitySim Playable Backlog

This is the authoritative first-wave task source. The shared target is one coherent 20-minute journey: diagnose pressure, choose, observe consequences, recover, reach an outcome, save, and resume.

### [x] PLAY-001: Establish the native playable baseline

- **Player outcome:** A readable top-down city, rich command-center HUD, explicit modes, visible placement truth, keyboard-accessible global commands, and retained proof.
- **Owning lane:** Integration.
- **Dependencies:** None.
- **Scope:** Native world/HUD/input slice, tests, audit records, plans, and proof.
- **Acceptance:** Full tests, staged build/launch, live inspection, compact/default proof, and truthful residual risks.
- **Commits:** `cb30157`, `48bc2b5`.

### [ ] PLAY-010: Create consequential early-game pressure

- **Player outcome:** Within two minutes the player understands a real treasury-demand-utilities-happiness-employment tradeoff; the session contains a warned recoverable squeeze, two viable strategies, and a meaningful Town Charter milestone.
- **Owning lane:** Gameplay loop.
- **Requirement IDs:** `SIM`, `ECO`, `POP`, `GOV`, `UX` first-wave rows.
- **Dependencies:** Accepted baseline; integration approval for durable objective, save, command, or snapshot contract changes.
- **In scope:** Starting scenario, economy/demand/service relationships, objective sequencing, recovery, milestone, causal analytics, deterministic scenarios.
- **Out of scope:** Renderer art, HUD composition, persistence format, package topology.
- **Acceptance:** First decision by 02:00; two distinct successful strategies; overextension is warned and recoverable; transient spikes cannot complete milestones; full tests plus a staged 20-minute journey and retained causal evidence.
- **Stop conditions:** Shared-model/save/store contract change without approval, non-deterministic outcome, or unrelated UI/rendering edits.

### [ ] PLAY-020: Make consequences readable in the city

- **Player outcome:** Growth, construction, utility trouble, prosperity, pollution, selection, decline, and recovery are legible in the world without consulting only numbers.
- **Owning lane:** World rendering.
- **Requirement IDs:** `ART`, `UX`, `ENV`, `TEC` first-wave rows.
- **Dependencies:** Accepted baseline; approved simulation-to-renderer snapshot fields from PLAY-010/040.
- **In scope:** Renderer composition, truthful consequence states, representative neighborhood, camera/LOD behavior, renderer tests, telemetry, and visual proof.
- **Out of scope:** Inventing simulation truth, gameplay balance, HUD redesign, save schema.
- **Acceptance:** Named world states are visually distinct and non-color-only; default/compact/camera proof retained; stable deterministic variation; unchanged-pulse reuse preserved; performance budget and limitations recorded.
- **Stop conditions:** Renderer derives gameplay facts absent from snapshot, unapproved asset/license input, or regression beyond accepted render budgets.

### [ ] PLAY-030: Complete the command and keyboard system

- **Player outcome:** Every non-spatial game action has one discoverable command, menu/shortcut route, contextual availability, accessible label, and consistent focus behavior.
- **Owning lane:** UI and input.
- **Requirement IDs:** `UX`, `AUD`, `TEC` first-wave rows.
- **Dependencies:** Accepted baseline; integration approval for the public command/store contract; PLAY-050 journey inventory.
- **In scope:** Typed command registry, menus, shortcuts, command palette/help, focus rules, accessibility semantics, compact layout, UI/input tests and proof.
- **Out of scope:** Simulation rules, renderer truth, persistence architecture. Spatial grid navigation must be proposed separately if it changes interaction architecture.
- **Acceptance:** 100% inventory coverage for declared non-spatial actions; no collisions or focus traps; pointer and shortcut routes dispatch identical intents; default and 900 x 600 layouts remain usable; full tests and live keyboard evidence.
- **Stop conditions:** Duplicate command state, shortcut collision, inaccessible critical action, or shared-store change without approval.

### [ ] PLAY-040: Establish deterministic simulation and recovery contracts

- **Player outcome:** A city can be saved, resumed, replayed, diagnosed, and recovered without losing or silently changing authoritative state.
- **Owning lane:** Simulation platform.
- **Requirement IDs:** `SIM`, `TEC`, `REL` first-wave rows.
- **Dependencies:** Accepted baseline; PLAY-010 fixture/command sequence; integration decisions on command, hash, snapshot, save-v0, and undo scope.
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
