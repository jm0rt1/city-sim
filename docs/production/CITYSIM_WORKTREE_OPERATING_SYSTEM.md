# CitySim Worktree Operating System

**Status:** Approved operating plan

**Version:** 1.0

**Date:** July 19, 2026

**Integration branch:** `master`

**Active product:** `Native/CitySimNative`

## 1. Mission

This system exists to turn CitySim into a genuinely playable game by allowing several agents to work concurrently without fragmenting the product or destabilizing the integration branch.

The immediate product target is a coherent 20-minute session in which a player can:

1. understand the city and its immediate pressure;
2. make a meaningful construction or policy decision;
3. read the visible and numerical consequences;
4. diagnose a worsening condition;
5. recover through a second decision;
6. reach a clear milestone, failure, or next objective;
7. save, leave, and resume safely.

Task count, code volume, test count, and visual polish do not substitute for that loop. Work is accepted only when it improves an integrated player outcome.

## 2. Authority and product boundary

When sources conflict, use this order:

1. approved decisions or ADRs;
2. `docs/aaa/README.md` and the authoritative documents under `docs/aaa/`;
3. this operating system and the active `PLAY-*` task source;
4. subsystem specifications and architecture documents;
5. dated native graphics, UI, keyboard, audit, and remediation plans;
6. current native implementation as evidence of existing behavior;
7. legacy Python implementation as migration or behavioral reference only.

`Native/CitySimNative` is the shipping product lane. Legacy Python code is off limits unless a claimed task explicitly identifies a migration, contract, or reference dependency.

## 3. Repository topology

The system has one integration command center, five product specialist
worktrees, and one isolated world-art generation cell.

| Lane | Branch | Default worktree path | Mission |
|---|---|---|---|
| Integration | `master` | Main repository checkout | Own accepted builds, allocation, integration, conflict resolution, release proof, and rollback |
| Gameplay loop | `codex/citysim-gameplay-loop` | `/Users/James/.codex/worktrees/citysim/gameplay-loop` | Make decisions consequential and the session paced, legible, recoverable, and worth replaying |
| World rendering | `codex/citysim-world-rendering` | `/Users/James/.codex/worktrees/citysim/world-rendering` | Make the city readable, alive, performant, and visually compelling |
| World art | `codex/citysim-world-art` | `/Users/James/.codex/worktrees/citysim/world-art` | Author governed high-fidelity directional source art without changing renderer or gameplay authority |
| UI and input | `codex/citysim-ui-input` | `/Users/James/.codex/worktrees/citysim/ui-input` | Make every command discoverable, responsive, accessible, and keyboard-operable |
| Simulation platform | `codex/citysim-simulation-platform` | `/Users/James/.codex/worktrees/citysim/simulation-platform` | Own deterministic state, persistence, performance, diagnostics, and system contracts |
| Playtest quality | `codex/citysim-playtest-quality` | `/Users/James/.codex/worktrees/citysim/playtest-quality` | Prove or disprove playability with golden cities, journeys, visual evidence, balance findings, and regressions |

The paths are defaults, not instructions to create worktrees before the integration baseline is clean. Each branch may be checked out by only one worktree at a time.

## 4. Lane ownership

### 4.1 Integration command center

The integration lane owns:

- the accepted playable build;
- `docs/production/PLAYABLE_BACKLOG.md` and task prioritization;
- cross-lane contracts and approved decision records;
- merge order, conflict resolution, rollback, and release tags;
- integration play sessions and proof manifests;
- shared files that would otherwise attract simultaneous edits;
- advancement of `docs/aaa/TRACEABILITY_MATRIX.md`.

The integration lane does not act as a sixth undifferentiated feature worker. It may make narrow integration fixes, but substantial feature corrections return to the owning lane.

### 4.2 Gameplay loop lane

Primary ownership:

- economy pressure and treasury consequences;
- demand, development, population, employment, happiness, and service relationships;
- objectives, milestones, progression, incidents, recovery, win/fail states, and feedback pacing;
- scenario and balance fixtures;
- gameplay-facing analytics needed to explain causal outcomes.

