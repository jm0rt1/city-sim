# PLAY-051 Candidate-Isolation and Capture Harness

**Status:** prepared only; final acceptance has not run

## Integration handoff required

Integration supplies the exact candidate full commit and confirms it contains accepted PLAY-012, PLAY-041, PLAY-022, and PLAY-032 commits. Quality records, but does not infer, the merge order and ancestry. Before any live action:

```bash
git status --short --branch
git rev-parse HEAD
git merge-base --is-ancestor <accepted-master> HEAD
bash -n script/build_and_run.sh
./script/build_and_run.sh --verify
```

Copy `docs/production/evidence/PLAY-050/wave-002-candidate-manifest-template.md` into a new immutable run directory named `<full-commit-prefix>-wave-003-<route>` and complete every field. Add the frozen PLAY-051 route ID, spatial contract/version, start fingerprint, executable and `Info.plist` hashes, window size, accessibility settings, and allowed-knowledge attestation. The timer cannot start while any identity field is blank.

## Isolation preflight

1. Require a clean quality worktree at the integration-supplied candidate.
2. Create a second isolated candidate checkout with the same branch label and commit only under integration direction; do not clone production preferences or saves. A normal linked worktree cannot check out the same branch twice, so use the already accepted isolated-clone pattern rather than bypassing Git's worktree guard.
3. Stage and launch both worker candidates through their own `script/build_and_run.sh --verify`.
4. Run `script/verify_candidate_isolation.sh <quality-worktree> <control-worktree>` while both exact processes are alive.
5. Record both manifests, canonical roots, bundle identifiers, preference domains, data roots, executable paths/hashes, PIDs, and exact process commands.
6. Dismiss welcome, toggle Reduce Motion, create a save, and change diagnostics only in candidate A; verify candidate B is unchanged.
7. Stop only candidate A by its recorded exact PID/path; verify B remains alive. Relaunch A through its verified launcher and confirm each candidate retains only its own state.

Any mismatch blocks the candidate. Never use global `pkill`, a bare process name, the master production bundle, or the production Application Support root.

## Run directory

Each route gets its own directory:

```text
docs/production/evidence/PLAY-051/<candidate-prefix>-wave-003-<route>/
  manifest.md
  automated-validation.md
  session-record.md
  session-ledger.csv
  data-root-inventory.csv
  disposition.md
  replay-response.md
  visuals/
  defects/
```

Never overwrite another route's file. Retain original screenshots; derived annotations get a distinct filename and hash. Record whether a capture is live, accessibility-tree text, or deterministic harness output. Fixture proof is never labeled live.

## Timer and ledger protocol

- Use one monotonic wall-clock origin per route and store ISO-8601 wall timestamps with timezone plus elapsed `MM:SS.mmm`.
- Record launch, session zero, every action attempt, meaningful decision, UI consequence, world consequence, diagnosis, recovery action/signal, payoff, pause start/end, save, stop, relaunch, load, undo, and route end.
- Use the frozen columns in `session-ledger-template.csv`. Do not reconstruct missing times from simulation tick after the run.
- For each decision, calculate UI and world latency separately using unpaused simulation time. Keep wall latency as a diagnostic.
- Open a dead-time row at 30.001 seconds even if the interval later resolves. Explain whether it was authored waiting, search/confusion, tool delay, or evidence pause.

## Computer Use fail-fast boundary

Computer Use is currently an infrastructure risk. Prior exact-bundle `get_app_state` requests returned no state and were user-aborted after 2,275.1 seconds, 5,922.0 seconds, and—after four orphaned workers were terminated—913.1 seconds despite a requested 12-second timeout. No live timestamps or actions were recovered from those calls.

For each final candidate window:

1. Integration confirms no orphaned `cua_node` or `node_repl` process remains before the attempt.
2. Start one fresh Node REPL session and bootstrap the bundled Computer Use wrapper exactly as its skill specifies.
3. Issue one full-tree `get_app_state` against the manifest bundle identifier with a requested 12-second timeout.
4. A separate integration operator enforces a 30-second outer boundary because the tool timeout has not been reliable. If no app state returns, terminate only the newly identified Computer Use worker, record start/end/duration and process identity, classify live acceptance blocked, and stop. Do not retry within that candidate window.
5. If responsive, immediately retain the initial accessibility tree and screenshot, then perform actions only through Computer Use. Refresh app state after each action cluster and never reuse stale element indices.

Do not substitute `osascript`, System Events, JXA, CGEvent synthesis, source-derived coordinates, or fixture commands. Infrastructure delay is not player dead time, but it must be recorded separately and cannot be used to claim a live pass.

## Persistence and corruption protocol

- Seal a normal save/load result before corruption testing.
- Stop the exact candidate process and copy the isolated route data root to a new CORRUPT route root; record hashes before mutation.
- Corrupt only the copied isolated primary using the already accepted PLAY-050 method, preserving the original bytes/hash in evidence.
- Relaunch through the verified candidate launcher pointed at the copied root, invoke normal Load, and capture explicit recovery feedback and resulting fingerprint.
- Inventory the preserved corrupt artifact, backup, new primary, and diagnostics. Confirm every canonical path remains inside the copied route root and that a subsequent save/load succeeds.

## Final handoff

Quality returns an exact commit, candidate identity, G01–G16 classification, route durations, all threshold calculations, defect owners, and proof paths. It does not change product code, coach a rerun, update frozen platform fixtures, push, integrate, or declare the wave accepted.
