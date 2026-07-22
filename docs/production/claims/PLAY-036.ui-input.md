# PLAY-036 Claim

- **Title:** Make searched remedies reliably actionable
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Base authority:** integration commit containing this claim, after PLAY-035
- **Claimed:** July 21, 2026
- **Defect authority:** PLAY-051 exact integrated simulation/HUD gate against `23d2bf9`
- **Planned surfaces:** command-guide query lifecycle, catalog result presentation/action semantics, store-routed command activation, focused UI/input tests, exact staged keyboard/pointer/AX evidence
- **Dependencies:** complete PLAY-035 first; no renderer or simulation dependency
- **Validation/proof:** fresh searches for `tax`, `budget`, and `storefront` each produce the single truthful Tax Policy result; pointer, Return, Space, and the AX action all activate the existing store command exactly once when available; disabled state retains its reason and does not activate; Escape restores map focus without query leakage
- **Status:** claimed and authorized after PLAY-035

Reproduce the independent live failure before editing. Repair the real staged command-guide behavior, not only immutable catalog matching. Keep the existing `CityCommandID`, availability, disabled-reason, and store intent path; do not add a parallel action or hard-code warning text in the view.

Do not touch renderer, gameplay, save/session, simulation, or CONTRACT-008 surfaces. Commit this separately from PLAY-035 and retain exact default plus 900 x 600 staged evidence.
