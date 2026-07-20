# PLAY-050-D003 — Published Dense Fixture Digest Does Not Match the Integrated Candidate

- Candidate: product `6e87d24398fb204cbb4bc2612239d7e295730949`; playtest merge HEAD `dfc9a67ca826a12e0df5c0eac11ae336dc314776`
- Severity: critical acceptance blocker
- Owner return: Simulation platform / Integration contract evidence
- Requirement impact: CONTRACT-003 canonical fingerprint assertions; PLAY-050 Wave 002 preflight and persistence gate
- Disposition: reproduced twice; wave rejected before live interaction

## Reproduction

1. Start from the clean `codex/citysim-playtest-quality` branch at playtest merge HEAD `dfc9a67ca826a12e0df5c0eac11ae336dc314776`.
2. Confirm product candidate `6e87d24398fb204cbb4bc2612239d7e295730949` is an ancestor.
3. Run the full native suite with isolated Swift caches.
4. Record `CITYSIM_SESSION_PERFORMANCE fixture=dense-24x24 ticks=400 ... digest=...`.
5. Repeat only `SessionPlatformTests/testDenseSessionSimulationAndPersistencePerformance` without rebuilding.
6. Compare both actual digests to the value published for the same declared fixture in `docs/production/completed/PLAY-040.simulation-platform.md`.

## Expected

Before execution, the accepted completion record freezes the `dense-24x24`, 400-tick fingerprint as:

`fe710ac93dcb3d4bc4438157f777a2e2e8557397573b0d39f1d8ac3e5ab86cd5`

The integrated candidate should reproduce that digest, or integration must publish an authorized replacement expectation before independent execution with the applicable contract/version rationale.

## Actual

Both independent runs produced:

`7b6454ecbe83aeb3bdc88de4fb1d6cb23ef67ce81849123e907d3147c6c52a77`

The envelope remained 135,456 bytes and save/load recomputed the actual digest, so the test passed internally. The performance test does not assert the pre-published dense digest and therefore reports green despite the external contract mismatch.

## Impact

PLAY-050 cannot tell whether the accepted dense fixture changed because of authorized simulation semantics, unintended state drift, or an unrecorded fixture/expectation update. The frozen gate forbids inventing a replacement after observation and names unchanged-fixture digest mismatch as an immediate rejection. The long journey and persistence manipulations cannot establish trustworthy checkpoint equality from this preflight state.

No product repair or expectation update was made in the quality lane.
