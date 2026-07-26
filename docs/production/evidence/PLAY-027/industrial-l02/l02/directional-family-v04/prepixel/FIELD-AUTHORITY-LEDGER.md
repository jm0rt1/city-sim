# PLAY-027 Industrial L2 V04 entrance field authority

V04 preserves every V03 value and adds only the eleven keys required by the
production `EntranceDescriptor`.

| Added key | Value | Immutable authority |
|---|---:|---|
| `entrance.stepRun` | `2` | East v05 same field |
| `entrance.canopyDepth` | `9` | East v05 same field |
| `entrance.hingeSide` | `right` | East v05 same field |
| `entrance.pavilionWidth` | `30` | East v05 same field |
| `entrance.pavilionDepth` | `8` | East v05 same field |
| `entrance.pavilionHeight` | `24` | East v05 same field |
| `entrance.pavilionRoofHeight` | `3` | East v05 same field |
| `entrance.porchWidth` | `30` | East v05 same field |
| `entrance.porchColumnWidth` | `1.4` | East v05 same field |
| `entrance.porchLateralOffset` | `0` | East v05 same field |
| `entrance.pavilionMaterialID` | `v05-hall-metal` | Integration-approved closest same-role blue-gray steel in immutable East v05 library |

East v05's same-field `pavilionMaterialID`, `v02-painted-steel`, is explicitly
rejected as a literal authority because it is absent from the referenced
material library. Its declared blue-gray steel values are RGBA
`0.56/0.62/0.66`, roughness `0.75`, metalness `0.24`. `v05-hall-metal` is the
closest same-role governed East-v05 material at RGBA `0.60/0.72/0.80`,
roughness `0.76`, metalness `0.22`. V04 does not propagate the dangling value,
and the validator rejects any pavilion mapping to the subordinate
`v05-safety` accent.

All added compatibility fields are render-neutral because every N/S/W
descriptor retains `building.usesExplicitComponentGeometry=true`; the
production scene builder does not synthesize `entrance` geometry for explicit
component scenes. Removing these eleven fields reproduces V03 canonically.

East v05 descriptor:
`482bea0169e9229df437b05ca6f0299046d49bb92e2e9d9ef4f3865df9be5fa0`.

East v05 material library:
`6ab8b19d6d6cf53dc98f77867117569f6cccd104cd886a2dc1788361736404fb`.

East v05's dangling pavilion metadata remains a family-level blocker. V04
validates N/S/W decode and canonical geometry only; it does not claim complete
N/E/S/W family authority or authorize an East metadata/pixel repair.
