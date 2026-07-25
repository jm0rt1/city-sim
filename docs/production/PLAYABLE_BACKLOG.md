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

### [x] PLAY-012: Deliver a three-act playable session

- **Player outcome:** A fresh player reaches an opening fork, a strategy-specific complication, a recovery decision, and an unmistakable durable result within 20 minutes, with no unexplained wait longer than 30 seconds.
- **Owning lane:** Gameplay loop.
- **Dependencies:** Accepted Wave 002 baseline `74b694d`; consume PLAY-041 truth after integration approval.
- **In scope:** Deterministic pacing, authored strategy decisions, incidents, recovery, balance, objectives/messages through approved surfaces, gameplay fixtures, and live causal proof.
- **Out of scope:** Renderer art, UI composition, input architecture, save schema, and unapproved shared contracts.
- **Acceptance:** First meaningful decision by 02:00; at least three consequential decisions; feedback within 15 seconds of relevant simulation time; commercial and industrial stories remain viable and mechanically distinct; recovery before minute 18; focused/full tests plus a staged no-coaching session.
- **Stop conditions:** Passive fixture-only success, nondeterminism, renderer/UI edits, or a shared contract change without approval.
- **Accepted integration:** Closure evidence `67b5822` and claim/completion `1c65bb4`; Commercial won in 06:42 and Industrial in 05:22 on the integrated candidate with 159/159 tests.

### [x] PLAY-041: Publish spatial consequence truth

- **Player outcome:** Location-specific service, pollution, prosperity/strain, recovery, and event identity are deterministic, inspectable, persistent where required, and safe for renderer/UI consumption.
- **Owning lane:** Simulation platform.
- **Dependencies:** Accepted Wave 002 baseline `74b694d`; integration approval before any public contract change.
- **In scope:** Smallest presentation contract proposal, deterministic derivation, replay/save/load/undo/fingerprint consequences, diagnostics, performance budgets, and contract tests.
- **Out of scope:** Gameplay balance, renderer art, HUD layout, and invented player-facing copy.
- **Acceptance:** One authoritative spatial truth source; stable identity; exact undo/replay/save behavior; frozen fixtures and performance evidence; documented compatibility and migration risk; integration-approved contract before consumers change.
- **Stop conditions:** Duplicate truth, implicit schema migration, renderer-oriented facts in persistence without need, or unapproved public surface changes.
- **Accepted integration:** `36774db97e5dd017f1a4c9ecd0a4c288dd09c387`; completion record at `docs/production/completed/PLAY-041.simulation-platform.md`.

### [x] PLAY-022: Make strategy reshape the living city

- **Player outcome:** Commercial and industrial strategies visibly create different cities, and utility trouble, pollution, prosperity, decline, construction, and recovery are legible in the live world without reading the HUD alone.
- **Owning lane:** World rendering.
- **Dependencies:** Accepted PLAY-021; approved and integrated PLAY-041 truth for factual consequence states.
- **In scope:** The production recovery sequence in `PLAY-022_PRODUCTION_WORLD_RECOVERY_PLAN.md`: calibration footprint/anchor/depth descriptors and validation, one overlap-safe coherent street corridor, authored architecture/environment families, construction, restrained interaction, density/consequence presentation, bounded ambient life, LOD/reuse/performance, accessibility, and live default/compact visual proof.
- **Out of scope:** Inventing simulation facts, gameplay balance, HUD redesign, save schema, and fixture-only visual claims.
- **Acceptance:** Resolve the 28 findings in `WORLD_RENDERING_ISSUE_REPORT_2026-07-21.md` through the ordered production gates in `PLAY-022_PRODUCTION_WORLD_RECOVERY_PLAN.md`; first pass its overlap-safe playable-corridor Round 1, then the same live city shows strategy and three-act state changes non-color-only at city/neighborhood/block scales. Both integration and playtest must score the exact staged candidate at least 17/20 with no category below 3/4. Retain stable deterministic identity, truthful feedback, bounded performance, and uncropped same-seed before/after evidence.
- **Accepted integration:** Round 1E product `45dd181` and world evidence `013bdd3`, integrated through UI/world merge `37894a6`; independent quality preserved a 17/20 score with no category below 3 and no automatic reject in `52ea60b`. The same exact candidate passed default, compact, Reduce Motion, overlays, construction, accessibility, and unified-target play in the retained combined evidence.
- **Stop conditions:** A mostly empty developed frame, disconnected road language, inconsistent projection/scale/light, debug-like indicator clutter, cosmetic recolor or asset-count delivery, author self-acceptance, off-window-only proof, false simulation implications, unclear asset provenance, or regression in hit testing/reuse/accessibility.

### [x] PLAY-023: Build the generated-v4 asset pipeline

- **Player outcome:** High-resolution generated art loads crisply and consistently in the exact staged app, with stable anchors and LODs instead of silently missing or blurry resources.
- **Owning lane:** World rendering.
- **Dependencies:** Accepted PLAY-022 Gate A; CONTRACT-005 and CONTRACT-006.
- **In scope:** Manifest v4, geometry templates, provenance, normalization, deterministic page packing, descriptor-driven loading, LOD cache/diagnostics, staging digests, rollback, and focused tests using Gate A as the sample.
- **Out of scope:** Bulk architecture generation, gameplay truth, HUD, save schemas, and production selection of an incomplete pack.
- **Acceptance:** Two clean builds produce byte-identical pages/manifests; every entry loads from the staged Bundle.module resource; alpha, padding, anchor, seam, digest, LOD cycling, memory, fallback, and rollback gates pass.
- **Stop conditions:** Absolute development paths, raw tool output in shipping resources, silent fallback, unbounded cache, nondeterministic pack bytes, or shared-package changes without integration approval.
- **Accepted integration:** Product `32f3099`, evidence `64a2c7d`, and completion `e5590a3`. The integrated generated-v4 runtime loads four deterministic atlas pages, retains all 84 accepted pixel digests, bounds three-LOD residency, exposes explicit rollback/failure diagnostics, and passed the integrated 194/194 suite. PLAY-023 deliberately preserved the accepted pixels; visible excellence continues under PLAY-024.

### [x] PLAY-024: Replace terrain, streets, and environmental structure

