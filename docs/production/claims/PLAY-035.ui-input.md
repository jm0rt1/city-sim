# PLAY-035 Claim

- **Title:** Make rejected keyboard actions explain themselves
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Base commit:** `23d2bf972834b11be82f763d156d111f8ff76bc4`
- **Claimed:** July 21, 2026
- **Defect authority:** PLAY-051 exact integrated simulation/HUD gate against `23d2bf9`
- **Planned surfaces:** map-command routing eligibility, `CitySceneView` command bridge, store-owned primary-action attempt, focused command/input tests, exact staged default and compact evidence
- **Dependencies:** accepted PLAY-033 integration; no dependency on PLAY-022 or CONTRACT-008
- **Validation/proof:** occupied, no-road, and unaffordable Return attempts expose the same accepted reason and durable recovery guidance as pointer attempts; valid Return still mutates exactly once; AX availability remains truthful; modal/text quarantine, selection, tool retention, Escape, default, and exact 900 x 600 remain intact
- **Status:** claimed and authorized for immediate implementation

Repair the conflation between whether a map command can be routed to the store and whether its announced primary action will mutate state. A focused Return attempt on a selected but invalid build target must reach the existing store-owned rejection path so the player receives durable feedback. Keep catalog/AX availability and disabled reasons truthful; do not make invalid actions appear available.

This task may separate route eligibility from action availability narrowly. It must not choose or synchronize pointer versus keyboard coordinates, change hover/selection semantics, implement CONTRACT-008, touch renderer art, or alter simulation validation.