Default code surfaces:

- `Models/CityGameState.swift`
- gameplay portions of `Models/CityModels.swift`
- `Services/CitySimulation.swift`
- gameplay portions of `Support/CityAnalytics.swift`
- focused gameplay tests and scenario fixtures

It does not own rendering, general HUD composition, input routing, or persistence formats.

### 4.3 World rendering lane

Primary ownership:

- SpriteKit scene composition, terrain, roads, lots, buildings, props, animation, effects, lighting, overlays, camera, and world hit testing;
- deterministic visual variation and camera detail levels;
- asset atlases, render budgets, visual fixtures, and renderer telemetry;
- selection, hover, placement, and in-world consequence presentation.

Default code surfaces:

- `Rendering/`
- native world-art resources
- renderer-focused tests and proof harnesses
- world visual direction and asset pipeline records

It consumes simulation snapshots and typed interaction state. It does not invent gameplay truth inside renderer nodes.

### 4.4 UI and input lane

Primary ownership:

- SwiftUI window composition, HUD, build tools, inspector, objectives, alerts, overlays, settings, onboarding, and responsive layouts;
- command registry, keyboard shortcuts, focus rules, accessibility descriptions, reduced motion, and Full Keyboard Access;
- map-to-UI command bridging when the state owner remains explicit;
- player-facing terminology and command discoverability.

Default code surfaces:

- `App/`
- `Views/`
- `Support/GameTheme.swift`
- UI/input portions of `Stores/CityGameStore.swift`
- UI/input tests and default/compact proof

It does not duplicate simulation rules or keep a second copy of world state.

### 4.5 Simulation platform lane

Primary ownership:

- deterministic command/tick boundaries;
- save format, migrations, atomic persistence, replay, snapshots, stable identities, and recovery;
- performance profiling, memory budgets, logging, diagnostics, and support exports;
- package boundaries, background work, and platform/runtime contracts;
- clean-build, signing-readiness, and test infrastructure when assigned.

Default code surfaces:

- persistence and platform services;
- shared typed contracts approved by integration;
- performance/determinism/save tests and fixtures;
- architectural decisions and diagnostics.

It does not rebalance the game or redesign the HUD while changing infrastructure.

### 4.6 Playtest quality lane

Primary ownership:

- critical player journeys and pointer-free journeys;
- golden sparse, growing, pressured, recovery, mature, compact, overlay, and accessibility cities;
- hands-on defect reproduction, screenshot proof, visual comparisons, performance captures, and playtest reports;
- requirement verification proposals and release evidence;
- balance observations expressed as reproducible scenarios rather than unscoped tuning edits.

Default surfaces:

- test fixtures, harnesses, scripts, and `docs/production/evidence/`;
- focused test additions that reproduce a defect;
- audit and verification records.

This lane is read-mostly against feature code. It should return product defects to the owning lane rather than casually repairing cross-cutting implementation.

### 4.7 World art generation cell

Primary ownership:

- ImageGen prompts, raw masters, provenance, rejection records, and source-art
  contact sheets for an integration-approved asset batch;
- deterministic normalization inputs and source-level geometry reports;
- authored directional-view consistency, family recognition, material quality,
  and visual-style adherence.

Default surfaces:

- `Native/CitySimNative/WorldArt/ImageGen/`;
- task-owned source catalog additions outside the shipping production selection;
- source-art validators, contact sheets, and `PLAY-027` evidence.

The cell does not edit `Rendering/`, the shipping atlas pages or production
selection, package topology, gameplay/simulation/UI code, or shared manifests.
Only integration may approve a manifest contract; the renderer lead later
reviews and ingests accepted source batches. This cell must never run
concurrently as a second writer on the world-rendering worktree.

## 5. Shared surfaces and contract locks

The following are integration-controlled because they are likely collision points:

- `Package.swift` and package topology;
- shared model enums used by more than one lane;
- `CityGameStore` public intent/state contract;
- the simulation snapshot and renderer input contract;
- save schemas and migration identifiers;
- the command registry public shape;
- shared theme tokens;
- release authority, traceability, and task-source files;
- app launch/build scripts and Codex actions.