- **Player outcome:** The city sits on cohesive terrain and connected streets with curbs, sidewalks, crossings, frontages, vegetation, and props instead of visible tile strips and empty green board space.
- **Owning lane:** World rendering.
- **Dependencies:** Accepted PLAY-023 and frozen generated-v4 style/family anchors.
- **In scope:** Program batches 1–3: calibration spine, terrain/material sources, deterministic 16-mask road grammar, oriented frontages, buildable-kind anchors, vegetation base, seam mosaics, default/compact proof, and budgets.
- **Out of scope:** Full density breadth, lifecycle states, simulation rules, and HUD layout.
- **Acceptance:** All ten buildable kinds share projection/light/scale; reciprocal roads and 3 x 3 terrain mosaics have no visible seams; golden-row and live default/compact frames pass independent review.
- **Stop conditions:** Image-generated connectivity, endpoint drift, toy-island framing, mixed projection/light, unreviewed source provenance, or fixture-only proof.
- **Accepted integration:** Returned candidate `ad2f35314bb471a07923c41653374b05ace51ee3` repaired the retained 14/20 rejection without changing gameplay topology, saves, commands, or HUD contracts. Independent PLAY-053 evidence `2e83570eda92e14fcf39bca78b9152ff3c7b8411` scored it 19/20: composition 4/4, coherence 4/4, LOD/life 3/4, state/interaction 4/4, shipping/HUD/accessibility/performance 4/4, no category below 3, and zero automatic rejects. The exact proof is `docs/production/evidence/PLAY-053/rescore-ad2f353/`. Building-family and directional breadth remains explicitly owned by PLAY-027/CONTRACT-011 and does not reopen this accepted environment/street-system slice.

### [ ] PLAY-025: Replace every building and lifecycle family

- **Player outcome:** Every buildable type, density level, construction phase, maintained/weathered/distressed state, and recovery reads as one rich city-building art system without debug graffiti.
- **Owning lane:** World rendering.
- **Dependencies:** Accepted PLAY-024 and authoritative PLAY-041 spatial truth.
- **In scope:** Program batches 4–7: all 19 identities, three maintained variants, levels 1–4 for R/C/I, explicit LODs, construction/condition composition, civic/service/utility breadth, contextual life, and truth-driven consequences.
- **Out of scope:** New gameplay effects, save changes, labels as primary state, and monolithic district plates as final rendering.
- **Acceptance:** Unlabeled grayscale recognition, same-coordinate healthy/strained/recovered truth, deterministic identity, Reduce Motion, dense-fixture repetition, construction, save/load/undo visual stability, performance, and staged proof all pass.
- **Stop conditions:** Recolor-only variants, generated false state, retained debug-glyph dominance, missing LODs, memory accumulation, or self-acceptance.

### [ ] PLAY-026: Retire legacy world art and publish the systemic city

- **Player outcome:** Normal play uses only the generated-v4 semantic atlas across opening, growth, build, diagnosis, recovery, compact, and dense cities; no special hero image hides a weak systemic renderer.
- **Owning lane:** World rendering.
- **Dependencies:** Accepted PLAY-023, PLAY-024, and PLAY-025.
- **In scope:** Remove the production golden plate and legacy-v2 loading, freeze the production pack ID, preserve rollback sources, run full staged journeys/contact sheets/LOD video, and produce completion evidence.
- **Out of scope:** Deleting rollback history, simulation rebalance, HUD redesign, or accepting partial asset coverage.
- **Acceptance:** Zero manifest fallbacks and legacy texture loads; exact staged A/B evidence wins independent review; all interactions, accessibility, Reduce Motion, frame/memory budgets, full tests, and rollback verification pass.
- **Stop conditions:** Any visible legacy art, special-case starting-state substitution, missing buildable/state coverage, staged/built digest mismatch, user visual rejection, or incomplete proof.

### [ ] PLAY-027: Author the four-direction production building catalog

- **Player outcome:** Residential, commercial, industrial, civic, service, and utility buildings are materially distinct, face their real road frontage, and retain coherent projection, pivots, shadows, and identity from every supported direction.
- **Owning lane:** World art generation cell.
- **Dependencies:** Approved CONTRACT-006, CONTRACT-010, and CONTRACT-011; accepted generated-v4 style anchors and accepted PLAY-024. Source production may proceed through the calibration gate, but ingestion and shipping selection require independent source-art acceptance and renderer-lead review.
- **In scope:** Audit and eliminate cross-type source aliasing; author N/E/S/W masters without runtime mirroring or rotation; first pass the CONTRACT-011 residential L1 four-scene calibration gate, then complete the first 48-source R/C/I variant-zero directional batch and extend the governed catalog toward three material/massing variants for every built identity; retain scene sources, tools, material prompts/references, provenance, rejection reasons, geometry registration, and actual-scale contact sheets.
- **Out of scope:** `Rendering/`, shipping atlas pages or production selection, shared manifest implementation, simulation/gameplay/UI changes, lifecycle composition, package/build scripts, and self-acceptance.
- **Acceptance:** The CONTRACT-011 residential L1 N/E/S/W calibration set passes before batch expansion; every accepted logical building type has its own non-aliased source identity; every accepted variant has four separately authored views; direction pairs preserve footprint, pivot, frontage socket, vertical envelope, scale, northwest light, southeast shadow, and material identity within CONTRACT-010 tolerances; R/C/I remain recognizable in unlabeled grayscale; all scene/tool/source/provenance/normalization/geometry validators pass; independent art review approves each batch before renderer ingestion.
- **Stop conditions:** Reuse across building types, recolor-only variants, runtime mirroring/rotation, perspective or light drift, invented roads or ground truth, geometry/pivot/frontage mismatch, missing provenance, direct edits to live renderer/shipping selection, or generation continuing after two rejected direction siblings without anchor review.
- **Current disposition:** Residential L1 calibration `6380037d42ede73eca60aac4a9b1c7b710f681d6` and the independently reviewed Residential L2–L4 slice `8f928ed5dd01453ff9d4d9910858d8bf786afa9d` are accepted source inputs and integrated through `32e5d1dec2857f8617ecc3cd3c194c98d35b2d6b`. Independent review scored L2 26/28, L3 25/28, L4 26/28, and cross-level identity 19/20; the 12 raw sources and 36 normalized LODs are all unique, frontage remains readable in color and grayscale, and accepted L1 surfaces are unchanged. Integration authorizes the next controlled source slice: Commercial L1–L4 variant-zero N/E/S/W (16 sources), with clearly commercial massing, storefront/entrance hierarchy, and level progression distinct from the residential family. Industrial expansion remains blocked pending independent review of that Commercial slice. Production selection and live Residential ingestion are separately governed by PLAY-028.

### [ ] PLAY-028: Ship the directional residential skyline

