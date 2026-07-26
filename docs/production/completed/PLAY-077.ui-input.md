# PLAY-077 Completion — Keep Command Chrome from Targeting the Map

- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Status:** accepted-and-integrated
- **Published baseline:**
  `bd9dc14d9d4b5f26f5f1dca153725f8ee919438f`
- **Product candidate:**
  `b04f4e22471d4279457b5b8e099c08c17ff5b264`
- **Evidence commit:**
  `59e59e19c751506b44d15b54e380ed2e0cf98b14`
- **Evidence root:**
  `docs/production/evidence/PLAY-077/candidate-b04f4e2/`
- **Integrated master product:**
  `897c191355d2fcb18ecc2e8d7358b44e9cae7cd4`
- **Integration evidence:**
  `docs/production/evidence/PLAY-077/integration-897c191/VALIDATION.md`

The completion commit containing this record is reported in the lane handoff
because a commit cannot embed its own identity.

## Player-visible outcome

Selecting a compact build-catalog item now changes only the build tool. The
item's pointer release starts the existing store-independent map transition
gate before the typed build command runs, so popup dismissal, stationary
input, and zero-delta hover cannot invent or move a map target, reach a map
primary/secondary action, change the city, or enable Undo. Intentional
same-window pointer movement releases the existing gate and restores ordinary
map targeting.

The correction is tied to build-item activation, not to how the Catalog was
opened. A keyboard/FKA-opened Catalog followed by pointer item selection is
quarantined. A keyboard-selected item stays immediate. Menu cancellation
clears pending capture before a later semantic action can consume it.

For an accepted `.roadAccessRequired` rejection, `Place road` now chooses one
deterministic valid adjacent Road parcel instead of reusing the blocked
building parcel. It prefers a real network extension, retains one active
target, names both parcels, and requires explicit confirmation. Escape cancels
without mutation; Return, pointer, and AX confirmation use the existing map
action once; Command-Z restores exact state.

## Ordered commits

1. `066cbedc743e77d73f24dad8532474edec4af47c` —
   `PLAY-077: Quarantine compact catalog pointer selection`
2. `c494fe4947109a5bf06a1490865596779414a2c4` —
   `PLAY-077: Target truthful adjacent road recovery`
3. `16571bb89f35bbc046cdd372f0039d683fb37d12` —
   `PLAY-077: Bind quarantine to catalog item pointer activation`
4. `b04f4e22471d4279457b5b8e099c08c17ff5b264` —
   `PLAY-077: Bind pointer capture to catalog tracking`
5. `59e59e19c751506b44d15b54e380ed2e0cf98b14` —
   `PLAY-077: Bind compact input evidence`

## Exact product and test surfaces

- `Native/CitySimNative/Sources/CitySimNative/Views/BuildToolbarView.swift`
- `Native/CitySimNative/Sources/CitySimNative/Support/CityMapPointerTransitionGate.swift`
- `Native/CitySimNative/Sources/CitySimNative/Stores/CityGameStore.swift`
- `Native/CitySimNative/Sources/CitySimNative/Support/CityDirectActionPresentation.swift`
- `Native/CitySimNative/Tests/CitySimNativeTests/CityCommandCatalogTests.swift`

Evidence is confined to the task-owned PLAY-077 evidence root. This completion
record is the only additional task-management file.

## Verification

- Focused command/input suite: 52/52 passed.
- Complete native suite: 266/266 passed in 205.425 seconds.
- Exact staged candidate verify: passed.
- `git diff --check`: passed.
- Repository shell syntax: passed.
- No temporary PLAY-077 trace or production logging remains.
- Staged executable SHA-256:
  `67f58be1c99a5c0eae3604864aee952f0c3f9f5627ccf4333c48cec1e2bc76a9`.
- Staged manifest SHA-256:
  `d84a2f4dcbe3539e62bc478c7d4b4366fad983cc5c0a1d3e12e983920f45735e`.

The native lifecycle tests prove:

- keyboard/FKA open followed by pointer item activation is captured;
- pointer open followed by pointer item activation is captured identically;
- keyboard item selection clears pointer capture and remains immediate;
- the synchronous item action consumes capture before menu tracking ends;
- canceled menu tracking cannot leak capture to another action;
- every map pointer bridge stays blocked until real movement beyond the
  existing threshold.

The tests supplement, rather than replace, the binding real-app pointer
journey.

## Hands-on regular and compact proof

In exact compact content:

- real pointer Catalog → Residential left `No block selected`, treasury
  `$31,202`, and Undo disabled;
- intentional movement then selected blocked Residential block 14,18;
- recovery selected Road block 14,17 and required confirmation;
- Escape preserved `$31,202` / `-$88` with Undo disabled;
- Return built once at `$31,082` / `-$91`;
- Command-Z restored exact `$31,202` / `-$88`, no target, and disabled Undo;
- the command guide selected Commercial and preserved no target.

In the authored regular window:

- keyboard `C` selected Commercial with no target;
- pointer-selected Commercial block 13,17 exposed direct-road-access truth;
- recovery selected adjacent Road block 13,16;
- Return built once at `$31,880` / `-$94`;
- Command-Z restored exact `$32,000` / `-$90`;
- the live AX Road action built exactly once and Undo restored exact state.

Default proof frames are 1229 x 768. Compact proof frames are 900 x 652 with
exact 900 x 600 content and ran with Reduce Motion proof enabled. The evidence
ledger records pointer coordinates, state values, AX routes, frame hashes, and
candidate identity.

## Accessibility, focus, and continuity

- The SwiftUI Catalog button remains the only semantic FKA/AX control. The
  AppKit binder is AX-hidden and does not hit-test.
- FKA Tab reached Catalog; Space opened it; Escape canceled it without changing
  tool, target, treasury, or Undo.
- Keyboard shortcuts, macOS menu/guide commands, FKA, and AX semantic
  activation do not start pointer quarantine.
- The City map retains its accessibility identity, value, help, and selected
  action. AX construction and focused Return each mutate exactly once.
- Existing modal/text quarantine, topmost Escape, focus restoration, camera,
  active-target, save/load, and Focus City behavior remain unchanged.

## Scope, deferred work, and merge notes

- No renderer, camera, gameplay/simulation rule, persistence, public
  command/store contract, package/build script, art, shipping resource, or
  legacy Python file changed.
- The recovery action selects a truthful adjacent Road candidate. It does not
  invent a promise that one segment alone completes a longer road network.
- VoiceOver-critical semantics and actions were inspected through the live AX
  tree; no separately recorded spoken VoiceOver session is claimed.
- CONTRACT-017 is fully adopted without broadening CONTRACT-014.
- No shared-contract conflict or merge-order dependency remains beyond normal
  independent review and integration disposition.
