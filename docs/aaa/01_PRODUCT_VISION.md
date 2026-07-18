# Product Vision

## 1. Release statement

CitySim: New Arcadia is a native macOS city-building game about shaping a place, reading its consequences, and guiding it through decades of growth. It combines the creative satisfaction of laying out a city, the strategic tension of balancing interdependent systems, and the emotional reward of watching a living place respond.

The game must feel generous and legible. Complexity belongs in the relationships between systems, not in hidden rules or clerical interaction. A player should be able to understand why a district thrives, trace why it fails, and act with confidence without the simulation becoming predictable or trivial.

## 2. Player fantasy

The player is the long-term steward of a city, not merely a road painter or budget operator. They set its physical form, public priorities, resilience, identity, and pace of change. The city answers through movement, construction, sound, public sentiment, finances, service outcomes, environmental change, and memorable local events.

The desired emotional arc is:

1. **Possibility:** open land and a clear first decision.
2. **Ownership:** a recognizable neighborhood forms from the player's choices.
3. **Mastery:** the player reads connected systems and solves problems intentionally.
4. **Attachment:** districts, landmarks, and stories acquire history and meaning.
5. **Stewardship:** growth creates tradeoffs that cannot all be optimized at once.
6. **Legacy:** the finished city visibly records decades of choices and recovery.

## 3. Product pillars

### 3.1 Readable cause and effect

Every material state change must have a discoverable cause. The world, HUD, overlays, inspectors, notifications, and historical charts must tell one consistent story. Warnings identify the affected place and explain a next diagnostic action; they do not merely announce failure.

### 3.2 A city that looks alive

Citizens, traffic, construction, utilities, weather, lighting, parks, commerce, and emergency response must visibly reflect simulation state. The renderer is not decoration over a spreadsheet; it is the primary way players perceive the simulation.

### 3.3 Creative agency with strategic weight

Multiple city forms must be viable. Dense transit-oriented centers, low-density suburbs, industrial logistics hubs, green cities, and service-heavy civic models should create distinct strengths and costs. The game must resist one dominant build order.

### 3.4 Consequences with recovery

Poor decisions create real pressure, but collapse must usually be diagnosable and recoverable. Debt, congestion, service failure, pollution, disasters, and demographic shocks should generate stories and hard choices before they generate a game-over state.

### 3.5 Native desktop craft

The product must feel designed for macOS: precise pointer input, strong keyboard control, native menus and windows, accessible controls, correct full-screen behavior, reliable saves, and polished performance on supported Apple silicon.

## 4. Audience

### 4.1 Core players

- City-builder players who enjoy deep systems, long saves, optimization, and modifiable layouts.
- Creative builders who value visual composition, landscaping, landmarks, and shareable cities.
- Strategy players who want policy tradeoffs, fiscal pressure, and scenario goals.

### 4.2 Adjacent players

- Players new to city builders who need progressive disclosure and an excellent guided start.
- Mac players underserved by native strategy games and unwilling to accept poor desktop integration.
- Simulation enthusiasts who value determinism, inspectability, and credible systemic behavior.

The default experience must be understandable without prior city-planning knowledge. Advanced detail can be exposed through inspectors, overlays, policies, and difficulty settings rather than front-loaded into the first hour.

## 5. Modes

### 5.1 Guided campaign

A connected set of cities teaches the complete game through civic problems rather than detached tutorials. Each chapter introduces a region, constraints, a local identity, and a small number of new systems. Completion unlocks tools for campaign and sandbox use but never requires repetitive grinding.

### 5.2 Scenario play

Authored, replayable challenges begin from designed city states. Objectives can reward growth, recovery, emissions reduction, mobility, fiscal reform, disaster response, housing, or preservation. Scenarios support medal tiers, optional constraints, deterministic seeds, and shareable final scorecards.

### 5.3 Sandbox

Sandbox offers all unlocked systems, configurable starting conditions, region selection, disaster controls, economic difficulty, simulation complexity, and optional unlimited money. Creative settings remain clearly separated from progression and challenge records.

### 5.4 Benchmark and photo modes