- **Player outcome:** Residential growth visibly progresses from grounded homes to walk-ups, courtyard mid-rises, and a restrained tower, and every building presents its real road-facing entrance without rotated, mirrored, aliased, or fallback art.
- **Owning lane:** World rendering.
- **Dependencies:** Accepted PLAY-023 generated-v4 pipeline; accepted PLAY-024 environment system; integrated PLAY-027 Residential L1–L4 source catalog at `32e5d1dec2857f8617ecc3cd3c194c98d35b2d6b`; CONTRACT-006, CONTRACT-010, and CONTRACT-011.
- **In scope:** Renderer-lead source review; production selection of the accepted Residential L1–L4 variant-zero N/E/S/W sources; deterministic normalization/packing; generated-v4 manifest and atlas ingestion; logical level and frontage-direction selection; stable pivots, footprint, shadow, hit truth, LOD, residency, diagnostics, tests, retained staged default/compact and directional proof, and rollback.
- **Out of scope:** Commercial or industrial ingestion; new source authoring; runtime image rotation or mirroring; gameplay, simulation, save, command, or SwiftUI HUD changes; lifecycle breadth beyond preserving existing truthful composition.
- **Acceptance:** All 16 authored Residential direction/level identities load from the staged production bundle with zero alias, mirror, rotation, legacy fallback, or missing-asset diagnostic; identical state and road adjacency select identical bytes; each N/E/S/W entrance faces the authoritative adjacent-road frontage; levels remain recognizable at block, neighborhood, and city LODs; construction, condition, selection, preview, undo, save/load, Reduce Motion, pointer/keyboard/AX hit truth, bounded residency, full tests, and exact staged default/compact journeys pass. Retained comparison evidence must materially beat the pre-ingestion residential rendering in independent review.
- **Stop conditions:** A source-quality repair inside the renderer lane, any cross-family source substitution, frontage inferred from camera rather than authoritative adjacency, runtime pixel transform, changed simulation or store truth, fixture-only proof, unbounded pack/residency growth, or author self-acceptance.
- **Current disposition:** Ready for dispatch from the first published integration authority containing this task and claim. Renderer-lead production selection is authorized only for the independently accepted Residential L1–L4 variant-zero source set; Commercial/Industrial and additional variants remain non-shipping.

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

### [x] PLAY-013: Make the strategy story impossible to miss

- **Player outcome:** A fresh player can read, diagnose, make one valid Commercial or Industrial commitment, and receive the complete authored opportunity, warning, setback, recovery, and payoff in order even when the choice lands after the old Day 25 boundary.
- **Owning lane:** Gameplay loop.
- **Dependencies:** Integrated PLAY-051 dual audit; approved `CONTRACT-007`; accepted PLAY-012 checkpoint; simulation-platform adoption under PLAY-042.
- **In scope:** Durable strategy commitment, phase-relative daily scheduling, minimum warning interval, late-choice catch-up, objective/message retirement, derived urgency analytics, deterministic route/recovery balance, and compatibility evidence.
- **Out of scope:** HUD composition, panel pause policy, renderer/placement presentation, new commands, general event framework, and unrelated economy redesign.
- **Acceptance:** The retained missed-deadline reproduction can commit after Day 25 and still receives every phase exactly once and in order; a failed placement never commits; strategy never flips from later tile counts; both strategies reach Town Charter or an explicit terminal failure inside 20:00 in deterministic no-coaching runs; save/load/undo/replay/fingerprints remain exact.
- **Stop conditions:** Exact-tick story gating remains, legacy saves replay/cascade missed phases, new shared state exceeds CONTRACT-007, UI/rendering changes enter the lane, or platform fixture adoption is omitted.
- **Accepted integration:** Durable product `6d5df6b`; final live evidence/completion `eee7bca` and `9eb7c9a`. Commercial and Industrial staged routes reached the Charter in 7:47 and at most 7:10 respectively; the synchronized full suite passed 185/185 with no additional gameplay repair.

### [x] PLAY-014: Make recovery choice a durable strategic identity

- **Player outcome:** Each strategy offers two viable recoveries whose cost, payoff, and retained identity make the city and replay meaningfully different.
- **Owning lane:** Gameplay loop.
- **Requirement IDs:** GOV-004, GOV-005, GOV-006, ECO-002, ECO-003, SIM-004.
- **Dependencies:** Approved CONTRACT-009; platform adoption follows under PLAY-044.
- **In scope:** Four typed resolution paths, first-qualifying daily capture, non-flipping identity, distinct consequences/messages/analytics, balance and deterministic story proof.
- **Out of scope:** New UI commands, renderer inference, save-schema identifiers, platform fingerprints/fixtures, or unrelated economy redesign.
- **Acceptance:** Two Commercial and two Industrial recovery routes remain viable; each captures once, never flips, produces distinct numerical/payoff evidence, survives model round trip and undo, and reaches the authored finish inside 20:00.
- **Stop conditions:** Resolution is inferred from prose or current city counts after capture, one path dominates, legacy nil fails, UI/rendering changes enter the lane, or platform adoption is omitted.
- **Accepted integration:** Gameplay `10023e5` and `e02d2c0`; platform adoption `705fc51`; evidence/completion through `7be0e6b` and `71bb3bd`.

### [x] PLAY-015: Make the Town Charter an unmistakable session victory

- **Player outcome:** Earning the Town Charter conclusively ends the mayoral mandate, preserves the earned strategy and recovery identity, and immediately offers a trustworthy route into a new region instead of leaving the player to coast after every objective is complete.
- **Owning lane:** Gameplay loop.
- **Requirement IDs:** GOV-004, GOV-005, GOV-006, SIM-004, UX-001, UX-007, REL-004.
- **Dependencies:** Accepted PLAY-014/044; UI companion PLAY-038 consumes the existing won state; simulation platform must verify the final candidate across save/replay boundaries.
- **In scope:** Transition to the existing `.won` state on the governed daily boundary that newly awards the Charter; deterministic normalization of legacy `townCharterAwarded == true` and `.playing` saves on their next daily boundary without load-time mutation or duplicate award; terminal immutability; four-route gameplay tests; truthful typed result analytics only if required.
- **Out of scope:** New progression systems, commands, public store types, save-schema identifiers, renderer work, SwiftUI victory composition, or unrelated economy tuning.
- **Acceptance:** All four durable recovery routes award the Charter and enter `.won` exactly once at tick 844; no route wins before payoff or without 12 qualifying checks; the recovery identity and one-time message remain exact; subsequent ticks cannot mutate the won state; failed checks, ignored recovery, undo, loss, and legacy missing fields remain valid; legacy awarded-playing state normalizes only at the next daily boundary; save/load/replay/fingerprint equality requires no schema bump.
- **Live gate:** A no-coaching Commercial and Industrial staged route each reaches a clearly explained victory inside 20 minutes; the player can explain why they won and deliberately start a new region through PLAY-038.
- **Stop conditions:** The change requires load-time mutation, a schema/fingerprint-version bump, premature victory, gameplay-owned UI edits, a new command/state authority, or any recovery route losing viability.
- **Accepted integration:** Product/evidence/completion `836453d`, `5f3d720`, and `7e6badc`; terminal runtime adoption follows under PLAY-046.

