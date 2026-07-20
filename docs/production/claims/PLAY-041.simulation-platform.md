# PLAY-041 Claim

- **Title:** Publish spatial consequence truth
- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Worktree:** `/Users/James/.codex/worktrees/e909/city-sim`
- **Base commit:** Accepted Wave 002 publication `74b694d`; authority commit containing this claim
- **Claimed:** July 20, 2026
- **Planned surfaces:** deterministic simulation derivation, immutable presentation snapshots, stable identities, diagnostics, compatibility/fingerprint tests, and a proposed contract record
- **Dependencies:** accepted PLAY-040 and Wave 002 product
- **Validation/proof:** contract compatibility matrix, repeated hashes, exact replay/save/load/undo, focused/full suites, performance measurements, and consumer examples
- **Approved contract:** additive derived-only `CityPresentationSnapshot.spatialConsequences`, separate utility/pollution bands, deterministic forward transition events, and stable `spatial-v1` identities; no persisted-model, save-schema, fingerprint-version, renderer, UI, gameplay-balance, or package change
- **Status:** ready-for-integration

Propose the smallest authoritative contract for per-location utility service, pollution, prosperity/strain, recovery, and stable event identity. Explain what is transient versus durable, how old saves decode, and the exact performance and fingerprint effects.

Do not change a shared public contract until integration replies APPROVED. Do not tune gameplay or build renderer/UI presentation.

Integration approved the proposed contract and PLAY-022's explicit `powerBand`, `waterBand`, `combinedBand`, `pollutionBand`, and non-applicable vitality-transition suppression clarifications before implementation. The candidate is complete at the ordered commits recorded in `docs/production/completed/PLAY-041.simulation-platform.md`; the worker has not pushed or integrated it.
