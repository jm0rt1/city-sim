# Quality and Release Operations

## 1. Quality policy

CitySim ships when the complete player experience is proven on supported hardware, not when a feature checklist reaches nominal completion. Quality evidence must cover real mature cities, long saves, adverse conditions, accessibility settings, clean-machine installation, and recovery from failure.

Every release requirement has an owner, implementation evidence, verification evidence, and current status in [TRACEABILITY_MATRIX.md](TRACEABILITY_MATRIX.md). A milestone cannot waive an unknown state; it can only accept a named, time-bounded risk with an owner and fallback.

## 2. Quality attributes

The release quality bar is evaluated across:

- Correctness and deterministic simulation.
- Meaningful, balanced, and explainable gameplay.
- Readability and visual truthfulness.
- Input responsiveness and native macOS behavior.
- Performance and scalability in mature cities.
- Stability, memory safety, and long-session integrity.
- Save durability, migration, and recovery.
- Accessibility and adaptable presentation.
- Content completeness, localization, and cultural care.
- Security, privacy, packaging, update, and support readiness.

Passing one attribute cannot compensate for a release-blocking failure in another.

## 3. Defect severity

| Severity | Definition | Release policy |
| --- | --- | --- |
| Priority 0 | Data loss, security compromise, widespread inability to launch or save, deterministic corruption, or platform-harming behavior | Stop-ship; no waiver |
| Priority 1 | Crash or progression blocker in supported play, major simulation falsehood, inaccessible critical path, severe performance breach, or broken distribution flow | Zero open at release candidate |
| Priority 2 | Material gameplay, presentation, compatibility, or usability defect with a viable workaround | Requires owned disposition; strict cap approved at RC |
| Priority 3 | Minor polish, rare cosmetic, text, or low-impact inconsistency | May ship only if documented and scheduled appropriately |

Duplicate symptoms with one root cause retain the highest observed severity. A defect is closed only with a regression test or a written reason that automation is not appropriate plus retained manual evidence.

## 4. Verification layers

### 4.1 Static and content validation

Every change runs formatting, compiler warnings, dependency checks, API compatibility, schema validation, content references, localization completeness, asset budgets, license checks, and forbidden-debug-setting checks.

### 4.2 Unit and property tests

Pure rules, formulas, ledgers, random streams, geometry, route cost, capacity, migration, serialization, and state transitions receive deterministic unit tests. Property tests cover conservation, nonnegative constraints, bounded rates, order independence where promised, and round trips.

### 4.3 Contract and integration tests

Tests verify command results, system read and write boundaries, event schemas, presentation snapshots, content packages, save manifests, platform adapters, renderer data, audio triggers, and management workspace queries.

### 4.4 Simulation replay and golden cities

Golden fixtures represent:

- First settlement.
- Growing mixed-use town.
- Congested mature city.
- Transit-oriented city.
- Industrial logistics hub.
- Financial crisis and recovery.
- Utility cascade failure.
- Major disaster and recovery.
- 250,000-resident-equivalent benchmark city.
- Migrated save from every supported compatibility version.

Each fixture has initial state, content set, seeds, command stream, state-hash checkpoints, expected invariant ranges, screenshots at named camera bookmarks, performance envelope, and known narrative outcomes. Exact numeric hashes are used where the determinism contract permits; otherwise the approved tolerance is explicit.

### 4.5 Render and visual validation

Automated captures cover camera bookmarks, time, weather, seasons, construction, damage, overlays, UI scale, display scale, quality tiers, and accessibility modes. Image comparisons detect missing assets, shader failures, layout regressions, network seams, LOD popping beyond tolerance, and contradictory world state.

Human art and UX review remains required for composition, repetition, motion quality, readability, color, cultural context, and fatigue.

### 4.6 UX and accessibility validation

Critical journeys are scripted for new player, returning player, keyboard-only player, VoiceOver user, reduced-motion user, color-vision presets, large interface scale, trackpad, mouse, and controller if supported. Accessibility testing includes automated API inspection, manual assistive-technology review, and participant testing.

### 4.7 Performance and soak testing

Continuous benchmarks record frame, simulation, memory, allocations, streaming, shader, save, load, startup, and input latency on golden cities. Nightly runs include:

- One-hour active mature-city play.
- 24-hour accelerated simulation soak.
- 100-hour logical city advancement with periodic saves and loads.
- Repeated open, save, quit, launch, and load cycles.
- Window, display, sleep, full-screen, graphics-tier, and audio-device changes.
- Low-disk, interrupted save, missing content, and corrupted-copy recovery.

Memory growth must plateau within the approved cache envelope. Any unbounded trend blocks the stability gate even if the process has not yet exhausted memory.

### 4.8 Packaging and clean-machine tests

Signed release candidates are installed on clean supported machines with no developer tools. Tests cover first launch, Gatekeeper, permissions, save locations, updates, downgrade rejection, uninstall expectations, offline play, missing network, multiple displays, sleep, crash restart, support export, and notarization validation.

## 5. Test environments

The final matrix is approved with the hardware decision and includes:

- Baseline supported Apple silicon and memory tier.
- Target recommended Apple silicon tier.
- High-end tier and high-resolution display.
- Every supported macOS major version.
- Integrated display and common external-display scale combinations.
- Mouse, trackpad, Magic Mouse, keyboard layouts, audio outputs, and controller if approved.
- English plus representative long-string, double-byte, and right-to-left pseudo-locales before final languages are locked.

Unsupported hardware may run only if the product communicates that status; it cannot weaken supported-tier gates.

## 6. Quantitative release gates

Unless superseded by an approved decision, release candidate requires:

- Zero open Priority 0 and Priority 1 defects.
- No reproducible save loss or unrecoverable migration failure in the supported corpus.
- All deterministic golden replays passing for 100 consecutive continuous-integration runs on supported architectures.
- Performance budgets in [06_TECHNICAL_ARCHITECTURE.md](06_TECHNICAL_ARCHITECTURE.md) passing at the 95th percentile on every supported tier.
- No unbounded memory growth in a 24-hour soak and no material corruption after 100 logical hours.
- At least 99.8 percent crash-free internal and external test sessions once sample size is statistically useful, with every crash cluster triaged.
- 100 percent pass for launch, new city, load, save, quit, recovery, and clean-install critical journeys.
- 100 percent pass for the declared keyboard and accessibility critical-path suite.
- All launch content at final art, audio, localization, balance, performance, and legal status.
- Signed package installation, notarization, update, rollback, and support export proven from clean machines.

Telemetry percentages are supporting evidence, not permission to ignore reproducible defects.

## 7. Production gates

### Gate 0 — Release contract approval

Exit requires approved vision, gameplay, content, experience, technical target, requirement set, decision owners, staffing model, schedule ranges, risk register, and funding authority. No full production staffing is assumed before this gate.

### Gate 1 — Production architecture spike

Exit requires engine and renderer approval, determinism proof, save-format draft, content-pipeline proof, region streaming prototype, representative agent rendering, hardware measurements, accessibility architecture, and retired critical unknowns.

### Gate 2 — AAA vertical slice

Exit requires one polished district-scale scenario with final-quality world art, native UI, audio, construction, zoning, traffic, population, economy, utilities, service response, incident, objective, save and load, and measured target-tier performance. The slice uses production architecture and content pipeline.

### Gate 3 — Production readiness

Exit requires stable pipelines, feature teams, automated builds, golden cities, test environments, outsourcing interfaces, localization workflow, performance dashboards, save migration policy, and a credible burn-up against release requirements.

### Gate 4 — Alpha

Alpha is feature-complete: all release systems function end to end, all launch modes are playable, saves are durable, content can be completed without engine changes, and every requirement has implementation evidence. Placeholder polish may remain but cannot hide a missing loop.

### Gate 5 — Beta

Beta is content-complete: launch regions, campaign, scenarios, assets, music, voice, text, accessibility, localization, tutorials, and balance are integrated. Only fixes, measured optimization, and approved polish enter after the beta lock.

### Gate 6 — Release candidate

RC is code- and content-frozen except for stop-ship fixes. All quantitative gates pass, legal and privacy approval is complete, storefront metadata and support materials are final, and signed packages are tested from clean machines.

### Gate 7 — Launch approval

Launch approval requires named executive, product, creative, engineering, production, QA, accessibility, security, privacy, legal, support, and release-engineering sign-off; rollback capability; staffed incident rotation; and verified player communication channels.

### Gate 8 — Post-launch stabilization

For the defined stabilization window, the team monitors crash, save, performance, support, accessibility, and progression issues; publishes known issues; preserves hotfix compatibility; and completes a release retrospective before expansion work takes priority.

## 8. Balance and playtest program

Balance is validated through telemetry-enabled internal runs, deterministic bots where useful, designer reviews, and human playtests across skill levels. Tests examine:

- Viability of distinct city forms.
- Opening variety and avoidance of mandatory build order.
- Time to diagnose and recover from major pressures.
- Fiscal and service curves across city tiers.
- Transit, driving, freight, and walking competitiveness.
- Housing, employment, pollution, and access distributions.
- Disaster preparation value and recovery burden.
- Campaign learning and scenario replayability.
- Alert fatigue, panel usage, and overlay comprehension.

Balance changes after beta require replay comparison, save impact review, scenario revalidation, and explicit production approval.

## 9. Save compatibility operations

Every release candidate is tested against the complete supported save corpus. Migration runs on copies and records source version, target version, transformations, warnings, validation, and duration. A migration failure leaves the original untouched and produces an actionable support package.

Hotfixes within a release line must read all earlier saves from that line. Downgrades are not promised; the launcher or app must reject them safely rather than corrupting data. Content removal requires fallback or an explicit incompatible-package flow.

## 10. Build and release pipeline

The protected release pipeline produces reproducible versioned artifacts from reviewed source and content:

1. Resolve locked dependencies and verify provenance.
2. Build all code and tools in release mode.
3. Compile and validate content and localization.
4. Run unit, integration, replay, save, asset, and policy checks.
5. Run required hardware performance and visual suites.
6. Assemble the app and legal notices.
7. Sign, notarize, staple, and validate the package.
8. Generate symbols, manifest, checksums, software bill of materials, and support metadata.
9. Promote the same immutable artifact through candidate channels.
10. Publish only after launch approval, with rollback artifact retained.

Secrets remain in approved release infrastructure. Developer-local signing is not evidence of production readiness.

## 11. Privacy, telemetry, and support

The game remains fully playable when optional analytics are declined. Consent is specific, revocable, and explained in plain language. Crash or usage data uses data minimization, retention limits, access controls, and deletion paths appropriate to the approved distribution model.

Support documentation covers installation, performance settings, saves and backups, migration, accessibility, mods if supported, known issues, and diagnostic export. Support staff receive a versioned troubleshooting tree and escalation path for save corruption, crashes, performance, and progression blockers.

## 12. Release acceptance record

The launch record retains requirement-matrix snapshot, open-defect list, approved waivers, build and content hashes, test reports, benchmark reports, accessibility conformance report, save-corpus results, notarization evidence, licenses, privacy approval, store approval, support readiness, rollback plan, and all named sign-offs.