A worker needing a shared-surface change must write a compact contract proposal in its task completion record:

- why the current contract blocks the player outcome;
- the smallest proposed interface change;
- affected lanes and migration risk;
- tests proving compatibility.

Integration approves and orders the contract change before dependent work merges. Parallel agents must not land incompatible versions of a shared contract.

## 6. Task source and identifiers

Concurrent production work uses `docs/production/PLAYABLE_BACKLOG.md` with permanent IDs:

```markdown
### [ ] PLAY-001: Imperative player outcome
```

Every task must contain:

- **Player outcome:** the observable improvement in play.
- **Owning lane:** exactly one worktree.
- **Requirement IDs:** relevant `PRD`, `SIM`, `BLD`, `MOB`, `ECO`, `POP`, `GOV`, `ENV`, `UX`, `ART`, `AUD`, `TEC`, or `REL` rows.
- **Dependencies:** accepted tasks or approved contracts required first.
- **In scope / out of scope:** explicit edit boundaries.
- **Work checklist:** implementation and evidence work.
- **Acceptance criteria:** functional, visual, accessibility, performance, and persistence criteria as applicable.
- **Validation:** exact commands and hands-on flow.
- **Proof:** required screenshots, fixtures, logs, or reports.
- **Stop conditions:** ambiguity, contract conflict, unrelated dirty state, missing asset/input, or failed gate.

Oversized tasks are split before implementation. A normal task should integrate into a playable build within one production iteration and should avoid broad edits across lane ownership.

## 7. Claim protocol

Only one lane may claim a task.

A claim record lives at:

```text
docs/production/claims/PLAY-001.<lane>.md
```

It records:

- task ID and title;
- lane, branch, and worktree;
- base commit;
- claimed timestamp;
- planned code surfaces;
- dependencies and contract assumptions;
- expected validation and proof;
- current status: `active`, `blocked`, or `ready-for-integration`.

Claim records prevent duplicate work; they do not prove completion. Integration may reassign a claim only after the original lane is stopped and its branch state is preserved.

## 8. Completion protocol

A completion record lives at:

```text
docs/production/completed/PLAY-001.<lane>.md
```

It must include:

- player-visible outcome;
- exact files changed;
- commit hash or ordered commit hashes;
- automated commands and exact results;
- hands-on flow and result;
- proof artifact paths;
- accessibility, compact-layout, performance, and save consequences;
- known limitations and deferred work;
- merge-order or shared-contract notes.

Completed-but-uncommitted work is invalid. A green unit test is insufficient for UI/gameplay work. A screenshot is insufficient for interaction work. A successful build is insufficient for playability.

## 9. Git authority and safety

### Worker lanes may

- edit only their claimed task and approved ownership surfaces;
- create focused commits on their worker branch;
- rebase or merge the latest accepted `master` only when the worktree is clean and integration has not frozen the lane;
- create proof and completion records;
- report a blocker without forcing progress.

### Worker lanes may not

- push unless the user later grants that authority;
- merge or cherry-pick into `master`;
- force-push or rewrite shared history;
- delete, reset, restore, or stage unrelated user work;
- claim completion without concrete commit hashes;
- modify another lane's active claim or completion record;
- expand into legacy Python work without explicit task scope;
- resolve a product decision silently in code.

### Integration lane may

- inspect worker commits and evidence;
- request changes or reject a slice;
- integrate accepted commits in dependency order;
- make narrow merge fixes with a recorded rationale;
- push accepted `master` after validation;
- tag stable playable baselines.

The integration lane must preserve a recoverable pre-merge commit and never integrate from a dirty main worktree.

### Intelligent commit protocol

All lanes treat commits as continuous durability and review boundaries:

