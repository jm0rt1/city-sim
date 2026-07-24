# PLAY-012 Integrated Three-Act Closure Evidence

- **Lane:** gameplay loop
- **Branch:** `codex/citysim-gameplay-loop`
- **Candidate HEAD before this evidence:** `df289420698af776fa13dccbde7f6f123b9ded86`
- **Integrated authority:** local master `39980d753a566a2a4ea68e320f059d8046d051b7`
- **Preserved PLAY-015 HEAD:** `c808ac1f83520c8525bad7e7a99de0430b8c027f`
- **Staged candidate:** `gameplay-loop-w8f1a46b88376`
- **Bundle identifier:** `com.jfmortensen.citysim.gameplay-loop.w8f1a46b88376`
- **Data root:** `dist/test-data/gameplay-loop-w8f1a46b88376`
- **Disposition:** PLAY-012 closes without a gameplay change because the accepted PLAY-013, PLAY-014, PLAY-015, PLAY-038, PLAY-045, and PLAY-046 stack now satisfies the original three-act promise.

## Gap matrix

| PLAY-012 outcome | Integrated successor coverage | Deterministic evidence | Exact staged result |
| --- | --- | --- | --- |
| Opening fork by 02:00 | PLAY-012 authors the visible Commercial/Industrial fork; PLAY-013 makes the first successful eligible placement commit at the next daily boundary and prevents a late choice from flipping or cascading. | Focused tests preserve rejected-placement no-op, late-choice catch-up, route non-flip, stale-guidance retirement, and daily-boundary scheduling. | Commercial committed in 00:44; Industrial committed in 00:30 using ordinary visible controls. |
| Strategy-specific complication | PLAY-013 schedules monotonic opportunity, warning, setback, and payoff phases relative to commitment. | Fixed daily checks place authored beats no more than 26.88 seconds apart at 1x. | Commercial saw Market Weekend, Chain Store Rumor, and Storefront Slump Avoided. Industrial saw Regional Freight Contract, Freight Load Forecast, and Industrial Load Absorbed. |
| Recovery decision | PLAY-014 makes tax relief, public-realm investment, utility expansion, and green buffer durable first-qualifying identities. | All four resolution identities are non-flipping, undoable, round-trip compatible, and viable to tick 844. | Commercial chose 9% tax relief. Industrial built power and water capacity. Both routes displayed the matching recovery and payoff copy. |
| Durable Charter victory inside 20:00 | PLAY-015 enters existing `.won` on the award boundary; PLAY-038/045/046 provide terminal presentation, command immutability, save/load, and relaunch behavior. | All four recovery routes win at tick 844; terminal state remains immutable through tick 2,800; legacy awarded-playing state normalizes only at its next daily boundary. | Commercial won Day 212 in 06:42. Industrial won Day 212 in 05:22. Both showed `Town Charter Secured` and the correct strategy/recovery identity. |
| At least three consequential decisions | PLAY-012/013/014 connect placement, response, and recovery to authoritative economy and progression. | Representative zoning, tax, park, and utility actions alter state at governed checks. | Commercial: first zone, tax policy, power, water, second zone. Industrial: first zone, power, water, second zone. |
| Feedback within 15 seconds of relevant simulation time | Existing daily evaluation produces numerical and message feedback within one four-tick day where the consequence is immediate; scheduled story consequences retain their advertised phase timing. | One day is 1.68 seconds at 1x; exact-once story phases advance monotonically. | Commercial first zone 1.38s, tax response 14.41s, second zone 2.37s. Industrial first zone 1.54s and second zone 2.34s; utility purchases charged treasury immediately and capacity updated at the governed check. |
| No unexplained wait over 30 seconds | PLAY-013 phase-relative scheduling and the accepted HUD/messages explain every authored wait; growth remains visibly advancing. | Story gaps are at most 26.88 seconds at 1x. | Story waits were at most 11.29s. The longest observed growth chunk was under 25s. One 34.60s Industrial interval was active diagnosis and construction, not idle or unexplained time. |
| Distinct viable routes | PLAY-011/012 establish divergent strategy effects; PLAY-014 preserves route-specific recovery identities. | Both routes reach tick 844 while retaining distinct cashflow, jobs, happiness, pollution, utilities, recovery cost, and message identity. | Commercial ended at `$11,796`, `+$104/cycle`, 61% happiness. Industrial ended at `$37,445`, `+$254/cycle`, 55% happiness with visibly heavier job and utility load. |

No gameplay-owned acceptance gap remained. No product, renderer, UI/input,
save-schema, package/build, fixture, shared-contract, or legacy-Python file was
changed for this closure.

## Commercial no-coaching timeline

The journey began from a fresh region and used visible pointer actions,
keyboard map navigation, Return, Space, and the existing speed controls. The
pause action settled at Day 5 because of ordinary UI action latency; the first
consequential choice still landed 44 seconds after the session timer began.

