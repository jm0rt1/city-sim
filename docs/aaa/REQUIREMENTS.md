# AAA Release Requirements

## 1. Use of this document

These requirements define the minimum complete release. Every item is release-blocking unless it is explicitly superseded through the change-control process. Acceptance statements define the evidence expected; detailed thresholds live in the linked design and quality specifications.

## 2. Product requirements

### PRD-001 — City stewardship fantasy

**Requirement:** The player must shape the city's physical form, public priorities, resilience, identity, and long-term development, with material decisions producing visible and inspectable consequences.

**Acceptance:** Representative playtests show that players can identify their major decisions in the world and correctly explain the leading causes of at least the tested growth, congestion, fiscal, service, and environmental outcomes.

### PRD-002 — Complete play modes

**Requirement:** Release 1 must include a guided campaign, authored standalone scenarios, configurable sandbox, benchmark mode, and photo mode.

**Acceptance:** Every mode can be entered from a clean profile, completed or exited safely, saved where applicable, resumed, and used without developer tools.

### PRD-003 — Strategic variety

**Requirement:** The standard game must support multiple viable city forms and avoid one mandatory build order or universally superior policy package.

**Acceptance:** Balance evidence demonstrates at least dense transit-oriented, lower-density road-oriented, industrial-logistics, and green-service strategies reaching metropolis capability without exploits or creative-mode resources.

### PRD-004 — Consequence and recovery

**Requirement:** Financial, mobility, service, environmental, and disaster failures must be legible and normally recoverable through player action before any terminal condition.

**Acceptance:** Authored crisis fixtures expose warning, cause, escalating consequence, at least two recovery approaches, and a debrief; blind playtest participants recover without developer explanation at the approved rate.

### PRD-005 — Session continuity

**Requirement:** A new player must reach a meaningful construction choice within two minutes, and a returning player must understand the loaded city's active pressures within one minute.

**Acceptance:** Timed usability studies pass both journeys on supported baseline hardware, including a first-run profile and a mature autosave.

### PRD-006 — Approved release model

**Requirement:** The shipping scope, price, storefronts, online services, post-launch obligations, and expansion boundary must match an approved commercial decision while preserving offline core play and local save ownership.

**Acceptance:** The closed commercial and distribution decisions are reflected consistently in product behavior, store copy, privacy, support, entitlement, packaging, and recovery tests.

## 3. Simulation requirements

### SIM-001 — Deterministic outcomes

**Requirement:** Given the same compatibility version, content, initial state, seeds, ordered commands, and tick count, the authoritative simulation must reproduce the same approved outputs.

**Acceptance:** Golden replays pass state-hash or approved-tolerance checkpoints for 100 consecutive CI runs on every supported architecture.

### SIM-002 — Fixed cadence and speed equivalence

**Requirement:** Simulation state must advance on a fixed logical clock with pause and three forward speeds that change wall-clock pacing but not authoritative outcomes.

**Acceptance:** Equivalent command fixtures run at every speed and produce matching checkpoint state; overload visibly throttles speed rather than skipping ticks.

### SIM-003 — Commanded state ownership

**Requirement:** Only the simulation core may mutate gameplay state, and every player, scenario, or system action must enter through a typed command or declared deterministic system phase.

**Acceptance:** Architecture tests reject direct presentation mutation, command results are typed and inspectable, and system read and write sets pass contract validation.

### SIM-004 — Cross-system causality

**Requirement:** Population, economy, mobility, finance, utilities, services, governance, environment, construction, and progression must exchange declared data and create meaningful second-order effects.

**Acceptance:** Golden scenarios demonstrate and explain at least one bidirectional causal loop for every subsystem, without hidden global modifiers.

### SIM-005 — Scalable fidelity with conservation

**Requirement:** The simulation may change entity fidelity by relevance and scale, but transitions must preserve people, money, goods, trips, utility flow, and progression within approved rounding bounds.

**Acceptance:** Promotion and aggregation property tests pass at target scale, and long soaks show no unexplained creation or loss outside the declared tolerance.

