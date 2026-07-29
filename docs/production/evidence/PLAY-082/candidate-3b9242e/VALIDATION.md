# PLAY-082 Candidate Validation — Selected Target Beacon

## Candidate identity

- Product commit:
  `3b9242efcde6f6183c4de9649afbe66085db3478`
- Candidate branch: `codex/citysim-ui-input`
- Accepted authority merged before product work:
  `775bea061ee4e9cb0af7842edbd1ec341d61aa41`
- Corrected PLAY-082 authority:
  `d15b3b41e3abd61d9a28e9e8611593e954625388`
- Staged candidate ID: `ui-input-wdbeadac6e0bd`
- Bundle identifier:
  `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Executable SHA-256:
  `d30488dff241d75427f47775c3ba05d8ccc9b6290d5807c5e00e9f3d9e6ff803`
- Staged manifest SHA-256:
  `fb6ab9211b8d80b41c383ae0f914b07c1e7af5eb7cd3ed90b3ba776520a6ef37`
- Exact staged verification: passed; process `89113` remained alive.

The staged bundle was built from the clean product commit at:

`dist/CitySim-ui-input-wdbeadac6e0bd.app`

## Product and ownership result

The 64-point closed command rail now presents one strong selected-target
beacon from existing store truth:

- target or tool name;
- one-based block coordinate or truthful no-selection instruction;
- `INSPECT`, `CHOOSE`, `READY`, `BLOCKED`, or `BULLDOZE` state;
- the existing authoritative primary-action description as its AX value.

When a target exists, the beacon remains the existing semantic SwiftUI
`Button` and performs only `toggleCommandCenter` once. Nil targets do not
advertise an action. Build targets with an active decision retain the existing
decision row, which remains the authoritative ready/blocked explanation.

Only these product/test files changed:

- `Native/CitySimNative/Sources/CitySimNative/Views/BuildToolbarView.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CitySimulationTests.swift`

No content composition, scene, store, command, objective, alert, theme,
renderer, gameplay, simulation, persistence, package, or build-script surface
changed.

## Focused validation

Command:

```text
env SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/citysim-play082-module-cache \
  CLANG_MODULE_CACHE_PATH=/private/tmp/citysim-play082-module-cache \
  swift test --package-path Native/CitySimNative \
  --scratch-path /private/tmp/citysim-play082-scratch \
  --disable-sandbox --filter CitySimulationTests.testSelectedTargetBeacon