### [ ] PLAY-016: Author a believable starter district

- **Player outcome:** New Arcadia opens as a connected, inhabited district with purposeful blocks, several legitimate growth directions, and the same understandable strategic pressure instead of eight buildings stranded around one long cross.
- **Owning lane:** Gameplay loop.
- **Requirement IDs:** GOV-004, ECO-002, SIM-004, ART-001, UX-001.
- **Dependencies:** Accepted PLAY-015 and published Wave 006 authority; PLAY-024 consumes only the resulting authoritative topology and may not anticipate it with invented renderer state.
- **In scope:** `CityGameState.newCity` authored road/building arrangement, opening economy and capacity rebalance required by that arrangement, deterministic scenario tests, four-route viability, and an exact gameplay checkpoint for platform adoption.
- **Out of scope:** SpriteKit presentation, HUD composition, new building kinds, public store/command contracts, persisted schema identifiers, story-fixture rewrites, or renderer-authored roads.
- **Acceptance:** The authoritative opening contains a legible multi-block connected street structure with no accidental interior dead ends, distributes occupied lots across more than one block, preserves multiple valid road-adjacent build choices, exposes the Commercial/Industrial decision inside two minutes, retains visible utility/treasury tradeoffs, and keeps all four durable recovery routes viable through Town Charter inside 20 minutes. The state remains seed-deterministic and round-trips without schema or fingerprint-version changes.
- **Stop conditions:** The layout is cosmetic-only, roads are added solely to make a screenshot, one strategy becomes dominant or blocked, initial facts contradict tile consequences, renderer/UI files change, legacy saves are rewritten, or platform adoption is omitted.
- **Current status:** Authorized by `docs/production/claims/PLAY-016.gameplay-loop.md`. Begin only after merging the published authority commit containing this claim; return a frozen product checkpoint before PLAY-048 adoption.

### [x] PLAY-033: Make the HUD a compact city command center

- **Player outcome:** Urgent decisions stay visible and understandable, every warning leads directly to the relevant action, invalid placement recovery is durable, and exact 900 x 600 play keeps the map dominant.
- **Owning lane:** UI and input.
- **Dependencies:** Integrated PLAY-051 dual audit; approved CONTRACT-007 analytics; PLAY-013 publishes authoritative strategy status; PLAY-034 resolves in-world placement truth under CONTRACT-008.
- **In scope:** Authoritative urgency/countdown presentation, diagnose-to-act path, explicit pause/running communication, deterministic compact surface precedence, persistent placement-rejection guidance, command search synonyms/context, focus restoration, pointer/keyboard parity, accessibility, and staged proof.
- **Out of scope:** Gameplay deadlines/balance, local re-derivation of strategy truth, renderer art, save schema, or a second command/state system.
- **Acceptance:** Exact 900 x 600 retains at least 40% content height for the interactive map with Objectives plus Command Center (or a separately approved equivalent measure); selected context and critical actions remain visible; `tax`, `budget`, and `storefront` locate Tax Policy; rejection reason survives long enough to recover; default/compact pointer, keyboard, Full Keyboard Access, and VoiceOver routes pass against the exact staged candidate.
- **Stop conditions:** HUD infers countdown from tick/message prose, compact panels displace the map, transient-only critical recovery, shortcut/catalog divergence, focus trap, or UI code claims renderer placement truth.
- **Accepted integration:** Product `d0aa222` and `1fd842f`, evidence `97d2fdb`, and completion `905f740`. The authoritative strategy priority, command routing, compact map aperture, rejection recovery, keyboard/FKA/AX behavior, and both strategy stories passed the integrated 194/194 suite.

### [x] PLAY-034: Unify the active map-action target

- **Player outcome:** The grounded world preview, accessibility description, pointer click, and Return key always describe and act on the same coordinate with the same availability and disabled reason.
- **Owning lane:** UI and input.
- **Dependencies:** Approved `CONTRACT-008`; accepted/integrated PLAY-022 renderer base or an integration-approved compatible adapter checkpoint.
- **In scope:** Store-owned active action target, narrow SpriteKit candidate callback, scene-view wiring, one authoritative action presentation, modality transition rules, pointer/keyboard parity, focused tests, accessibility, and staged default/compact proof.
- **Out of scope:** Build validation rules, simulation balance, renderer art, hover-only inspect behavior, save state, snapshots, camera behavior, or general input-mode architecture.
- **Acceptance:** Occupied, road-required, unaffordable, valid, and newly connected tiles report one identical coordinate/outcome across grounded preview, AX, click, and Return at default and exact 900 x 600; alternating pointer and keyboard movement cannot expose stale hover truth; mutations occur iff the visible/accessible presentation is valid.
- **Stop conditions:** Two action targets remain live, renderer revalidates different coordinates, pointer hover changes inspect selection, store/player-intent ownership is duplicated, or implementation begins on an unaccepted incompatible renderer base.
- **Accepted integration:** Product/evidence/completion `704784b`, `88cebf4`, and `7de4412`, integrated through `37894a6`; independent combined quality approval `52ea60b` proved the five-state matrix, pointer/Return/AX exactly-once mutation, focus/Escape, default, and exact compact operation.

### [ ] PLAY-035: Make rejected keyboard actions explain themselves

- **Player outcome:** Pressing Return on a selected invalid build target explains the exact problem and recovery just as clearly as clicking it, while valid actions still happen once.
- **Owning lane:** UI and input.
- **Dependencies:** Integrated PLAY-033 and the PLAY-051 reproduction on exact master `23d2bf9`; independent of the blocked PLAY-034 target-unification contract.
- **In scope:** Separate map-command route eligibility from primary-action availability, route focused Return attempts to the existing store rejection path, preserve truthful catalog/AX disabled state, focused tests, and staged default/compact proof.
- **Out of scope:** Changing the active target coordinate, pointer-hover selection, renderer validation/art, simulation build rules, save state, or CONTRACT-008 implementation.
- **Acceptance:** Occupied, no-road, and unaffordable Return attempts expose the same accepted reason and durable guidance as pointer attempts; the selected tool and coordinate remain stable; valid Return mutates exactly once; AX availability/disabled reason remains truthful; modal/text quarantine and compact behavior do not regress.
- **Stop conditions:** Invalid commands become advertised as available, a second validation path is introduced, selection or active target semantics change, the renderer is edited, or CONTRACT-008 is implemented early.

### [ ] PLAY-036: Make searched remedies reliably actionable

