# PLAY-015 Claim

- **Title:** Make the Town Charter an unmistakable session victory
- **Lane:** Gameplay loop
- **Branch:** `codex/citysim-gameplay-loop`
- **Worktree:** `/Users/James/.codex/worktrees/80f0/city-sim`
- **Base authority:** integration commit containing this claim, based on accepted master `643fd1a`
- **Requirement IDs:** GOV-004, GOV-005, GOV-006, SIM-004, UX-001, UX-007, REL-004
- **Planned surfaces:** `CitySimulation.swift`, gameplay analytics only if required, focused `GameplayLoopTests.swift`, staged gameplay evidence, and completion record
- **Dependencies:** accepted PLAY-014/044; existing `.won` state; UI companion PLAY-038; later simulation-platform candidate adoption
- **Validation/proof:** four exact tick-844 terminal routes, legacy awarded-playing next-boundary normalization, one-time award/message, no premature win, terminal immutability, undo/loss compatibility, full suite, and no-coaching Commercial plus Industrial staged victories
- **Status:** active

Transition to the existing `.won` state on the same governed daily boundary
that newly awards the Town Charter. Never mutate on decode or load. A legacy
save with an awarded Charter and `.playing` status may normalize only on its
next governed daily boundary, without repeating the award or message. Preserve
the four durable recovery identities and every accepted compatibility
boundary. Do not edit SwiftUI, commands, save identifiers, renderer code, or
task authority.