### SIM-006 — Observable history

**Requirement:** Material state changes must emit enough structured event, ledger, trend, and provenance data for UI explanation, replay diagnosis, and support investigation.

**Acceptance:** Tested outcomes can be traced from current state through causal events to source commands or system inputs, with stable entity IDs and authoritative ticks.

## 4. Building and land requirements

### BLD-001 — Region and land model

**Requirement:** Every region must model terrain, buildability, water, ecology, resources, climate, outside connections, and hazards that materially affect construction and city outcomes.

**Acceptance:** Every launch region passes layer completeness and supports tested engineering, environmental, and growth tradeoffs without unreachable required content.

### BLD-002 — Complete network construction

**Requirement:** Players must be able to plan, build, upgrade, and remove roads and paths with curves, intersections, bridges, tunnels, snapping, grade rules, and network-type constraints.

**Acceptance:** The construction suite covers valid and blocked geometry, local graph rebuild, cost, demolition, undo-safe planning, save round trip, and visual seams.

### BLD-003 — Zoning and development lifecycle

**Requirement:** Residential, commercial, industrial, office or mixed employment, and mixed-use zoning must create demand-driven development through construction, occupancy, operation, upgrade, decline, abandonment, and redevelopment.

**Acceptance:** Deterministic fixtures exercise every lifecycle state and prove that access, demand, land value, utilities, labor, policy, and environment influence eligibility and outcome.

### BLD-004 — Project preview and commitment

**Requirement:** Construction tools must preview legality, footprint, acquisition, demolition, direct cost, operating cost, capacity, access, major consequences, and uncertainty before authoritative commitment.

**Acceptance:** Usability and contract tests cover legal, blocked, unaffordable, destructive, uncertain, grouped, paused, canceled, and partially completed projects.

### BLD-005 — Demolition and relocation consequences

**Requirement:** Demolition and eligible relocation must account for displaced households and jobs, network impact, waste, historical loss, cost, critical dependencies, and affected objectives.

**Acceptance:** Preview and post-command results reconcile every declared impact, and critical inhabited or network assets require the approved confirmation level.

### BLD-006 — Districts and local identity

**Requirement:** Players must be able to name and edit districts whose shared boundaries drive statistics, policies, service priorities, objectives, and visual identity.

**Acceptance:** Boundary edits update all dependent queries deterministically, survive save and load, and avoid orphaned policy or history records.

## 5. Mobility requirements

### MOB-001 — Purpose-based trips

**Requirement:** Households, businesses, freight, services, visitors, and outside connections must generate trips with origin, destination, purpose, time, urgency, and completion outcome.

**Acceptance:** Demand fixtures reconcile generated, canceled, completed, failed, and aggregated trips against their source activities and capacities.

### MOB-002 — Mode and route choice

**Requirement:** Travelers must choose among available walking, driving, transit, freight, service, and approved micromobility options using time, cost, transfers, reliability, parking, comfort, policy, and access.

**Acceptance:** Controlled network tests produce explainable choices, stable tie-breaking, bounded rerouting, and no path across disconnected or forbidden links.

### MOB-003 — Road operations

**Requirement:** Traffic must respond to lanes, direction, speed, intersections, signals, merging, parking access, incidents, restrictions, and service priority.

**Acceptance:** Micro and city-scale fixtures validate capacity, queue propagation, turning, blocking, priority, deadlock recovery, and graph edits within performance budgets.

### MOB-004 — Public transit operations

**Requirement:** Players must create and operate transit lines with compatible stops, paths, depots, vehicles, frequency, capacity, fares, staffing, budget, reliability, and transfer behavior.

**Acceptance:** At least one bus-like and one rail-like launch mode complete the line lifecycle, report every invalid state, and carry traced passenger journeys through transfers.

### MOB-005 — Freight and municipal movement

**Requirement:** Freight and municipal services must obey network access, vehicle, loading, depot, schedule, capacity, and route constraints while supporting bounded emergency priority.

**Acceptance:** Logistics and emergency fixtures prove delayed and completed deliveries, dispatch, access failure, congestion interaction, and recovery without teleportation.

