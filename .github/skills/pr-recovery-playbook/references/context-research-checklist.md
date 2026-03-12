# Context Research Checklist

Use this checklist before writing the corrective plan comment.

## A. User Intent
- [ ] Capture exact user goal in one sentence.
- [ ] Capture constraints (API stability, determinism, timelines, etc.).
- [ ] Capture explicit asks (for example: tag @copilot).

## B. Target PR/Issue State
- [ ] Title/body reviewed.
- [ ] Changed files inspected.
- [ ] Current review state identified (open, changes requested, approved).
- [ ] Timeline comments reviewed for unresolved requests.

## C. Code Reality
- [ ] Read key files involved in the reported problem.
- [ ] Gather current diagnostics (type/lint/test failures where available).
- [ ] Separate newly introduced regressions from pre-existing issues.

## D. Cross-Repo In-Progress Research
- [ ] Search open PRs for overlapping scope.
- [ ] Search open issues for related defects/features.
- [ ] Note dependencies/conflicts and ownership overlaps.
- [ ] Include project/milestone context when accessible.

## E. Plan Construction
- [ ] Root-cause section is evidence-based.
- [ ] Tasks are ordered by severity/impact.
- [ ] Tasks reference concrete files/modules.
- [ ] Verification criteria are objective and executable.
- [ ] Scope boundaries are explicit.

## F. Publication
- [ ] Comment starts with @copilot if requested.
- [ ] Comment posted to correct issue/PR.
- [ ] Posted URL captured and shared with user.
