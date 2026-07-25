# PLAY-057 shared input-boundary diagnostic

Status: **STOPPED — integration authorization required**

## Exact identity

- Diagnostic commit: `2642ec56f1970fb54bd318f86f73529bb9518e74`
- Runtime PID: `73008`
- Runtime window number: `58803`
- Executable SHA-256: `f4ced8b5468da30bcb033e87f2b92c5272c1e9c8285fb8bf08b2bb5a8d2b914a`
- Candidate manifest: `candidate.manifest`

The instrumentation is compiled only under `#if DEBUG` and writes only when
`CITYSIM_FOCUS_POINTER_TRACE_PATH` is explicitly supplied. It does not change
event filtering, command dispatch, store state, renderer behavior, focus, or
accessibility.

## Live geometry and pointer

The retained trace disproves collapsed overlay bounds:

- Enter overlay bounds/frame: `{{0,0},{89,44}}`
- Enter overlay window rect: `{{815.5,71},{89,44}}`
- Window frame: `{{261,283},{1278,768}}`
- Derived control center in Computer Use coordinates: `(860,675)`
- Pointer event location in AppKit window coordinates: `{860,93}`
- Converted overlay-local point: `{44.5,22}`

The click used that derived center, not a stale coordinate.

## Monitor result

For the one real pointer sequence:

1. Left mouse down reached the monitor with event/window/object/view window
   number `58803`.
2. The converted point was inside the exact overlay bounds.
3. The monitor changed `owned=false` to `owned=true` and returned `nil`.
4. Left mouse up reached the same monitor and window at the same point.
5. The monitor recorded `callback.post.perform` and invoked the typed store
   command once.
6. The Focus exit overlay was then installed at
   `{{1135.5,646},{122.5,44}}`, proving Focus presentation briefly became
   active.
7. That exit overlay was immediately dismantled without another monitor
   callback, and the final AX tree was back on the full HUD.

Despite the monitor owning both down and up, the active Commercial target
changed from valid block `10,11` to occupied block `16,14`. Treasury remained
`$30,255`, the simulation remained paused on Day 19, and Undo remained
unavailable.

## Boundary conclusion

The handler was reached with correct geometry and a matching window, yet the
SpriteKit-backed target still changed and another input path completed outside
this local-monitor callback. The UI-owned down/drag/up boundary is therefore
insufficient to guarantee CONTRACT-012. The trace plus the existing source
behavior support these inferences:

- SpriteKit accepts pointer candidate movement beneath visible SwiftUI chrome
  before the owned down/up sequence.
- A second UI input observer can still complete after the local monitor's typed
  action, producing the observed transient Focus entry and immediate exit.

Per integration direction, no coordinate restoration, renderer edit, expanded
event mask, compact retry, or new product attempt followed. Resolution needs an
approved shared input-boundary contract defining how visible SwiftUI chrome
quarantines renderer pointer candidates and how pointer activation avoids a
second semantic dispatch while keeping FKA/AX on the SwiftUI Button.

## Retained artifacts

- `play057-pointer-monitor.trace`
  - SHA-256 `364c53af7e3c3472f74364268dce9ebc6d2a063a415f5a5d3ddd070838101625`
- `play057-before-derived-pointer.ax.txt`
  - SHA-256 `fcc921e6a02d4675e41f954ca5d24cf88feba8e3c49933d671b7a2deec325df7`
- `play057-before-derived-pointer.png`
  - SHA-256 `8fcadfc5d03b4eb5b7104a59390478d25a5b1b0c8ef48427e0f2978a8d9bbca6`
- `play057-after-derived-pointer.ax.txt`
  - SHA-256 `93d2304c2cf51157f050f14da25ff1299ff62cc30b5522a38b955271346c32b5`
- `play057-after-derived-pointer.png`
  - SHA-256 `f47c74b2397548de2958257655a506ae3b8353ba0f5bf921482894ba5a6432dc`

Focused diagnostic tests:

`swift test --package-path Native/CitySimNative --filter CityCommandCatalogTests.testFocusCityPointerMonitor`

Result: `3/3` passed. This proves the component monitor contract only; the live
trace disproves end-to-end containment.