### MOB-006 — Mobility diagnosis

**Requirement:** Players must be able to inspect congestion, delay, reliability, mode share, parking, freight, transit, and failed-trip causes from region to individual-link scale.

**Acceptance:** Blind diagnostic tasks lead players from a citywide symptom to the causal links, destinations, or capacity constraints using overlays and inspectors.

## 6. Economy requirements

### ECO-001 — Reconciled treasury ledger

**Requirement:** Every treasury change must be represented by a timestamped, categorized ledger entry with amount, source, and related entity or policy.

**Acceptance:** Treasury equals opening balance plus ledger entries at every checkpoint, including construction, operations, taxes, grants, imports, debt, and disaster flows.

### ECO-002 — Budgets, debt, and fiscal recovery

**Requirement:** Service budgets and debt instruments must expose their capacity, quality, staffing, maintenance, interest, term, payment, credit, and recovery effects.

**Acceptance:** Fiscal scenarios cover surplus, deficit, borrowing, covenant pressure, default prevention, emergency aid, and recovery with fully reconciled statements.

### ECO-003 — Businesses and employment

**Requirement:** Businesses must occupy eligible buildings, hire reachable workers, consume inputs, sell outputs, and expand, contract, relocate, or fail under explainable conditions.

**Acceptance:** Market fixtures demonstrate unemployment alongside vacancies, skill and access mismatch, business lifecycle, wage and cost pressure, and stable save round trips.

### ECO-004 — Derived development demand

**Requirement:** Residential and business demand indicators must derive from viable unmet development conditions and expose their major positive and negative components.

**Acceptance:** Changing vacancies, income, access, land, costs, policy, and macro pressure moves the correct components and produces explainable development response.

### ECO-005 — Land and property value

**Requirement:** Land and property values must respond to access, permitted use, services, jobs, amenities, environment, safety, congestion, taxation, hazard, and disamenities without causing instantaneous unexplained displacement.

**Acceptance:** Golden districts show expected relative responses, history, revenue effects, rents or cost pressure, and staged redevelopment or moves.

### ECO-006 — Production, freight, and external trade

**Requirement:** Production classes must consume inputs, use storage, create freight, produce outputs, trade through finite outside connections, and lose output when logistics fail.

**Acceptance:** Production-chain fixtures conserve goods and money, expose bottlenecks, respect gateway capacity and price, and recover after network restoration.

## 7. Population requirements

### POP-001 — Persistent household model

**Requirement:** The city must retain household identity, home, composition or cohort, income, work, education, life stage, access, needs, satisfaction, and migration history at the approved fidelity.

**Acceptance:** Household lifecycle fixtures remain internally consistent across births or cohort change, work, moves, displacement, departure, aggregation, and save migration.

### POP-002 — Multidimensional wellbeing

**Requirement:** Household outcomes must derive from housing, employment, travel, safety, health, education, utilities, environment, recreation, social access, taxation, and shocks rather than one hidden happiness rule.

**Acceptance:** Inspectors expose distributions and leading drivers, and controlled changes affect only declared paths with bounded lag.

### POP-003 — Migration with real eligibility

**Requirement:** Arrival, departure, and internal moves must compare households with viable housing, opportunity, access, cost, and outside alternatives.

**Acceptance:** No household occupies nonexistent housing or impossible jobs; migration fixtures explain rejected moves, vacancies, departures, and recovery.

### POP-004 — Housing, displacement, and equity

**Requirement:** The game must distinguish housing supply, occupancy, quality, cost pressure, eviction, disaster displacement, redevelopment displacement, and voluntary moves, and report outcomes by district and household group.

**Acceptance:** Housing scenarios reconcile people and units, retain cause, and expose distributional service, travel, pollution, and fiscal effects without assigning demographic moral scores.

### POP-005 — Demographic and city history

**Requirement:** Age or life-stage, education, income, household, and migration distributions must evolve over time and feed services, labor, housing, and historical views.

**Acceptance:** Long-run fixtures remain within population conservation rules, produce expected cohort transitions, and preserve comparable historical series across saves.

