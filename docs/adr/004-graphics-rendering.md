# ADR 004: Graphics Rendering with pygame-ce

## Status
Accepted

## Context
City-Sim requires an isometric 2D renderer that:
- Reads only from `City` state and an `EventBus`; never imports simulation internals
- Runs on a decoupled frame rate (e.g. 60 fps) independent of the simulation tick rate
- Supports deterministic visual output when a fixed seed is used for procedural decoration
- Does not block or slow the headless simulation path

Several rendering libraries were evaluated:

| Library | Reason rejected |
|---|---|
| `tkinter` | No hardware-accelerated 2D; cannot sustain 60 fps for tile compositing |
| `PyQt6 / PySide6` | Heavyweight dependency; GUI event loop integration with background sim threads is complex |
| `pyglet` | Smaller ecosystem; fewer isometric game examples |
| `arcade` | Built on pyglet; adds abstraction layers not needed here |
| `pygame` (original) | Unmaintained; last release 2022; does not support Python 3.13+ |

## Decision
Adopt **pygame-ce** (Community Edition, `pygame-ce >= 2.4.0`) as the rendering backend.

Key reasons:
- Pure Python, minimal dependencies (SDL2 only)
- Hardware-accelerated 2D surfaces via `pygame.Surface` and `pygame.draw`
- Built-in sprite groups, layered rendering, and clock — all needed for the isometric renderer
- Active maintenance; tested with Python 3.13+
- Compatible with free-threaded Python (ADR-002): the render loop runs on the main thread while simulation advances on a daemon thread

**Pillow** (`>= 10.0.0`) is added for atlas pre-processing (normalize AI-generated PNGs to
64 × 32 isometric tiles) and for procedural placeholder tile generation.

**pytmx** is added to support loading `.tmx` / `.tmj` Tiled map files for the base city layout.

All three packages are **optional at runtime** — they are imported only inside the
`_run_with_gui()` code path activated by the `--gui` flag.  Headless runs have no
dependency on any of them.

## Consequences
- `requirements.txt` gains three new entries (`pygame-ce`, `Pillow`, `pytmx`)
- `src/gui/renderer/` is the sole location for all rendering code
- The renderer never imports from `src/simulation/` (beyond event types from `EventBus`)
- Visual randomness (tile dithering, decoration) must use `RandomService` with a fixed seed
  to preserve determinism (ADR-001)
- The `--gui` flag in `run.py` gates all graphical code; omitting it leaves behavior unchanged

## References
- Workstream: [Graphics](../design/workstreams/11-graphics.md)
- Spec: [Graphics](../specs/graphics.md)
- ADR-001: [Simulation Determinism](001-simulation-determinism.md)
- ADR-002: [Free-Threaded Python](002-free-threaded-python.md)
