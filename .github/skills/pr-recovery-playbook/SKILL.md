---
name: pr-recovery-playbook
description: 'Explicit-user-invocation-only workflow to research and draft a truthful recovery plan for a specified issue or PR; posts only when the user explicitly asks to comment on that exact artifact. Do not use merely because PR drift is mentioned.'
argument-hint: 'Issue/PR URL or number + desired end-goal and constraints'
user-invocable: true
disable-model-invocation: true
---

# PR Recovery Playbook

## Purpose
Use this skill only when the user explicitly invokes `$pr-recovery-playbook`.
Mere mention of PR drift, Copilot, a review, or a recovery plan does not invoke
it. Draft a plan by default.

Primary outcome:
- Produce a high-signal, actionable draft recovery plan with explicit goals,
  scope boundaries, verification steps, and ownership cues.

## Invocation and publication boundary

- On explicit invocation, inspect the specified issue or PR and return a draft
  unless the user explicitly asks to post or comment to that exact issue or PR.
- Post externally only when the request names the target artifact and expressly
  authorizes posting or commenting there. Do not infer permission from a
  request to investigate, summarize, diagnose, draft, or recover work.
- Include `@copilot` only when the user explicitly requests it.

## Required Inputs
- User's target outcome in plain language.
- Target artifact: issue/PR URL or number.
- Current branch context (if in workspace).
- Any constraints: no API breaks, determinism, test expectations, release deadlines.

If the target artifact or posting authority is missing, ask the minimum needed
question or provide a clearly labeled local draft; do not post.

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

8. Deliver the draft to the user.
- Label evidence that is unavailable or inferred.
- Keep tone direct and execution-focused.

9. Post only with explicit, artifact-specific authorization.
- Confirm the target issue/PR matches the user's requested destination.
- Include `@copilot` only if explicitly requested.
- Use an available repository-aware comment tool. If none is available, return
  the draft and state that posting requires a supported tool; do not simulate a
  post. After a real post, provide its URL.

## Output Contract
The draft, and any subsequently posted comment, should contain:
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
- Never post, comment, tag, or otherwise make an external change without the
  user's explicit request for the specified issue or PR.
- Keep recommendations minimal, precise, and testable.