## 8. Governance and service requirements

### GOV-001 — Connected utilities

**Requirement:** Power, water, wastewater, waste, and communications must model supply, demand, connectivity, capacity, quality, cost, resilience, and bounded import where relevant.

**Acceptance:** Utility fixtures cover normal flow, shortage, disconnection, import, storage where applicable, dependency cascade, repair, and clear cause tracing.

### GOV-002 — Delivered public services

**Requirement:** Fire, safety, healthcare, education, parks, waste, maintenance, and administration outcomes must account for access, travel, staffing, capacity, quality, budget, and demand rather than coverage radius alone.

**Acceptance:** Coverage and delivered-outcome views diverge correctly under tested congestion, staffing, funding, and capacity failures.

### GOV-003 — Asset maintenance and lifecycle

**Requirement:** Networks and civic assets must age, wear, damage, receive maintenance, degrade visibly, and fail or recover according to use, budget, access, and risk.

**Acceptance:** Accelerated lifecycle fixtures show warnings, rising cost or reduced performance, failure, repair projects, and restored state with ledger reconciliation.

### GOV-004 — Policies with tradeoffs

**Requirement:** City and district policies must declare scope, eligibility, cost, lead time, administration, direct effects, side effects, and repeal consequences.

**Acceptance:** Policy fixtures prove staged activation and repeal, budget effects, targeted outcomes, public response, and no unlisted hidden modifier.

### GOV-005 — Objectives and progression

**Requirement:** Milestones, mandates, campaign goals, scenarios, and pinned metrics must expose current value, target, trend, persistence, deadline, diagnostic link, pass or fail rules, and reward.

**Acceptance:** Objective tests prevent transient false completion, preserve progress through saves, explain failure, and unlock coherent capability rather than unexplained global bonuses.

### GOV-006 — Incident and recovery lifecycle

**Requirement:** Local incidents and civic crises must progress through readiness, warning where plausible, impact, response, recovery, and review with spatial and systemic consequences.

**Acceptance:** Authored incident fixtures validate dispatch, damage, displacement, finance, service dependencies, recovery projects, resilience changes, and seeded replay.

## 9. Environment requirements

### ENV-001 — Environmental sources and exposure

**Requirement:** Air, water, ground, noise, heat, habitat, canopy, and emissions must derive from sources, spread or transport, exposure, and mitigation.

**Acceptance:** Environmental fixtures conserve relevant quantities or indices, show spatial propagation, and affect declared health, value, business, policy, and reputation paths.

### ENV-002 — Weather and seasons

**Requirement:** Region-appropriate weather and seasons must affect presentation and selected travel, demand, utilities, water, ecology, fire, and maintenance rules within visible bounds.

**Acceptance:** Seeded weather replays produce synchronized simulation, visual, audio, and UI state; accessibility settings retain critical readability.

### ENV-003 — Disaster preparation and recovery

**Requirement:** Major disasters must use spatial hazard, exposure, vulnerability, readiness, impact, response, aid, recovery, and adaptation rather than arbitrary citywide damage.

**Acceptance:** Flood, storm, fire, heat, and one geologic launch fixture each demonstrate preparation value, causal damage, service response, recovery choice, and sandbox disable controls.

### ENV-004 — Water and terrain interaction

**Requirement:** Terrain, shoreline, water flow or extent, drainage, engineering, and terraforming must interact without silently deleting assets or creating hidden invalid states.

**Acceptance:** Terrain and water suites cover slope, bridge and tunnel interfaces, flood extent, drainage, invalid previews, ecological effects, and save stability.

## 10. Experience requirements

### UX-001 — Native macOS shell

**Requirement:** The game must provide native lifecycle, menus, shortcuts, settings, windows, full-screen behavior, help, accessibility integration, and safe termination.

**Acceptance:** Clean-machine journeys pass across supported macOS versions, displays, input devices, sleep and wake, Spaces, and quit during save or load boundaries.

### UX-002 — Legible HUD

