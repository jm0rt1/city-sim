# PLAY-057 pointer-boundary rejection

Status: **BLOCKED — no candidate is offered for integration**

## Exact rejected history

- `5165615f63775f6f67bfba0f1643d8f2679e4374`: accepted Focus City composition, later rejected for pointer pass-through.
- `7f727a620bf90c1aedc8831e3b605d435519c003`: task-yield deferral; live pointer still changed the target.
- `c3ff211c26b3518746b482e6db499e3028715df1`: 80 ms deferral; live pointer still changed the target.
- `47f531de13f190edcb837c246ed45f2217813b47`: AppKit hit-test shield; live pointer still changed the target.
- `0701323f4b077eabef79b72eb09d15f951ae344d`: unsafe snapshot/restore experiment, retained only as a rejected ancestor.
- `732365d`: non-rewriting revert of `0701323`, restoring the product tree to the `47f531d` state.
- `2b27faae3d8d1756c3cfbae85e8aae78ba5587ac`: exact-window local down/drag/up monitor; automated containment passed, but the staged pointer route failed.

## Exact `2b27faa` staged identity

- Branch: `codex/citysim-ui-input`
- Candidate commit: `2b27faae3d8d1756c3cfbae85e8aae78ba5587ac`
- PID: `65077`
- Executable SHA-256: `de1779cbac8853a7b7832025ec775e0e52607c889663d9870897acb204edec1c`
- Full staging identity: `rejected-candidate-2b27faa-local-monitor-failure/candidate.manifest`

## Binding failure

In one uninterrupted regular-window process:

1. The city was paused on Day 11 with treasury `$31,078`, Commercial selected, Undo unavailable, and the active target at block `11,12`.
2. The pointer was first moved to non-map title chrome, leaving the authored target stable.
3. A real coordinate click was sent to the visible `Focus City` control.
4. Focus City did not open.
5. The underlying map target changed to block `18,16`; its action changed from occupied Residential rejection to road-required Open Land rejection.

This violates CONTRACT-012 before compact or exit proof can be meaningful. Per integration direction, testing stopped after the first exact staged failure. No coordinate restoration was used, and no compact result is claimed.

## Retained evidence

- `rejected-candidate-2b27faa-local-monitor-failure/play057-regular-before-pointer.png`
  - SHA-256 `46f3e13976f522546499255b082b2c4087f2dd37fd5de9ba8eecfa6a1172e5f6`
- `rejected-candidate-2b27faa-local-monitor-failure/play057-regular-before-pointer.ax.txt`
  - SHA-256 `0f2eea1012e8da728949d333024ad637193a731e9a7c018e543ec338b9ad50ec`
- `rejected-candidate-2b27faa-local-monitor-failure/play057-regular-after-pointer.png`
  - SHA-256 `dd2713bc7c46fdbb13426cc65199c739ebfca0639a25f8f578f18fb00180e192`
- `rejected-candidate-2b27faa-local-monitor-failure/play057-regular-after-pointer.ax.txt`
  - SHA-256 `cb29a282b6e3850953b3b52ebde54415575638fe2b9e3e1be136e4ca3e1f1575`

Earlier candidate evidence remains under the three `rejected-candidate-*` directories. Those frames are diagnostic history only and are not binding proof for `2b27faa`.

## Automated result and boundary

`swift test --package-path Native/CitySimNative --filter CityCommandCatalogTests`
passed `42/42`. The focused regressions proved local monitor lifecycle, exact-window/bounds filtering, drag-out cancellation, exactly-once typed command invocation, and unchanged state fingerprints for inspect/build/bulldoze when the monitor handler receives the sequence.

The staged failure proves that those component tests do not establish delivery ordering against SpriteKit in the real app. No full-suite or compact evidence is offered for this rejected candidate.
