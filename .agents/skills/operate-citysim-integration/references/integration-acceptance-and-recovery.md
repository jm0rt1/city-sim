# Integration Acceptance and Recovery

Read this reference before candidate review, acceptance, integration, rollback, or recovery.

## Integrate a candidate

1. Freeze the exact candidate commit and confirm the worktree is clean.
2. Confirm its completion record contains scope, commits, validation, live evidence, proof, risks, and shared-contract notes.
3. Mechanically inspect the complete commit range for path, ownership, and
   contract scope. Deep-read no more than a risk-weighted 10% sample of routine
   fast-path commits; deep-read every escalated/shared-contract change and the
   final integrated player candidate.
4. Automatically integrate routine candidates that pass identity, path, diff,
   focused-proof, and cleanliness checks. Return oversized, mixed, weakly
   proven, or cross-lane work to its owner.
   A static/AST/token-presence check may prove source structure only. If the
   completion claim says launch, execute, render, save, reload, interact,
   deterministic output, or visual quality, independently run the matching
   schema-2 behavioral/full proof before acceptance.
5. Preserve a recoverable pre-integration `master` commit.
6. Integrate in dependency order: platform contracts, simulation/gameplay, rendering, UI/input, quality fixtures.
7. Resolve only narrow mechanical conflicts; return semantic conflicts to owners.
8. Run:
   - `swift test --package-path Native/CitySimNative`
   - `git diff --check`
   - `bash -n script/build_and_run.sh`
   - `./script/build_and_run.sh --verify`
9. Seal the staged app exactly once with
   `bash script/canonical_tree_digest.sh <staged-app-path>`. Record the helper's
   Git blob SHA-256 beside its output and give both unchanged values to QA.
   Integration and QA must use this producer; an absolute-path inventory or
   any locally reconstructed digest is not candidate identity. If a supplied
   seal differs, compare the same staged tree with this producer before
   rebuilding, rerunning, or declaring byte drift.
   Before sending the lease, bind route, dispatch, candidate ref/commit, this
   staged root/seal/producer, and exact launch argv/environment/window in one
   schema-1 `qa_handoff`; require
   `validate_model_route_v1.py --qa-handoff <path>` to PASS. For compact proof,
   include `CITYSIM_COMPACT_WINDOW=1` and an absolute isolated
   `CITYSIM_DATA_ROOT`. QA must verify the actual PID environment before
   interaction. Handoff failure returns to Integration setup without rebuilding
   or adding review.
10. Operate the target journey in the staged app using pointer and affected keyboard paths at default and compact layouts.
11. Check accessibility, focus, save/load, undo, visual truth, performance, and recovery when affected.
    For UI, Renderer, WorldArt, or visual/interaction acceptance routes, reject
    dispatch without the validator-approved immutable composed-screen contract.
    The existing final journey compares predecessor and candidate at identical
    fixture, camera, and regular/900x600 geometry, including map aperture,
    guidance-layer exclusivity, overlap/clipping, and visible-asset coherence.
12. Update completion, baseline, proof, decision, and requirement records truthfully.
13. Commit integration-only changes separately, push accepted `master`, verify remote parity, and announce the next baseline.

## Reject false completion

Do not accept work because it compiles, has isolated tests, contains expected
source tokens, looks attractive once, closes checkboxes, or is committed.
Require an understandable decision, visible consequence, recovery path,
correct ownership, live operation, and retained evidence. A worker PASS whose
claimed behavior was not executed is a returned false-green, not partial
acceptance.
An isolated component PASS cannot overrule a composed-screen RETURN. This
comparison strengthens the one existing aggregate/final gate; it does not add
a reviewer, ACK, or second acceptance turn.

## Recover safely

- Preserve dirty or rejected work on its branch; never erase it for convenience.
- Stop on stale baseline, unknown provenance, detached mutation, missing claim, conflicting contract, failing gate, or staged-app regression.
- Use explicit rollback commits or preserved pre-merge commits; never rewrite shared history to hide integration mistakes.
- When a worker is blocked, identify the exact owner, required decision/input, safe interim work, and resumption condition.
- Escalate only decisions that materially alter product promise, architecture, commercial scope, irreversible content investment, or user authority.
