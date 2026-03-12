---
name: pr-recovery-playbook
description: 'Recover a stalled or off-track issue/PR by combining user intent, PR code review, timeline comment history, and cross-repo in-progress context; then post a precise phased recovery plan comment to the issue/PR (including @copilot tag when requested). Use for prompts like: get this agent back on track, Copilot missed the goal, PR is drifting, write a concrete corrective plan, summarize and course-correct ongoing work.'
argument-hint: 'Issue/PR URL or number + desired end-goal and constraints'
user-invocable: true
disable-model-invocation: false
---

# PR Recovery Playbook

## Purpose
Use this skill when the user wants an AI agent to recover from drift and re-align active development work with the intended goal.

Primary outcome:
- Post a high-signal, actionable recovery plan to the target issue/PR with explicit goals, scope boundaries, verification steps, and ownership cues.

## When To Use
- User says the agent is off-track or output is not what they want.
- A PR has merged/conflicting implementation paths, regressions, or review-loop churn.
- The user requests a concrete correction plan to unblock progress.
- The user asks to tag @copilot with exact implementation guidance.

## Required Inputs
- User's target outcome in plain language.
- Target artifact: issue/PR URL or number.
- Current branch context (if in workspace).
- Any constraints: no API breaks, determinism, test expectations, release deadlines.

If critical input is missing, ask minimal clarifying questions and proceed.

## Procedure
1. Establish the objective from the user prompt.
- Extract one-sentence success criteria.
- Identify constraints and non-goals.

2. Gather target artifact context.
- Read the active/open PR or issue details (title, body, changed files, state).
- Capture timeline comments and review feedback, especially requested changes and unresolved concerns.

3. Perform code truth-check for the current state.
- Inspect relevant changed files in workspace.
- Run diagnostics/lint/type checks to detect current blockers.
- Prefer evidence over assumptions; cite concrete file locations.

4. Build a root-cause map.
- Distinguish between:
  - Regressions introduced by recent iterations.
  - Pre-existing repository issues.
  - Environment/setup-only failures.
- Rank by severity: critical, medium, low.

5. Research broader in-progress context.
- Search open issues/PRs for overlapping scope, related labels, and linked work.
- Identify duplication risk, dependency risk, and potential conflicts.
- If project boards/milestones are accessible, include relevant status signals.

6. Draft a pointed recovery plan.
- Use phased structure:
  - Phase 1: unblockers and correctness fixes.
  - Phase 2: behavioral/UX alignment.
  - Phase 3: validation and release readiness.
- For each phase include:
  - Exact files/modules to touch.
  - Expected code-level actions.
  - Acceptance checks.

7. Enforce plan quality bar.
- Must include:
  - Root-cause summary.
  - Ordered tasks by impact.
  - Scope boundaries (in-scope/out-of-scope).
  - Verification checklist with commands and expected outcomes.
  - Risks and assumptions.
- Avoid vague tasks like "refactor" without file-level direction.

8. Post the plan to the issue/PR.
- If user requested, include @copilot at the top.
- Keep tone direct and execution-focused.
- Post using repository-aware comment tooling.

9. Confirm completion to the user.
- Provide the posted comment URL.
- Summarize the highest-impact next action in one sentence.

## Output Contract
Final posted comment should contain:
- Objective alignment statement.
- Root-cause findings.
- Phase-by-phase recovery tasks.
- Validation commands/checks.
- Scope boundaries and success criteria.

Use the template: [PR recovery comment template](./assets/pr-recovery-comment-template.md)
Use the checklist: [Context research checklist](./references/context-research-checklist.md)

## Guardrails
- Do not claim a check passed unless run/verified.
- Call out when evidence is unavailable.
- Preserve unrelated user changes.
- Avoid destructive git actions unless explicitly requested.
- Keep recommendations minimal, precise, and testable.
