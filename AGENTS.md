# CitySim Agent Lane Router

These instructions apply to every task in this repository and every linked worktree.

## Required startup on every prompt

1. Run `pwd`, `git branch --show-current`, and `git status --short --branch` before planning or editing.
2. Load and follow the lane skill matching the current branch:

| Branch | Required skill |
|---|---|
| `master` | `.agents/skills/operate-citysim-integration/SKILL.md` |
| `codex/citysim-world-art-ledger-game012a-current7a` | `.agents/skills/operate-citysim-integration/SKILL.md` |
| `codex/citysim-gameplay-loop` | `.agents/skills/build-citysim-gameplay-loop/SKILL.md` |
| `codex/citysim-gameplay-g003-current6d` | `.agents/skills/build-citysim-gameplay-loop/SKILL.md` |
| `codex/citysim-world-rendering` | `.agents/skills/render-citysim-world/SKILL.md` |
| `codex/citysim-world-rendering-r4b-current` | `.agents/skills/render-citysim-world/SKILL.md` |
| `codex/citysim-world-rendering-r6-current302` | `.agents/skills/render-citysim-world/SKILL.md` |
| `codex/citysim-world-art` | `.agents/skills/produce-citysim-world-art/SKILL.md` |
| `codex/citysim-world-art-east` | `.agents/skills/produce-citysim-world-art/SKILL.md` |
| `codex/citysim-world-art-south` | `.agents/skills/produce-citysim-world-art/SKILL.md` |
| `codex/citysim-world-art-west` | `.agents/skills/produce-citysim-world-art/SKILL.md` |
| `codex/citysim-world-art-pipeline` | `.agents/skills/produce-citysim-world-art/SKILL.md` |
| `codex/citysim-world-art-residential` | `.agents/skills/produce-citysim-world-art/SKILL.md` |
| `codex/citysim-world-art-commercial` | `.agents/skills/produce-citysim-world-art/SKILL.md` |
| `codex/citysim-world-art-industrial` | `.agents/skills/produce-citysim-world-art/SKILL.md` |
| `codex/citysim-world-art-civic` | `.agents/skills/produce-citysim-world-art/SKILL.md` |
| `codex/citysim-world-art-north-imagegen` | `.agents/skills/produce-citysim-world-art/SKILL.md` |
| `codex/citysim-world-art-east-imagegen` | `.agents/skills/produce-citysim-world-art/SKILL.md` |
| `codex/citysim-world-art-west-imagegen` | `.agents/skills/produce-citysim-world-art/SKILL.md` |
| `codex/citysim-world-rendering-single-angle` | `.agents/skills/render-citysim-world/SKILL.md` |
| `codex/citysim-playtest-single-angle` | `.agents/skills/verify-citysim-playability/SKILL.md` |
| `codex/citysim-ui-input` | `.agents/skills/build-citysim-ui-input/SKILL.md` |
| `codex/citysim-ui-g003-current6d` | `.agents/skills/build-citysim-ui-input/SKILL.md` |
| `codex/citysim-ui-input-game014-currentcc21` | `.agents/skills/build-citysim-ui-input/SKILL.md` |
| `codex/citysim-simulation-platform` | `.agents/skills/evolve-citysim-simulation/SKILL.md` |
| `codex/citysim-simulation-g003-current6d` | `.agents/skills/evolve-citysim-simulation/SKILL.md` |
| `codex/citysim-playtest-quality` | `.agents/skills/verify-citysim-playability/SKILL.md` |
| `codex/citysim-os-optimization` | `.agents/skills/optimize-citysim-operating-system/SKILL.md` |

Fresh outcome branches inherit their lane skill by prefix, so current-baseline
work does not require editing this table for every branch name:

| Branch prefix | Required skill |
|---|---|
| `codex/citysim-gameplay-` | `.agents/skills/build-citysim-gameplay-loop/SKILL.md` |
| `codex/citysim-world-rendering-` | `.agents/skills/render-citysim-world/SKILL.md` |
| `codex/citysim-world-art-` | `.agents/skills/produce-citysim-world-art/SKILL.md` |
| `codex/citysim-ui-` | `.agents/skills/build-citysim-ui-input/SKILL.md` |
| `codex/citysim-simulation-` | `.agents/skills/evolve-citysim-simulation/SKILL.md` |
| `codex/citysim-playtest-` | `.agents/skills/verify-citysim-playability/SKILL.md` |
| `codex/citysim-os-` | `.agents/skills/optimize-citysim-operating-system/SKILL.md` |