```

Result: **3/3 passed**.

The tests bind:

- inspect, build, bulldoze, and nil presentations;
- ready and blocked state;
- exact AX label and value from the existing target presentation;
- one `toggleCommandCenter` activation;
- Escape through `cancelInteraction`;
- unchanged city state, selection, interaction mode, Undo, and focus generation
  on activation;
- one map-focus restoration request after Escape;
- unchanged 64-point compact and regular situational rails;
- compact closed interactive map height of 416/600 points (69.3%).

The existing viewport-settlement test in the complete suite continues to bind
554/768 points (72.1%) for the regular closed map and 416/600 points (69.3%)
for exact compact.

## Complete native suite

A first 274-test run under simultaneous renderer work in another worktree
produced five existing timing-ceiling assertions and no functional failure.
After the competing process ended, all four affected methods passed unchanged
in isolation:

- renderer changed-pulse average: 0.701 ms, 1/1 passed;
- current story corpus builds: 5,493.750 and 5,519.262 ms, 1/1 passed;
- spatial derivation average/max: 2.400/3.285 ms, 1/1 passed;
- golden renderer world update: 4.160 ms, 1/1 passed.

The complete suite was then repeated without product mutation and exited
successfully: **274/274 passed**. No performance threshold or unrelated test
was changed.

## Deterministic layout evidence

These focused-test renders are supplemental layout evidence, not substitutes
for the staged-app interaction gate:

| Artifact | Point fixture | Disposition | SHA-256 |
|---|---:|---|---|
| `compact-unit-beacon.png` | 884 x 64 | retained compact proof | `e55ccb2e6d4aec9982e8bfbbb9b32b25ca0e3ece32f09034f4428a5d8d197e07` |
| `regular-unit-beacon.png` | 1020 x 64 | rejected as artificial noncompact proof | `68fc62a3cc40da445235e05bb4382bc4eb2da55513edb96ad9176b252429f891` |

The original 1020-point fixture forced `compact: false` below the real
ContentView breakpoint and is not evidence for regular layout. It is retained
only as the rejected surface that prompted the integration return.

## Integration-return regular-width correction

- Focused product/test repair:
  `816f8f321ec506979f8258e34ea05eed366a6bd1`
- Authentic regular window: 1278 x 768 points
- Authentic regular command-rail maximum: 1120 x 64 points
- Compact command rail: 884 x 64 points

The first authentic 1120-point render showed `Commands` wrapping onto two
lines. Inspect, Bulldoze, Details, and the City Hall title/status remained
single-line. The focused repair gives the existing command-guide label one
line and its natural horizontal size; it changes no command or hit target.
The corrected render keeps all command labels plus `City Hall` and `INSPECT`
single-line and unclipped while retaining the 64-point rail.

| Artifact | Pixels | Disposition | SHA-256 |
|---|---:|---|---|
| `return-regular-1120-before-wrap.png` | 2240 x 128 | rejected authentic-width render; Commands wraps | `0a74cff8ac0ce3ef09382351975ec5b614194375daa34ebb041598f063cc4c61` |
| `return-regular-1120-after.png` | 2240 x 128 | accepted focused regular proof, 1120 x 64 points at 2x | `0f7d0f5253f04ba86c134be645877d4905d8167945ac094d0b2db4cf6f463908` |
| `return-compact-after.png` | 1768 x 128 | compact continuity, 884 x 64 points at 2x | `ecf5446aa6a1b55a07f440d84607e007862228f7d6dec4925693f3b6c92abf52` |

Return validation:

- all selected-target beacon tests: **3/3 passed**;
- settled closed/decision/Details/post-close viewport test: **1/1 passed**;
- regular ContentView path explicitly resolves noncompact;
- regular rail width is explicitly bound to 1120 points;
- compact and regular rails remain exactly 64 points high;
- existing target presentation, activation, Escape, focus, and AX assertions
  remain unchanged and green.

## Independent-return actionable AX correction

- Focused product/test repair:
  `d12d1df1948605153e7fa91c7ea05621391a71fb`

The beacon is a semantic button whose activation opens Details. Build and
bulldoze targets previously exposed the underlying primary action name, such
as `Build Road` or `Demolish City Hall`, even though pressing the beacon never
performed that action. The descendant repair makes every actionable beacon
name its actual result:

```text
Open details for <target or tool> at block <x>, <y>
```

The AX value remains the existing primary-action disclosure without
transformation. It therefore retains availability, blocked reason, cost,
upkeep/consequence, and demolition protection truth. Nil inspect/build/
bulldoze presentations remain nonactionable and retain their truthful mode or
selection descriptions.

Focused assertions now bind exact labels and untouched disclosure values for:

- inspect;
- build-ready and build-blocked;
- bulldoze-ready and bulldoze-blocked;
- inspect/build/bulldoze nil controls.

Return validation:

- all selected-target beacon tests: **3/3 passed**;
- settled closed/decision/Details/post-close viewport test: **1/1 passed**;
- exactly one `toggleCommandCenter` activation: retained;
- Escape, focus generation, selection, state, mode, and Undo continuity:
  retained;
- 64-point compact and authentic 1120-point regular rails: unchanged;
- current regular/compact visual evidence: still binding because the repair
  changes only semantic AX text.

## Staged-app attempt and unresolved gate

The exact candidate was staged and verified, but the desktop was locked.
Computer Use returned:

```text
The Mac is locked and automatic unlock could not unlock it.
Ask the user to unlock the Mac manually before continuing.
```

Per integration direction, no further unlock or desktop retry was attempted.
Therefore this packet does **not** claim:

- live regular or exact-compact City/Pollution frames;
- real pointer, Return, FKA, AX press, Escape, or Reduce Motion activation;
- live selection/camera continuity after opening and closing Details.

Integration retains those candidate-bound checks as an explicit required gate
when desktop access is available. The pure presentation and command-route
tests above establish the owned implementation contract without weakening or
self-passing the live gate.

## Repository gates

- `git diff --check`: passed.
- `bash -n script/build_and_run.sh`: passed.
- Exact staged `--verify`: passed.
- Product checkpoint staged with explicit paths and checked with cached
  diff/check/stat before commit.
- No temporary product logging or diagnostic trace remains.
- Exact staged candidate terminated after the blocked attempt; zero matching
  candidate or test process remained at handoff.
- The return did not retry or claim the locked staged-app interaction gate.
