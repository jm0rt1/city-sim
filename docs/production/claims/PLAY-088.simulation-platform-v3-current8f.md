# PLAY-088 Claim — current-baseline Phase B outcome lease

- **Title:** Prove deterministic storm recovery across save, replay, and Undo
- **Lane owner:** Agent 201 — Simulation Lead
- **Branch:** `codex/citysim-simulation-g003-current6d`
- **Worktree:** `/Users/James/.codex/worktrees/0688/city-sim`
- **Owning task:** `019febf6-2651-70c2-903a-1f8f20b668d9`
- **Governance baseline:** `8f538aeb0ddc8873252d4d6ba6191125143c509a`
- **Accepted product candidate:** `4b57e43c4e2329a7d83b97494ea9e9942ba69814`
- **Accepted storm product commit:** `703a8968e62654b7037c9b0437686930f46368f8`
- **Allowed paths:**
  - `Native/CitySimNative/Tests/CitySimNativeTests/StormRecoveryPlatformTests.swift`
  - `docs/production/evidence/PLAY-088/v3/`
  - `docs/production/completed/PLAY-088.simulation-platform.md`
- **Outcome:** Add candidate-bound deterministic proof that active and recovered
  storm ownership survives save/load, backup recovery, replay, snapshots,
  message dismissal, invalid-target retirement, and exact Undo without healing
  unrelated buildings or changing historical bytes.
- **Focused proof:** one route-listed SwiftPM invocation selecting
  `StormRecoveryPlatformTests`, followed by task-local deterministic evidence
  validation and `git diff --check`.
- **Commit:** one coherent `PLAY-088:` commit, staging only paths actually
  changed from the allowlist.
- **Forbidden:** product/source edits; save/schema/fingerprint version changes;
  old fixture or manifest rewrites; UI, renderer, art, package/build, aggregate,
  app, QA, push, integration, and release actions.
- **Stop:** product semantics or shared contracts must change; historical bytes
  drift; nondeterminism; a path outside the allowlist changes; focused proof
  fails twice; or authority/branch/HEAD/status differs from the selected route.
- **Status:** ready for a validated schema-2 outcome lease after a protected
  collision-free fast-forward to the claim-bearing authority commit.

The historical Phase-A and bootstrap-only claims remain immutable provenance;
they do not authorize or substitute for this current-baseline execution.
