# PLAY-038 Claim

- **Title:** Make Charter victory truthful and replayable
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Base authority:** integration commit containing this claim, based on accepted master `643fd1a`
- **Requirement IDs:** UX-001, UX-004, UX-007, UX-009, AUD-001, REL-005
- **Planned surfaces:** existing victory SwiftUI surface, existing store/catalog action routing, focused UI/input tests, default/compact accessibility proof, and completion record
- **Dependencies:** existing `.won` contract; PLAY-015 supplies the reachable authoritative transition
- **Validation/proof:** Charter-accurate copy, retained strategy/recovery explanation, pointer/Return/Space/AX Start a New Region exactly once, deterministic focus, exact 900 x 600, won-state save/relaunch truth, full suite, and staged evidence
- **Status:** integrated on master through `38c925c`; exact PLAY-015 victory is integrated

Replace the inaccurate metropolis victory language with Town Charter truth and
make the existing replay action fully operable. Consume existing authoritative
analytics only. Do not add commands, duplicate progression state, edit gameplay
rules, change save contracts, touch renderer art, or begin PLAY-034.