**Requirement:** The HUD must summarize frequently changing city state with exact values on demand, trends, periods, warnings, source links, labels, and adaptable density.

**Acceptance:** Usability and accessibility tests show players can identify treasury, time, population, employment, sentiment, active objectives, alerts, and simulation speed without color-only cues.

### UX-003 — Precise camera and input

**Requirement:** Camera and navigation must support smooth, frame-independent pan, zoom around pointer, rotation, bounded pitch, focus, bookmarks, cinematic movement, and configurable sensitivity across supported devices.

**Acceptance:** Input tests pass at supported frame rates with mouse, trackpad, Magic Mouse, and keyboard, including reduced motion and interruption of camera animations.

### UX-004 — Consistent tool state

**Requirement:** Construction and editing tools must share a predictable inactive, selected, preview, adjust, confirm, commit, and outcome state model with progressive cancel and safe undo where applicable.

**Acceptance:** Critical tool journeys pass legal, blocked, unaffordable, destructive, multi-step, canceled, undo, and panel-interruption cases without hidden state.

### UX-005 — Inspectors, overlays, and charts

**Requirement:** Players must be able to move from summary to world location, entity details, causal dependencies, historical trends, comparison, overlay, and raw owned data where appropriate.

**Acceptance:** Blind tasks diagnose representative mobility, finance, utility, service, housing, and environment problems; charts have keyboard values and table alternatives.

### UX-006 — Actionable notification system

**Requirement:** Notifications must use bounded urgency, aggregate repetition, retain history, identify place and cause, explain consequence, and link to one useful diagnostic or action.

**Acceptance:** Alert-load tests show no dropped critical event, no repeated minor spam beyond thresholds, correct auto-pause preferences, and accessible visual or audio equivalents.

### UX-007 — Safe save and load experience

**Requirement:** Players must have manual, quick, rotating autosave, named branch, scenario checkpoint, metadata, integrity, migration, conflict, and recovery experiences that never report false success.

**Acceptance:** Save journeys pass normal, low-disk, interrupted, corrupted-copy, old-version, missing-content, conflict if supported, and original-backup cases.

### UX-008 — Progressive onboarding and help

**Requirement:** The game must teach core play in context, recognize alternate valid solutions, provide optional hints, and include searchable concept, formula, control, accessibility, and glossary help.

**Acceptance:** New-player studies complete the first-hour curriculum without external instructions, and experienced players can skip and reset guidance without losing game capability.

### UX-009 — Accessibility floor

**Requirement:** Release must provide VoiceOver coverage for non-spatial critical paths, scalable UI, high contrast, color-vision support, non-color cues, remapping, timing alternatives, subtitles, audio alternatives, reduced motion, flash controls, and pause access.

**Acceptance:** The declared accessibility critical-path suite passes automated API inspection, expert manual review, and participant testing with retained conformance evidence.

### UX-010 — Responsive display behavior

**Requirement:** Windowed, borderless full-screen, and native full-screen layouts must remain usable across supported resolutions, aspect ratios, scale factors, display changes, and minimum window size.

**Acceptance:** Visual and interaction suites show no clipped critical control, unreadable text, lost input, invalid camera, or corrupted layout during live display transitions.

## 11. Art requirements

### ART-001 — Approved readable visual direction

**Requirement:** Region, city, neighborhood, and street views must follow an approved visual style and camera grammar that make land, networks, density, activity, prosperity, strain, and hazards readable.

**Acceptance:** The closed style decision includes approved look targets and blind readability evidence across representative cities, weather, night, overlays, and accessibility modes.

### ART-002 — Complete launch content floor

**Requirement:** The release must meet the approved region, building, network, service, landmark, vehicle, citizen, animation, and variation content floor without visibly unfinished required states.

**Acceptance:** Content inventory, automated validation, art review, repetition review, localization, placement, balance, save, and performance evidence are complete for every launch asset.

### ART-003 — Dynamic environment presentation

**Requirement:** Day, night, seasons, weather, water, terrain, lighting, emissives, and operational power state must present consistently with simulation and retain gameplay readability.

