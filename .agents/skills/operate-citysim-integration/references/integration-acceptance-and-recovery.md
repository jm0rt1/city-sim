# Integration Acceptance and Recovery

Read this reference before candidate review, acceptance, integration, rollback, or recovery.

## Integrate a candidate

1. Freeze the exact candidate commit and confirm the worktree is clean.
2. Confirm its completion record contains scope, commits, validation, live evidence, proof, risks, and shared-contract notes.
3. Review the full commit range and verify only claimed surfaces changed.
4. Return oversized, mixed, weakly proven, or cross-lane work to its owner.
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
9. Operate the target journey in the staged app using pointer and affected keyboard paths at default and compact layouts.
10. Check accessibility, focus, save/load, undo, visual truth, performance, and recovery when affected.
11. Update completion, baseline, proof, decision, and requirement records truthfully.
12. Commit integration-only changes separately, push accepted `master`, verify remote parity, and announce the next baseline.

## Reject false completion

Do not accept work because it compiles, has isolated tests, contains expected
source tokens, looks attractive once, closes checkboxes, or is committed.
Require an understandable decision, visible consequence, recovery path,
correct ownership, live operation, and retained evidence. A worker PASS whose
claimed behavior was not executed is a returned false-green, not partial
acceptance.

## Recover safely

- Preserve dirty or rejected work on its branch; never erase it for convenience.
- Stop on stale baseline, unknown provenance, detached mutation, missing claim, conflicting contract, failing gate, or staged-app regression.
- Use explicit rollback commits or preserved pre-merge commits; never rewrite shared history to hide integration mistakes.
- When a worker is blocked, identify the exact owner, required decision/input, safe interim work, and resumption condition.
- Escalate only decisions that materially alter product promise, architecture, commercial scope, irreversible content investment, or user authority.
