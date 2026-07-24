# PLAY-023 Claim

- **Title:** Build the generated-v4 asset pipeline
- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Worktree:** `/Users/James/.codex/worktrees/cac1/city-sim`
- **Base commit:** Accepted beauty baseline integration commit containing this claim
- **Claimed:** July 23, 2026
- **Planned surfaces:** generated-v4 manifest and descriptors, normalization and deterministic packing tools, Bundle.module loading and cache diagnostics, rollback/fallback tests, performance budgets, and exact staged evidence
- **Dependencies:** accepted PLAY-022 in integration merge `37894a6`; approved CONTRACT-005 and CONTRACT-006
- **Validation/proof:** two clean byte-identical builds; source/staged manifest and page digests; alpha, padding, anchor, seam, LOD, cache, memory, fallback, rollback, and resource-bundle gates; focused/full suites; exact default/compact staged proof
- **Status:** authorized after synchronization to the published accepted beauty baseline

Turn the accepted Round 1E calibration assets into a deterministic,
production-grade generated-v4 pipeline. Preserve the 17/20 visual baseline and
the accepted connected district while eliminating manual or fragile asset
loading seams. The staged app must either load the exact declared asset or emit
an explicit bounded diagnostic; silent fallback is a failure.

Do not generate the full architecture family, redesign gameplay/HUD, change
save or simulation contracts, introduce absolute development paths, or replace
the accepted live city with fixture-only proof. Commit product, evidence, and
completion as separate coherent checkpoints; do not push or self-integrate.