**Acceptance:** Golden captures and live review pass every required state, quality tier, overlay, and accessibility combination without contradictory or obscured critical information.

### ART-004 — Truthful animation and effects

**Requirement:** Citizens, vehicles, construction, utilities, services, incidents, disasters, repairs, and civic life must animate from authoritative intent with scalable LOD and restrained feedback effects.

**Acceptance:** State-to-animation contracts, crowd truth tests, VFX accessibility variants, visual review, and performance captures pass in mature cities.

### ART-005 — Asset and scene budgets

**Requirement:** Every asset must declare and pass LOD, material, texture, triangle, draw, rig, animation, collision, shadow, state, and memory budgets, with measured golden-city scene limits.

**Acceptance:** Import rejects invalid assets, no unapproved hero exception breaches the scene envelope, and LOD or streaming transitions remain within visual tolerance.

## 12. Audio requirements

### AUD-001 — Adaptive score

**Requirement:** Music must respond to city phase, time, region, pressure, disaster, recovery, and achievement through non-repetitive, phrase-aware transitions and player frequency controls.

**Acceptance:** The approved music floor is delivered, transition tests avoid clipping or thrashing, long-session repetition stays within target, and all mix controls persist.

### AUD-002 — State-driven city ambience

**Requirement:** Region, district, traffic, transit, industry, crowd, nature, weather, service, and incident ambience must derive from current world state and camera context.

**Acceptance:** Blind listening and state tests distinguish representative areas and events, remain consistent with closures and time, and scale within voice and CPU budgets.

### AUD-003 — Action feedback and hearing access

**Requirement:** Important commands, failures, saves, objectives, and alerts must have synchronized, restrained sonic feedback plus subtitles or visual equivalents, category volumes, dynamic range, and mono support.

**Acceptance:** Feedback never precedes authoritative success, critical paths pass muted and mono tests, and hearing-access settings retain equivalent information.

## 13. Technical requirements

### TEC-001 — Native modular architecture

**Requirement:** The shipping runtime must separate native app shell, coordinator, deterministic simulation, world, gameplay systems, presentation snapshot, renderer, UI, audio, persistence, content tools, and diagnostics with explicit ownership.

**Acceptance:** Approved ADRs and architecture tests enforce boundaries, and no prototype-only dependency remains on the shipping path without a retired replacement plan.

### TEC-002 — Production 3D renderer

**Requirement:** The approved renderer must deliver the complete 3D terrain, networks, buildings, agents, lighting, weather, effects, overlays, picking, LOD, streaming, and photo-mode target natively on supported Macs.

**Acceptance:** The Gate 2 vertical slice uses production architecture and passes visual, input, stability, and measured GPU budgets on baseline and target hardware.

### TEC-003 — Mature-city performance

**Requirement:** The production runtime must meet approved frame, simulation, input, memory, startup, load, and save budgets on the supported golden-city workload.

**Acceptance:** The 95th-percentile hardware benchmark matrix passes with no hidden quality reduction below the declared tier and no unbounded long-session trend.

### TEC-004 — Versioned persistence and replay

**Requirement:** Saves must be atomic, versioned, integrity-checked, recoverable, migration-tested, content-aware, and capable of deterministic replay diagnostics without serializing presentation state.

**Acceptance:** The supported save corpus, corruption suite, compatibility suite, replay suite, rotation policy, and clean recovery journeys all pass.

### TEC-005 — Data-authored content and tools

**Requirement:** Gameplay and launch content must use stable IDs, versioned schemas, validated dependencies, compiled packages, designer-facing tools, CI validation, localization, and change-impact reporting.

**Acceptance:** Designers can author and tune a complete scenario and region without engine recompilation; invalid content fails with actionable diagnostics before release packaging.

### TEC-006 — Security and privacy

**Requirement:** The game must treat saves, content, mods, localization, and support packages as untrusted; minimize personal data; secure official packages; and preserve full core play without optional telemetry.

**Acceptance:** Threat model, static and dynamic review, malformed-input corpus, privacy review, consent tests, dependency inventory, and release-signing controls pass.