- **Player outcome:** Typing the words used by a warning finds the intended remedy, and the visible result actually opens through pointer, keyboard, or accessibility action.
- **Owning lane:** UI and input.
- **Dependencies:** Integrated PLAY-033, PLAY-051 live reproduction on exact master `23d2bf9`, and completion of PLAY-035.
- **In scope:** Command-guide query lifecycle, result action semantics, existing catalog/store dispatch, truthful availability/disabled reasons, focus restoration, focused tests, and staged default/compact proof.
- **Out of scope:** New commands, warning prose ownership, simulation policy, renderer, persistence, or a parallel view-only action path.
- **Acceptance:** Fresh `tax`, `budget`, and `storefront` searches each show the one existing Tax Policy result; pointer, Return, Space, and AX activation execute that result exactly once when available; disabled results retain and announce their reason; Escape restores map focus without shortcut leakage.
- **Stop conditions:** Unit-only matching replaces live proof, a result is visible but inert, action paths diverge by input method, availability is overstated, or view code bypasses the store/catalog.

### [x] PLAY-037: Restore compact spatial keyboard and Escape parity

- **Player outcome:** Exact compact mode exposes the same operable City map as default and closes layered surfaces in a predictable topmost-first order.
- **Owning lane:** UI and input.
- **Requirement IDs:** UX-003, UX-004, UX-009, UX-010, REL-005.
- **Dependencies:** Accepted PLAY-035/036 integration; independent of PLAY-022 and PLAY-034.
- **In scope:** Compact map view identity/lifecycle, keyboard selection, AX semantics/actions, selected-action reachability, and Escape arbitration.
- **Out of scope:** Active-target unification, renderer art/validation, simulation rules, or new commands.
- **Acceptance:** Exact 900 x 600 exposes `City map`, moves selection with arrows, retains selected actions, and closes Command Center then Objectives on successive Escape presses; default, pointer, focus, modal/text quarantine, and compact map occupancy remain sound.
- **Stop conditions:** Generic SKView remains, pointer-only recovery is required, Escape cancels underlying intent, focus leaks to text/modal surfaces, or CONTRACT-008 is implemented early.
- **Accepted integration:** `c196373`, `d75120c`, and `6d58857`; retained proof at `docs/production/evidence/PLAY-037/5016740/`.

### [x] PLAY-038: Make Charter victory truthful and replayable

- **Player outcome:** The victory surface accurately celebrates a Town Charter city, preserves the earned strategy/recovery story, and lets pointer, keyboard, and accessibility users start a different region without ambiguity.
- **Owning lane:** UI and input.
- **Requirement IDs:** UX-001, UX-004, UX-007, UX-009, AUD-001, REL-005.
- **Dependencies:** Existing `.won` surface and command routes; PLAY-015 supplies the reachable authoritative victory transition. No new public store or command contract is authorized.
- **In scope:** Charter-accurate victory copy, existing earned analytics presentation, Start a New Region action routing, initial focus, Escape/cancellation policy, default/compact layout, Full Keyboard Access, accessibility semantics, focused tests, and exact staged proof.
- **Out of scope:** Victory rules, gameplay balance, new commands, save schema, renderer art, active map-target work, or a second source of strategy/recovery truth.
- **Acceptance:** The victory surface never says “thriving metropolis” for the roughly 500–700 resident Charter result; it explains the earned Charter and retained recovery identity; Start a New Region executes exactly once through pointer, Return/Space, and AX action; focus is deterministic; exact 900 x 600 remains operable; save/relaunch of a won city remains truthful and paused; existing command-guide, map, modal, and Escape behavior does not regress.
- **Stop conditions:** UI infers gameplay truth from prose or tile counts, bypasses the store/catalog, adds a public contract without approval, hides the map before victory, or cannot prove keyboard/AX replay initiation.
- **Accepted integration:** Product `a8e88ee`, `4683fff`, `af4b821`, and `a10cc9b`; evidence/completion `38c925c`.

### [x] PLAY-039: Make the world the hero of the HUD

- **Player outcome:** The city is the dominant, beautiful play surface; the HUD remains immediately understandable without looking like two opaque control walls placed over the world.
- **Owning lane:** UI and input.
- **Dependencies:** Accepted PLAY-033 and the published Wave 006 baseline. PLAY-024 may proceed in parallel because this task changes no SpriteKit rendering contract.
- **In scope:** SwiftUI chrome hierarchy, visual weight, compact/default map aperture, priority placement, metric density, selected-context continuity, one-glance pause/urgency, pointer/keyboard/FKA/AX parity, and retained same-state before/after proof.
- **Out of scope:** Renderer art, simulation facts, gameplay balance, new commands, save state, active-target ownership, or local re-derivation of strategy truth.
- **Acceptance:** Default and exact 900 x 600 materially increase the visible interactive world while retaining every critical action and semantic route; the priority no longer reads as a floating opaque map obstruction; top and bottom chrome establish one clear hierarchy; selection, rejection, command search, focus, and accessibility remain exact.
- **Stop conditions:** Hiding required truth, icon-only critical actions, reducing hit targets or contrast, keyboard/AX divergence, SwiftUI claims over renderer-owned geometry, or accepting a screenshot that is prettier but less operable.
- **Accepted integration:** Product `f8f800656cf1cefb87aa5cdca231fa31bef6d860`, evidence `a895568cbf618830e587d1675be72702669c9af1`, and completion `b497f1d` are integrated. Independent PLAY-053 accepted the combined world/HUD candidate at 19/20 with shipping/HUD/accessibility/performance at 4/4. PLAY-054 owns the newly observed legibility and compact command-center follow-up without reopening the accepted map-aperture outcome.

### [ ] PLAY-054: Make the command surface readable and alive

