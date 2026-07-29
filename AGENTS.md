# CitySim Agent Lane Router

These instructions apply to every task in this repository and every linked worktree.

## Required startup on every prompt

1. Run `pwd`, `git branch --show-current`, and `git status --short --branch` before planning or editing.
2. Read `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md` completely.
3. Load and follow the lane skill matching the current branch:

| Branch | Required skill |
|---|---|
| `master` | `.agents/skills/operate-citysim-integration/SKILL.md` |
| `codex/citysim-gameplay-loop` | `.agents/skills/build-citysim-gameplay-loop/SKILL.md` |
| `codex/citysim-world-rendering` | `.agents/skills/render-citysim-world/SKILL.md` |
| `codex/citysim-world-art` | `.agents/skills/produce-citysim-world-art/SKILL.md` |
| `codex/citysim-world-art-east` | `.agents/skills/produce-citysim-world-art/SKILL.md` |
| `codex/citysim-world-art-south` | `.agents/skills/produce-citysim-world-art/SKILL.md` |
| `codex/citysim-world-art-west` | `.agents/skills/produce-citysim-world-art/SKILL.md` |
| `codex/citysim-ui-input` | `.agents/skills/build-citysim-ui-input/SKILL.md` |
| `codex/citysim-simulation-platform` | `.agents/skills/evolve-citysim-simulation/SKILL.md` |
| `codex/citysim-playtest-quality` | `.agents/skills/verify-citysim-playability/SKILL.md` |

4. State the active lane and mission in the first work update.
5. For mutations, require a lane-appropriate `PLAY-*` claim unless the user explicitly requests integration/bootstrap work that creates the task system itself.

If the branch is detached, unexpected, or does not match the requested lane, do not make product changes. Report the mismatch and obtain an explicit routing decision.

## Universal boundaries

- `Native/CitySimNative` is the active product. Treat legacy Python as read-only reference unless the claimed task explicitly includes it.
- Preserve every unrelated dirty or untracked file as user-owned work.
- Keep rules in models/services, player intent in the store, world presentation in SpriteKit, and window/UI/input composition in SwiftUI.
- Shared public contracts, task authority, build scripts, and traceability are integration-controlled.
- Workers may commit focused claimed work but may not push or integrate it. `master` is the only accepted integration branch.
- Treat commits as continuous durability: stage explicit paths, inspect the staged diff, validate the checkpoint, and commit every coherent outcome before handoff, task switches, risky work, or ending a turn with completed work. Never use `git add -A` in a dirty multi-owner checkout.
- Use `PLAY-###: Imperative outcome` for task commits and identify incomplete preservation commits as checkpoints. Completed-but-uncommitted work is invalid.
- Tests alone do not prove UI/gameplay completion. Require the staged app, hands-on flow, visible proof, and affected accessibility/performance/save evidence.
- Stop on ownership conflicts, missing claims, ambiguous requirements, unrelated dirty state, failed validation, or material contract changes without integration approval.

Task-specific skills such as UI audit/remediation may be used in addition to the required lane skill; they never replace lane ownership and integration rules.