### TEC-007 — Safe content dependency and mod boundary

**Requirement:** Saves and content packages must declare stable dependencies and load order, reject missing or changed requirements safely, and prevent untrusted arbitrary native execution whether or not public mods ship.

**Acceptance:** Dependency, package, removal, mismatch, malicious-input, and save-reporting tests pass against the approved mod-support scope.

### TEC-008 — Diagnostics and support reproduction

**Requirement:** The runtime must expose structured logs, metrics, state hashes, command provenance, performance captures, crash context, benchmark mode, and a previewable privacy-safe support package.

**Acceptance:** QA and support reproduce defined crash, performance, progression, and save issues from retained diagnostics without requiring a developer build.

## 14. Release requirements

### REL-001 — Audited requirement gates

**Requirement:** Every release requirement must have approved design, implementation, verification, owner, and status, with no design or implementation gaps at release candidate.

**Acceptance:** Automated matrix validation and human release review find no missing, duplicate, orphaned, or falsely mapped requirement.

### REL-002 — Golden replay qualification

**Requirement:** The complete golden-city and scenario corpus must pass correctness, determinism, balance invariants, visual snapshots, performance envelopes, and save round trips.

**Acceptance:** One hundred consecutive protected-branch runs pass on supported architectures before launch approval.

### REL-003 — Stability and soak qualification

**Requirement:** The release must pass crash, hang, memory, long-session, repeated lifecycle, display transition, sleep, audio-device, and adverse I/O qualification.

**Acceptance:** Quantitative stability gates in the quality specification pass with zero open Priority 0 or Priority 1 defects.

### REL-004 — Save and update compatibility

**Requirement:** Every release and hotfix must preserve the approved save-read window, migrate on copies, reject unsupported downgrade safely, and retain rollback artifacts.

**Acceptance:** The full save corpus passes source-to-target migration, old-build rejection, update, rollback, missing-content, and recovery tests.

### REL-005 — Accessibility qualification

**Requirement:** Accessibility features and critical paths must be complete in code, content, localization, help, packaging, and support before release candidate.

**Acceptance:** Automated, expert, and participant testing passes; known limitations are accurate, approved, and published; no Priority 1 accessibility defect remains.

### REL-006 — Localization and culturalization

**Requirement:** Every approved launch language must have complete text, fonts, layout, numbers, dates, currencies, names, subtitles, assets, cultural review, QA, store copy, and support readiness.

**Acceptance:** Localization reports show no missing or truncated release text, language-specific test suites pass, and named reviewers approve sensitive content.

### REL-007 — Signed and notarized distribution

**Requirement:** The immutable release artifact must be reproducibly built, signed, notarized, installed, launched, updated, diagnosed, and removed as documented on clean supported Macs.

**Acceptance:** Release pipeline evidence, checksums, symbols, manifests, software bill of materials, Gatekeeper checks, and clean-machine journeys pass for every approved channel.

### REL-008 — Launch content completion

**Requirement:** All campaign, scenario, sandbox, building, network, vehicle, citizen, visual, audio, tutorial, encyclopedia, achievement, and marketing-represented content must be final and internally consistent.

**Acceptance:** The approved content inventory has no placeholder, missing dependency, unlocalized item, budget breach, unresolved legal issue, or untested required state.

### REL-009 — Support, incident, and rollback readiness

**Requirement:** Launch must have staffed ownership, player communication, known issues, diagnostic intake, save recovery, severity triage, hotfix, rollback, and post-launch stabilization procedures.

**Acceptance:** A launch-incident rehearsal completes from detection through player communication, candidate fix, compatibility test, release approval, deployment, and rollback.

### REL-010 — Legal, privacy, credits, and store compliance

**Requirement:** The product, content, dependencies, music, fonts, telemetry, privacy disclosures, accessibility claims, credits, licenses, age rating, and storefront materials must be reviewed and approved for every channel and launch region.

**Acceptance:** Release records contain all approvals and artifacts with no unresolved blocking claim, license, privacy, security, or platform-policy issue.

