# PLAY-102 Claim — candidate-neutral QA preregistration

- **Title:** Freeze the exact four-direction QA measurement plan before admission
- **Lane:** Playability and QA
- **Branch:** `codex/citysim-playtest-quality`
- **Worktree:** `/Users/James/.codex/worktrees/2504/city-sim`
- **Authority baseline:** The current Integration master commit containing this claim
- **Owning thread:** `019fe8f2-43ac-7700-9eaf-e137c4c5ecb4`
- **Owned root:** `docs/production/evidence/PLAY-102/v2/`
- **Bounded deliverable:** Prepare candidate-neutral fixture/camera matrices,
  rubric, defect schema, measurement commands, and a 24-capture rehearsal plan
  (four directions × three LODs × regular/compact layouts). Keep candidate,
  resource, camera output, and renderer receipts null until Integration publishes
  an admitted exact aggregate.
- **Dependencies:** Exact 43×4×3 source/admission/quarantine evidence,
  Contract-027 runtime proof, a candidate-bound renderer receipt, and a fresh
  Integration QA route. Current South admission remains 0/43.
- **Focused proof:** JSON/schema validation, fixture inventory, rubric coverage,
  deterministic command rehearsal, and `git diff --check`; no app launch.
- **Independent/full gate:** A fresh independent Frontier QA task owns the real-app
  24-capture judgment only after Integration binds the exact candidate.
- **Stop/refill:** Stop on missing admission, non-null candidate/resource data,
  app-launch pressure, candidate judgment, or route/lease drift. Refill only with
  another candidate-neutral measurement artifact.
- **Forbidden:** Product implementation, source/admission, renderer/runtime,
  resources, app launch, production selection, push, integration, and self-acceptance.
- **Status:** Fresh current-master candidate-neutral claim; preregistration is not
  final QA approval.