1. Inspect branch and working state before staging.
2. Stage explicit task-owned paths; never use `git add -A` in a dirty multi-owner checkout.
3. Review unstaged and staged diffs, run `git diff --cached --check`, and confirm no unrelated or generated files entered the index.
4. Commit one coherent player, contract, test, evidence, or management outcome at a time using `PLAY-###: Imperative outcome` or `Integration: Imperative outcome`.
5. Commit after validated checkpoints, before handoff, before task/lane changes, before risky refactors/merges, and before ending a turn with completed work.
6. Use explicit checkpoint commits only to preserve incomplete worker work; record unrun/failing validation and do not mark the task ready.
7. Keep completion records tied to exact commit hashes. Finished-but-uncommitted work is never complete.
8. Workers keep commits local until accepted. Integration audits every worktree's cleanliness, latest commit, divergence, and claim before integration.

If provenance is unclear, freeze and preserve the worktree before cleanup. Never erase or absorb ambiguous work merely to obtain a clean status.

## 10. Baseline rule

No specialist worktree is created from the current dirty checkout.

Before provisioning workers:

1. inventory the existing graphics, HUD, input, audit, tests, and proof changes;
2. validate them as one candidate slice;
3. commit or deliberately split and commit the accepted slice;
4. push the clean baseline;
5. record the baseline commit in `docs/production/BASELINE.md`;
6. create all worker branches from that exact commit.

If the current slice fails validation, preserve it on a dedicated recovery branch before repairing or reducing it. Do not discard it to obtain a clean `master`.

## 11. Worktree provisioning

After the baseline gate, create branches and worktrees from the recorded commit:

```bash
git worktree add -b codex/citysim-gameplay-loop \
  /Users/James/.codex/worktrees/citysim/gameplay-loop <baseline-commit>
git worktree add -b codex/citysim-world-rendering \
  /Users/James/.codex/worktrees/citysim/world-rendering <baseline-commit>
git worktree add -b codex/citysim-ui-input \
  /Users/James/.codex/worktrees/citysim/ui-input <baseline-commit>
git worktree add -b codex/citysim-simulation-platform \
  /Users/James/.codex/worktrees/citysim/simulation-platform <baseline-commit>
git worktree add -b codex/citysim-playtest-quality \
  /Users/James/.codex/worktrees/citysim/playtest-quality <baseline-commit>
```

If a branch already exists, attach it rather than recreating it. Validate `git worktree list`, branch identity, clean status, and baseline ancestry in every worktree before dispatching tasks.

Worktrees are manual initially. No heartbeat or detached recurring automation is authorized until two complete claim → implementation → evidence → integration cycles succeed without stale claims, silent blockers, or cross-lane damage.

## 12. Integration cadence

The system uses short vertical integration waves rather than long-lived independent feature epics.

### Daily lane behavior

1. Sync accepted baseline when directed.
2. Claim one ready task.
3. Reproduce the current player problem.
4. Implement the smallest complete player outcome.
5. Test continuously in the owning layer.
6. Operate the staged app when player-facing behavior changes.
7. Commit focused work and write the completion record.
8. Stop at `ready-for-integration`; do not self-merge.

### Integration wave

1. Freeze candidate lanes at their completion commits.
2. Review task scope, diff, shared contracts, and evidence.
3. Integrate in dependency order: platform contracts, simulation/gameplay, rendering, UI/input, quality fixtures.
4. Resolve or return conflicts to their owner.
5. Run the complete integration gate.
6. Perform the target player journey.
7. Capture evidence and update task/requirement dispositions.
8. Push accepted `master` and publish the next baseline commit.

One or two small accepted outcomes per lane per wave is preferable to a large merge that cannot be understood or playtested.

## 13. Integration gate

At minimum, every integration candidate runs:

```bash
swift test --package-path Native/CitySimNative
git diff --check
bash -n script/build_and_run.sh
./script/build_and_run.sh --verify
```

Use writable Swift module-cache paths when the environment requires them. Player-facing integration additionally requires:

- real staged application launch;
- a pointer-based critical journey;
- the keyboard-only critical journey when affected;
- default and compact window checks;
- visible proof from the real SpriteKit scene or a disclosed deterministic harness limitation;
- focused accessibility checks;
- save/load and undo checks when state changes;
- performance comparison when renderer, simulation, or observation boundaries change.

