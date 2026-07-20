# PLAY-031 Completion — Quarantine Onboarding Input and Restore the Intended Window

## Outcome

PLAY-050-D005 is repaired on `codex/citysim-ui-input`. Welcome now owns command eligibility, hit testing, keyboard focus, and accessibility exposure through one store-owned `CityCommandPolicy`. While Welcome blocks, the underlying HUD, toolbar, build deck, map, panels, catalog dispatch, and renderer camera shortcuts cannot act or enter the accessibility tree. The only app-content action exposed is `welcome.start-building`.

Fresh isolated candidates establish the intended 1,440 x 900 default once, subject to the host display's visible-frame constraint. Later user resizing remains intact. `CITYSIM_COMPACT_WINDOW=1` remains the sole route that requests the 900 x 600 proof content size. Production preferences and non-candidate window restoration are not changed.

## Commits

1. `1a14df2ad8707b781d8bedd668de9472a29f59d5` — `PLAY-031: Quarantine onboarding commands`
2. `640f7e3d04a714e1b042ee9ae43aa40b4fb81700` — `PLAY-031: Restore fresh candidate window size`
3. `cd97787b64854d0041dca0636247599c41fcbf65` — `PLAY-031: Contain onboarding focus`
4. `bacbe6fdba3d85047fca49548191b8dfec29c5c0` — `PLAY-031: Restore gameplay focus after welcome`
5. `fc61b177a639e768615664a46f7a5e8f81381c30` — `PLAY-031: Tie focus restoration to welcome policy`

Integration authority `43be4f40f92827c081663ed41fcc93090ce506fc` and product candidate ancestor `c70321b` are both ancestors. No push or integration was performed.

## Authoritative policy and routing

- `CityGameStore.commandPolicy` is the sole blocking-modal authority.
- `perform`, `canPerform`, disabled reasons, simulation pulses, and map primary/secondary actions consume that policy.
- `CityScene` asks the same policy before gameplay, Escape, and renderer camera shortcuts; SpriteKit still dispatches non-spatial intent exactly once through the store.
- SwiftUI toolbar presence and the game surface's hit-testing/accessibility exposure derive from the same policy. There is no parallel presentation flag.
- Welcome renders from `.blocked(.welcome)`. Return dismisses from initial non-action modal focus; pointer, Full Keyboard Access, and VoiceOver can activate the labeled CTA. Leading Space remains inert.
- Dismissal transitions the policy to `.enabled` without changing the authored normal speed or gameplay state. The existing `hasSeenCitySimWelcome` preference remains the persistence mechanism.

## Automated validation

The final full native suite passed 80 tests with 0 failures in 39.085 seconds. Focused coverage includes:

- `CityCommandCatalogTests.testWelcomePolicyBlocksEveryCatalogAndRendererRouteUntilExplicitDismissal`
- `CitySimulationTests.testBlockingWelcomePreservesExactAuthoredStartUntilDismissed`
- `CitySimulationTests.testMapFirstChromeDefaultsClosed`
- `ProofWindowConfiguratorTests.testFreshCandidateGetsDefaultButOnlyExplicitCompactGetsNineHundredBySixHundred`
- catalog inventory, shortcut collision/equivalence, renderer dispatch, compact/default command-guide, save/session round-trip, fingerprint, recovery, gameplay, and world-rendering suites

Final static checks passed:

- `git diff --check`
- `bash -n script/build_and_run.sh`
- exact staged `./script/build_and_run.sh --verify` at `cd97787b64854d0041dca0636247599c41fcbf65`

Save/session architecture and behavior are unchanged; the session and persistence suites passed in the final run.

## Live D005 and accessibility evidence

Exact isolated candidate:

- bundle: `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- executable: `dist/CitySim-ui-input-wdbeadac6e0bd.app/Contents/MacOS/CitySimNative-wdbeadac6e0bd`
- staged commit: `cd97787b64854d0041dca0636247599c41fcbf65`

On a fresh default launch, the exact sequence Space, 1, 2, 3, B, V, Escape, Command-/ was sent to the focused Welcome modal. At 0, 10, 30, and 60 seconds:

- Welcome remained visible and the focused accessibility element remained `welcome.blocking-modal`.
- `welcome.start-building` remained enabled, labeled, and reachable.
- no HUD speed controls, notices, command deck, build controls, toolbar actions, map/SKView, or Command Guide appeared in the accessibility tree.
- the visible background remained Day 1, $26,000, population 300, one notice, the original objective, and 1x throughout the blocked interval.

Return dismissed Welcome. The first post-dismissal accessibility read showed Day 1, $26,000, population 300, one notice, the original objective, and 1x selected; the complete HUD/map/toolbar tree reappeared. After map focus, `2` selected 2x and `B` selected Bulldoze with visible feedback. Command-/ opened the searchable command guide and Escape closed it.

The compact candidate was relaunched from fresh isolated preferences with `CITYSIM_COMPACT_WINDOW=1`. Its blocking tree likewise exposed only Welcome and the CTA. Pointer activation dismissed it and restored the compact HUD/map/toolbar tree at Day 1 and 1x.

## Window and retained captures

The host display constrained the requested 1,440 x 900 default content to a 1,229 x 768 captured window frame (approximately 1,229 x 736 content before toolbar presentation), clearly distinct from compact. The explicit compact launch requested exactly 900 x 600 content and produced a 900 x 632 Welcome frame; after the toolbar returned, the same 900 x 600 content produced a 900 x 652 decorated frame. Thus the prior 900 x 652 result occurs only after explicit compact launch, not on a normal fresh candidate launch.

- `docs/production/evidence/PLAY-031/default-welcome-contained.jpeg` — default Welcome at the 60-second gate, 1,229 x 768
- `docs/production/evidence/PLAY-031/default-keyboard-dismissed.jpeg` — default keyboard dismissal, 1,229 x 768
- `docs/production/evidence/PLAY-031/default-gameplay-commands.jpeg` — default post-dismissal command routing, 1,229 x 768
- `docs/production/evidence/PLAY-031/compact-welcome-contained.jpeg` — compact blocking Welcome, 900 x 632 frame / 900 x 600 content
- `docs/production/evidence/PLAY-031/compact-pointer-dismissed.jpeg` — compact pointer dismissal, 900 x 652 frame / 900 x 600 content

## Contract review

No shared-contract conflict was found. PLAY-031 extends the accepted CONTRACT-002 catalog/store route with typed modal availability and does not redefine command IDs, gameplay progression truth, persistence, renderer truth, or spatial-grid keyboard design.

## D006 follow-up repair

Independent PLAY-050 testing found that both Return and pointer activation removed Welcome but left first-responder ownership on the vanished SwiftUI modal/window. Bare gameplay shortcuts were therefore inert until the player clicked the `SKView`; global Command-/ still worked through the menu route.

The repair is scoped to the existing focus boundary:

- `WelcomeView` releases its `@FocusState` before either dismissal route invokes the shared continuation.
- `CitySceneView.Coordinator` retains the previous typed `CityCommandPolicy`.
- `updateNSView` observes the exact `.blocked(.welcome)` to `.enabled` transition while holding the real `SKView`, then calls `window.makeFirstResponder(view)` once.
- Enabled-to-enabled updates and enabled-to-blocked presentation do not change first responder. There is no delay, timer, duplicate shortcut route, rendering change, or new shared contract.

Clean writable-cache validation on candidate `fc61b177a639e768615664a46f7a5e8f81381c30`:

- focused `CityCommandCatalogTests`: 10/10 in 0.730 seconds;
- full native suite: 88/88 in 225.292 seconds;
- the focused AppKit regression moves first responder from an actual `NSTextField` to an actual `SKView` only for the typed Welcome dismissal transition, then proves the transition cannot churn focus;
- exact staged `./script/build_and_run.sh --verify` passed for bundle `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`, executable `CitySimNative-wdbeadac6e0bd`, PID 50539, with isolated candidate data and freshly reset candidate preferences.

The Computer Use `get_app_state` call hung without returning accessibility or screenshot state and was aborted after the integration captain intervened. No live D006 pass is claimed from this lane. The previously retained D001 default/compact containment captures remain valid because the repair does not alter modal visibility, hit testing, accessibility hiding, or command policy. PLAY-050 must independently prove both dismissal routes, immediate Space/1-3/B/V operation without a click, Command-/ and Escape precedence, and absence of vanished modal focus before acceptance.
