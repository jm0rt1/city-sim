# Content and Progression Specification

## 1. Content purpose

Launch content exists to create distinct city stories, strategic variety, visual identity, and a durable learning curve. Quantity is not a substitute for systemic differentiation. Each content family must change a meaningful combination of place, access, economy, service, environment, risk, or identity.

The quantities in this document are production planning floors for the AAA target. They become binding after the content-budget decision in [08_OPEN_DECISIONS.md](08_OPEN_DECISIONS.md) is approved against staffing, schedule, memory, localization, and performance budgets.

## 2. Launch experience structure

### 2.1 First-run sequence

The first run opens with accessibility and display setup, then moves directly into a small guided region. It teaches observation, roads, zoning, utilities, budget, services, diagnosis, and recovery through a functioning town. It does not require reading a manual or completing disconnected control drills.

Players can skip, replay, or selectively revisit every lesson. Experienced players can enter sandbox immediately.

### 2.2 Guided campaign

The campaign contains four chapters with three cities per chapter for a 12-city authored arc:

1. **Foundations:** access, zoning, utilities, treasury, and basic services.
2. **Connections:** traffic, transit, freight, districts, and regional trade.
3. **Tradeoffs:** housing, pollution, equity, policy, and economic transition.
4. **Legacy:** disasters, climate adaptation, mature infrastructure, and long-term renewal.

Each city introduces at most two major system families, revisits prior systems, offers optional mastery goals, and remains playable after its primary objective.

### 2.3 Standalone scenarios

At least 12 standalone scenarios cover growth, debt recovery, congestion, housing shortage, industrial transition, water stress, severe weather, public health, transit conversion, historic preservation, regional logistics, and balanced-metropolis mastery.

Each scenario includes a deterministic starting save, briefing, explicit constraints, target tiers, failure conditions, estimated duration, adaptive hints, debrief, and a regression-test profile.

### 2.4 Sandbox regions

At least eight handcrafted regions span four climate families and materially different terrain, resource, hazard, and outside-connection conditions. Every region supports multiple viable city forms. Seeds may vary vegetation, resources, weather, and selected starting constraints without invalidating authored terrain quality.

## 3. Progression model

### 3.1 City capability tiers

Progression uses five legible capability tiers:

1. Settlement.
2. Town.
3. City.
4. Regional center.
5. Metropolis.

Tier advancement evaluates durable outcomes across population, treasury, network access, service readiness, and development diversity. A temporary spike does not permanently unlock a tier until the persistence window is met.

### 3.2 Permits and institutions

New tools unlock through capability permits and civic institutions. A permit grants a coherent planning capability such as transit operations, higher density, advanced medicine, university education, clean industry, or regional infrastructure. Institutions provide ongoing capacity and create operating obligations.

Unlocks expand strategic options; they do not make earlier assets obsolete by raw numeric superiority. Mature cities must retain reasons to use local roads, small parks, neighborhood schools, and low-density development.

### 3.3 Research and policy knowledge

Research is a civic investment portfolio, not a click-to-wait technology tree. Projects consume money, staff, institutional capacity, and time; some require observed city needs or partnerships. Results unlock designs, improve information quality, or enable policy, with bounded and explained effects.

### 3.4 Rewards

Rewards may include grants, permits, landmarks, visual themes, policy authority, regional contracts, scenario medals, and historical recognition. Paid currency, daily-login rewards, and randomized reward boxes are outside Release 1.

## 4. Building and network content floor

The proposed launch floor is:

| Family | Minimum authored scope | Variation method |
| --- | ---: | --- |
| Growable residential | 45 archetypes | Density, lot, wealth, climate, age, and facade kits |
| Growable commercial | 32 archetypes | Scale, frontage, district, climate, and prosperity states |
| Growable industrial and logistics | 28 archetypes | Production class, yard, storage, pollution, and upgrade state |
| Growable office and mixed use | 24 archetypes | Density, district, era, and mixed frontage |
| Civic services and utilities | 60 assets | Capacity tiers, modules, climate, and operational state |
| Parks, plazas, and recreation | 40 assets | Modular paths, vegetation, furnishings, and seasonal state |
| Landmarks and unique institutions | 24 assets | Authored progression, scenario, and city-identity roles |
| Road and path families | 20 families | Width, transit, trees, parking, direction, bridge, and tunnel kits |
| Rail and transit infrastructure | 18 families | Surface, elevated, underground, depot, station, and platform kits |

The art target is at least 600 visibly distinct building configurations after modular variation, with silhouette and material rules preventing obvious repetition in the same camera view.

