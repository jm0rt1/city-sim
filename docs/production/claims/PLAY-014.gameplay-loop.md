# PLAY-014 Claim

- **Title:** Make recovery choice a durable strategic identity
- **Lane:** Gameplay loop
- **Branch:** `codex/citysim-gameplay-loop`
- **Worktree:** `/Users/James/.codex/worktrees/80f0/city-sim`
- **Base authority:** Wave 005 integration commit containing CONTRACT-009 and this claim
- **Requirement IDs:** GOV-004, GOV-005, GOV-006, ECO-002, ECO-003, SIM-004
- **Planned surfaces:** strategy progression model, gameplay rules/messages, derived analytics, focused deterministic strategy tests, exact staged story evidence
- **Dependencies:** approved CONTRACT-009; PLAY-043 may proceed independently, while PLAY-044 waits for this frozen checkpoint
- **Validation/proof:** four deterministic recovery routes, late and failed-choice boundaries, non-flipping resolution, distinct numerical consequences, both strategies finish inside 20:00, legacy nil decode, round trip, undo exactness, default staged story proof
- **Status:** claimed for Wave 005

Implement exactly two viable recovery resolutions per committed strategy through existing player actions. Capture the first qualifying resolution only on a governed daily boundary, retain it durably, and make the payoff numerically and narratively distinct. Do not add UI commands, renderer behavior, save-schema identifiers, or platform-owned fixture changes.
