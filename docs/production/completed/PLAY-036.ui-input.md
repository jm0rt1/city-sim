# PLAY-036 Completion — Make Searched Remedies Reliably Actionable

- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Status:** accepted
- **Claim authority:** `a264f3489adaa259d61f32dae281b97d2e3e50b1`
- **Authority merge:** `539abce4d805c11ede392b3c1aad85e94d18ae87`
- **Product commit:** `878114e2fde2be18bad88b1b53294cafb19e18e8` — `PLAY-036: Make searched remedies actionable`

## Outcome

The command guide now presents an actionable catalog row as the real SwiftUI `Button` instead of combining the button into an outer accessibility element. The sole filtered result owns the default Return action, focused buttons retain native Space activation, and accessibility Press reaches the same button. Successful guide activation calls `CityGameStore.perform(_:)` once through `performFromCommandGuide`, then dismisses the guide so the existing destination is visible. Failed or disabled activation leaves the guide open and retains the store-owned disabled reason.

Every guide opening explicitly clears the previous query and defers search focus until the sheet is mounted. Existing catalog keywords remain the only search source: no Tax Policy alias or warning text was hard-coded in the view.

## Files changed

- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Sources/CitySimNative/Views/CommandGuideView.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`

No renderer, simulation, gameplay, save/session, model, CONTRACT-008, PLAY-034, or spatial target surface changed.

## Automated validation

- `CityCommandCatalogTests`: 24 tests passed, 0 failures in 33.447 seconds.
- New `testCommandGuideActivationUsesExistingStoreIntentAndKeepsDisabledReason`: available activation opened Finances and dismissed the guide; Welcome-blocked activation retained the guide and exact existing disabled reason.
- Existing search coverage proved `tax`, `budget`, and `storefront` resolve to the same single Tax Policy descriptor with current availability and disabled reason.
- Full native suite: 133 tests passed, 0 failures in 371.076 seconds.
- Renderer diagnostics from unchanged rendering: 5,759 reused tiles, 1 updated tile, 1.443 ms average; 4,286-pulse soak averaged 1.1179 ms.
- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- Exact staged `./script/build_and_run.sh --verify`: passed at `878114e2fde2be18bad88b1b53294cafb19e18e8`.

## Staged proof

Default and exact 900 x 600 content pointer/keyboard/AX journeys are retained in `docs/production/evidence/PLAY-036/878114e/README.md`.

- Fresh default: isolated preferences opened a 1,229 x 768 frame with Welcome containment, then an authored Day 1 city.
- Search: fresh `tax`, `budget`, and `storefront` queries each exposed one available `Open Tax Policy and Finances` result.
- Activation: coordinate pointer, Return, focused Space, and accessibility Press each closed the guide and exposed the existing Finances destination.
- Disabled: Undo retained `There is no reversible construction action`; Return and accessibility activation attempts left the guide and city unchanged.
- Escape: closed the guide, restored map focus, and a later opening contained an empty focused search field.
- Compact: explicit `CITYSIM_COMPACT_WINDOW=1` measured a 900 x 652 frame / 900 x 600 content; `storefront` and Return remained operable and exposed the compact Finances deck.

## Compatibility and contract notes

- **One command path:** `performFromCommandGuide` delegates once to the existing `perform(_:)`; it adds only guide dismissal after success and no parallel catalog action.
- **Truthful availability:** the real button remains disabled from `canPerform`, and its accessibility value continues to use `disabledReason(for:)`.
- **Focus:** deferred search focus makes fresh typing reliable; successful activation and Escape both return to the existing map-focus lifecycle.
- **Simulation/save:** no city rule, tax mutation, snapshot, or persistence behavior changed; the full deterministic, undo, save, replay, and fingerprint suites passed.
- **Accessibility:** actual button semantics, disabled state, labels, values, hints, keyboard focus, and Press action were inspected at both sizes. Spoken VoiceOver was not claimed.

No shared-contract proposal is required. No push or integration was performed.

## Current-baseline rebind addendum

- **Branch:** `codex/citysim-ui-play036-current88b6`
- **Base:** `d8d2fa799cb5d07d611773fa49418b5a755127da`
- **Delta:** the current rebind restores an explicit map-focus request when Escape closes the command guide; query state remains local to the dismissed view.
- **Focused proof:** `PLAY036SearchRemedyTests` passed 2 tests at compact `620 × 480` and regular `760 × 560`; exported images are `/private/tmp/CITYSIM-PLAY036-after-compact.png` and `/private/tmp/CITYSIM-PLAY036-after-regular.png`.
- **Boundary:** candidate evidence only; no aggregate suite, staged app, launch, push, integration, or release claim.

## Current-baseline acceptance

- **Accepted product:** `6fb457b15df22a493960911d805610694fc66a55`
  (`cb1e9e2c1c8485a4c14df98e4697d48c332eb70f`).
- **Independent result:** `APPROVE_PLAY036_SEARCH_REMEDY`.
- **Continuation receipt:**
  `docs/production/evidence/PLAY-036/6fb457b/QA-PASS-CONTINUATION.json`,
  SHA-256 `58515e2bbe4be393adc44f3188041bc00849efef905d0d2f343c38004e19f45f`.
- **Preserved history:**
  `docs/production/evidence/PLAY-036/6fb457b/QA-RETURN.json`, SHA-256
  `c77016aecef946657c31f5e2c1f15da032f27adf655d7ddbf71aa798ffbcf024`.
- QA confirmed tax, budget, and storefront each expose the single Tax Policy
  result; pointer, Return, Space/FKA, and accessibility activation open
  Finances exactly once; disabled Undo remains truthful; Escape restores map
  focus; and regular plus exact 900 × 600 layouts remain usable.
- The existing candidate process was reused without relaunch. No release or
  push is claimed.