The playtest quality lane proposes evidence. Integration owns acceptance.

## 14. Stop conditions

A worker stops and reports instead of improvising when:

- its worktree has unrelated dirty changes;
- another lane owns the necessary surface without an approved contract change;
- the task depends on an unresolved product decision;
- validation fails outside the claimed scope;
- save compatibility, data migration, accessibility, or performance impact is unknown and material;
- a required asset, fixture, API, permission, or user decision is unavailable;
- the task cannot reach a playable integration state within one iteration;
- the proposed solution would duplicate state or create a parallel authority.

Integration stops a wave when the main worktree is dirty, a completion lacks commits/evidence, merge order is unresolved, the staged app fails, or the target journey regresses.

## 15. First production wave: make the game playable

The first wave is deliberately smaller than the AAA backlog. Its purpose is to prove the operating model and produce one enjoyable loop.

### Integration: `PLAY-001` — Establish the accepted native baseline

- Package and validate the current graphics/HUD/input slice.
- Record baseline commit, launch evidence, screenshots, test result, and known defects.
- Provision the five worktrees only after the pushed baseline is clean.

### Gameplay loop: `PLAY-010` — Create consequential early-game pressure

- Define a 20-minute starting economy and objective sequence.
- Make treasury, demand, utilities, happiness, and employment force understandable tradeoffs.
- Provide at least one recoverable failure and one meaningful milestone.

### World rendering: `PLAY-020` — Make consequences readable in the city

- Ensure growth, construction, utility trouble, prosperity, pollution, selection, and recovery are visibly distinct.
- Improve the representative neighborhood without inventing simulation truth.
- Establish visual/performance baselines.

### UI and input: `PLAY-030` — Complete the build → diagnose → adjust workspace

- Implement the command registry and essential keyboard routes.
- Keep the map dominant while exposing costs, consequences, remedies, and safe cancellation.
- Verify default and compact layouts.

### Simulation platform: `PLAY-040` — Prove deterministic saveable sessions

- Establish deterministic fixtures and state hashes for the first-wave scenario.
- Prove save/load, undo, recovery, and stable renderer/UI snapshots.
- Record simulation and save performance.

### Playtest quality: `PLAY-050` — Define and run the playable-session gate

- Create the 20-minute critical journey and golden starting city.
- Record confusion, dead time, false feedback, dominant strategy, recovery, keyboard, and compact-layout findings.
- Reject the wave if testers cannot understand cause, effect, next action, or success/failure.

The first wave exits only when all lanes integrate into one build and a fresh player can complete the journey without developer coaching.

## 16. Measures that matter

Track:

- time to first meaningful decision;
- time between decision and readable consequence;
- percentage of critical actions discoverable without documentation;
- critical-journey completion and recovery rates;
- unresolved player confusion and dead-time observations;
- deterministic replay and save-corpus pass rate;
- frame-time, node/draw, memory, and simulation budgets;
- accessibility critical-path completion;
- accepted tasks versus returned/rejected integration candidates;
- defect escape from worker validation into integration.

Do not use lines of code, number of agents, task closures, test count, or asset count as primary measures of game quality.

## 17. Scaling the army

The five-lane system expands only after two successful waves. Add capacity by splitting a proven lane along a stable contract—for example, world art from renderer engineering or content/scenarios from gameplay systems—not by adding interchangeable workers to the same files.

Automation becomes eligible when:

- claims and completions are consistently parseable;
- preflight detects dirty/diverged worktrees;
- completion records contain real commits and evidence;
- integration can identify merge order from dependencies;
- workers stop reliably on ambiguity and failures;
- no worker requires direct merge authority;
- the target player journey runs automatically where feasible and manually where required.

Until then, manual dispatch and integration are features, not overhead: they are how the project learns where its real product and architectural seams are.

## 18. Definition of success

This worktree system succeeds when parallel work produces a better single game faster than one lane could, without creating contradictory systems, hidden regressions, unreviewable merges, or a false sense of progress.

The game—not the army—is the deliverable.
