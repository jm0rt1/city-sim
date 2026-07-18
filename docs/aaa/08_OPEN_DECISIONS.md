# Open Decisions Register

## 1. Purpose

This register prevents an assumption from masquerading as an approved release decision. A decision is closed only when the named owners approve one option, record evidence and consequences, update affected requirements and specifications, and link a superseding ADR or decision record.

The recommended default keeps specification work coherent while a decision is open. It is not authorization for irreversible production investment.

## 2. Decision register

| ID | Decision | Required owners | Due gate | Recommended default | Main impact | Status |
| --- | --- | --- | --- | --- | --- | --- |
| DEC-001 | Shipping engine and renderer | CTO, engine lead, rendering lead, art director, production | Gate 1 | Native Swift and C++ core with Metal renderer, SwiftUI and narrow AppKit shell | Staffing, tools, performance, schedule, platform reach | Needs design confirmation |
| DEC-002 | Minimum macOS and hardware tiers | Product, engine, QA, release engineering, finance | Gate 1 | macOS 14+, Apple silicon only, M1 16 GB baseline, M2 Pro recommended | Audience size, graphics floor, QA matrix, memory budgets | Needs design confirmation |
| DEC-003 | Visual style and camera model | Creative director, art director, game director, UX, rendering | Gate 1 | Stylized civic realism with adjustable three-quarter perspective camera | Asset cost, readability, renderer, marketing identity | Needs design confirmation |
| DEC-004 | Maximum city and simulation fidelity | Game director, simulation lead, engine lead, production | Gate 1 | 250,000 resident equivalent with layered agent fidelity and 20,000 visible movers | Architecture, content density, performance, player promise | Needs design confirmation |
| DEC-005 | Commercial model and price | Executive, product, finance, publishing | Gate 0 | Premium base game, no consumables, complete offline core | Scope, revenue, storefront copy, post-launch obligations | Needs design confirmation |
| DEC-006 | Distribution channels | Publishing, release engineering, legal, finance, product | Gate 1 | Signed notarized direct download first; evaluate Mac App Store in parallel | Sandbox, entitlements, updates, fees, support | Needs design confirmation |
| DEC-007 | Campaign narrative and voice scope | Creative, narrative, game design, audio, localization, production | Gate 2 | Four-chapter civic campaign, voiced briefings only, text operational events | Writing, recording, localization, accessibility, budget | Needs design confirmation |
| DEC-008 | Final launch content budget | Creative, game design, art, audio, production, finance | Gate 2 | Use the floors in the content specification | Headcount, outsourcing, memory, schedule, replay value | Needs design confirmation |
| DEC-009 | Launch languages | Publishing, localization, UX, QA, support, production | Gate 3 | English plus French, German, Spanish, Japanese, Korean, Simplified Chinese | UI, fonts, voice, QA, culturalization, support | Needs design confirmation |
| DEC-010 | Full controller support | Product, UX, accessibility, QA, engineering | Gate 2 | Support mouse, trackpad, and keyboard at launch; controller only if complete | Input architecture, UI focus, certification, testing | Needs design confirmation |
| DEC-011 | Mod and user-content support | Product, engine, tools, security, legal, support | Gate 2 | Reserve package architecture; ship data mods only if sandbox and compatibility pass | Tools, security, storefront, saves, moderation, support | Needs design confirmation |
| DEC-012 | Cloud saves and account services | Product, platform, privacy, security, release engineering | Gate 2 | Local saves are authoritative; optional platform cloud after conflict proof | Offline promise, privacy, conflicts, support | Needs design confirmation |
| DEC-013 | Telemetry and crash reporting | Product, QA, privacy, legal, support, engineering | Gate 2 | Explicit opt-in diagnostics with previewable support export | Quality evidence, privacy, legal, player trust | Needs design confirmation |
| DEC-014 | Post-launch and expansion model | Executive, product, creative, production, finance, publishing | Gate 5 | Stabilization and free fixes first; no live-service cadence assumed | Team retention, compatibility, roadmap, messaging | Needs design confirmation |
| DEC-015 | Multiplayer or city sharing scope | Product, game director, engine, services, security, production | Gate 0 | No multiplayer in Release 1; local screenshots and city export only | Architecture, cost, moderation, accounts, schedule | Needs design confirmation |
| DEC-016 | Intel Mac support | Product, engine, rendering, QA, finance | Gate 1 | Do not support Intel for Release 1 | Runtime architecture, QA cost, market reach | Needs design confirmation |
| DEC-017 | Storefront sandbox and file model | Release engineering, platform, UX, support, security | Gate 1 | App-owned local save library with explicit import and export | Mods, backup, support, entitlements, UX | Needs design confirmation |
| DEC-018 | HDR and advanced display features | Art, rendering, UX, accessibility, QA | Gate 3 | Ship excellent SDR; enable HDR only if independently validated | Rendering, capture, accessibility, QA matrix | Needs design confirmation |

