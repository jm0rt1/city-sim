# PLAY-083 Claim

- **Title:** Prove exact lifecycle save bindings without relabeling history
- **Lane:** Simulation platform
- **Branch:** `codex/citysim-simulation-platform`
- **Worktree:** `/Users/James/.codex/worktrees/e909/city-sim`
- **Base authority:** Next published clean Integration commit containing this
  claim and the accepted PLAY-075 upstream request
- **Input request:**
  `docs/production/evidence/PLAY-075/industrial-l4-family-preregistration-v1/production-quality-rubric-v2/UPSTREAM-LIFECYCLE-SAVE-REQUEST.json`
- **Planned surfaces:** simulation-owned focused tests or task-local validators
  needed to reproduce the request's deterministic binding gates, plus
  `docs/production/evidence/PLAY-083/`
- **Dependencies:** Accepted VisibleCityStates v3 corpus; exact request SHA-256
  `73842570ee5d10e83ef3ec59b301dd9998959bd07e9d3d64e4d9d49c678bf51b`;
  schema-one save, fingerprint-v1, replay, snapshot, and fixture-preservation
  contracts
- **Validation/proof:** exact manifest/save Git blobs and SHA-256 values;
  lifecycle semantics; focus, diagnostics, activity, progression, and recovery
  invariants; two-run materialization identity; fingerprint, replay, load,
  pause, save/load, backup-only recovery, and round-trip identity; all 22
  fail-closed negatives
- **Status:** Accepted and closed by Integration at
  `1008eadf553a445f01f9405558d260e0c779674b`. Final mapping receipt:
  `docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-LIFECYCLE-SAVE-BINDING-ACCEPTANCE.json`
  at SHA-256
  `b7722a9d686b8aa2c61fc8350b29f580a2e441bd38de943f5b1bf1d948da87db`.

Reproduce every gate in the accepted PLAY-075 request against the exact
published VisibleCityStates v3 manifest and the existing
`industrial-active-district-v3` and `industrial-recovering-district-v3` save
bytes. Prove the proposed rubric mappings are semantically truthful without
renaming, rewriting, regenerating, or silently relabeling either persisted
file. Emit a machine-readable candidate packet for independent Integration
review; the worker must not publish the final mapping authority.

The focused proof may add simulation-owned tests or a task-local validator only
when existing tests cannot express a required gate. It may write task-owned
PLAY-083 evidence and disposable temporary outputs. It must not change any
fixture, manifest, product source, public contract, schema, fingerprint
version, renderer, UI, gameplay, art, package, build script, or legacy Python.

Stop if either mapping requires an inferred or weakened lifecycle meaning, a
fixture byte change, a manifest edit, a save/schema/fingerprint change, a
product rule change, a non-deterministic replay, or suppression of any
fail-closed negative. Keep QA rehearsal blocked. Do not push, integrate,
self-authorize the semantic mappings, or claim product/visual acceptance.
