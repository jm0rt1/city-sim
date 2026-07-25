# PLAY-074 Viewport Settlement Validation

## Repair scope

The defect was UI-owned. `ContentView.mapViewportInsets` continued to apply
compact fallback floors after valid live chrome frames existed, while
preference aggregation could retain outgoing geometry during animated
transitions. A closed deck could therefore publish a Details-like safe
aperture to the renderer.

The repair changes only:

- `ContentView.swift`: live named-space geometry reporting, valid-frame
  filtering, measured-frame-first inset resolution, and Focus City retention
  until restored chrome settles.
- `CitySimulationTests.swift`: deterministic compact and regular settlement
  coverage for closed, active-decision, Details-open, and post-close states.

No renderer/camera/LOD logic, gameplay or simulation rule, command, save,
active-target truth, undo behavior, package, or build script changed.

## Automated gates

- Focused viewport/build/selection tests: 5/5 passed.
- Complete native suite, repeat run: 243/243 passed.
- First complete run had one existing renderer timing variance
  (2.3388 ms versus a 2.1 ms threshold); the exact isolated test immediately
  passed at 2.038 ms and the repeated complete suite passed.
- Exact staged `--verify` passed at product commit `6bb06ee`.
- `git diff --check` and repository shell syntax passed.

## Real-app journeys

- Compact closed -> active decision -> Details -> post-close published four
  distinct settled chrome frames and the expected expanding/contracting map
  aperture.
- Regular repeated the same four-state route.
- Selected City Hall block 12,12 and its unavailable Residential action
  remained visible and authoritative across Details open/close.
- Focus City entered and exited without changing target or camera geometry.
- Full Keyboard Access reached `hud.command.details`; Space opened Details.
  Escape closed the topmost Details surface, restored the active decision, and
  returned map focus.
- Accessibility trees retained the selected coordinate, unavailable reason,
  command action, and focus destination.
- Reduce Motion proof mode was enabled for all candidate live routes.
- Pointer, keyboard, command, save/load, undo, and active-target behavior were
  unchanged; their complete regression coverage passed in the full suite.

## Primary image hashes

| Frame | SHA-256 |
|---|---|
| Before compact closed | `2834211777e96ab4e4524a70769a87c4eff4bf3bae0ca7d51dd463f98567f7c9` |
| Before compact active decision | `765b4caf7069465909e4d41a1bf33a10c36b436a5bc9f49ce0f34f24bd5ea725` |
| Before compact Details | `116033f7fbee8724ba03fda22520a516720fb9f07761ee47f5863677f6bdd1aa` |
| Before compact post-close | `27127d074fc529a5c64176ab5288b5a5e2fcafb7e4482d3341bcf17890cd1199` |
| After compact closed | `5aa23359896aeaf860945dcd040491a369469d17b32098a76c45aa35473d9b5d` |
| After compact active decision | `cb46554cea19d4ff050326e71fe4bc419225355aaade209bee69fc45838c1b53` |
| After compact Details | `ee92f588a41d5044fa6663c668cd8bf0c75bfe72f944dd76495c3e685d58f897` |
| After compact post-close | `4adc32908268e6482b92264793fd9bde27731abbcb176c106dc269b24b1d5234` |
| After regular closed | `870a1b023c053304459f893a5214e612943603bb7fe5bf93e4f369ce1c7b7ca0` |
| After regular active decision | `c194e89c2b8891242fff337eddccb39bc1f4bbfcbd709a74158c557578f533f2` |
| After regular Details | `98788a737e8e270a4d9be8005e3ff14102b7f9b933cd9cd0bc0c3bf21c3b5603` |
| After regular post-close | `385e4db5156e2b6f4e01a2e97d8257c46c0a1e62230d04e92c7c2a7017f3a28f` |

## Known limitations

- Regular screenshots include macOS window decoration and use visual
  screenshot-edge measurements; deterministic tests bind exact content-space
  outputs.
- VoiceOver-critical names, values, actions, and FKA traversal were inspected
  through the live accessibility tree; spoken audio was not recorded.
- One test that assumes `NSApp` exists can crash when invoked alone before the
  AppKit-initializing tests. It passed in the complete suite and is unrelated
  to this product change.

Final process cleanup: exact verify PID `36146` and both proof PIDs were
terminated; the final candidate-process query returned no match.