## 3. Required evidence by decision

### DEC-001 — Engine and renderer

Compare at least native Metal, Unreal, Unity, and any credible internal hybrid against deterministic simulation integration, mature-city CPU and GPU performance, macOS-native input and accessibility, editor workflow, asset pipeline, debugging, licensing, source access, hiring, distribution, save control, and five-year maintenance cost.

The decision must include a representative terrain, network, modular-building, crowd, weather, overlay, picking, and native-panel spike on baseline and target hardware. A logo-rendering demo is insufficient.

### DEC-002, DEC-004, and DEC-016 — Platform and scale

Approve these together using a benchmark city, market and support analysis, memory profile, graphics tiers, simulation profiling, and content-density review. Publish one supported matrix and one exact benchmark workload.

### DEC-003 — Art and camera

Run blind readability and appeal tests across region, city, neighborhood, and street views. Include construction, congestion, night, storm, overlays, tall buildings, accessibility modes, and representative dense scenes. Approve style sheets and measurable asset budgets with the camera.

### DEC-005, DEC-006, and DEC-014 — Commercial release model

Record base-game promise, price band, storefront mix, update ownership, refund and support implications, expansion boundaries, and how every option affects production funding. The product cannot be designed around an unapproved recurring-revenue assumption.

### DEC-007 and DEC-008 — Campaign and content

Validate one finished campaign chapter and one sandbox region through end-to-end production. Measure writing, design, art, animation, audio, localization, integration, balance, QA, memory, and patch cost before locking quantities.

### DEC-009 — Localization

Decide from audience, revenue, linguistic complexity, fonts, text expansion, generated names, culturalization, voice, support, and QA capacity. Pseudo-localization and international text architecture remain mandatory regardless of launch list.

### DEC-010 — Controller

Test complete play from first launch through a mature-city recovery task. If world construction, focus navigation, charts, remapping, and text entry are not coherent, defer honestly rather than advertise partial support.

### DEC-011, DEC-012, DEC-013, and DEC-017 — Trust boundaries

Threat-model content, saves, scripts, cloud conflicts, paths, privacy, moderation, support, and account recovery. Every approved online or extensibility feature must preserve local recovery and explain failure without endangering the only city copy.

## 4. Decision record template

Each closed decision records:

- Decision ID and date.
- Chosen option and rejected options.
- Named approvers.
- Player and business rationale.
- Prototype, benchmark, research, or playtest evidence.
- Scope, staffing, schedule, cost, and risk effect.
- Architecture, content, UX, accessibility, save, legal, and support effect.
- Requirements and documents changed.
- Revisit trigger and fallback.

## 5. Escalation rule

If a due gate arrives with a decision still open, production must choose one of three explicit outcomes: approve the recommended default, approve another option with evidence, or stop the dependent work. Quietly continuing with team-local assumptions is not permitted.

