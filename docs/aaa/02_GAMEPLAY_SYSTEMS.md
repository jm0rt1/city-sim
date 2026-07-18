# Gameplay Systems Specification

## 1. System-wide rules

All gameplay systems follow a common contract:

- State changes occur through explicit commands and deterministic simulation steps.
- Every cost, capacity, eligibility rule, and material outcome is inspectable.
- Subsystems exchange defined inputs and outputs rather than mutating one another's state invisibly.
- Visual, audio, UI, and historical feedback derive from the same authoritative state.
- Difficulty changes parameters within documented bounds; it does not create hidden exceptions.
- The player can pause before committing construction, policy, or budget actions.
- Destructive actions preview consequences and require confirmation when recovery would be expensive.

The simulation uses a fixed logical tick. Rendering, audio, and UI may interpolate but may not advance authoritative game state.

## 2. World and land

### 2.1 Region model

Each playable region contains terrain elevation, buildability, soil or ground class, water, shoreline, ecology, natural resources, climate, external connections, hazard exposure, and authored points of interest. These layers affect engineering cost, attractiveness, pollution, industry, mobility, and disaster risk.

Regions must support terraforming within bounded slope, water, cost, and environmental rules. Water flow and terrain changes can invalidate planned construction before commitment but may not silently delete built assets.

### 2.2 Parcels and districts

The world resolves construction against a spatial grid or parcel graph that supports:

- Network adjacency and access.
- Buildable footprint and slope checks.
- Ownership and acquisition cost.
- Zone, district, policy, and service membership.
- Historical provenance for placed, upgraded, moved, or demolished assets.

Players can name districts and draw editable boundaries. District policies, service priorities, visual identity, and statistics use those same boundaries.

### 2.3 External world

Every region has one or more outside connections for people, freight, power, water, waste, and regional contracts as appropriate. Outside capacity and prices are finite, can change through events, and remain visible to the player.

## 3. Networks, zoning, and construction

### 3.1 Planning state

Roads, transit, utilities, zones, service buildings, parks, and civic assets begin as a non-authoritative preview. The preview shows footprint, grade, demolition, acquisition, construction cost, operating cost, capacity, access, and blocking rules before commitment.

Queued plans may be grouped into a project. A project can be confirmed, reordered, paused, or canceled. Cancelation refunds only unspent construction value and reports sunk cost.

### 3.2 Roads and paths

Road construction supports straight and curved segments, intersections, bridges, tunnels, grade constraints, snapping, upgrades, and reversible direction where the road type permits. A committed edit rebuilds only affected graph regions and preserves unaffected route state.

Road types define lanes, speed, access, parking, transit compatibility, freight permissions, pedestrian quality, noise, cost, maintenance, and visual kit.

### 3.3 Zoning and development

Release zones include residential, commercial, industrial, office or mixed employment, and mixed-use forms. Zone controls include density, frontage or access, district style, and selected policy modifiers.

Zoning grants development permission; it does not instantly place a finished building. A developer evaluates demand, land value, access, utilities, labor, customers, pollution, risk, policy, and available parcels. Approved projects move through site preparation, construction, occupancy, operation, upgrade, decline, abandonment, and redevelopment.

### 3.4 Ploppable assets

Services, utilities, parks, landmarks, and special industry are placed directly by the player. Placement reports service reach or network effects without promising outcomes that depend on later traffic or staffing.

### 3.5 Demolition and relocation

Demolition reports direct cost, displaced households and jobs, network impact, historical loss, waste, and affected objectives. Critical network demolition and inhabited landmark removal require a stronger confirmation. Eligible civic assets may be relocated through an explicit project rather than deleted and recreated.

## 4. Time and simulation cadence

The player can pause and select three forward speeds. Speed changes alter wall-clock pacing only. All speeds must produce equivalent authoritative results for the same commands, seed, and number of ticks within documented numeric tolerance.

Subsystem cadence is tiered:

- Every tick: command application, network reservations, immediate incidents, and authoritative clocks.
- Frequent: movement, traffic signals, utility flow, construction animation state, and urgent service dispatch.
- Periodic: household and business choices, service outcomes, demand, land value, pollution, and maintenance.
- Daily: treasury settlement, migration, education or health progression, policy effects, and objective checks.
- Monthly or annual: taxes, debt, budget planning, demographic cohorts, market cycles, and historical summaries.