- **Player outcome:** The player can read the city’s condition, priority, and next action at a glance, and opening Details or Notices reveals a genuinely usable command surface rather than tiny text or visually collapsed content.
- **Owning lane:** UI and input.
- **Requirement IDs:** UX-001, UX-003, UX-004, UX-007, UX-009, UX-010, AUD-001, REL-005.
- **Dependencies:** Accepted PLAY-033 and PLAY-039; published Residential source authority `1d4d4f7eba1bb1cf3c8d64b1c221f33d3be91637`. May proceed in parallel with PLAY-027 and PLAY-028 because it changes no SpriteKit or asset contract.
- **In scope:** Responsive Top HUD hierarchy; MetricCard and priority typography; compact/default command-deck composition; useful Details/Inspector/Journal viewport; HUD-specific material, contrast, grouping, depth, and motion; existing selected-context continuity; pointer/keyboard/FKA/AX parity; retained same-state evidence.
- **Out of scope:** Renderer art or camera, simulation/gameplay facts, new commands, save state, active-target ownership, command/store contract changes, or hiding critical information to create whitespace.
- **Work checklist:** Freeze exact compact/default baseline frames and typography/aperture measurements; design responsive open/closed hierarchy; implement semantic type and HUD-specific visual tokens; repair Overview/Journal visibility; retain selected/rejection/action continuity; exercise every existing input/accessibility route; capture candidate-bound comparison and completion evidence.
- **Acceptance:** At standard text size, no critical metric, priority, action, warning, or current-state text renders below 11 points and no supporting text required to choose an action renders below 10 points. Exact 900 x 600 Details/Journal visually exposes at least one complete actionable section and two complete notice summaries without relying on an invisible AX-only scroll region; default exposes a useful diagnostic section without microscopic cards. Closed compact map aperture remains at least the accepted 58%, open compact aperture remains at least 45%, and every critical action remains present. Priority, paused/running state, negative cashflow, utility shortfall, selected context, and action availability are readable in one glance in color and grayscale. Pointer, keyboard, command search, Escape, FKA, AX, Reduce Motion, focus stability at 3x, full tests, and exact staged default/compact journeys pass. Independent review must materially prefer the candidate over the retained baseline.
- **Validation:** Focused UI/layout/accessibility tests; `swift test --package-path Native/CitySimNative`; `git diff --check`; `bash -n script/build_and_run.sh`; exact lane-staged `./script/build_and_run.sh --verify`; direct pointer and keyboard journeys at regular and exact 900 x 600.
- **Proof:** Candidate-bound font inventory, open/closed aperture measurements, default/compact color and grayscale before/after frames, visible Overview and Journal frames, AX trees, focus route, Reduce Motion state, staged identity/manifest, performance observations, and independent quality disposition under `docs/production/evidence/PLAY-054/`.
- **Stop conditions:** Font scaling without responsive recomposition; a taller opaque wall that violates the aperture floor; visually hidden but AX-present information; icon-only critical actions; fixed-height clipping; state duplication; renderer/store/simulation contract changes; screenshot-only or author self-acceptance.
- **Current disposition:** Ready for dispatch from the first published authority containing `docs/production/claims/PLAY-054.ui-input.md`; the binding integration audit is `docs/production/evidence/PLAY-054/INTEGRATION-AUDIT.md`.

### [x] PLAY-042: Adopt durable strategy progression into runtime trust

- **Player outcome:** The repaired strategy story remains identical across speed grouping, save/load, undo, replay, recovery, and immutable presentation snapshots.
- **Owning lane:** Simulation platform.
- **Dependencies:** Approved CONTRACT-007 and a gameplay-owned PLAY-013 model/rules checkpoint.
- **In scope:** Legacy schema-0/schema-1 validation, version-1 fingerprint adoption, deterministic fixtures/digests, save/backup recovery, replay/undo invariants, immutable analytics snapshots, and measured performance/save-size evidence.
- **Out of scope:** Strategy balance/content, HUD presentation, renderer behavior, commands, or redesigning gameplay progression.
- **Acceptance:** Frozen legacy nil-strategy bytes/digests remain valid; every nonnil phase has stable repeated fingerprints; grouped-speed, uninterrupted, save/resume, and replay routes match exactly; corrupt-primary recovery preserves progression; dense/save/snapshot budgets remain bounded; full suite passes.
- **Stop conditions:** Authentic legacy envelope digest failure without version-aware handling, schema bump without integration approval, platform-owned gameplay rules, duplicate snapshot truth, or unexplained golden-digest drift.
- **Accepted integration:** Platform closure `0bedeb1` retains schema 1 and fingerprint version 1, authentic legacy bytes, all strategy/recovery/terminal fixtures, replay/undo/save/recovery equivalence, and measured budgets on the accepted beauty baseline.

### [x] PLAY-043: Restore exact save, relaunch, and load trust

- **Player outcome:** A city saved by the staged app reliably reloads after process termination and compact relaunch with its strategy intact and simulation paused.
- **Owning lane:** Simulation platform.
- **Requirement IDs:** UX-007, TEC-004, REL-004, REL-009, SIM-001.
- **Dependencies:** Wave 005 baseline.
- **In scope:** Exact rejection diagnosis, SaveGameService validation/recovery, persistence diagnostics/tests, isolated data roots, and staged same-bundle proof.
- **Out of scope:** Weakening corruption checks, gameplay rebalance, HUD redesign, or worker-local build-script changes.
- **Acceptance:** Exact save/relaunch/load preserves fingerprint, strategy phase, next action, and paused state; valid primary is accepted; corrupt primary still recovers backup; legacy fixtures and full suite pass.
- **Stop conditions:** Root cause is integration-controlled without proposal, valid corruption evidence is discarded, schema changes silently, or exact bytes/identity are not retained.
- **Accepted integration:** `e19ec8a` and `c0ce926`; exact relaunch evidence at `docs/production/evidence/PLAY-043/`.

### [x] PLAY-044: Adopt durable recovery resolution into runtime trust

- **Player outcome:** The selected recovery identity remains exact through every supported session boundary.
- **Owning lane:** Simulation platform.
- **Requirement IDs:** SIM-001, SIM-002, SIM-006, TEC-004, REL-002, REL-004.
- **Dependencies:** PLAY-043 complete and integration-supplied PLAY-014 candidate implementing CONTRACT-009.
- **In scope:** Legacy compatibility, fingerprints, four fixtures, replay, undo, recovery, snapshots, and measured persistence budgets.
- **Out of scope:** Gameplay rules, balance, UI, renderer, or authentic-fixture rewriting.
- **Acceptance:** Missing legacy field stays valid; four resolution fingerprints are stable; speed grouping, save/resume, recovery, replay, undo, and snapshots agree exactly within budgets.
- **Stop conditions:** Gameplay rules enter the lane, authentic legacy data is regenerated, schema bump appears, or unexplained digest drift remains.
- **Accepted integration:** `705fc51`, `75398a3`, and `7be0e6b`; completion record at `docs/production/completed/PLAY-044.simulation-platform.md`.

### [x] PLAY-045: Make last-known-good backup recovery reachable

