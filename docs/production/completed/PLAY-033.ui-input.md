# PLAY-033 Completion — Make the HUD a Compact City Command Center

- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Status:** ready-for-integration
- **Base authority:** `c3c0f4ad109791fe5a90dd120b98a9812ff685e2`
- **Exact staged product candidate:** `dd878b232be003fffa653185d69872ac4d4a27a4`

## Player-visible outcome

At exact 900 x 600 content, simultaneous Objectives and Command Center details now follow one deterministic precedence rule: Objectives becomes its compact summary and Command Center details are capped at 72 points with visible scrolling. The measured live HUD leaves 246 / 600 points (41%) for the interactive map, keeps the selected tile visible, and retains diagnostic and destructive actions.

The command guide now translates warning vocabulary directly into the existing policy surface. Searches for `tax`, `budget`, and `storefront` find the visibly named `Open Tax Policy and Finances` command and preserve its current catalog availability or disabled reason. Search remains on the one catalog/store intent path.

Rejected placement feedback now persists until the player acts or dismisses it, includes the accepted `BuildRejection` reason, states that the selected tool remains active, and exposes the message as an accessible `Action blocked` status. The rejected coordinate does not become a selected inspector target. The existing speed truth now produces an unmistakable textual/icon `PAUSED` or `RUNNING Nx` HUD state with a labeled accessibility value.

## Ordered product commits

1. `3d964e246bb266a98ab46ba77e3f7a3b1a0fa7dc` — `PLAY-033: Preserve compact map dominance`
2. `64b9c995bdcd75584cfc2eb4190594d599936d53` — `PLAY-033: Find tax remedies from warning language`
3. `4fc596809d1156769ba009a919c6453676d70683` — `PLAY-033: Keep placement recovery actionable`
4. `7f9344ddc652cc7670e40594e294d6bd7a5a791c` — `PLAY-033: Preserve rejected-build selection semantics`
5. `5672d2b6175231644155a4ad64c3b658ad5371ee` — `PLAY-033: Name the searchable tax policy remedy`
6. `dd878b232be003fffa653185d69872ac4d4a27a4` — `PLAY-033: Meet the compact map occupancy gate`

The fourth commit is an explicit correction checkpoint: the first full-suite run exposed that selecting a rejected coordinate violated the existing interaction invariant. The correction retained the active tool and durable reason without changing selection or HUD scope. History was preserved; no commit was rewritten.

## Exact product and test files changed

- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Sources/CitySimNative/Support/CityCommandCatalog.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/BuildToolbarView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/CommandGuideView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/ContentView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/TopHUDView.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CitySimulationTests.swift`

The `CitySimulationTests.swift` edit remains limited to its existing ownership of ContentView compact arbitration and presentation measurement. It adds no simulation-rule assertion.

## Automated validation

- Focused `CityCommandCatalogTests`: 21 tests passed with 0 failures after the search and placement checkpoints.
- `CityCommandCatalogTests.testWarningLanguageFindsTaxPolicyThroughTheCatalog` covers `tax`, `budget`, and `storefront` plus exact catalog inventory uniqueness.
- `CityCommandCatalogTests.testTaxPolicySearchResultUsesCurrentAvailabilityAndDisabledReason` proves enabled and Welcome-blocked availability use the existing store policy.
- `CityCommandCatalogTests.testRejectedPlacementPreservesToolTargetAndDurableAcceptedReason` proves the active Commercial tool, accepted reason, persistence beyond 3.2 seconds, catalog dismissal, and unchanged selection scope.
- `CitySimulationTests.testMapFirstChromeDefaultsClosed` proves compact Objectives arbitration, the 72-point details cap, the 41% measured map ratio, and exact paused/running presentation values.
- `CityCommandCatalogTests.testMeasuredHUDChromeKeepsKeyboardSelectionInsideDefaultAndExactCompactMapViewport` retains measured HUD-safe insets for default and compact selection.
- First full native suite: 122 tests with 1 failure in the pre-correction rejected-selection invariant. The focused correction then passed.
- Final full native suite on `dd878b2`: 122 tests passed, 0 failures in 378.793 seconds.
- Final renderer diagnostics from that unchanged renderer: 5,759 reused tiles, 1 updated tile, 1.778 ms average; 4,286-pulse soak averaged 1.2034 ms.
- `git diff --check` passed.
- `bash -n script/build_and_run.sh` passed.
- Exact staged `./script/build_and_run.sh --verify` passed for candidate `ui-input-wdbeadac6e0bd` at `dd878b2`.

## Staged default and compact journeys

The exact product candidate and retained evidence are documented in `docs/production/evidence/PLAY-033/dd878b2/README.md`.

- Default, pointer and keyboard: visible/AX `PAUSED`; Commands opened with search focus; `tax`, `budget`, and `storefront` each found the available Tax Policy route; Escape restored map focus without shortcut leakage.
- Default placement: keyboard selected Commercial and pointer chose an occupied structure. Build/Commercial stayed selected, the exact accepted reason appeared in both durable HUD feedback and the tested map overlay, and the accessible message remained present after four seconds.
- Exact compact: `CITYSIM_COMPACT_WINDOW=1` produced 900 x 600 content. Objectives collapsed to summary when details opened. The selected Road block 14,13 remained visible; the details scroll region, City data menu, close action, and `Demolish Road $50` remained reachable. Measured live map occupancy was 41%.
- Focus/accessibility: search focus, safe Escape, map focus, selected state, feedback value, scroll-region label, menu/action labels, and keyboard Tab reachability were inspected in the live AX tree. Full Keyboard Access-critical semantics were exercised; spoken VoiceOver was not claimed.

Retained captures:

- `docs/production/evidence/PLAY-033/dd878b2/default-paused.jpeg`
- `docs/production/evidence/PLAY-033/dd878b2/default-tax-policy-search.jpeg`
- `docs/production/evidence/PLAY-033/dd878b2/default-placement-rejection-after-4s.jpeg`
- `docs/production/evidence/PLAY-033/dd878b2/compact-objectives-command-center.jpeg`

## Compatibility and quality consequences

- **Command/store:** no new `CityCommandID` or public command contract was added. Catalog-owned matching and aliases feed the existing descriptor, `canPerform`, disabled-reason, and `perform` route.
- **Gameplay/urgency:** no PLAY-013 analytics were consumed. No countdown, deadline, or simulation pacing was inferred or implemented; authoritative urgency remains a separate integration-supplied checkpoint.
- **Renderer:** no renderer or world-presentation file changed. The single occupied-placement proof does not claim general renderer truth.
- **Save/session:** no model, save schema, persistence service, state mutation contract, or session behavior changed. Save was not invoked in this presentation-only live journey; the complete native suite remained green.
- **Focus/cancellation:** command-guide Escape returns to the map. Existing topmost-first Escape and speed-restoration routes remain authoritative; no shortcut-specific path was added.
- **Accessibility:** status is conveyed through text, icon, color, value, and selection rather than color alone. The persistent error is dismissible through the existing command catalog.
- **Reduce Motion:** existing opacity-only feedback behavior remains in force when Reduce Motion is enabled; no new animation dependency was introduced.
- **Performance:** search filters immutable command metadata and compact layout only changes SwiftUI presentation. Simulation observation and renderer invalidation boundaries are unchanged.

## Shared-contract and merge notes

No shared-contract proposal is required. Integration should apply the six ordered product commits, followed by the evidence/completion commit containing this record. CONTRACT-007 urgency analytics remain deliberately unconsumed until the PLAY-013 checkpoint is supplied. No push or integration was performed by this lane.
