# PLAY-118 Operational Excellence canonical staged-app seal claim

- **Lane:** Operating-system optimization
- **Owner:** Operational Excellence Officer
- **Thread:** `019ff2ea-cde0-7c72-86ce-805918e21956`
- **Branch:** `codex/citysim-os-canonical-stage-seal-current8e8e`
- **Worktree:** `/Users/James/.codex/worktrees/e742/city-sim`
- **Base authority:** `8e8e39f9b09ee90b13851d7c662f8861f9e5be6d`
- **Status:** active candidate; Integration acceptance remains required

## Exact owned roots

- `docs/production/claims/PLAY-118.operational-excellence-canonical-stage-seal.md`
- `docs/production/evidence/INTEGRATION/MODEL-ROUTE-PLAY-118-OPERATIONAL-EXCELLENCE-CANONICAL-STAGE-SEAL-V1.json`
- `docs/production/evidence/INTEGRATION/MODEL-DISPATCH-PLAY-118-OPERATIONAL-EXCELLENCE-CANONICAL-STAGE-SEAL-V1.json`
- `docs/production/CITYSIM_WORKTREE_OPERATING_SYSTEM.md`
- `.agents/skills/operate-citysim-integration/references/integration-acceptance-and-recovery.md`
- `.agents/skills/verify-citysim-playability/references/exact-candidate-real-app-gate.md`
- `script/canonical_tree_digest.sh`
- `script/test_canonical_tree_digest.sh`
- `script/package_release.sh`

## Bounded outcome

Eliminate staged-app identity disagreement caused by Integration and QA hashing
identical bundles with different absolute-path and relative-path algorithms.
Extract the existing release packager's relative-path tree digest into one
reusable executable producer, make release packaging consume that producer,
and require Integration and QA to bind the exact producer and digest. Do not
rebuild, reseal with an alternate command, or add another review turn.

## Focused proof

- `bash script/test_canonical_tree_digest.sh`
- `bash -n script/canonical_tree_digest.sh script/test_canonical_tree_digest.sh script/package_release.sh`
- route/dispatch validation; and
- `git diff --check`.

## Stop conditions

Stop on product/app/asset mutation, any path outside these exact roots,
release semantics beyond extracting the existing digest algorithm, a second
focused failure, or need for candidate acceptance, publication, push, or
release judgment.