- **Player outcome:** If the primary quicksave disappears but its valid backup survives, Load remains available and restores the exact city paused with truthful recovery feedback.
- **Owning lane:** Simulation platform.
- **Requirement IDs:** SIM-001, TEC-004, UX-007, REL-004, REL-009.
- **Dependencies:** Accepted PLAY-043/044; integration approves only the narrow default-preserving `SaveGameService` adoption in `CityGameStore`.
- **In scope:** Read-only primary-or-backup candidate availability, default-preserving service injection for isolated store tests, existing load-source feedback, backup-only schema-0/schema-1 and four-resolution fixtures, deterministic continuation, budgets, and staged isolated-root proof.
- **Out of scope:** Save-byte changes, schema/fingerprint bumps, backup promotion, primary fabrication, corrupt-file deletion, durable undo, general replay persistence, UI redesign, gameplay, or renderer work.
- **Acceptance:** Empty roots remain disabled; primary-only behavior is unchanged; valid backup-only saves enable Load and restore exact paused state through menu, shortcut, toolbar, and command guide; invalid backup-only attempts reject without mutation or false success; all four recovery identities, legacy bytes, fingerprints, snapshots, continuation, and frozen budgets remain exact.
- **Budgets:** Availability is exactly two bounded existence probes with no scan or decode; 1,000 checks complete within 100 ms on the declared machine; existing save/load, snapshot, envelope, and memory ceilings remain unchanged.
- **Stop conditions:** Availability performs validation/repair, a persisted contract changes, backup files are promoted or deleted, process-global roots replace injection, the shared store surface expands beyond the approved service dependency, or unrelated product work enters the lane.
- **Accepted integration:** Product/evidence/completion `854f4ef`, `9034645`, and `ebfbcdf`.

### [x] PLAY-046: Adopt terminal Charter victory into runtime trust

- **Player outcome:** The decisive Charter ending remains exact across deterministic checkpoints, save/load, replay, undo, immutable snapshots, and legacy awarded-playing normalization instead of leaving stale post-victory platform expectations.
- **Owning lane:** Simulation platform.
- **Requirement IDs:** SIM-001, SIM-002, SIM-004, SIM-006, TEC-004, REL-002, REL-004.
- **Dependencies:** Frozen PLAY-015 product `0e3e68e`; accepted PLAY-044 runtime trust; PLAY-045 may remain an independent earlier integration commit.
- **In scope:** Adopt the existing `.won` terminal boundary into platform-owned command/checkpoint fixtures and digests; stop accepted command sequences at victory; prove rejected post-terminal commands, schema-0/schema-1 behavior, awarded-playing next-boundary normalization, save/resume, replay, undo, backup recovery, fingerprints, analytics, and immutable snapshots.
- **Out of scope:** Gameplay rule changes, victory timing/balance, UI copy, renderer, schema/fingerprint-version changes, authentic legacy fixture rewriting, or general replay redesign.
- **Acceptance:** The frozen platform checkpoint suite and complete native suite pass against `0e3e68e`; all four recovery identities enter the exact terminal state once; post-terminal commands reject without mutation; won-state save/load/replay/backup/snapshot/fingerprint equality is exact; legacy decode/load never mutates and next-boundary normalization is deterministic; authentic fixture bytes and pre-victory digests remain unchanged.
- **Stop conditions:** Platform changes gameplay rules, rewrites authentic legacy inputs, bumps a version, masks an unexpected digest change, permits post-terminal mutation, or expands beyond the smallest adoption required for a green integrated candidate.
- **Accepted integration:** Product/evidence/completion `e636724`, `64a360c`, and `6d7df1e`; integrated suite 159/159.

### [x] PLAY-047: Freeze production story-state fixtures

- **Player outcome:** The real app, renderer, HUD, and independent playtest can all open the same trustworthy Commercial and Industrial story moments—opening, complication, recovery, and Charter victory—without synthetic visual truth, manual save surgery, or harness-only substitution.
- **Owning lane:** Simulation platform.
- **Requirement IDs:** SIM-001, SIM-002, SIM-006, TEC-004, REL-002, REL-004, ART-001.
- **Dependencies:** Integrated PLAY-015/045/046 and existing schema-1/fingerprint-v1 contracts; consumes existing strategy, recovery, spatial snapshot, and terminal truth without changing them.
- **In scope:** Test-owned deterministic story-state builders and frozen schema-1 save fixtures for both strategies at four named phases; exact fingerprints, immutable presentation/spatial snapshots, primary/backup load, replay, undo boundaries, repeated-build byte identity, compact fixture manifest, size/timing budgets, and documented consumption paths for renderer/UI/quality.
- **Out of scope:** Gameplay balance, new events or outcomes, schema/fingerprint-version changes, production save mutation, renderer/HUD composition, build scripts, app-only debug menus, or replacing no-coaching journeys with fixtures.
- **Acceptance:** Eight named states are generated twice with byte-identical fixture bytes and stable v1 digests; each loads paused through the production save service, preserves authoritative strategy/recovery/terminal identity and spatial truth, remains compatible with legacy fixtures, and stays within existing persistence/snapshot budgets; full suite passes and consumers can bind evidence to exact hashes.
- **Stop conditions:** A fixture invents facts unavailable in authoritative state, authentic legacy bytes are rewritten, a version changes, production behavior depends on test support, random or wall-clock data enters generation, or fixtures are represented as substitutes for the PLAY-052 player journey.
- **Accepted integration:** Fixtures/evidence/completion `0706dbe`, `ce450a3`, and `57c75b7`; eight schema-1 story states are byte-identical across repeated generation, and the complete native suite passed 164/164 in the owning lane.

### [ ] PLAY-048: Adopt the believable starter district into runtime trust

- **Player outcome:** The richer opening remains exact through save/load, replay, undo, immutable snapshots, frozen story moments, and performance budgets rather than becoming a visually attractive but nondeterministic exception.
- **Owning lane:** Simulation platform.
- **Requirement IDs:** SIM-001, SIM-002, SIM-006, TEC-004, REL-002, REL-004, ART-001.
- **Dependencies:** Frozen gameplay-owned PLAY-016 product checkpoint; accepted PLAY-047 fixture system.
- **In scope:** Current-state fingerprints and scenario expectations affected by PLAY-016, production story fixture regeneration through the existing deterministic builder, save/backup/replay/undo/snapshot equivalence, legacy-byte preservation, diagnostics, and measured budgets.
- **Out of scope:** Changing the starter layout, gameplay balance, renderer/HUD composition, schema/fingerprint-version bumps, authentic legacy fixture rewriting, or product behavior depending on test resources.
- **Acceptance:** Authentic schema-0/schema-1 bytes and legacy digests remain unchanged; the new opening and all eight strategy story states build twice byte-identically; save/resume, backup recovery, replay, undo, snapshots, and grouped-speed continuation agree exactly; full suite and existing persistence/performance ceilings pass without a migration.
- **Stop conditions:** Platform changes authored layout or balance, authentic legacy data is regenerated, a version bump appears, current digest drift is unexplained, renderer/UI changes enter the lane, or fixtures substitute for final PLAY-053 real-app proof.
- **Current status:** Authorized to prepare only by `docs/production/claims/PLAY-048.simulation-platform.md`; implementation waits for integration to hand off the exact frozen PLAY-016 checkpoint.