Benchmark mode is a support and engineering surface that runs known cities and reports performance. Photo mode removes operational chrome, offers camera and time controls, and exports clean still images without changing simulation state.

## 6. Core loops

### 6.1 Moment-to-moment loop: 10 to 60 seconds

1. Observe motion, construction, demand, alerts, or an overlay.
2. Select a place or system and inspect the cause.
3. Place, zone, budget, route, prioritize, or enact a policy.
4. Receive immediate placement feedback and a clear projected cost.
5. Watch construction and first-order simulation response.

### 6.2 Planning loop: 5 to 20 minutes

1. Identify a district-scale goal or pressure.
2. Compare capacity, access, cost, demand, and environmental constraints.
3. Commit a coordinated package of networks, land use, services, and policy.
4. Advance time and read second-order effects.
5. Adapt, defer, refinance, redesign, or celebrate success.

### 6.3 City arc: 1 to 4 hours

The city moves through settlement, town, city, regional center, and metropolis phases. Each phase adds options and interdependencies while preserving earlier neighborhoods. Milestones are earned by durable outcomes, not population alone.

### 6.4 Legacy loop: 20 hours and beyond

Long saves accumulate historical charts, named districts, upgraded infrastructure, landmark stories, policy eras, disasters, and demographic change. The player can continue after campaign or scenario completion, branch saves, and revisit a visual timeline of the city's evolution.

## 7. Meaningful choice model

A release-quality choice must change at least two of the following and communicate both:

- Physical form or land use.
- Access, travel time, or network capacity.
- Treasury, operating cost, debt, or tax incidence.
- Household or business opportunity.
- Service quality, safety, health, or education.
- Pollution, ecology, noise, or resilience.
- Public sentiment, equity, identity, or progression.

Purely cosmetic choices are welcome but must be labeled as such. False choices with one numerically superior answer must be removed, rebalanced, or made situational.

## 8. Difficulty and failure

Difficulty presets tune starting resources, economic volatility, demand elasticity, disaster severity, assistance, and information timing. They must not remove core rules or make the UI less truthful.

The normal game has no abrupt bankruptcy screen. Financial crisis triggers escalating interventions: warnings, credit pressure, project deferral, emergency measures, negotiated aid, and recovery objectives. A scenario may define a terminal failure condition, but it must be visible before the player commits and explain the failed objective afterward.

## 9. Session and continuity promise

- A new player reaches the first meaningful construction decision within two minutes.
- A returning player can load the most recent city and understand its active pressures within one minute.
- Pause, speed, quick save, and undo-safe planning interactions remain available without hunting through menus.
- The game autosaves safely, never overwrites the only known-good save, and exposes recovery copies.
- A normal session can be satisfying in 20 minutes while long cities support hundreds of hours.

## 10. Launch outcomes

The full release succeeds as a game when playtest evidence shows that:

- Players can explain the cause of major city problems without developer coaching.
- Distinct city strategies remain viable through the metropolis phase.
- New players complete the guided first hour without external instructions.
- Experienced players find meaningful optimization and planning decisions after 20 hours.
- Players form attachment to named places and can describe stories produced by the simulation.
- The native presentation, input, stability, and save behavior meet the release gates on supported Macs.

Commercial targets, price, storefront mix, post-launch model, target hardware, and final content quantities remain approval decisions in [08_OPEN_DECISIONS.md](08_OPEN_DECISIONS.md). They do not weaken the quality bar defined here.

## 11. Non-goals for Release 1

- Competitive or cooperative multiplayer.
- An always-online account requirement.
- Real-money consumables, randomized paid rewards, or energy timers.
- First-person or third-person action gameplay.
- A photogrammetric recreation of real-world cities.
- Professional planning, traffic-engineering, or emergency-management certification.
- Exact simulation of every resident as a continuously active high-fidelity agent.

## 12. Product acceptance

This vision is accepted when product, creative, game design, engineering, production, UX, art, audio, QA, and accessibility owners approve it; all unresolved scope choices are entered in the open-decision register; and each promise is represented by one or more stable requirements.

