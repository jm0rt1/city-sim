# PLAY-036 Current-Baseline Claim

- **Task:** PLAY-036 — Make searched remedies reliably actionable
- **Lane:** UI and input
- **Owner:** Agent 301 — UI/Input Lead
- **Thread:** `019fec92-42dc-7eb2-8993-c9fd8ffdf3bf`
- **Branch:** `codex/citysim-ui-play036-current88b6`
- **Worktree:** `/private/tmp/citysim-play036-search-remedies-current88b6`
- **Product base:** `d8d2fa799cb5d07d611773fa49418b5a755127da`
- **Accepted prerequisite:** PLAY-032 direct warning remedy, QA receipt SHA-256 `34ac2e469e83664b8cc1a540f6582f4911da8c4d3d841d6710c7033de3276d59`
- **Status:** Active under one outcome-fast-path lease.

## Player outcome

Typing the words already used by a warning finds the intended existing remedy,
and the visible result actually opens through pointer, Return, Space, or its
accessibility action. Availability and disabled reasons stay truthful, and
Escape restores map focus without leaking the query.

## Maximum mutable paths

- `Native/CitySimNative/Sources/CitySimNative/Views/CommandGuideView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Support/CityCommandCatalog.swift`
- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/PLAY036SearchRemedyTests.swift`
- `docs/production/evidence/PLAY-036/currentd8d2/`
- `docs/production/completed/PLAY-036.ui-input.md`

Fewer paths are valid. Every renderer, simulation, gameplay, save, package,
build, accepted PLAY-032 evidence, protected-dirt, and unrelated UI byte is
immutable.

## Contract and stop boundary

- Reuse the existing `CityCommandID`, catalog availability, disabled reason,
  and store intent path. Do not add a second command or view-only action path.
- Fresh `tax`, `budget`, and `storefront` searches must each expose the
  one existing Tax Policy result.
- Pointer, Return, Space, and AX activation must dispatch that same result
  exactly once when available. Disabled results remain visible and announce
  their reason without activating.
- Escape restores map focus without shortcut or query leakage; default and
  exact 900 × 600 remain usable and truthful.
- No simulation rule, renderer truth, save schema, warning-copy ownership, or
  shared public contract change is authorized.

## Outcome lease

Agent 301 owns diagnosis, the smallest coherent implementation, one focused
pointer/keyboard/AX proof, one bounded local repair after the first focused
failure, `git diff --check`, explicit staging, full-index inspection,
task-local evidence, and one coherent `PLAY-036:` commit. Stop on a second
focused failure, unexpected path, semantic ambiguity, or contract expansion.
Do not run aggregate/build/app QA, signal accepted PID 9249, push, release, or
self-integrate.
