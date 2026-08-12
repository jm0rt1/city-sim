# PLAY-116 Operational Excellence composed-screen claim

- **Lane:** Operating-system optimization
- **Owner:** Operational Excellence Officer
- **Thread:** `019ff2ea-cde0-7c72-86ce-805918e21956`
- **Branch:** `codex/citysim-os-composed-screen-current6f0f`
- **Worktree:** `/Users/James/.codex/worktrees/e742/city-sim`
- **Base authority:** `6f0f448f706558b01d85b08b3f6ed63402f0845f`
- **Status:** active candidate; Integration acceptance remains required

## Exact owned roots

- `docs/production/claims/PLAY-116.operational-excellence-composed-screen.md`
- `docs/production/evidence/INTEGRATION/MODEL-ROUTE-PLAY-116-OPERATIONAL-EXCELLENCE-COMPOSED-SCREEN-V1.json`
- `docs/production/evidence/INTEGRATION/MODEL-DISPATCH-PLAY-116-OPERATIONAL-EXCELLENCE-COMPOSED-SCREEN-V1.json`
- `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`
- `.agents/skills/operate-citysim-integration/scripts/validate_model_route_v1.py`
- `.agents/skills/operate-citysim-integration/scripts/test_validate_model_route_v1.py`
- `.agents/skills/operate-citysim-integration/references/integration-acceptance-and-recovery.md`
- `.agents/skills/build-citysim-ui-input/references/ui-input-execution-and-evidence.md`
- `.agents/skills/render-citysim-world/references/renderer-feature-evidence.md`
- `.agents/skills/verify-citysim-playability/references/preregistration-and-source-review.md`
- `.agents/skills/verify-citysim-playability/references/exact-candidate-real-app-gate.md`

## Bounded outcome

Make a comparative composed-screen contract mandatory for every future route
that can change UI, Renderer, WorldArt, or final visual/interaction acceptance.
Bind regular and true 900x600 thresholds, predecessor/candidate identity,
fixture, aggregate command, map aperture, guidance-layer exclusivity, and a
single visible-asset profile. Strengthen the existing final QA gate; do not add
another reviewer or acceptance turn.

## Focused proof

- `PYTHONDONTWRITEBYTECODE=1 python3 .agents/skills/operate-citysim-integration/scripts/test_validate_model_route_v1.py`
- adversarial rejection of missing, stale, malformed, or weak composed-screen
  contracts for UI, Renderer, WorldArt, and acceptance routes;
- route/dispatch validation; and
- `git diff --check`.

## Stop conditions

Stop on product mutation, any path outside these exact roots, weakened
independent QA, a new review layer, nondeterministic validation, second focused
failure, or need for product-priority, candidate-acceptance, integration,
push, or release judgment.