## 5. Population and households

### 5.1 Population model

The simulation represents households and persons at a fidelity chosen by scale. Persistent household identity includes home, members or cohort composition, income band, employment, education, life stage, transport access, needs, satisfaction, and migration history. Visual crowd agents may be sampled from authoritative trips rather than equal one persistent renderer entity per resident.

### 5.2 Needs and satisfaction

Household outcomes derive from housing cost and quality, employment, travel burden, safety, health, education, utilities, environment, recreation, social access, taxation, and recent shocks. A citywide happiness number is a summary, never the sole authority. Inspectors must expose distributions and major drivers.

### 5.3 Migration and displacement

Households compare the city and available homes against outside options. New arrivals require an eligible dwelling and plausible opportunity. Departure, eviction, disaster displacement, redevelopment displacement, and voluntary moves are distinct events with distinct policy effects.

### 5.4 Equity

Service, travel, pollution, housing, and fiscal outcomes are measurable by district and household group. The game does not assign moral scores to demographics. It exposes distributional consequences and lets scenarios or policies define explicit equity goals.

## 6. Economy, employment, and land value

### 6.1 Businesses and jobs

Businesses occupy eligible buildings, hire from reachable labor pools, buy inputs, sell outputs, pay costs, and may expand, contract, relocate, or fail. Employment matching considers skill, wage, travel time, schedule, and availability. Unfilled jobs and unemployment can coexist when access or skills do not match.

### 6.2 Markets and demand

Residential and business demand are derived indicators of viable unmet development, not arbitrary bars. Inspectors decompose demand into population, income, vacancies, land availability, access, costs, policy, and macroeconomic pressure.

### 6.3 Land value and property

Land value responds to access, permitted use, service quality, jobs, amenities, environment, safety, congestion, taxation, hazard, and nearby disamenities. Property value affects development feasibility and revenue but does not instantly evict occupants; rent or cost pressure acts through leases, moves, subsidies, and redevelopment.

### 6.4 Production and freight

Industrial and commercial chains consume inputs, use storage, create freight trips, and lose output when logistics fail. Release 1 uses understandable production classes rather than requiring the player to micromanage individual contracts.

## 7. Treasury and finance

The treasury is a reconciled ledger. Every balance change has a timestamp, category, source, amount, and related entity or policy where applicable.

Revenue can include property or land tax, income or sales tax abstractions, utility fees, fares, service fees, grants, external contracts, and asset sales. Expense can include construction, maintenance, wages, procurement, imports, debt service, emergency response, subsidies, and policy programs.

Budgets set funding targets by service and district priority. Funding affects capacity, quality, staffing, maintenance, and response time through visible curves. Budget cuts do not produce an unexplained global penalty.

Debt instruments define principal, interest, term, payment schedule, covenants, and credit impact. Fiscal crisis escalates through warnings and recovery choices before a terminal scenario condition.

## 8. Mobility, traffic, and transit

### 8.1 Trip generation

Households, businesses, services, freight, visitors, and external connections generate purpose-based trips. A trip has origin, destination, time window, mode eligibility, value or urgency, and completion outcome.

### 8.2 Mode and route choice

Available modes include walking, private vehicle, freight vehicle, public transit, service vehicle, and region-appropriate micromobility. Choice considers generalized cost: time, money, transfers, reliability, parking, comfort, policy, and access.

Routes use current network restrictions and estimated congestion. Agents may re-route at bounded intervals; they may not gain omniscient, frame-perfect knowledge.

### 8.3 Road operations

Intersections, signals, lane permissions, merging, parking access, incidents, and service priority affect throughput. Congestion is reported by delay and reliability, not only vehicle count. Gridlock detection identifies causally important links and destinations.

### 8.4 Public transit

Players create lines from compatible stops and depots, assign vehicle class and service frequency, and inspect capacity, waiting, travel time, transfers, reliability, fare, operating cost, and ridership. A line must fail visibly when it lacks a valid path, depot, vehicle, staff, power, or budget.

### 8.5 Freight and services

Freight shares the network but has class restrictions, loading needs, delivery windows, and external gateways. Emergency and critical utility vehicles can receive bounded priority; priority does not allow impossible routing through disconnected networks.

## 9. Utilities and municipal services

### 9.1 Utility networks