### [x] PLAY-052: Gate Wave 005 trust, choice, and world quality

- **Player outcome:** Independent evidence proves or rejects both the production world and the complete saveable, keyboard-operable, replayable strategy journey.
- **Owning lane:** Playtest quality.
- **Requirement IDs:** REL-001, REL-002, REL-003, REL-004, REL-005, ART-001, UX-007, UX-009.
- **Dependencies:** Separate frozen handoffs from PLAY-022 and the integrated PLAY-043/037/014/044 candidate.
- **In scope:** Exact-candidate identity, no-coaching journeys, default/compact pointer/keyboard/AX, save/relaunch/load, four recovery routes, visual rubric, performance disclosure, and retained proof.
- **Out of scope:** Product repair, coaching, candidate substitution, or combining renderer and integrated dispositions.
- **Acceptance:** Renderer independently earns at least 17/20 with no category below 3 or automatic reject; integrated candidate completes the governed journey, preserves save state, exposes semantic compact operation, and proves distinct viable recovery paths.
- **Accepted integration:** Contract `e28fdd2` and final evidence `7943b90`. Independent default Commercial and exact-compact Industrial no-coaching routes reached Charter in 8:34 and 4:42; save/relaunch/load, backup-only recovery, four durable recovery routes, pointer/keyboard/AX replay, and the integrated suite passed. The preserved 17/20 renderer score is a Wave 005 floor, not the Wave 006 excellence target.
- **Stop conditions:** Any P1 contradiction, hidden coaching, stale bundle, missing hashes/PID cleanup, save failure, pointer-only compact operation, nondurable choice, or misleading visual evidence.

### [x] PLAY-053: Gate world and HUD excellence

- **Player outcome:** Independent evidence proves that the integrated city is not merely functional but visually cohesive, spatially believable, easy to read, and materially preferable in both default and compact play.
- **Owning lane:** Playtest quality.
- **Dependencies:** Published Wave 006 baseline, completed PLAY-024 and PLAY-039 candidates, and exact integration handoff.
- **In scope:** Preregistered visual/usability rubric, same-seed and same-state before/after comparisons, default/compact pointer and keyboard journeys, city/neighborhood/block LOD, construction and consequence states, overlap/seam/stub inspection, accessibility, Reduce Motion, performance disclosure, and retained uncropped proof.
- **Out of scope:** Product repair, coaching, fixture-only acceptance, candidate substitution, author self-scoring, or preserving the old 17/20 threshold.
- **Acceptance:** At least 19/20 overall; 4/4 in composition/map occupancy and projection/material/light/street coherence; no category below 3; zero automatic rejects; the new candidate must be materially preferred to the frozen Wave 005 frame in an explicit side-by-side finding.
- **Stop conditions:** Toy-island framing, unexplained road stubs, large undifferentiated green voids, sprite overlap, mixed fidelity/projection/light, obscured priority or selection, stale identity, coached success, missing compact proof, or misleading crop/zoom.
- **Current status:** Exact returned candidate `ad2f35314bb471a07923c41653374b05ace51ee3` independently **APPROVED** at 19/20 by evidence commit `2e83570eda92e14fcf39bca78b9152ff3c7b8411`: composition 4, coherence 4, LOD/life 3, interaction clarity 4, shipping quality 4. Both governed comparisons are materially preferred, no category is below 3, and no automatic reject remains; integration review remains separate.

### [ ] PLAY-055: Gate the directional skyline and readable HUD

- **Player outcome:** Independent real-app evidence proves that residential growth now looks materially richer and faces its real roads, while the HUD is immediately readable and useful at both regular and compact sizes without surrendering the city.
- **Owning lane:** Playtest quality.
- **Requirement IDs:** ART-001, UX-001, UX-003, UX-004, UX-007, UX-009, UX-010, AUD-001, TEC-004, REL-005.
- **Dependencies:** Published PLAY-055 claim and preregistration baseline; exact clean PLAY-028 renderer and PLAY-054 UI candidate handoffs; final scoring occurs only after integration provides an exact combined candidate.
- **In scope:** Frozen pre-candidate regular/compact baselines; exact-candidate identity and staged-resource parity; R L1–L4 x N/E/S/W frontage/level matrix; city/neighborhood/block LOD; default/compact HUD typography, priority, metrics, Details, Overview, Journal, objectives, selection/rejection, pointer/keyboard/FKA/AX, Reduce Motion, grayscale/contrast, performance/residency, uncropped comparisons, defect ledger, and independent disposition.
- **Out of scope:** Product repair, source-art acceptance outside the reviewed Residential set, Commercial/Industrial scoring, coaching, candidate substitution, author evidence as independent disposition, or accepting manifest/test counts without live proof.
- **Work checklist:** Preregister rubric and baseline before candidate receipt; freeze exact process/window/state identity; independently inspect all 16 Residential identities and responsive HUD states; run affected critical journeys; compare exact same-state regular/compact frames; audit AX and focus; disclose performance/residency; return defects to owning lanes; commit disposition separately.
- **Acceptance:** Residential level progression and all four frontage directions score 4/4 and show no mirror, rotation, alias, fallback, wrong-road entrance, overlap, mixed projection/light, or unreadable city/neighborhood/block identity. HUD legibility/operability scores 4/4: critical text floors pass, priority/negative cashflow/utility/paused/action state is readable in one glance, compact Details exposes one complete actionable section and two complete notice summaries, and accepted 58% closed/45% open compact aperture floors hold. The combined candidate scores at least 19/20 with no category below 3, zero P0/P1 defects, zero automatic rejects, and material preference over the frozen baseline in both regular and compact comparisons.
- **Validation:** Exact staged build identity and source/resource hashes; focused renderer/UI tests; full native suite; pointer and keyboard build/inspect/undo; N/E/S/W fixture matrix; default and exact 900 x 600; 3x focus stability; FKA/AX/Reduce Motion; pack/residency/RSS/performance reports; `git diff --check`.
- **Proof:** Candidate-bound manifests, hashes, uncropped color and grayscale comparisons, directional/level contact sheets, Overview/Journal frames, AX trees, interaction ledger, performance logs, rejection records, and independent disposition under `docs/production/evidence/PLAY-055/`.
- **Stop conditions:** Missing exact candidate, stale or duplicate process, changed fixture between comparisons, cropped defect, author-authored score, visually hidden but AX-present information, one hero frame masking systemic failure, any fallback/mirror/alias/wrong frontage, unbounded resource growth, or quality-lane product mutation.
- **Current disposition:** Ready for baseline preregistration from the first published authority containing `docs/production/claims/PLAY-055.playtest-quality.md`; final candidate scoring remains blocked until integration supplies the exact combined PLAY-028/054 handoff.
