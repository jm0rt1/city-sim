# PLAY-031 D006 Focus-Handoff Repair

- Rejected integration candidate: `d947b7d`
- Repair base: `1084ba6ef624f9928d80f30829fe9f651ed68166`
- Product repair commits: `bacbe6fdba3d85047fca49548191b8dfec29c5c0`, `fc61b177a639e768615664a46f7a5e8f81381c30`
- Exact staged candidate: `fc61b177a639e768615664a46f7a5e8f81381c30`
- Candidate bundle: `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Candidate executable: `dist/CitySim-ui-input-wdbeadac6e0bd.app/Contents/MacOS/CitySimNative-wdbeadac6e0bd`
- Staged PID at verification: `50539`

## Reproduction and cause

PLAY-050 proved that D001 containment remained intact, but both Return and pointer dismissal left keyboard focus on the vanished Welcome/window. Global Command-/ continued through the menu route while bare gameplay shortcuts stayed inert until an `SKView` click. Code inspection showed the matching lifecycle gap: Welcome acquired SwiftUI `@FocusState`, but dismissal only enabled `CityCommandPolicy` and removed the modal; no owner restored AppKit first responder.

## Repair

Welcome releases modal focus before its shared dismissal continuation. During the resulting representable update, `CitySceneView.Coordinator` recognizes only `.blocked(.welcome)` to `.enabled` and transfers first responder to the actual map `SKView`. The previous policy is advanced before returning, so later renders cannot repeat the transfer. No asynchronous delay or alternative shortcut route exists.

## Automated and staged evidence

- `CityCommandCatalogTests`: 10/10, including `testWelcomePolicyTransitionHandsFirstResponderToMapExactlyOnce` and the complete modal command-policy regression.
- Full native suite: 88/88 in 225.292 seconds.
- Renderer diagnostics remained bounded: 9,004 nodes, 5,760 unchanged tile reuses, 0 updates, 1.859 ms average over ten pulses.
- Thirty-minute-equivalent renderer soak remained bounded: 4,286 pulses, 9,004 nodes, 2,424 drawables, 3 actions, 0.8764 ms average.
- Exact staged verify passed at `fc61b17` with isolated data root and freshly reset candidate preference domain.

## Live limitation

The Computer Use runtime hung in `get_app_state` without returning an accessibility tree or screenshot and the attempt was aborted. This record does not claim live D006 acceptance. Independent PLAY-050 must run the keyboard and pointer dismissal matrix on this exact candidate or its integrated descendant.
