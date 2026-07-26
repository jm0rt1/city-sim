# PLAY-077 Candidate Validation

## Identity

- Product candidate:
  `b04f4e22471d4279457b5b8e099c08c17ff5b264`
- Baseline:
  `bd9dc14d9d4b5f26f5f1dca153725f8ee919438f`
- Branch: `codex/citysim-ui-input`
- Staged candidate: `ui-input-wdbeadac6e0bd`
- Bundle identifier:
  `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Bundle:
  `dist/CitySim-ui-input-wdbeadac6e0bd.app`
- Executable SHA-256:
  `67f58be1c99a5c0eae3604864aee952f0c3f9f5627ccf4333c48cec1e2bc76a9`
- Manifest SHA-256:
  `d84a2f4dcbe3539e62bc478c7d4b4366fad983cc5c0a1d3e12e983920f45735e`
- Exact staged `./script/build_and_run.sh --verify`: passed.

No `PLAY077_TRACE` or `CITYSIM_PLAY077_TRACE` source remains. The native menu
tracking implementation has no production logging.

## Automated verification

- `swift test --package-path Native/CitySimNative --filter CityCommandCatalogTests`
  passed 52/52.
- `swift test --package-path Native/CitySimNative` passed 266/266 in
  205.425 seconds.
- `git diff --check`: passed.
- `bash -n script/build_and_run.sh script/persistence_relaunch_gate.sh
  script/verify_candidate_isolation.sh`: passed.

The focused lifecycle coverage binds quarantine to build-item activation:

- a catalog opened through a keyboard event and then selected by item pointer
  mouse-up starts the existing transition gate;
- the same item capture works when the catalog was opened by pointer;
- keyboard selection clears pointer capture and dispatches immediately;
- the captured mouse-up is consumed synchronously by the SwiftUI item action
  before menu tracking ends, without an asynchronous expiry task;
- canceled menu tracking clears the pending capture, so it cannot leak into a
  later semantic action;
- candidate, primary, and secondary map bridges remain blocked through
  dismissal, stationary input, and zero-delta movement;
- real same-window movement beyond the existing four-point threshold releases
  the gate.

These deterministic lifecycle tests support the real-app proof below; they do
not replace it.

## Binding compact pointer journey

The exact staged executable ran with:

```text
CITYSIM_COMPACT_WINDOW=1
CITYSIM_REDUCE_MOTION_PROOF=1
CITYSIM_DATA_ROOT=dist/test-data/ui-input-wdbeadac6e0bd
```

The captured window is 900 x 652 pixels with exact 900 x 600 content.

1. Paused state: treasury `$31,202`, net `-$88`, Road selected, no block
   selected, Undo disabled.
2. The real pointer opened Catalog at `(280, 610)` and selected Residential at
   the live item point `(350, 260)`.
3. After the menu dismissed, Residential was selected exactly once while the
   map still announced `No block selected`; treasury and Undo were unchanged.
4. Intentional pointer movement and click at `(250, 450)` then selected
   Residential block 14,18 and exposed the accepted direct-road-access reason.
5. `Place road` selected Road block 14,17, not the blocked building parcel.
   The deck announced that it borders Residential block 14,18 and required
   confirmation.
6. Escape cleared the active target without construction: treasury `$31,202`,
   net `-$88`, Undo disabled.
7. Repeating recovery and pressing Return built exactly one Road:
   treasury `$31,082`, net `-$91`, Undo enabled.
8. Command-Z restored treasury `$31,202`, net `-$88`, no selection, and Undo
   disabled.
9. Command Guide search for `commercial`, Tab, Return selected Commercial
   through the existing catalog/store command and left `No block selected`.

The focused Catalog button was also opened through the Full Keyboard Access
Tab loop and Space in the exact compact staged process; Escape canceled it
without changing the Road tool, selection, treasury, or Undo. Native menu
lifecycle coverage binds the required keyboard/FKA-open then pointer-item
combination. The binding fall-through proof remains the physical-pointer
journey in steps 1-4, rather than an element-targeted or synthetic click.

## Binding regular journey

The authored fresh candidate preference domain produced a 1229 x 768 captured
window without `CITYSIM_COMPACT_WINDOW`.

1. Paused fresh state: treasury `$32,000`, net `-$90 / cycle`, no selection,
   Undo disabled.
2. Keyboard `C` selected Commercial immediately and preserved `No block
   selected`.
3. A real pointer selected roadless Commercial block 13,17.
4. `Place road` selected deterministic adjacent Road block 13,16 and required
   confirmation.
5. Return built once: treasury `$31,880`, net `-$94 / cycle`, Undo enabled.
6. Command-Z restored exact `$32,000`, `-$90 / cycle`, no selection, and
   disabled Undo.
7. The map accessibility action `Build Road at block 14, 18` built once with
   the same `$120` / `$4` consequence and Command-Z restored the exact state.

## Accessibility and input ledger

- Pointer: physical compact catalog/item selection and regular/compact map
  targeting passed.
- Keyboard: shortcuts, focused Return confirmation, Escape cancellation,
  Command-Z, and command-guide activation passed.
- Full Keyboard Access: Tab reached the semantic Catalog button; Space opened
  it and Escape canceled it. The SwiftUI button remains the semantic route.
- AX/VoiceOver-critical semantics: the City map retained its identity, value,
  help, and selected Road build action; the AX build action mutated exactly
  once and Undo restored exact state.
- Reduce Motion: the complete compact journey ran with the proof override and
  retained the same command, target, rejection, and recovery behavior.
- Modal/text quarantine and Focus City pointer behavior remain covered by the
  unchanged shared command policy and transition-gate tests.

## Artifact inventory

| Artifact | Dimensions | SHA-256 |
|---|---:|---|
| `default-closed.png` | 1229 x 768 | `b32f5ce0a2a3709657f49c049599860e0cffc1e9b34d67dbf4c67dc637b73cd3` |
| `default-roadless-commercial.png` | 1229 x 768 | `30d76ca4ac577b5f52fb088a84552c581bf1b200b568338c8b7a9cd4c3ca35b1` |
| `default-adjacent-road-target.png` | 1229 x 768 | `571ca0db3c3662490a36a99661ef21d32c3e7cfdc6f3fe145b8daf9c02453597` |
| `default-road-built.png` | 1229 x 768 | `0982a62bdf1c0fffc4e92a83579d4f52a09597a17dcd30bd8b15418de52f2ecb` |
| `compact-baseline.png` | 900 x 652 | `646700d6f80d7fa2fe687ba992dcc65189466cabad1ef3ce4ea8217d76a7cac8` |
| `compact-pointer-quarantined.png` | 900 x 652 | `9563359578b9c668e1107bc6c1cba1746d6173043eef1fe7f5b2b834f02c0d00` |
| `compact-adjacent-road-target.png` | 900 x 652 | `dedea1b3aa9ad1a92d3122d603f39af08c0f0a6eea35d21c5fb7a1568c700b84` |
| `compact-road-built.png` | 900 x 652 | `292756ed9b13165a9a32092c0e163157cb221a04c236272945462d7572e7b649` |
| `live-state-ledger.json` | n/a | `fe9745ec36157dace846d05840b059ca400ff08a3f9f7a327235e66f02ea46ac` |

## Scope and limitations

- No renderer, camera, gameplay validation, simulation, save schema, public
  command/store contract, package, build script, art, or shipping resource
  changed.
- Recovery selects one adjacent Road candidate using existing Road validation;
  it does not promise that one Road segment alone completes a longer network
  path.
- The evidence checks VoiceOver-critical AX semantics and actions through the
  live accessibility tree; it does not claim a separately recorded spoken
  VoiceOver session.
- Candidate processes were terminated after proof.