3. Read `.agents/skills/operate-citysim-integration/references/model-routing-and-cost-control.md` and apply its context-loading rule. A complete applicable authority read, including `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`, the lane skill, the active claim, and required conditional references, is mandatory for a new thread, new or revised claim, changed claim/authority/skill/routing/conditional-reference hash, branch/worktree/task mismatch, context loss or compaction without a valid compact packet, or a stale/missing/contradictory packet.
4. On an unchanged same-thread continuation, still run step 1, verify the exact Git revisions and every recorded file hash, and consume the compact lane-context packet. Any mismatch fails closed to the complete-read path.
5. State the active lane and mission in the first work update.
6. For mutations, require a lane-appropriate `PLAY-*` claim unless the user explicitly requests integration/bootstrap work that creates the task system itself.

If the branch is detached, unexpected, or does not match the requested lane, do not make product changes. Report the mismatch and obtain an explicit routing decision.

## Autonomy inside an assigned outcome

Once Integration or the user assigns a bounded player outcome on a correctly
routed lane, the owning agent is responsible for completing the entire local
loop without asking for command-by-command permission:

1. understand the player problem and inspect the current implementation;
2. choose the smallest coherent implementation inside owned paths;
3. edit, run focused proof, and inspect the real output;
4. make one bounded repair when the first focused proof exposes a local defect;
5. capture the evidence a human reviewer actually needs; and
6. stage explicit paths and create one coherent commit.

Agents should make routine engineering decisions themselves, communicate with
peer agents for read-only facts or interface needs, and keep working while
other lanes progress. Do not stop merely to request permission for ordinary
code reads, local reversible edits, focused tests, screenshots, or commits that
are already inside the assigned outcome and path boundary.

Escalate only when the next step would change shared architecture or contracts,
alter save/schema compatibility, cross an ownership boundary, require a second
repair after failed focused proof, perform an irreversible/external action, or
claim integration acceptance, publication, push, or release. A status update
is not an escalation and must not pause useful work.

## Ten-percent manual review budget

Routine, contract-preserving work must flow without serial approval. Apply
automated identity, owned-path, diff, focused-test, and clean-commit checks to
100% of candidate commits, but deep manual review to no more than a
risk-weighted 10% sample of routine commits.

Do not create separate static-review, ACK, execution-release, receipt-review,
or CTO approval turns for an outcome that satisfies the fast-path checks.
Integration accepts and integrates it automatically. One reviewer gives one
decision at an integrated player milestone; a second review round requires a
new material defect, not a formatting or receipt preference.

Review 100% only when work changes shared architecture or contracts, alters
save/schema compatibility, crosses ownership, performs an irreversible or
external action, or claims final candidate acceptance, publication, push, or
release. The CEO sets product promise, priority, budget, and publish authority;
the CTO owns cross-lane product judgment and integrated milestone acceptance;
neither is part of routine implementation flow.

## Mandate cascade

The user sets the company mandate: desired player outcome, priority, deadline,
budget, and non-negotiable constraints. Integration interprets that mandate
into a small set of owned outcomes, assigns one accountable agent per outcome,
states decision rights and acceptance criteria, and keeps dependencies moving.
Do not forward raw executive language as command-by-command work.

Owning agents choose implementation details, coordinate directly with peers,
delegate bounded subtasks, and deliver coherent commits. Integration conducts
oversight through outcome progress, product evidence, dependency health, and
the integrated build; it intervenes on stalls, collisions, scope drift, and
quality failures. Report completed outcomes and material exceptions upward.
Ask the user only for a change to product promise, priority, budget, an
irreversible external action, or explicit publish/release authority.

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
- Every dispatch must carry a validated machine-readable `modelRoute`. Break substantial `PLAY-*` work at judgment boundaries: frontier authority, disjoint Luna execution packet(s), and independent frontier acceptance.
- Luna packets run focused owner/affected gates only. The lane coordinator joins coherent packets; the full Swift suite, staged build, and real-app journey run once against the exact aggregated/integrated tree unless identity changes or focused evidence is stale. Independent final QA remains mandatory.

Task-specific skills such as UI audit/remediation may be used in addition to the required lane skill; they never replace lane ownership and integration rules.