| Elapsed / city time | Player action or visible consequence | Causal result |
| --- | --- | --- |
| 00:44 / opening | Place Commercial at visible valid block 15,14. | Within 1.38s, cashflow changed `-$60` to `+$85`, 57 open jobs appeared, treasury was charged, and utility headroom changed. |
| Day 6 | Main Street Crossroads. | Commercial stewardship committed and stale opening guidance retired. |
| Day 22 | Market Weekend. | Visible message credited `$1,800` in measured Main Street activity with lower utility exposure. |
| Day 38 | Chain Store Rumor. | Visible warning explained the Day-54 deadline and `$3,000` risk. |
| +14.41s from warning interaction | Use `Act on Chain Store Rumor`, review tax policy, and choose 9%. | Cashflow changed `+$82` to `+$48`; tax changed 10% to 9%; the response remained inside the 15-second feedback gate. |
| Day 54 | Storefront Slump Avoided. | Tax relief avoided the `$3,000` shock in exchange for lower revenue and demand. |
| Before payoff | Build a Water Tower and Power Plant through existing routed tools. | Treasury and utility capacity visibly responded; these were additional consequential actions. |
| Day 70 | Main Street Rebound. | `$1,500` recovery dividend and confidence payoff. |
| After payoff | Place a second Commercial zone. | Within 2.37s, cashflow changed `-$146` to `-$16` and open jobs changed 12 to 91. |
| Day 212 / 06:42 | Town Charter victory. | Terminal overlay reported 511 residents, `$11,796`, `+$104/cycle`, 61% happiness, `Commercial Stewardship`, and `Recovery · Temporary Tax Relief`. |

The largest passive progression chunk was 24.59 seconds. Every longer interval
contained visible player diagnosis or interaction.

## Industrial no-coaching timeline

The journey began through the terminal overlay's visible `Start a New Region`
action. The pause action settled at Day 3; the first Industrial decision landed
30 seconds after the session timer began.

| Elapsed / city time | Player action or visible consequence | Causal result |
| --- | --- | --- |
| 00:30 / opening | Place Industrial at visible valid block 15,14. | Within 1.54s, cashflow changed `-$61` to `+$137`, 88 open jobs appeared, treasury was charged, and power/water headroom tightened more sharply than on the Commercial route. |
| Day 4 | Freight Contract Watch. | Industrial expansion committed and stale opening guidance retired. |
| Day 20 | Regional Freight Contract. | Visible message credited `$5,000` in measured industry with stronger jobs and higher exposure than stewardship. |
| Day 36 | Freight Load Forecast. | Visible warning required added power and water or a green buffer before Day 52 and explained the `$5,500` risk. |
| Active 34.60s interaction | Use the visible `Act` path, then place Power and Water on valid blocks 16,14 and 17,14. | Treasury changed immediately; the next governed check reflected capacity. This was continuous diagnosis and construction, not dead time. |
| Day 52 | Industrial Load Absorbed. | Early utility reserves avoided the `$5,500` disruption. |
| Day 68 | Freight Network Secured. | The route repaid a `$5,500` industrial recovery dividend. |
| After payoff | Place a second Industrial zone at block 18,14. | Within 2.34s, cashflow changed `-$66` to `+$111` and open jobs changed 44 to 153. |
| Day 212 / 05:22 | Town Charter victory. | Terminal overlay reported 511 residents, `$37,445`, `+$254/cycle`, 55% happiness, `Industrial Expansion`, and `Recovery · Utility Expansion`. |

The largest passive progression chunk was under 25 seconds. The retained
terminal screenshot is:

`/var/folders/lt/l53t4qb94_j47hhmm9ylk9nw0000gn/T/com.openai.sky.CUAService/CitySim [Gameplay w8f1a46b88376] Screenshot 2026-07-23 at 1.17.46 PM.jpeg`

## Validation

- `swift test --package-path Native/CitySimNative --filter GameplayLoopTests`
  with isolated approved module caches: **31/31 passed**, 0 failures, 10.730s.
- Complete native suite with the same caches: **159/159 passed**, 0 failures,
  410.496s.
- Platform frozen checkpoints, terminal victory, undo/save/load, command
  immutability, rendering, and strategy suites all passed.
- Exact deterministic pre-victory tick 840 and terminal tick 844 checkpoints
  passed.
- Renderer diagnostic average: **1.398 ms**.
- `bash -n script/build_and_run.sh`: passed.
- `git diff --check`: passed.
- `./script/build_and_run.sh --verify`: passed for exact candidate
  `gameplay-loop-w8f1a46b88376`; resource bundle and isolated data root were
  present, and the staged process remained alive for both journeys.

The first unprivileged test launch was blocked before compilation by
`sandbox-exec: sandbox_apply: Operation not permitted`. The exact commands were
rerun with the approved workspace caches and produced the results above; no
test failure was hidden or inferred away.

## Closure

The originally blocked PLAY-012 checkpoint is now fully covered by accepted
integrated successors and exact current-stack live evidence. This record does
not recharacterize the old blocked candidate as sufficient on its own; it
closes the player promise against the current integrated terminal stack.
