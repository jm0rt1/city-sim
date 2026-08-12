# PLAY-119 Operational Excellence candidate-bound QA handoff claim

- **Lane:** Operating-system optimization
- **Owner:** Operational Excellence Officer
- **Thread:** `019ff2ea-cde0-7c72-86ce-805918e21956`
- **Branch:** `codex/citysim-os-qa-handoff-currente30d`
- **Worktree:** `/Users/James/.codex/worktrees/e742/city-sim`
- **Base authority:** `e30d6eb960ff32b4643975e4df7dcd4856515e8b`
- **Status:** active candidate; Integration acceptance remains required

## Exact owned roots

- `docs/production/claims/PLAY-119.operational-excellence-qa-handoff.md`
- `docs/production/evidence/INTEGRATION/MODEL-ROUTE-PLAY-119-OPERATIONAL-EXCELLENCE-QA-HANDOFF-V1.json`
- `docs/production/evidence/INTEGRATION/MODEL-DISPATCH-PLAY-119-OPERATIONAL-EXCELLENCE-QA-HANDOFF-V1.json`
- `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`
- `.agents/skills/operate-citysim-integration/references/model-routing-and-cost-control.md`
- `.agents/skills/operate-citysim-integration/references/integration-acceptance-and-recovery.md`
- `.agents/skills/operate-citysim-integration/scripts/validate_model_route_v1.py`
- `.agents/skills/operate-citysim-integration/scripts/test_validate_model_route_v1.py`
- `.agents/skills/build-citysim-ui-input/SKILL.md`
- `.agents/skills/render-citysim-world/SKILL.md`
- `.agents/skills/verify-citysim-playability/references/exact-candidate-real-app-gate.md`

## Bounded outcome

Make one validated QA-handoff envelope mandatory before final-QA activation.
Bind the exact acceptance route and dispatch, integrated candidate ref/commit,
canonical staged-app root/seal/producer, and launch command/environment/window
contract. Fail closed before launch on any missing, stale, substituted, or
mismatched value. Require QA to verify the launch contract on the actual PID
before visual interaction. This strengthens the existing handoff; it does not
add a reviewer, build, product gate, or acceptance turn.

## Focused proof

- `PYTHONDONTWRITEBYTECODE=1 python3 .agents/skills/operate-citysim-integration/scripts/test_validate_model_route_v1.py`
- adversarial rejection of missing/mismatched route, dispatch, candidate,
  staged seal, producer, compact environment, and expected window;
- route/dispatch validation; and
- `git diff --check`.

## Stop conditions

Stop on product/app/asset/build-script mutation, any path outside these exact
roots, weakened independent QA, a new review layer, nondeterministic
validation, second focused failure, or need for product priority, candidate
acceptance, publication, push, or release judgment.
