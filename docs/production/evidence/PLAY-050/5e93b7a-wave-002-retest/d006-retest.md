# PLAY-050-D006 Repaired-Candidate Retest — Still Reproduced

- Product candidate: `1dd89f6af439238b192b9b60e666e8be2fbb302b`.
- Quality candidate: `5e93b7a808aed7cb4fbb12c24e8386ba5f7e35f8`.
- Result: **failed at the first required default/Return route**.
- Owner return: UI and Input.

## Exact reproduction

1. Reset only `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4` and launch the freshly staged candidate.
2. During Welcome, press `Space`, `1`, `2`, `3`, `B`, `V`, `Escape`, and `Command-/`; pointer-attempt the visible underlying HUD, command deck, and map.
3. At exact-process elapsed time 69 seconds, confirm Welcome is still the only game-content accessibility surface and the authored visible state remains Day 1, $26,000, population 300, and 1x.
4. Press Return to activate `welcome.start-building`.
5. Fetch a fresh complete accessibility tree, then press Space without any pointer action.
6. Fetch a second complete tree, then press Space again without any pointer action.

Expected: the repaired blocked-to-enabled transition releases the Welcome FocusState and makes the actual `SKView` first responder exactly once. The first Space immediately selects Pause while the state is still Day 1.

Actual:

- Welcome disappears and no vanished modal remains in the accessibility tree.
- The focused accessibility element remains the standard `CitySim` window rather than `SKView`.
- After the first Space, Pause remains `Not selected`, 1x remains `Selected`, and the city reaches Day 6.
- After the second Space, Pause remains `Not selected`, 1x remains `Selected`, and the city reaches Day 13.
- No extra click or focus movement was made.

The focused unit test `testWelcomePolicyTransitionHandsFirstResponderToMapExactlyOnce` passed in the independently compiled suite before the run was stopped, but the same transition does not occur in the real staged SwiftUI/AppKit composition.

Evidence: `d001-default-after-77s.jpeg`, `d006-after-return-day1.jpeg`, `d006-first-space-inert-day6.jpeg`, and `d006-second-space-inert-day13.jpeg`.

The gate orders PLAY-050 to stop if D006 fails. Compact pointer dismissal and all later acceptance work were therefore not executed or credited.
