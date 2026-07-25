# PLAY-074 Accessibility and Action Ledger

## Decision semantics

`hud.build.decision` exposes one semantic summary containing:

- building and active block;
- `1 × 1 block` footprint;
- construction cost and upkeep;
- Ready or Blocked availability;
- the accepted store-owned disabled reason;
- a concise consequence derived from existing building constants;
- Escape cancellation;
- the one existing typed recovery command.

The visible `hud.build.recovery`, `hud.build.commit`, and `hud.build.cancel`
controls remain native SwiftUI buttons with labels, help, focus rings, and the
same store/catalog routes used elsewhere. No pointer-only control or duplicate
action target was added.

## Route ledger

| Route | Retained result |
| --- | --- |
| Pointer recovery, occupied | `Bulldoze` selected the existing bulldoze command, preserved block 12,12, left treasury `$31,078`, left Undo disabled, and restored map focus. |
| Keyboard Return, blocked | Existing map-primary intent retained Residential and produced the durable accepted reason: `Demolish the existing structure before building here. Residential remains selected — choose another block.` |
| Pointer recovery, road required | `Place road` selected the existing Road tool, preserved block 14,16, left treasury `$31,078`, left Undo disabled, and restored map focus. |
| Pointer commit, valid | `Build here` used the existing map-primary action exactly once: treasury became `$30,958`, Road occupied block 14,16, and Undo became enabled. |
| Escape | Returned to Inspect, cleared the interaction target, preserved `$30,958` and enabled Undo, and focused the map. |
| Command guide | Command+/ plus `road` exposed available Open Roads and Build Road entries; Return activated the existing Road command and returned to the map. |
| macOS menu | Tools retained category and build commands with their declared shortcuts; Build Residential activated the existing command once. |
| Full Keyboard Access | Tab traversal reached `hud.build.recovery`; Space activated the native semantic button, selected Bulldoze, and returned focus to the map. |
| AX / VoiceOver-critical | Live AX trees expose the full decision value, reason, consequence, recovery help, target action, selection, focus, and Undo state. |
| Reduce Motion | Both binding layouts ran with `CITYSIM_REDUCE_MOTION_PROOF=1`; decision and recovery remained complete and operable. |

Spoken VoiceOver audio was not recorded. The binding proof is the live AX
tree, semantic buttons/actions, focused FKA traversal, keyboard routes, and
the complete automated accessibility/input suite.

## Evidence map

- `regular/invalid-target.jpeg` and `.ax.txt`: complete occupied decision.
- `regular/durable-rejection.ax.txt`: durable Return rejection.
- `regular/pointer-recovery.ax.txt`: pointer recovery and target preservation.
- `compact/invalid-target.jpeg` and `.ax.txt`: exact compact road-required decision.
- `compact/pointer-recovery.ax.txt`: Road recovery and target preservation.
- `compact/pointer-commit.ax.txt`: exactly-once valid commit and Undo state.
- `compact/escape.ax.txt`: cancellation ordering and focus restoration.
- `compact/guide-activation.ax.txt`: command-guide route.
- `compact/tools-menu.ax.txt` and `menu-activation.ax.txt`: macOS menu parity.
- `compact/fka-recovery.ax.txt`: FKA Space activation and map focus return.
