# CitySim AAA Release Specification

| Field | Value |
| --- | --- |
| Product | CitySim |
| Release program | New Arcadia |
| Specification version | 0.1 |
| Status | Draft for product and production approval |
| Platform | Native macOS |
| Last updated | 2026-07-16 |

This directory defines the release contract for a premium, native macOS city-building game. It turns the current playable vertical slice and the repository's subsystem research into one coherent target for product, design, art, audio, engineering, production, QA, and release operations.

The release is not complete because every item in this pack is described. It is complete only when every release requirement is mapped to approved design, implemented, verified with retained evidence, and accepted through the gates in [07_QUALITY_RELEASE_OPERATIONS.md](07_QUALITY_RELEASE_OPERATIONS.md).

## Product promise

CitySim gives the player a legible, beautiful, and consequential city to steward. Every important decision should create visible change in the world, measurable change in the simulation, and understandable feedback in the interface. The player should be able to build freely, diagnose problems deeply, recover from mistakes, and feel that the city has a life beyond the spreadsheet.

## Release boundary

The full release is:

- A native macOS application designed first for Apple silicon.
- A premium-quality single-player city builder with sandbox, guided campaign, and authored scenario play.
- Offline-first for simulation, saves, and core content.
- A deterministic simulation with versioned saves and replayable test fixtures.
- A fully 3D, scalable city presentation with a native desktop interface.
- Shippable through a signed and notarized direct-download package, with Mac App Store distribution evaluated separately.

Release 1 does not include competitive multiplayer, an always-online economy, mobile platforms, or direct third-person control of an individual citizen. Those exclusions can only change through the decision process in [08_OPEN_DECISIONS.md](08_OPEN_DECISIONS.md).

## Specification map

| Document | Contract |
| --- | --- |
| [01_PRODUCT_VISION.md](01_PRODUCT_VISION.md) | Audience, fantasy, pillars, play modes, loops, outcomes, and non-goals |
| [02_GAMEPLAY_SYSTEMS.md](02_GAMEPLAY_SYSTEMS.md) | Rules and interactions of the complete city simulation |
| [03_CONTENT_AND_PROGRESSION.md](03_CONTENT_AND_PROGRESSION.md) | Launch content, campaign, scenarios, milestones, authoring, and localization |
| [04_UX_ACCESSIBILITY.md](04_UX_ACCESSIBILITY.md) | Native interaction model, HUD, camera, onboarding, accessibility, and input |
| [05_VISUAL_AUDIO_DIRECTION.md](05_VISUAL_AUDIO_DIRECTION.md) | World presentation, art pipeline, animation, music, ambience, and feedback |
| [06_TECHNICAL_ARCHITECTURE.md](06_TECHNICAL_ARCHITECTURE.md) | Runtime boundaries, renderer, data model, saves, tooling, and performance budgets |
| [07_QUALITY_RELEASE_OPERATIONS.md](07_QUALITY_RELEASE_OPERATIONS.md) | Test strategy, milestones, release gates, packaging, telemetry, and support |
| [08_OPEN_DECISIONS.md](08_OPEN_DECISIONS.md) | Unresolved choices, owners, deadlines, and safe defaults |
| [REQUIREMENTS.md](REQUIREMENTS.md) | Stable release requirements and acceptance criteria |
| [TRACEABILITY_MATRIX.md](TRACEABILITY_MATRIX.md) | Design, implementation, and verification status for every requirement |
| [RELEASE_BACKLOG.md](RELEASE_BACKLOG.md) | Production sequence, work packages, dependencies, and exit criteria |

## Design authority

When documents disagree, use this order:

1. Approved decisions recorded in [08_OPEN_DECISIONS.md](08_OPEN_DECISIONS.md) or a superseding ADR.
2. The approved documents in this `docs/aaa` release pack.
3. The subsystem contracts in `docs/specs`, `docs/architecture`, and `docs/adr`.
4. The roadmap and workstream documents in `docs/design/workstreams`.
5. The current native vertical-slice implementation under `Native/CitySimNative` as evidence of what exists, not proof of final scope.
6. The legacy Python implementation as a behavior reference and migration source.

`docs/DESIGN_SPEC.md` and `docs/COPILOT_PLAN.md` describe a separate developer-workflow tool and are not CitySim product authority.

## Requirement identifiers

Requirement IDs are permanent and are never reused:

- `PRD`: product promise and modes
- `SIM`: simulation behavior and determinism
- `BLD`: land, networks, zoning, and construction
- `MOB`: mobility, traffic, transit, and freight
- `ECO`: treasury, markets, employment, and land value
- `POP`: households, demographics, needs, and migration
- `GOV`: services, policies, objectives, and incidents
- `ENV`: ecology, weather, pollution, and disasters
- `UX`: interface, input, onboarding, saves, and accessibility
- `ART`: world art, lighting, animation, and content breadth
- `AUD`: music, ambience, and sonic feedback
- `TEC`: runtime, performance, data, tools, and platform
- `REL`: quality, packaging, compatibility, localization, and launch operations

Each requirement appears once in [REQUIREMENTS.md](REQUIREMENTS.md) and once in [TRACEABILITY_MATRIX.md](TRACEABILITY_MATRIX.md). A requirement may be split only by adding new IDs and marking the old one superseded.

## Status language

The traceability matrix uses these exact states:

- `Mapped`: design, implementation, and verification evidence all exist.
- `Design gap`: a product or design decision is not yet authoritative.
- `Implementation gap`: the approved behavior is not fully implemented.
- `Verification gap`: implementation exists but release-grade evidence is missing.
- `Superseded`: a later requirement or approved decision replaced the row.

Statements labeled **Must** are release-blocking. **Should** statements are expected unless production approves a written exception. **Could** statements are post-floor opportunities and do not justify delaying release.

## Change control

A change to player promise, platform, launch modes, simulation scale, renderer, save compatibility, content floor, accessibility floor, or commercial model requires:

1. A recorded decision with an owner and rationale.
2. Updated affected specifications and requirement rows.
3. Updated estimates and milestone risk.
4. A migration plan for code, content, saves, and tests where applicable.
5. Product, design, engineering, production, and QA approval before implementation becomes release-authoritative.

## Definition of release-ready

The release candidate is ready for launch approval only when:

- No release requirement remains a design or implementation gap.
- No Priority 0 or Priority 1 defect is open.
- Performance, stability, save integrity, accessibility, and compatibility gates pass on the supported hardware matrix.
- All launch content has completed design, localization, integration, balance, and regression review.
- Signing, notarization, installation, update, rollback, privacy, credits, licenses, and support paths are proven from a clean machine.
- A 100-hour soak city and the authored golden cities can be saved, loaded, advanced, and visually compared without corruption or unacceptable divergence.