Every placeable asset requires gameplay data, footprint, cost, operating profile, construction state, damage state, lighting, audio hooks, iconography, localization, accessibility label, LODs, collision, selection bounds, and test placement.

## 5. Vehicles, citizens, and life

The proposed launch floor includes:

- 40 road-vehicle families across private, freight, municipal, and emergency roles.
- 12 public-transit vehicle families with capacity and visual variants.
- 24 base citizen silhouettes across life stages and mobility needs, expanded through clothing, occupation, weather, and district variation.
- Construction crews, utility work, emergency response, deliveries, recreation, school arrival, commuting, and selected civic events as visible activity sets.
- Wildlife and ambient life appropriate to each climate family.

Visible agents are selected to tell the truth about current trips and activity. Decorative crowds may increase density but must not contradict closures, disasters, time of day, or service state.

## 6. Region and environment kits

Each climate family provides terrain materials, rock and shoreline sets, vegetation communities, water presentation, weather profiles, seasonal states, ambient sound, architectural guidance, utility adaptations, and hazard rules.

Regions must contain recognizable geographic structure rather than procedural noise. At least one authored sightline, one infrastructure challenge, one ecological tradeoff, and two credible growth corridors are required per region.

## 7. Objectives and replayability

Scenario scoring separates mandatory completion, efficiency, resilience, equity or access, environment, and city character. Players can compare their own runs locally without an online account.

Replayability comes from:

- Different region constraints and starting networks.
- Multiple policy and infrastructure strategies.
- Seeded market, weather, and event variation.
- Optional objectives and challenge modifiers.
- Branchable saves and scenario reset.
- City-history summaries and photo exports.

Randomness may vary circumstances but cannot decide success independently of preparation and response.

## 8. Narrative and worldbuilding

Narrative is civic and place-based. Briefings, advisors, local organizations, district names, landmark histories, headlines, and event chains give context without turning the player into a fixed-character role-playing protagonist.

Text must avoid satire that trivializes disaster, poverty, disability, crime, displacement, or demographic identity. Sensitive systems require narrative, accessibility, and cultural review.

Named recurring advisors may represent planning domains, but all advice must identify its assumptions and tradeoffs. Advisors can disagree; the underlying data cannot.

## 9. Tutorial and knowledge base

Learning content has four layers:

1. Contextual prompts for the next valid action.
2. Short concept cards explaining why a system matters.
3. Inspector-linked diagnostics for the current city.
4. A searchable in-game encyclopedia with controls, rules, formulas, examples, and glossary terms.

Every major tool has a safe practice state or undoable first use. Hints respond to player state and stop after dismissal. Tutorial progress is saved separately from city state and can be reset.

## 10. Content authoring contract

All gameplay content is data-authored against versioned schemas. Content definitions use stable IDs and declare dependencies, unlock rules, costs, effects, localization keys, art references, audio references, and validation constraints.

The content pipeline must provide:

- Schema validation and readable errors.
- Referential-integrity checks.
- Unit and range validation.
- Duplicate and missing-ID detection.
- Automated thumbnail and icon checks.
- LOD, material, texture, animation, and memory-budget checks.
- Localization completeness and overflow checks.
- Golden-region loading and placement tests.
- A change report that identifies saves or scenarios affected by data edits.

Designers must be able to tune normal content without recompiling the engine. Release builds load only signed or trusted content packages according to the approved modding decision.

## 11. Localization and culturalization

All player-facing text, numbers, dates, currencies, key names, subtitles, advisor content, and generated names use localization services from first implementation. Layouts support expansion and right-to-left mirroring even if the first launch-language decision is narrower.

Names, symbols, emergency presentation, civic institutions, architecture, and sensitive scenarios receive cultural review for every supported locale. Generated city and citizen names use locale-aware pools and avoid unintended duplication or offensive combinations.

The final launch-language list remains an open production decision, but English is not permitted to become a hard-coded layout assumption.

## 12. Downloadable and post-launch content

The base game must be complete without post-launch purchases. Additional regions, architecture sets, scenarios, or system expansions may be developed after release only if they respect save compatibility, do not fragment core simulation fixes, and preserve a clear base-game content floor.

No live-service cadence is assumed by this specification. The commercial and post-launch model requires explicit approval.

## 13. Content acceptance

Content is release-ready when it is mechanically distinct, visually complete at every supported camera distance and state, performant within scene budgets, localized, accessible, balanced in at least one campaign or scenario context, compatible with save migration, and covered by automated validation plus human playtest evidence.

