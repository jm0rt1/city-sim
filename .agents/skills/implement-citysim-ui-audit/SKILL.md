---
name: implement-citysim-ui-audit
description: Turn dated native CitySim UI/UX and accessibility audit findings into scoped SwiftUI, SpriteKit, gameplay, information-design, and responsive-layout implementations with tests and rendered proof. Use when asked to follow up on, fix, implement, resolve, remediate, or work through findings from `docs/NATIVE_UI_UX_AUDIT_*.md`, including broad requests to improve the clunky interface or complete audit phases; preserves unrelated Python work and requires hands-on verification before findings are marked closed.
---

# Implement CitySim UI Audit

Convert audit findings into coherent player-facing improvements. Optimize for the build → read consequence → diagnose → adjust loop, not for maximizing the number of closed checklist items.

## Establish scope and preserve work

1. Confirm the repo root and inspect `git status --short` before editing.
2. Treat all existing changes as user-owned. Preserve unrelated Python and native work.
3. Find the newest applicable `docs/NATIVE_UI_UX_AUDIT_*.md`; read it completely. If the user names a different audit or finding set, use that instead.
4. Inspect current code before trusting audit line numbers or claimed behavior. Findings can become stale.
5. If the request is broad, select one coherent implementation batch using [implementation-playbook.md](references/implementation-playbook.md). State included and deferred finding IDs in the working plan.
6. Do not expand into economy rebalance, save migration, or a full accessibility architecture unless the chosen findings require it or the user explicitly includes it.

## Define the outcome before editing

For every included finding, write a compact implementation contract:

- **Problem:** the current reproducible behavior.
- **Player outcome:** what becomes easier, clearer, safer, or more accessible.
- **Code surfaces:** likely owners in SwiftUI, SpriteKit, store, model, or simulation layers.
- **Acceptance evidence:** unit/state test, build result, screenshot/layout proof, and interactive flow.
- **Regression risks:** save compatibility, input-mode ambiguity, overlay legibility, focus stability, or compact layout.

Prefer a small set of mutually reinforcing findings. For example, implement explicit interaction modes, placement preview, cancellation, and stronger selection feedback together; do not mix them casually with economy rebalance.

## Implement in the owning layer

- Keep simulation and durable game rules in models/services.
- Keep player intent, modes, undo, selection, and transient UI state in `CityGameStore` unless a narrower model is justified.
- Keep SwiftUI responsible for window composition, HUD, tool surfaces, inspector, commands, responsive layout, and accessibility descriptions.
- Keep SpriteKit responsible for map rendering, hover/placement visualization, hit testing, pan/zoom, and map-node accessibility integration.
- Avoid duplicate state between SwiftUI and SpriteKit. Flow state through `CitySceneView` and explicit callbacks.
- Preserve save compatibility unless migration is intentional and tested.
- Prefer semantic labels, stable IDs, and keyboard commands over icon-only or pointer-only behavior.
- Use design tokens from `GameTheme` rather than introducing one-off colors and chrome.

Use `apply_patch` for file edits. Add focused tests alongside behavior changes rather than after the UI is complete.

## Validate each batch

Run validation proportional to the changed layers:

1. `swift test --package-path Native/CitySimNative`
2. `bash -n script/build_and_run.sh` when launch/build tooling changes.
3. `git diff --check` and a focused diff review.
4. Build and stage the real app with `./script/build_and_run.sh` when UI or runtime behavior changes. If restricted native builds fail, set `CLANG_MODULE_CACHE_PATH` and `SWIFTPM_MODULECACHE_OVERRIDE` to writable temporary directories.
5. Use the companion `$audit-citysim-native-ui` workflow and Computer Use to exercise the affected flow in `com.jfmortensen.citysim`.
6. Capture visible proof at the default layout and every affected constrained/compact layout. Use the real SpriteKit scene or a deterministic harness only when macOS window capture is unavailable, and disclose that limitation.
7. Re-check accessibility names, focus/identity stability, keyboard operation, and recovery paths for affected controls.

Tests alone never close a UI finding. A build alone never proves the interaction. A screenshot alone never proves the action works.

## Update audit status durably

Do not rewrite historical observations as though they never existed. Add a dated remediation section to the applicable audit or create `docs/NATIVE_UI_UX_REMEDIATION_YYYY-MM-DD.md` when the implementation spans many findings.

For each finding, record one disposition:

- **Verified fixed:** implementation, tests, and hands-on evidence all satisfy acceptance criteria.
- **Partially addressed:** meaningful improvement landed, but a stated criterion remains open.
- **Not reproduced:** current build no longer shows it; include reproduction evidence.
- **Deferred:** deliberately outside the current coherent batch.
- **Blocked:** a concrete external dependency prevents progress.

Include file paths, test commands/results, proof artifact paths, and remaining risk. Never mark an entire phase complete because only its easiest findings passed.

## Restore and hand off

1. Restore the user's app state after Computer Use verification where practical.
2. Inspect `git status --short` and separate your files from pre-existing changes.
3. Summarize implemented finding IDs, visible player impact, validation results, proof artifacts, audit dispositions, and remaining findings.
4. Do not commit, stage, push, or open a pull request unless the user requests that Git operation.

## Completion bar

Do not declare a finding fixed until:

- the current defect was reproduced or its stale status was demonstrated;
- the implementation is owned by the correct layer and has focused coverage;
- the complete Swift package test suite passes, or failures are honestly scoped;
- the staged native app was operated through the changed flow;
- affected default and compact layouts have visible proof;
- accessibility and keyboard consequences were checked;
- the audit/remediation artifact records the disposition and remaining risk;
- unrelated user work remains intact.