Power, water, wastewater, solid waste, and communications each expose supply, demand, capacity, connectivity, quality, storage where relevant, operating cost, and resilience. Imports can bridge shortages at an explicit price and capacity limit.

Failures propagate through the actual dependency graph. For example, a power outage can reduce pumping capacity, which can affect water service and fire response. The inspector must expose the dependency chain.

### 9.2 Public services

Release services include fire, police or public safety, healthcare, education, parks and recreation, waste, maintenance, and civic administration. Each uses appropriate combinations of coverage, travel time, staffing, capacity, facility quality, budget, and demand.

Coverage overlays show potential access; actual outcome views show delivered service. The UI may not present radius alone as proof of service quality.

### 9.3 Maintenance and lifecycle

Networks and assets accumulate use, age, and damage. Maintenance funding and access affect reliability. Deferred maintenance creates rising risk and cost, with visible degradation before catastrophic failure whenever the event permits.

## 10. Governance and policy

Policies operate at city or district scope and define eligibility, cost, lead time, ongoing administration, direct effects, side effects, and repeal consequences. Policy examples include tax rates, development rules, transit pricing, parking, emissions controls, subsidies, service priorities, disaster preparation, and conservation.

Public sentiment is a distribution of issue responses informed by outcomes, expectations, identity, and recent events. It influences objectives, migration, compliance, and scenario scoring; it does not disable lawful player actions without an explicit governance rule.

## 11. Environment, weather, and disasters

### 11.1 Environmental systems

Air, water, ground, noise, heat, habitat, tree canopy, and emissions derive from sources, transport or spread, exposure, and mitigation. Environmental quality affects households, businesses, health, land value, policy, and regional reputation.

### 11.2 Weather and seasons

Weather changes lighting, ambience, visibility, demand, travel, energy, water, fire risk, and maintenance within region-specific bounds. Seasons alter ecology and consumption without making normal operation arbitrarily impossible.

### 11.3 Incidents and disasters

Incidents range from local fires and outages to storms, floods, earthquakes, heat waves, and regional economic shocks. A disaster follows readiness, warning where plausible, impact, response, recovery, and review phases. Damage is spatial and systemic. Recovery creates projects, aid, displacement, fiscal choices, and resilience opportunities.

Random events use seeded streams and bounded frequency. Players can disable major disasters in sandbox without disabling ordinary service incidents.

## 12. Objectives and progression

Milestones require durable combinations of population, fiscal health, access, service outcomes, and city capability. Population alone never unlocks the entire technology tree.

Objectives have:

- A clear statement and rationale.
- Current value, target, deadline if any, and trend.
- Explicit pass, fail, and persistence conditions.
- A source link to relevant inspectors or overlays.
- A reward that changes capability, resources, recognition, or scenario score.

The game supports optional mayoral mandates, scenario goals, campaign goals, achievements, and self-authored pinned metrics. Progression expands options rather than applying unexplained global buffs.

## 13. Feedback and consequence protocol

Every player command follows this feedback sequence:

1. **Preview:** legality, cost, affected entities, and major forecast uncertainty.
2. **Commit:** unmistakable visual and sonic confirmation with undo or cancel where safe.
3. **Process:** construction, dispatch, policy lead time, or other visible transition.
4. **Outcome:** world state, metrics, and people respond.
5. **Explanation:** inspectors and event history retain the causal chain.

Major outcomes use restrained celebration or warning. Repeated minor events aggregate; the notification system may not train players to ignore it.

## 14. Balance principles

- No mandatory opening sequence beyond true dependency constraints.
- No service building solves a problem through radius alone.
- Capacity without access, staffing, funding, or maintenance is not effective capacity.
- Growth creates both revenue and new obligations.
- Density improves some efficiencies while creating land, congestion, heat, and service pressures.
- External imports are useful bridges, not unlimited permanent substitutes without tradeoffs.
- Disasters reward preparation and adaptation rather than random punishment.
- Creative construction remains viable on standard difficulty; difficulty comes from consequence, not tedious placement restrictions.

## 15. System acceptance

A subsystem is release-complete only when its rules are deterministic, its commands and data contracts are versioned, its outcomes participate in at least one meaningful cross-system loop, its state is inspectable, its feedback is represented in the world and UI, its balance fixtures pass, and its failure and recovery paths have authored playtest coverage.

