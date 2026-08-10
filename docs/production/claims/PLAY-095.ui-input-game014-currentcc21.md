# PLAY-095 GAME-014 Current-Authority UI Claim

- **Title:** Show the authoritative strategy summary in compact HUD
- **Lane:** UI and input
- **Task/thread:** `019fec92-42dc-7eb2-8993-c9fd8ffdf3bf`
- **Branch:** `codex/citysim-ui-input-game014-currentcc21`
- **Worktree:** `/Users/James/.codex/worktrees/7f1d/city-sim`
- **Base authority:** exact Integration master
  `cc21debf0c5a900f6b17e0de705d5246c82ead08`; the worker receives no product
  authority until this claim/router/skill governance checkpoint is committed,
  its attached successor is clean at that checkpoint, and a fresh schema-2
  carrier passes independent review.
- **Worker tuple:** `LUNA_IMPLEMENTATION / gpt-5.6-luna / high`.
- **Independent semantic owner:** CitySim CTO task
  `019fe8df-faf7-7b50-a8a3-0d15b1191e10`, `gpt-5.6-sol / high`.
- **Integration owner:** task `019f7686-4491-7891-86a6-95a78d67e5c8` owns
  claim/route/dispatch publication, candidate adoption, aggregate/full native
  proof, and staged build. Distinct Playability/QA owns later real-app review.

## Exact ownership

The only product/test/evidence paths this successor may change are:

1. `Native/CitySimNative/Sources/CitySimNative/Views/StrategyCommandCenterView.swift`
2. `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`
3. `docs/production/evidence/PLAY-095/GAME-014-UI/`

Every other file is forbidden. In particular, preserve `CityAnalytics.swift`,
`CityGameStore.swift`, `ContentView.swift`, `TopHUDView.swift`, `GameTheme.swift`,
models/services, Renderer, resources, commands, package/build files, claims,
shared contracts, and historical UI evidence.

Historical successor task `019febf6-2651-70c2-903a-1f654b947b4d`, worktree
`/Users/James/.codex/worktrees/6bad/city-sim`, branch
`codex/citysim-ui-g003-current6d`, and clean checkpoint
`db6d64a39258481de69d0595e859de30b4debeb6` remain immutable preparation
evidence only. They are not current authority and their product/evidence bytes
must not be copied, merged, reset, cleaned, or silently adopted.

## Immutable current-authority inputs

- `StrategyCommandCenterView.swift` SHA-256:
  `1e86f910da5d632faff4c36c3af7a9dd3eb3cb772ae6ce531cd783f09eb2a3ae`
- `CityCommandCatalogTests.swift` SHA-256:
  `2332ef210892a469ae7b47f42749644a8b40a2e902848823abcbb5390f42018a`
- `CityAnalytics.swift` SHA-256:
  `33a0a04e36e17252cc80a4a61e522066d0e1cc68ae3f8d9bfd4ad0363c5734b8`
- `ContentView.swift` SHA-256:
  `1e3de20f3dbaebfbc00342b76903c6a3477515cdfff7e0b1547f7f00de55bc01`
- `TopHUDView.swift` SHA-256:
  `6e552d7d6883df142a6ce6f9afd6e2a7f636113787e9d20385a518287574b7ab`
- `GameTheme.swift` SHA-256:
  `85eb0e4c0edb2c175c205f4db0b9e745ca746b17f92fc14023f47847ec193b7f`

`CityStrategyHUDPresentation.make` and every `CityAnalytics` summary-producing
semantic remain byte-for-byte immutable.

## Frozen player outcome and display contract

At compact `1058x705`, expose the existing authoritative
`presentation.summary` as the sole visual second-line cue in the Strategy
Command Center without adding state, commands, simulation truth, Renderer
contracts, or state copies. The compact second line replaces the visible title;
the title remains in the existing parent accessibility label. At regular
`1229x768`, preserve the current title-plus-summary hierarchy and modifiers.

1. The source is exactly
   `CityStrategyHUDPresentation.make(analytics: store.analytics).summary` via
   `presentation.summary`: no prefix, suffix, rewrite, parsing, cache, copy,
   fallback, alternate producer, or changed producer bytes.
2. Compact preserves eyebrow and status on the first line. The second line is
   exactly the summary at `GameTheme.hudSupportTextSize` (`10` points), medium,
   secondary, one line, tail truncation, and `layoutPriority(1)`, with no wrap,
   marquee, or minimum-scale shrink.
3. Compact geometry remains: ContentView side padding `9`; TopHUD outer width
   `1040`; TopHUD side padding `6`; Strategy outer width `1028`; Strategy side
   padding `7`; inner HStack budget `1014`; TopHUD maximum height `104`; Strategy
   maximum height `48`. Summary yields/truncates before trajectory, diagnostic,
   and action controls; no control hides, changes order, or shrinks below `44`
   points.
4. Regular geometry remains: TopHUD outer width `1201`, Strategy outer width
   `1189`, inner width `1175`, TopHUD maximum height `118`, Strategy maximum
   height `52`. Title stays `13` point bold and summary stays `10` point medium
   secondary on one line.
5. Preserve identifier `hud.strategy.priority`; parent AX label stays exactly
   `City priority: <presentation.title>`; parent AX value stays exactly
   `<presentation.status>. <presentation.summary>` through existing
   `presentation.accessibilityValue`; help remains the exact summary. Hide only
   the new compact visual summary `Text` from accessibility so VoiceOver speaks
   it once. Do not alter action/menu labels, values, hints, or focus order.
6. Add no focusable element or gesture. Pointer, Return, Full Keyboard Access,
   VoiceOver, Escape, Reduce Motion, non-color meaning, `store.perform`, and
   `store.performMapFocused` routes remain unchanged.

## Focused proof and durability

The fresh schema-2 route must freeze exactly one named
`CityCommandCatalogTests` method proving authoritative summary bytes, compact
second-line selection, unchanged regular hierarchy, exact `1028x48` and
`1189x52` render bounds, parent AX label/value with no duplicate speech,
`44`-point controls, and unchanged command routing. It must freeze one exact
filtered SwiftPM command with task-specific writable caches plus
`git diff --check`. The prior `/6bad` focused result does not substitute for
this current-authority proof.

Focused PASS may create only the two allowed file changes, the assigned evidence
root, and one coherent `PLAY-095:` checkpoint commit. Worker proof is candidate
evidence only. CTO independently reviews exact semantics and scope; Integration
alone may later adopt and run aggregate/full native proof plus staged build; a
distinct Playability owner later checks one exact staged candidate at
`1058x705` and `1229x768` for the visible cue, tail truncation, no overlap or
clipping, regular hierarchy, pointer/Return/FKA/VoiceOver/Escape/Reduce Motion,
and unchanged command outcomes.

## Stop, rollback, and refill

Stop without mutation on any task, branch, attached-worktree, HEAD, claim,
router, skill, immutable-input, path, route, or dispatch mismatch; summary
semantic or producer change; new state, command, store API, gesture, focusable
element, or contract; compact overflow/control shrink; regular hierarchy or
AX/input/focus/routing regression; need for a forbidden path or shared contract;
failed focused proof; self-acceptance; or downstream gate request.

Rollback is abandonment or forward-revert of only the eventual focused UI
candidate. No migration, state, or resource rollback exists. Refill returns to
Integration for identity/carrier correction or CTO for semantic conflict; it
never rewrites the frozen summary authority.

This governance claim authorizes no implementation, test, app, evidence,
staging, commit by the worker, merge, push, or gate movement before a separately
validated route, independent static approval, zero-mutation worker ACK, and
explicit execution release.
