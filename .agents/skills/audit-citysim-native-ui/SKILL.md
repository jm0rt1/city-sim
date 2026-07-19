---
name: audit-citysim-native-ui
description: Rerun an evidence-backed, hands-on UI/UX and accessibility audit of the native macOS CitySim app in this repository. Use when asked to try, playtest, inspect, critique, reassess, or produce a full audit of `Native/CitySimNative`, especially after UI changes; covers live Computer Use interaction, compact/default layouts, SwiftUI and SpriteKit source correlation, dated repo-local reports, and restoration of the user's running session.
---

# Audit CitySim Native UI

Audit the product as a player first and the implementation second. Treat passing tests as supporting evidence, never as proof that the interface works.

## Preserve the workspace

- Remain read-only unless the user also asks for implementation.
- Inspect `git status --short` before work. Preserve unrelated native and Python changes.
- Write only the requested audit artifact, normally `docs/NATIVE_UI_UX_AUDIT_YYYY-MM-DD.md`.
- Do not reset the city, overwrite a save, demolish structures, or change durable settings.
- Record the initial app state needed for restoration: simulation speed, overlay, inspector visibility/section, objectives visibility, and window size.

## Prepare the app

1. Confirm the repo root and active product at `Native/CitySimNative`.
2. Read `script/build_and_run.sh` before launching. If a current `dist/CitySim.app` is already running, attach to it rather than rebuilding without need.
3. If the app is absent or stale, use `./script/build_and_run.sh`. Use writable module-cache overrides if Swift build permissions require them.
4. Use the Computer Use skill and its prescribed `node_repl` workflow for all Mac UI actions. Read that skill completely before operating the app.
5. Identify the app as bundle ID `com.jfmortensen.citysim`. Fetch a fresh accessibility tree after every action; do not reuse stale element indexes.

## Run the hands-on audit

Read [audit-checklist.md](references/audit-checklist.md) completely, then exercise every applicable flow. Use screenshots and accessibility text together: screenshots establish visual hierarchy; the accessibility tree establishes names, roles, focus, and stability.

Pause temporarily when necessary to compare live versus stable interaction. Specifically test whether simulation ticks invalidate accessibility targets or keyboard focus. Do not mistake automation friction for a product defect: reproduce, compare paused/running behavior, and correlate it to source before reporting.

Prefer reversible interactions:

- open and close panels;
- change overlays, then restore the original overlay;
- select tools without placing them;
- inspect tiles and city metrics;
- pan and zoom, then approximately restore the camera;
- resize the window without closing it;
- exercise keyboard focus and cancellation.

If construction feedback must be tested, use an empty tile only when it is safe and immediately undo the action. Do not save the resulting state.

## Correlate findings to source

Inspect at least:

- `Views/ContentView.swift`
- `Views/TopHUDView.swift`
- `Views/BuildToolbarView.swift`
- `Views/EventFeedView.swift`
- `Views/ObjectivesView.swift`
- `Views/InspectorView.swift`
- `Views/OverlayPickerView.swift`
- `Rendering/CityScene.swift`
- `Stores/CityGameStore.swift`
- relevant models, analytics, and simulation code for disputed semantics

For each significant finding, record:

- what was directly observed;
- why it harms a player or accessibility user;
- the responsible code surface with current line references;
- a concrete recommendation;
- confidence and any limitation when the cause is inferred.

Do not copy old findings blindly. The existing dated audit is historical evidence only; rerun the app and report current behavior.

## Write the report

Create or replace the requested dated report using this structure:

1. scope, build/session, date, method, and limitations;
2. executive summary and three highest-impact problems;
3. severity scale (`P0` blocking, `P1` high, `P2` medium, `P3` low);
4. ranked findings with observation, evidence, impact, and recommendation;
5. cross-cutting interaction model or design direction;
6. phased delivery order;
7. measurable acceptance criteria;
8. audit limitations and untested surfaces.

Distinguish current observations from source-backed inference. Avoid inflated completeness claims such as “full accessibility verified” when only the visible route was tested.

## Restore and verify

1. Restore the original overlay, inspector state, objectives visibility, simulation speed, and approximate window/camera state.
2. Fetch a final accessibility state and confirm the simulation is behaving as it did initially.
3. Run `git diff --check` for the report and inspect `git status --short`.
4. Validate that the only new change attributable to this run is the audit artifact unless the user authorized more.
5. Report the artifact path, finding count by severity, highest-priority conclusions, tested surfaces, limitations, and whether session restoration succeeded.

## Completion bar

Do not declare completion until all of these are true:

- the running app was operated directly, not only reviewed from source;
- default and constrained layouts were visually inspected where the environment permits;
- the core build, inspect, overlay, objectives, events, time, and accessibility paths were sampled;
- material claims have observable and/or source evidence;
- a durable repo-local report exists;
- the user's app state was restored or any restoration limitation is disclosed.
